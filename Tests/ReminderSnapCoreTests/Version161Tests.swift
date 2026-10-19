import EventKit
import Foundation
import ReminderSnapCore

enum Version161Tests {
    @MainActor static func run() throws {
        try identitiesAndMigration()
        try schedulesAndNoOpSnapshots()
        print("v1.6.1 same-deadline, migration and no-op persistence regression tests passed (no live saves).")
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "ReminderSnap161Test", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    private static func candidate(_ name: String, deadline: String = "November 11, 2026 at 11:59 PM EST") throws -> AssignmentCandidate {
        guard let parsed = DeadlineParser.parse(deadline) else { throw NSError(domain: "Test", code: 1) }
        return AssignmentCandidate(courseCode: "MA-UY 2034", assignmentName: name, assignmentType: "Homework", questionCount: 22,
                                   dueDate: parsed.date, hasExplicitTime: parsed.hasExplicitTime, timeZoneIdentifier: parsed.timeZoneIdentifier,
                                   sourcePlatform: .webAssign, sourceImages: [])
    }

    private static func identitiesAndMigration() throws {
        let tasks = try ["H8 F26 Determinant", "H9 F26 Vectors", "H10 F26 Bases", "H11 F26. Transformations"].map { try candidate($0) }
        try require(Set(tasks.map(\.identityKey)).count == 4, "Equal deadlines merged different homework tasks")
        try TaskBatchValidation.validate(tasks)
        for task in tasks {
            try require(AssignmentIdentity.fromReminderTitle(task.reminderTitle) == task.identityKey, "Generated fall title fails to match its source")
        }
        let original = try candidate("H11_F26: Matrix and Linear Transformations")
        let edited = try candidate("H11 F 26 Matrix and Linear Transformations", deadline: "November 25, 2026 at 11:59 PM EST")
        try require(original.identityKey == edited.identityKey, "Date/title punctuation changes created a new identity")
        try require(original.identityKey != candidate("H11 S26 Matrix and Linear Transformations").identityKey, "Spring/Fall collide")
        try require(original.identityKey != candidate("H11 F25 Matrix and Linear Transformations").identityKey, "Years collide")
        let generic = try candidate("Worksheet 2")
        try require(AssignmentIdentity.fromReminderTitle(generic.reminderTitle) == generic.identityKey, "Question count caused duplicate generic task")
        var countChanged = generic; countChanged.questionCount = 9
        try require(AssignmentIdentity.fromReminderTitle(countChanged.reminderTitle) == generic.identityKey, "Question count affects identity")
        do {
            try TaskBatchValidation.validate([original, edited])
            throw NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Repeated identity accepted in batch"])
        } catch RemindersServiceError.conflictingTasks { /* expected */ }

        let oldMarker = "ReminderSnap-ID: " + AssignmentIdentity.legacyKeys(for: original)[0]
        try require(TaskOwnership.matchesEvent(notes: oldMarker, title: "DUE 23:59 • " + original.reminderTitle, candidate: edited), "Old fall block not migrated")
        let spring = try candidate("H11 S26 Matrix and Linear Transformations")
        let oldSpringMarker = "ReminderSnap-ID: " + AssignmentIdentity.legacyKeys(for: spring)[0]
        try require(!TaskOwnership.matchesEvent(notes: oldSpringMarker, title: "DUE 23:59 • " + spring.reminderTitle, candidate: original), "Adopted other-semester block")
        try require(TaskOwnership.matchesEvent(notes: oldSpringMarker, title: "DUE 23:59 • " + spring.reminderTitle, candidate: spring), "Old spring block not migrated")
        let marked = TaskOwnership.notes("My original notes", marking: original)
        try require(marked.hasPrefix("My original notes\n"), "User notes lost")
        try require(TaskOwnership.notes(marked, marking: original) == marked, "Reimport duplicates marker")
        try require(TaskOwnership.identity(in: marked) == original.identityKey, "Custom title lost tracked identity")
    }

    @MainActor private static func schedulesAndNoOpSnapshots() throws {
        // Objects are never saved, and no authorization is requested.
        let store = EKEventStore()
        for deadline in ["September 16, 2026 at 11:59 PM EDT", "November 11, 2026 at 11:59 PM EST"] {
            let tasks = try (8...11).map { try candidate("H\($0) F26 Task \($0)", deadline: deadline) }
            let reminders = tasks.map { task -> EKReminder in
                let reminder = EKReminder(eventStore: store)
                reminder.title = task.reminderTitle
                ReminderSchedule.apply(task, to: reminder)
                reminder.addAlarm(EKAlarm(absoluteDate: task.dueDate!))
                return reminder
            }
            for (task, reminder) in zip(tasks, reminders) {
                let due = reminder.dueDateComponents!
                try require(due.hour == 23 && due.minute == 59 && due.second == 0, "Midnight/day shift")
                try require(reminder.startDateComponents == reminder.dueDateComponents, "Start/due anchors differ")
                try require((reminder.recurrenceRules ?? []).isEmpty, "Unexpected recurrence")
                try require(ReminderSchedule.matches(reminder, candidate: task), "Saved date differs from source")
                let before = ReminderSaveSnapshot(reminder)
                ReminderSchedule.apply(task, to: reminder)
                try require(ReminderSaveSnapshot(reminder) == before, "Unchanged deadline is not a no-op")
                var moved = task; moved.dueDate = task.dueDate!.addingTimeInterval(7 * 86_400)
                ReminderSchedule.apply(moved, to: reminder)
                try require(!ReminderSchedule.matches(reminder, candidate: task), "Changed deadline not detected")
                try require(ReminderSaveSnapshot(reminder) != before, "Date update not saved")

                let event = EKEvent(eventStore: store)
                let range = CompanionBlockSchedule.range(for: task)!
                event.startDate = range.start; event.endDate = range.end; event.title = task.reminderTitle
                var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/New_York")!
                try require(calendar.component(.hour, from: range.start) == 22 && calendar.component(.hour, from: range.end) == 23, "Block time changed")
                try require(calendar.component(.day, from: range.start) == due.day, "Block moved to different day")
                let snapshot = EventSaveSnapshot(event)
                event.startDate = range.start; event.endDate = range.end
                try require(EventSaveSnapshot(event) == snapshot, "Unchanged block is not a no-op")
                event.startDate = range.start.addingTimeInterval(86_400)
                try require(EventSaveSnapshot(event) != snapshot, "Moved block not detected")
            }
        }
        var calendar = Calendar(identifier: .gregorian)
        let zone = TimeZone(identifier: "Asia/Shanghai")!
        calendar.timeZone = zone
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11))!
        var allDay = try candidate("Worksheet 2"); allDay.dueDate = date; allDay.hasExplicitTime = false; allDay.timeZoneIdentifier = zone.identifier
        let reminder = EKReminder(eventStore: store)
        ReminderSchedule.apply(allDay, to: reminder)
        try require(reminder.dueDateComponents?.day == 11 && reminder.dueDateComponents?.hour == nil, "All-day became midnight event")
        try require(reminder.dueDateComponents?.timeZone == nil && reminder.timeZone == nil, "All-day date is not floating")
        try require(ReminderSchedule.matches(reminder, candidate: allDay), "Floating all-day date mismatch")
        let saved = ReminderSaveSnapshot(reminder)
        ReminderSchedule.apply(allDay, to: reminder)
        try require(ReminderSaveSnapshot(reminder) == saved, "All-day reimport is not a no-op")
    }
}
