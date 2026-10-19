import CoreGraphics
import EventKit
import Foundation

public enum CalendarEventServiceError: LocalizedError {
    case accessDenied
    case calendarUnavailable
    case serviceUnavailable(String)
    case saveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return Localizer.text("Calendar access was not granted. Enable ReminderSnap in System Settings → Privacy & Security → Calendars.")
        case .calendarUnavailable:
            return Localizer.text("ReminderSnap could not create or find a writable calendar for deadline blocks.")
        case .serviceUnavailable(let message):
            return Localizer.text("The macOS Calendar service is unavailable. Confirm Calendar access in System Settings, then reopen ReminderSnap and Calendar. (%@)", arguments: [message])
        case .saveFailed(let message):
            return Localizer.text("Could not save deadline blocks: %@", arguments: [Localizer.text(message)])
        }
    }
}

public enum CompanionBlockSchedule {
    /// For a 23:59 deadline this produces exactly 22:00–23:00. For other
    /// timed deadlines it preserves the same one-hour visualization window,
    /// ending 59 minutes before the real deadline. Date-only tasks use
    /// 22:00–23:00 on their due date.
    public static func range(for candidate: AssignmentCandidate) -> (start: Date, end: Date)? {
        guard let dueDate = candidate.dueDate else { return nil }
        if candidate.hasExplicitTime {
            return (
                dueDate.addingTimeInterval(-(119 * 60)),
                dueDate.addingTimeInterval(-(59 * 60))
            )
        }

        let timeZone = candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let day = calendar.dateComponents([.year, .month, .day], from: dueDate)
        var startComponents = DateComponents()
        startComponents.calendar = calendar
        startComponents.timeZone = timeZone
        startComponents.year = day.year
        startComponents.month = day.month
        startComponents.day = day.day
        startComponents.hour = 22
        startComponents.minute = 0
        guard let start = calendar.date(from: startComponents),
              let end = calendar.date(byAdding: .hour, value: 1, to: start) else { return nil }
        return (start, end)
    }
}

@MainActor
public final class CalendarEventService {
    public nonisolated static let defaultCalendarName = "ReminderSnap Deadlines"

    private var store = EKEventStore()
    private var observedPermission = PermissionState.current(for: .event)

    public init() {}

    public var permissionState: PermissionState { PermissionState.current(for: .event) }
    public var hasAccess: Bool { permissionState.canReadAndWrite }

    /// Called only while no write is in flight. Recreating the session clears
    /// EventKit data cached before authorization or a System Settings change.
    public func refreshAccess(reconnect: Bool = false) {
        let current = permissionState
        if reconnect || current != observedPermission {
            store.reset()
            store = EKEventStore()
        }
        observedPermission = current
    }

    public func calendars() -> [DestinationChoice] {
        guard hasAccess else { return [] }
        return store.calendars(for: .event).filter(\.allowsContentModifications).map {
            DestinationChoice(id: $0.calendarIdentifier, name: $0.title, account: $0.source.title)
        }.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    public func accounts() -> [AccountChoice] {
        guard hasAccess else { return [] }
        return store.sources.filter { [.local, .calDAV, .exchange].contains($0.sourceType) }.map {
            AccountChoice(id: $0.sourceIdentifier, name: $0.title)
        }
    }

    public func createCalendar(name: String, sourceID: String) throws -> DestinationChoice {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasAccess, !title.isEmpty, title.count <= 120,
              let source = store.sources.first(where: { $0.sourceIdentifier == sourceID }) else {
            throw CalendarEventServiceError.calendarUnavailable
        }
        if let existing = store.calendars(for: .event).first(where: {
            $0.source.sourceIdentifier == sourceID && $0.title.caseInsensitiveCompare(title) == .orderedSame && $0.allowsContentModifications
        }) { return DestinationChoice(id: existing.calendarIdentifier, name: existing.title, account: source.title) }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = title; calendar.source = source
        calendar.cgColor = CGColor(gray: 0.55, alpha: 1)
        do { try store.saveCalendar(calendar, commit: true) }
        catch { throw CalendarEventServiceError.saveFailed(Localizer.text("This account could not create a calendar. Choose an existing writable calendar or finish setup in Calendar. %@", arguments: [error.localizedDescription])) }
        return DestinationChoice(id: calendar.calendarIdentifier, name: calendar.title, account: source.title)
    }

    @MainActor
    public func requestAccess() async throws {
        do {
            let granted: Bool
            if #available(macOS 14.0, iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await withCheckedThrowingContinuation { continuation in
                    store.requestAccess(to: .event) { allowed, error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: allowed) }
                    }
                }
            }
            guard granted else { throw CalendarEventServiceError.accessDenied }
            refreshAccess(reconnect: true)
        } catch let error as CalendarEventServiceError {
            throw error
        } catch {
            throw CalendarEventServiceError.serviceUnavailable(error.localizedDescription)
        }
    }

    public func upsert(
        requests: [CompanionEventRequest],
        calendarName: String = CalendarEventService.defaultCalendarName,
        calendarID: String? = nil
    ) throws -> (created: Int, updated: Int, unchanged: Int) {
        guard !requests.isEmpty else { return (0, 0, 0) }
        try TaskBatchValidation.validate(requests.map(\.candidate))
        let calendar: EKCalendar
        if let calendarID, !calendarID.isEmpty {
            guard let selected = store.calendars(for: .event).first(where: {
                $0.calendarIdentifier == calendarID && $0.allowsContentModifications
            }) else { throw CalendarEventServiceError.calendarUnavailable }
            calendar = selected
        } else {
            calendar = try deadlineCalendar(named: calendarName)
        }
        let blocks = requests.compactMap { request -> (CompanionEventRequest, Date, Date)? in
            guard let range = CompanionBlockSchedule.range(for: request.candidate) else { return nil }
            return (request, range.start, range.end)
        }
        guard !blocks.isEmpty else { return (0, 0, 0) }

        let earliest = blocks.map(\.1).min()!.addingTimeInterval(-86_400)
        let latest = blocks.map(\.2).max()!.addingTimeInterval(86_400)
        let predicate = store.predicateForEvents(
            withStart: earliest,
            end: latest,
            calendars: [calendar]
        )
        let existing = store.events(matching: predicate)
        var created = 0
        var updated = 0
        var unchanged = 0
        // Only identifiers of app-owned events, never screenshot or OCR history.
        var identifiers = UserDefaults.standard.dictionary(forKey: "ReminderSnap.EventIdentifiers.v1") as? [String: String] ?? [:]
        var savedEvents: [(String, EKEvent)] = []

        do {
            for (request, start, end) in blocks {
                let candidate = request.candidate
                let marker = markerFor(candidate)
                let key = calendar.calendarIdentifier + "|" + candidate.identityKey
                let event: EKEvent
                let oldKeys = AssignmentIdentity.legacyKeys(for: candidate).map { calendar.calendarIdentifier + "|" + $0 }
                let tracked = ([key] + oldKeys).compactMap { identifiers[$0] }.compactMap { store.event(withIdentifier: $0) }
                var isExisting = false
                if let match = (tracked + existing).first(where: {
                    $0.calendar.calendarIdentifier == calendar.calendarIdentifier &&
                    TaskOwnership.matchesEvent(notes: $0.notes, title: $0.title, candidate: candidate)
                }) {
                    event = match
                    isExisting = true
                } else {
                    event = EKEvent(eventStore: store)
                    event.calendar = calendar
                }
                let before = EventSaveSnapshot(event)
                event.title = "DUE \(deadlineTime(candidate)) • \(candidate.reminderTitle)"
                event.startDate = start
                event.endDate = end
                event.isAllDay = false
                event.timeZone = candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
                event.notes = "\(marker)\nActual deadline: \(formattedDeadline(candidate))\nCreated by ReminderSnap."
                event.alarms?.forEach { event.removeAlarm($0) }
                if request.notifyAtStart {
                    event.addAlarm(EKAlarm(relativeOffset: 0))
                }
                let additionalDates = Set(request.additionalNotificationLeadTimes.map {
                    max(60, $0.rounded())
                })
                .map { candidate.dueDate!.addingTimeInterval(-$0) }
                .filter { $0 >= Date().addingTimeInterval(-60) }
                .sorted()
                for date in additionalDates where abs(date.timeIntervalSince(start)) >= 60 {
                    event.addAlarm(EKAlarm(absoluteDate: date))
                }
                savedEvents.append((key, event))
                if isExisting && before == EventSaveSnapshot(event) {
                    unchanged += 1
                    continue
                }
                try store.save(event, span: .thisEvent, commit: false)
                if isExisting { updated += 1 } else { created += 1 }
            }
            if created + updated > 0 { try store.commit() }
            for (key, event) in savedEvents { identifiers[key] = event.eventIdentifier }
            UserDefaults.standard.set(identifiers, forKey: "ReminderSnap.EventIdentifiers.v1")
            return (created, updated, unchanged)
        } catch {
            store.reset()
            throw CalendarEventServiceError.saveFailed(error.localizedDescription)
        }
    }

    private func deadlineCalendar(named name: String) throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: {
            $0.title.caseInsensitiveCompare(name) == .orderedSame && $0.allowsContentModifications
        }) {
            return existing
        }

        guard let source = store.defaultCalendarForNewEvents?.source else {
            throw CalendarEventServiceError.calendarUnavailable
        }

        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = name
        calendar.source = source
        calendar.cgColor = CGColor(red: 0.58, green: 0.52, blue: 0.95, alpha: 1)
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            throw CalendarEventServiceError.saveFailed(error.localizedDescription)
        }
    }

    private func markerFor(_ candidate: AssignmentCandidate) -> String {
        TaskOwnership.marker(for: candidate)
    }

    private func deadlineTime(_ candidate: AssignmentCandidate) -> String {
        guard let date = candidate.dueDate else { return "" }
        if !candidate.hasExplicitTime { return "ALL DAY" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formattedDeadline(_ candidate: AssignmentCandidate) -> String {
        guard let date = candidate.dueDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        formatter.dateStyle = .long
        formatter.timeStyle = candidate.hasExplicitTime ? .short : .none
        return formatter.string(from: date)
    }
}
