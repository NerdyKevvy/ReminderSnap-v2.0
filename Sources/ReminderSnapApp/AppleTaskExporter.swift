import EventKit
import Foundation
import ReminderSnapCore

/// Updates only positively identified app-owned items. Identifiers are local
/// to this device; stable task markers survive renames and deadline edits.
@MainActor
final class AppleTaskExporter {
    private var store = EKEventStore()
    private let registryKey = "Planner.AppleLinkedItems.v1"
    private struct ManagedAlarms: Codable {
        var absoluteDates: [Double]
        var relativeOffsets: [Double]
    }
    private let alarmRegistryKey = "Planner.AppleManagedAlarms.v1"
    private var alarmRegistry: [String: ManagedAlarms] {
        get {
            guard let data = UserDefaults.standard.data(forKey: alarmRegistryKey) else { return [:] }
            return (try? JSONDecoder().decode([String: ManagedAlarms].self, from: data)) ?? [:]
        }
        set { if let data = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(data, forKey: alarmRegistryKey) } }
    }

    /// Remove only alarms that this app recorded as its own. In particular,
    /// preserve location/early alerts the user adds in Apple's apps.
    private func applyAlarms(_ dates: [Date], to item: EKCalendarItem, task: SavedAssignment, kind: String) {
        let key = task.id.uuidString + "|" + kind
        var ledger = alarmRegistry
        var previous = ledger[key] ?? ManagedAlarms(absoluteDates: [], relativeOffsets: [])
        if kind == "reminder", ledger[key] == nil,
           let data = UserDefaults.standard.data(forKey: "ReminderSnap.ManagedNativeAlarms.v2"),
           let legacy = try? JSONDecoder().decode([String: ManagedAlarms].self, from: data) {
            let identity = item.calendar.calendarIdentifier + "|" + task.candidate.identityKey
            previous = legacy[identity] ?? legacy[task.candidate.identityKey] ?? previous
        }
        for alarm in item.alarms ?? [] {
            if let date = alarm.absoluteDate,
               previous.absoluteDates.contains(where: { abs($0 - date.timeIntervalSince1970) < 1 }) {
                item.removeAlarm(alarm)
            } else if alarm.absoluteDate == nil, alarm.structuredLocation == nil,
                      previous.relativeOffsets.contains(where: { abs($0 - alarm.relativeOffset) < 1 }) {
                item.removeAlarm(alarm)
            }
        }
        var added: [Double] = []
        for date in dates where date > Date() {
            guard !(item.alarms ?? []).contains(where: { alarm in
                alarm.absoluteDate.map { abs($0.timeIntervalSince(date)) < 1 } ?? false
            }) else { continue }
            item.addAlarm(EKAlarm(absoluteDate: date)); added.append(date.timeIntervalSince1970)
        }
        ledger[key] = ManagedAlarms(absoluteDates: added, relativeOffsets: [])
        alarmRegistry = ledger
    }
    private var registry: [String: [String: String]] {
        get { UserDefaults.standard.dictionary(forKey: registryKey) as? [String: [String: String]] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: registryKey) }
    }
    private func marker(_ task: SavedAssignment) -> String { "ReminderSnap-Task: " + task.id.uuidString }
    private func owned(_ item: EKCalendarItem, task: SavedAssignment) -> Bool {
        (item.notes ?? "").components(separatedBy: "\n").contains(marker(task))
    }
    private func notes(_ old: String?, task: SavedAssignment) -> String {
        var content = (old ?? "").components(separatedBy: "\n").filter { !$0.hasPrefix("ReminderSnap-Task: ") }
        if !content.contains(marker(task)) { content.append(marker(task)) }
        return content.filter { !$0.isEmpty }.joined(separator: "\n")
    }
    private func reminders(in list: EKCalendar) async -> [EKReminder] {
        let predicate = store.predicateForReminders(in: [list])
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { continuation.resume(returning: $0 ?? []) }
        }
    }
    func save(_ task: SavedAssignment, listID: String, calendarID: String, externalAlerts: Bool) async throws {
        store = EKEventStore()
        var links = registry[task.id.uuidString] ?? [:]
        if task.appleReminders {
            guard PermissionState.current(for: .reminder).canReadAndWrite else {
                throw CalendarConnectionError.message("Allow Reminders access to update this linked assignment.")
            }
            let old = links["reminder"].flatMap { store.calendarItem(withIdentifier: $0) as? EKReminder }
            let list = old?.calendar ?? store.calendar(withIdentifier: listID)
            guard let list, list.allowsContentModifications else { throw CalendarConnectionError.message("Choose a writable Reminders list in Settings.") }
            let existing = await reminders(in: list)
            let reminder = (old.flatMap { owned($0, task: task) ? $0 : nil }) ?? existing.first {
                owned($0, task: task) || TaskOwnership.identity(in: $0.notes) == task.candidate.identityKey
            } ?? EKReminder(eventStore: store)
            reminder.calendar = list; reminder.title = task.candidate.reminderTitle
            reminder.notes = notes(reminder.notes, task: task)
            ReminderSchedule.apply(task.candidate, to: reminder)
            reminder.isCompleted = task.isCompleted
            let reminderDates = externalAlerts && !task.isCompleted && task.candidate.hasExplicitTime ? [task.candidate.dueDate].compactMap { $0 } : []
            applyAlarms(reminderDates, to: reminder, task: task, kind: "reminder")
            try store.save(reminder, commit: true)
            links["reminder"] = reminder.calendarItemIdentifier
            var all = registry; all[task.id.uuidString] = links; registry = all
        }
        if task.appleCalendar {
            guard PermissionState.current(for: .event).canReadAndWrite else {
                throw CalendarConnectionError.message("Allow Calendar access to update this linked assignment.")
            }
            let old = links["event"].flatMap { store.event(withIdentifier: $0) }
            let calendar = old?.calendar ?? store.calendar(withIdentifier: calendarID)
            guard let calendar, calendar.allowsContentModifications,
                  let due = task.candidate.dueDate else { throw CalendarConnectionError.message("Choose a writable calendar in Settings.") }
            let start = min(due, old?.startDate ?? due).addingTimeInterval(-366 * 86400)
            let end = max(due, old?.endDate ?? due).addingTimeInterval(366 * 86400)
            let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: [calendar]))
            let event = (old.flatMap { owned($0, task: task) ? $0 : nil }) ?? events.first {
                owned($0, task: task) || TaskOwnership.matchesEvent(notes: $0.notes, title: $0.title, candidate: task.candidate)
            } ?? EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = (task.isCompleted ? "✓ " : "") + "DUE " + dueLabel(task.candidate) + " • " + task.candidate.reminderTitle
            event.notes = notes(event.notes, task: task)
            event.timeZone = task.candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
            if task.companionBlock, let range = CompanionBlockSchedule.range(for: task.candidate) {
                event.isAllDay = false; event.startDate = range.start; event.endDate = range.end
            } else {
                event.isAllDay = !task.candidate.hasExplicitTime; event.startDate = due
                if task.candidate.hasExplicitTime { event.endDate = due.addingTimeInterval(60) }
                else {
                    var day = Calendar(identifier: .gregorian); day.timeZone = event.timeZone ?? .current
                    event.endDate = day.date(byAdding: .day, value: 1, to: due)
                }
            }
            let eventDates = externalAlerts ? PlannerAlertSchedule.pending(tasks: [task]).map(\.date) : []
            applyAlarms(eventDates, to: event, task: task, kind: "event")
            try store.save(event, span: .thisEvent, commit: true)
            links["event"] = event.eventIdentifier
            var all = registry; all[task.id.uuidString] = links; registry = all
        }
    }

    func delete(_ task: SavedAssignment) throws {
        store = EKEventStore()
        guard let links = registry[task.id.uuidString] else { return }
        if links["reminder"] != nil && !PermissionState.current(for: .reminder).canReadAndWrite {
            throw CalendarConnectionError.message("Allow Reminders access to delete the linked reminder. Your assignment stays deleted in ReminderSnap.")
        }
        if links["event"] != nil && !PermissionState.current(for: .event).canReadAndWrite {
            throw CalendarConnectionError.message("Allow Calendar access to delete the linked planning block. Your assignment stays deleted in ReminderSnap.")
        }
        if let id = links["reminder"], let reminder = store.calendarItem(withIdentifier: id) as? EKReminder,
           owned(reminder, task: task) { try store.remove(reminder, commit: true) }
        if let id = links["event"], let event = store.event(withIdentifier: id), owned(event, task: task) {
            try store.remove(event, span: .thisEvent, commit: true)
        }
        var all = registry; all.removeValue(forKey: task.id.uuidString); registry = all
    }

    func eventIdentifier(for task: SavedAssignment) -> String? { registry[task.id.uuidString]?["event"] }
    func deleteCalendarBlock(_ task: SavedAssignment) throws {
        guard PermissionState.current(for: .event).canReadAndWrite else {
            throw CalendarConnectionError.message("Allow Calendar access to remove linked planning blocks.")
        }
        store = EKEventStore()
        var all = registry
        if let id = all[task.id.uuidString]?["event"], let event = store.event(withIdentifier: id) {
            guard owned(event, task: task) else { throw CalendarConnectionError.message("This calendar item is not owned by ReminderSnap; it was not deleted.") }
            try store.remove(event, span: .thisEvent, commit: true)
        }
        all[task.id.uuidString]?.removeValue(forKey: "event"); registry = all
    }
    private func dueLabel(_ task: AssignmentCandidate) -> String {
        guard let date = task.dueDate else { return "" }
        let formatter = DateFormatter(); formatter.timeZone = task.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        formatter.dateFormat = task.hasExplicitTime ? "HH:mm" : "MMM d"
        return formatter.string(from: date)
    }
}
