import Foundation
import EventKit

public enum ReminderWriteDisposition: String, Sendable {
    case create
    case duplicate
    case updateDeadline
}

public struct ReminderMatch: Sendable {
    public let disposition: ReminderWriteDisposition
    public let calendarItemIdentifier: String?

    public init(disposition: ReminderWriteDisposition, calendarItemIdentifier: String? = nil) {
        self.disposition = disposition
        self.calendarItemIdentifier = calendarItemIdentifier
    }
}

public enum RemindersServiceError: LocalizedError {
    case accessDenied
    case listNotFound(String)
    case invalidCandidate(String)
    case conflictingTasks(String)
    case saveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return Localizer.text("Reminder access was not granted. Enable ReminderSnap in System Settings → Privacy & Security → Reminders.")
        case .listNotFound(let name):
            return Localizer.text("The reminder list “%@” was not found. Create it in Apple Reminders or choose another list.", arguments: [name])
        case .invalidCandidate(let name):
            return Localizer.text("“%@” does not have a valid course or deadline.", arguments: [name])
        case .conflictingTasks(let name):
            return Localizer.text("Two selected rows refer to “%@”. Select just one version before saving.", arguments: [name])
        case .saveFailed(let message):
            return Localizer.text("Could not save reminders: %@", arguments: [Localizer.text(message)])
        }
    }
}

@MainActor
public final class RemindersService {
    private var store = EKEventStore()
    private var observedPermission = PermissionState.current(for: .reminder)
    private var activeReads = 0
    private var reconnectPending = false
    private let legacyManagedAlarmsKey = "ReminderSnap.ManagedAlarmDates.v1"
    private let managedAlarmsKey = "ReminderSnap.ManagedNativeAlarms.v2"

    private struct ManagedAlarmRecord: Codable {
        var absoluteDates: [Double]
        var relativeOffsets: [Double]
    }

    public init() {}

    @MainActor
    public func requestAccess() async throws {
        let granted: Bool
        if #available(macOS 14.0, iOS 17.0, *) {
            granted = try await store.requestFullAccessToReminders()
        } else {
            granted = try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .reminder) { allowed, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: allowed) }
                }
            }
        }
        guard granted else { throw RemindersServiceError.accessDenied }
        store.reset()
        observedPermission = permissionState
    }

    public func listNames() -> [String] {
        store.calendars(for: .reminder).map(\.title).sorted()
    }

    public var permissionState: PermissionState { PermissionState.current(for: .reminder) }
    public var hasAccess: Bool { permissionState.canReadAndWrite }

    public func refreshAccess(reconnect: Bool = false) {
        if activeReads > 0 {
            reconnectPending = reconnectPending || reconnect || permissionState != observedPermission
            return
        }
        let current = permissionState
        if reconnect || current != observedPermission {
            store.reset()
            store = EKEventStore()
        }
        observedPermission = current
    }

    public func lists() -> [DestinationChoice] {
        guard hasAccess else { return [] }
        return store.calendars(for: .reminder).filter(\.allowsContentModifications).map {
            DestinationChoice(id: $0.calendarIdentifier, name: $0.title, account: $0.source.title)
        }.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    public func accounts() -> [AccountChoice] {
        guard hasAccess else { return [] }
        return store.sources.filter {
            !$0.calendars(for: .reminder).isEmpty || $0.sourceType == .local || $0.sourceType == .calDAV
        }.map { AccountChoice(id: $0.sourceIdentifier, name: $0.title) }
    }

    public func createList(name: String, sourceID: String) throws -> DestinationChoice {
        guard hasAccess else { throw RemindersServiceError.accessDenied }
        let title = name.trimmed
        guard !title.isEmpty, title.count <= 120 else {
            throw RemindersServiceError.saveFailed("Use a list name between 1 and 120 characters.")
        }
        guard let source = store.sources.first(where: { $0.sourceIdentifier == sourceID }) else {
            throw RemindersServiceError.saveFailed("No compatible account is available. Open Reminders, finish account setup, and check again.")
        }
        if let existing = store.calendars(for: .reminder).first(where: {
            $0.source.sourceIdentifier == sourceID && $0.title.caseInsensitiveCompare(title) == .orderedSame && $0.allowsContentModifications
        }) {
            return DestinationChoice(id: existing.calendarIdentifier, name: existing.title, account: source.title)
        }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = title; list.source = source
        list.cgColor = CGColor(gray: 0.55, alpha: 1)
        do { try store.saveCalendar(list, commit: true) }
        catch { throw RemindersServiceError.saveFailed(Localizer.text("This account could not create a reminder list. Open Reminders to finish setup, or choose another account. %@", arguments: [error.localizedDescription])) }
        return DestinationChoice(id: list.calendarIdentifier, name: list.title, account: source.title)
    }

    public func matches(
        candidates: [AssignmentCandidate],
        listName: String,
        listID: String? = nil
    ) async throws -> [UUID: ReminderMatch] {
        activeReads += 1
        defer {
            activeReads -= 1
            if activeReads == 0 && reconnectPending {
                reconnectPending = false
                refreshAccess(reconnect: true)
            }
        }
        guard let list = reminderList(named: listName, identifier: listID) else {
            throw RemindersServiceError.listNotFound(listName)
        }
        let existing = await fetchIncompleteReminders(in: list)
        var result: [UUID: ReminderMatch] = [:]

        let indexed = Dictionary(existing.map {
            (TaskOwnership.identity(in: $0.notes) ?? AssignmentIdentity.fromReminderTitle($0.title ?? ""), $0)
        }, uniquingKeysWith: { first, _ in first })
        for candidate in candidates {
            guard let reminder = indexed[candidate.identityKey] else {
                result[candidate.id] = ReminderMatch(disposition: .create)
                continue
            }

            if ReminderSchedule.matches(reminder, candidate: candidate) {
                result[candidate.id] = ReminderMatch(
                    disposition: .duplicate,
                    calendarItemIdentifier: reminder.calendarItemIdentifier
                )
            } else {
                result[candidate.id] = ReminderMatch(
                    disposition: .updateDeadline,
                    calendarItemIdentifier: reminder.calendarItemIdentifier
                )
            }
        }
        return result
    }

    public func write(
        requests: [ReminderWriteRequest],
        matches: [UUID: ReminderMatch],
        listName: String,
        listID: String? = nil
    ) throws -> (created: Int, updated: Int, unchanged: Int) {
        guard let list = reminderList(named: listName, identifier: listID) else {
            throw RemindersServiceError.listNotFound(listName)
        }

        var created = 0
        var updated = 0
        var unchanged = 0
        // Validate before staging changes. Equal dates never imply equal tasks.
        try TaskBatchValidation.validate(requests.map(\.candidate))
        var legacyManagedAlarms = loadLegacyManagedAlarms()
        var managedAlarms = loadManagedAlarms()
        do {
            for request in requests {
                let candidate = request.candidate
                let match = matches[candidate.id] ?? ReminderMatch(disposition: .create)
                let existing = match.calendarItemIdentifier.flatMap { store.calendarItem(withIdentifier: $0) as? EKReminder }
                let isExisting = existing?.calendar.calendarIdentifier == list.calendarIdentifier && existing?.isCompleted == false
                let reminder = isExisting ? existing! : EKReminder(eventStore: store)
                let before = ReminderSaveSnapshot(reminder)
                if !isExisting {
                    reminder.calendar = list
                }
                reminder.title = candidate.reminderTitle
                reminder.notes = TaskOwnership.notes(reminder.notes, marking: candidate)
                ReminderSchedule.apply(candidate, to: reminder)
                applyNativeAlarms(request, candidate: candidate, to: reminder,
                                  registry: &managedAlarms, legacyRegistry: &legacyManagedAlarms)
                if isExisting && before == ReminderSaveSnapshot(reminder) {
                    unchanged += 1
                    continue
                }
                try store.save(reminder, commit: false)
                if isExisting { updated += 1 } else { created += 1 }
            }
            if created + updated > 0 { try store.commit() }
            saveManagedAlarms(managedAlarms)
            saveLegacyManagedAlarms(legacyManagedAlarms)
            return (created, updated, unchanged)
        } catch let error as RemindersServiceError {
            store.reset()
            throw error
        } catch {
            store.reset()
            throw RemindersServiceError.saveFailed(error.localizedDescription)
        }
    }

    private func reminderList(named name: String, identifier: String? = nil) -> EKCalendar? {
        if let identifier, !identifier.isEmpty {
            return store.calendars(for: .reminder).first { $0.calendarIdentifier == identifier && $0.allowsContentModifications }
        }
        return store.calendars(for: .reminder).first {
            $0.allowsContentModifications &&
            $0.title.caseInsensitiveCompare(name.trimmed) == .orderedSame
        }
    }

    private func fetchIncompleteReminders(in list: EKCalendar) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            let predicate = store.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: [list]
            )
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private func applyNativeAlarms(
        _ request: ReminderWriteRequest,
        candidate: AssignmentCandidate,
        to reminder: EKReminder,
        registry: inout [String: ManagedAlarmRecord],
        legacyRegistry: inout [String: [Double]]
    ) {
        guard let dueDate = candidate.dueDate else { return }
        let identity = reminder.calendar.calendarIdentifier + "|" + candidate.identityKey
        let oldKeys = [candidate.identityKey] + AssignmentIdentity.legacyKeys(for: candidate)
        let legacyAbsoluteDates = oldKeys.flatMap { legacyRegistry[$0] ?? [] }
        let previous = registry[identity] ?? oldKeys.compactMap { registry[$0] }.first ?? ManagedAlarmRecord(absoluteDates: [], relativeOffsets: [])

        // Migrate v1.3 absolute alarms, then remove only alarms recorded as
        // ReminderSnap-managed. Unrelated alarms added by the user survive.
        for alarm in reminder.alarms ?? [] {
            if let date = alarm.absoluteDate,
               (legacyAbsoluteDates + previous.absoluteDates).contains(where: {
                   abs($0 - date.timeIntervalSince1970) < 60
               }) {
                reminder.removeAlarm(alarm)
                continue
            }
            if alarm.absoluteDate == nil,
               previous.relativeOffsets.contains(where: { abs($0 - alarm.relativeOffset) < 1 }) {
                reminder.removeAlarm(alarm)
            }
        }

        var desiredAbsoluteDates: [Date] = []
        let desiredRelativeOffsets: [TimeInterval] = []

        if request.deadlineNotificationEnabled, dueDate >= Date().addingTimeInterval(-60) {
            desiredAbsoluteDates.append(dueDate)
        }

        // Public EventKit does not expose Apple Reminders' Early Reminder
        // field. Replace the v1.4 early-alert anchor with the actual deadline.
        // Setting nil is not reliable: EventKit may synthesize a start again.
        reminder.startDateComponents = reminder.dueDateComponents

        var existingAbsoluteDates = (reminder.alarms ?? []).compactMap(\.absoluteDate)
        for date in desiredAbsoluteDates where !existingAbsoluteDates.contains(where: {
            abs($0.timeIntervalSince(date)) < 60
        }) {
            reminder.addAlarm(EKAlarm(absoluteDate: date))
            existingAbsoluteDates.append(date)
        }

        let existingRelativeOffsets = (reminder.alarms ?? [])
            .filter { $0.absoluteDate == nil }
            .map(\.relativeOffset)
        for offset in desiredRelativeOffsets where !existingRelativeOffsets.contains(where: {
            abs($0 - offset) < 1
        }) {
            reminder.addAlarm(EKAlarm(relativeOffset: offset))
        }

        registry[identity] = ManagedAlarmRecord(
            absoluteDates: desiredAbsoluteDates.map(\.timeIntervalSince1970),
            relativeOffsets: desiredRelativeOffsets
        )
        for key in oldKeys { legacyRegistry.removeValue(forKey: key) }
    }

    private func loadLegacyManagedAlarms() -> [String: [Double]] {
        guard let data = UserDefaults.standard.data(forKey: legacyManagedAlarmsKey),
              let decoded = try? JSONDecoder().decode([String: [Double]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveLegacyManagedAlarms(_ registry: [String: [Double]]) {
        guard let data = try? JSONEncoder().encode(registry) else { return }
        UserDefaults.standard.set(data, forKey: legacyManagedAlarmsKey)
    }

    private func loadManagedAlarms() -> [String: ManagedAlarmRecord] {
        guard let data = UserDefaults.standard.data(forKey: managedAlarmsKey),
              let decoded = try? JSONDecoder().decode([String: ManagedAlarmRecord].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveManagedAlarms(_ registry: [String: ManagedAlarmRecord]) {
        guard let data = try? JSONEncoder().encode(registry) else { return }
        UserDefaults.standard.set(data, forKey: managedAlarmsKey)
    }
}
