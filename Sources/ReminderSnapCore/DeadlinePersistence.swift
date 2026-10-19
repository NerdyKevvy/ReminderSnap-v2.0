import EventKit
import Foundation

/// Minute-precision deadlines, never an early-alert date or companion range.
public enum ReminderSchedule {
    public static func components(for candidate: AssignmentCandidate) -> DateComponents? {
        guard let date = candidate.dueDate else { return nil }
        let zone = candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        var result = calendar.dateComponents([.year, .month, .day], from: date)
        result.calendar = calendar
        if candidate.hasExplicitTime {
            result.timeZone = zone
            let time = calendar.dateComponents([.hour, .minute], from: date)
            result.hour = time.hour; result.minute = time.minute; result.second = 0
        }
        // Date-only reminders are floating dates. No midnight UTC conversion.
        return result
    }

    public static func apply(_ candidate: AssignmentCandidate, to reminder: EKReminder) {
        guard let due = components(for: candidate) else { return }
        reminder.timeZone = due.timeZone
        reminder.dueDateComponents = due
        // Some EventKit versions synthesize a start when due is assigned, even
        // after setting start to nil. Explicitly align both; never anchor the
        // task at a one-day-before notification or companion block time.
        reminder.startDateComponents = due
    }

    public static func matches(_ reminder: EKReminder, candidate: AssignmentCandidate) -> Bool {
        guard let actual = reminder.dueDateComponents, let expected = components(for: candidate) else { return false }
        if !candidate.hasExplicitTime {
            return actual.hour == nil && actual.minute == nil &&
                actual.year == expected.year && actual.month == expected.month && actual.day == expected.day
        }
        guard actual.hour != nil, actual.minute != nil else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = actual.timeZone ?? reminder.timeZone ?? .current
        guard let date = calendar.date(from: actual), let expectedDate = candidate.dueDate else { return false }
        return abs(date.timeIntervalSince(expectedDate)) < 60
    }
}

public enum TaskOwnership {
    public static func marker(for candidate: AssignmentCandidate) -> String { "ReminderSnap-ID: \(candidate.identityKey)" }

    public static func identity(in notes: String?) -> String? {
        let prefix = "ReminderSnap-ID: "
        return notes?.components(separatedBy: "\n").first(where: { $0.hasPrefix(prefix) }).map { String($0.dropFirst(prefix.count)) }
    }

    public static func notes(_ notes: String?, marking candidate: AssignmentCandidate) -> String {
        let otherLines = (notes ?? "").components(separatedBy: "\n").filter { !$0.hasPrefix("ReminderSnap-ID: ") }
        let content = otherLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
        return content.isEmpty ? marker(for: candidate) : content + "\n" + marker(for: candidate)
    }

    public static func matchesEvent(notes: String?, title: String?, candidate: AssignmentCandidate) -> Bool {
        guard let identity = identity(in: notes) else { return false }
        if identity == candidate.identityKey { return true }
        let taskTitle = (title ?? "").components(separatedBy: " • ").dropFirst().joined(separator: " • ")
        return AssignmentIdentity.legacyKeys(for: candidate).contains(identity) &&
            AssignmentIdentity.fromReminderTitle(taskTitle) == candidate.identityKey
    }
}

/// Compare the actual fields we mutate, before deciding to save. An unchanged
/// reimport should not generate another EventKit/iCloud change notification.
public struct ReminderSaveSnapshot: Equatable {
    private let title: String?
    private let notes: String?
    private let due: DateSaveSnapshot?
    private let start: DateSaveSnapshot?
    private let zone: String?
    private let alarms: [AlarmSaveSnapshot]
    public init(_ reminder: EKReminder) {
        title = reminder.title; notes = reminder.notes
        due = reminder.dueDateComponents.map(DateSaveSnapshot.init)
        start = reminder.startDateComponents.map(DateSaveSnapshot.init)
        zone = reminder.timeZone?.identifier
        alarms = (reminder.alarms ?? []).map(AlarmSaveSnapshot.init)
    }
}

public struct EventSaveSnapshot: Equatable {
    private let title: String?
    private let notes: String?
    private let start: Date?
    private let end: Date?
    private let allDay: Bool
    private let zone: String?
    private let alarms: [AlarmSaveSnapshot]
    public init(_ event: EKEvent) {
        title = event.title; notes = event.notes; start = event.startDate; end = event.endDate
        allDay = event.isAllDay; zone = event.timeZone?.identifier
        alarms = (event.alarms ?? []).map(AlarmSaveSnapshot.init)
    }
}

private struct AlarmSaveSnapshot: Equatable {
    let date: Date?
    let offset: TimeInterval
    init(_ alarm: EKAlarm) {
        date = alarm.absoluteDate
        offset = date == nil ? alarm.relativeOffset : 0
    }
}

private struct DateSaveSnapshot: Equatable {
    let year: Int?, month: Int?, day: Int?, hour: Int?, minute: Int?, second: Int?
    let zone: String?
    init(_ date: DateComponents) {
        year = date.year; month = date.month; day = date.day
        hour = date.hour; minute = date.minute
        second = hour == nil ? nil : (date.second ?? 0)
        zone = date.timeZone?.identifier
        // EventKit can reconstruct the Calendar value on fetch. Compare
        // semantic fields, not an incidental Calendar cache representation.
    }
}

public enum TaskBatchValidation {
    public static func validate(_ candidates: [AssignmentCandidate]) throws {
        var seen = Set<String>()
        for candidate in candidates {
            guard !candidate.courseCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  candidate.dueDate != nil else {
                throw RemindersServiceError.invalidCandidate(candidate.assignmentName)
            }
            guard seen.insert(candidate.identityKey).inserted else {
                throw RemindersServiceError.conflictingTasks(candidate.assignmentName)
            }
        }
    }
}
