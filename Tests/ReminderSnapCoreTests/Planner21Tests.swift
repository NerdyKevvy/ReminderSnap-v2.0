import Foundation
import ReminderSnapCore

enum Planner21Tests {
    static func run() throws {
        func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw NSError(domain: "Planner21Tests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        func line(_ text: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 0.3, _ h: CGFloat = 0.02) -> OCRLine {
            OCRLine(text: text, boundingBox: CGRect(x: x, y: 1 - y - h / 2, width: w, height: h))
        }
        let routedLink = GoogleCalendarEventLink.url("https://calendar.google.com/calendar/event?eid=synthetic&authuser=0", email: "owner+calendar@example.com")!
        let routedQuery = URLComponents(url: routedLink, resolvingAgainstBaseURL: false)!.queryItems!
        try require(routedQuery.filter { $0.name == "authuser" }.map(\.value) == ["owner+calendar@example.com"], "Open event under connected Google account, replacing browser default")
        try require(routedQuery.contains { $0.name == "eid" && $0.value == "synthetic" }, "Preserve event identity when routing account")
        let apiLink = GoogleCalendarEventLink.url("https://www.google.com/calendar/event?eid=synthetic", email: "owner@example.com")
        try require(apiLink?.host == "calendar.google.com" && apiLink?.path == "/calendar/event", "Normalize Google's documented API htmlLink to Calendar before account routing")
        try require(GoogleCalendarEventLink.url("https://www.google.com/search", email: "owner@example.com") == nil, "Only Calendar event paths may receive account routing")
        try require(GoogleCalendarEventLink.url("https://example.com/event", email: "owner@example.com") == nil, "Do not attach account identity to an unrelated host")
        try require(GoogleCalendarEventLink.url("http://calendar.google.com/event", email: "owner@example.com") == nil, "Require secure Google event links")
        try require(GoogleCalendarEventLink.url("https://calendar.google.com/event", email: " ") == nil, "Missing account cannot silently use a different browser account")
        try require(CourseNormalizer.code(from: "FA26_CS-UY_1114") == "CS-UY 1114", "Underscored NYU course")
        try require(CourseNormalizer.code(from: "I&C SCI 31: F26: Intro to Python") == "I&C SCI 31", "UCI computing course")
        try require(CourseNormalizer.code(from: "AC ENG 20A LEC E: ACADEMIC WRITING") == "AC ENG 20A", "UCI writing course")
        try require(CourseNormalizer.code(from: "Homework 6") == nil, "Assignment must not become course")
        let headers = [line("FA26_CS-UY_1114", 0.01, 0.04), line("Fall 2026", 0.4, 0.04),
            line("Name", 0.01, 0.12, 0.06), line("Status", 0.3, 0.12, 0.07),
            line("Released", 0.48, 0.12, 0.1), line("Due (EDT)", 0.86, 0.12, 0.1)]
        let table = OCRDocument(sourceName: "synthetic-table", lines: headers + [
            line("Homework", 0.01, 0.22, 0.15), line("8", 0.01, 0.25, 0.02),
            line("No Submission", 0.3, 0.23, 0.15), line("Oct 20 at 12:00AM", 0.48, 0.27, 0.18), line("Nov 03 at 11:59PM", 0.82, 0.27, 0.17),
            line("Homework 7", 0.01, 0.42, 0.17), line("Submitted", 0.3, 0.42, 0.15),
            line("Oct 13 at 12:00AM", 0.48, 0.43, 0.18), line("Oct 27 at 11:59PM", 0.82, 0.43, 0.17)
        ])
        let parsed = AssignmentParser().parse(documents: [table])
        try require(parsed.count == 2, "Table must yield two tasks, not statuses")
        try require(parsed.contains { $0.assignmentName == "Homework 8" }, "Join wrapped Homework and number")
        try require(parsed.allSatisfy { $0.courseCode == "CS-UY 1114" }, "Apply underscore course")
        try require(parsed.allSatisfy { $0.hasExplicitTime && $0.dueDate != nil }, "Parse due dates, not release dates")
        try require(parsed.contains { $0.submissionStatus == "Submitted" }, "Keep status separately")
        let ambiguousTable = OCRDocument(sourceName: "synthetic-unclear-numbers", lines: headers + [
            line("Homework", 0.01, 0.22, 0.15), line("Nov 03 at 11:59PM", 0.82, 0.27, 0.17),
            line("Homework", 0.01, 0.42, 0.15), line("Oct 27 at 11:59PM", 0.82, 0.43, 0.17)
        ])
        let unclear = AssignmentParser().parse(documents: [ambiguousTable])
        try require(unclear.count == 2, "Unclear numbers must not collapse multiple Homework rows")
        try require(unclear.allSatisfy { $0.warnings.contains(where: { $0.contains("number") }) }, "Unclear numbers require verification")

        let canvas = OCRDocument(sourceName: "synthetic-canvas", lines: [
            line("I&C SCI 31: F26: Intro to Python", 0.15, 0.2, 0.7, 0.025),
            line("Programming", 0.15, 0.235, 0.4, 0.025),
            line("Mini-Lecture/Formative Assessment -", 0.15, 0.28, 0.7, 0.03),
            line("Ch4", 0.15, 0.32, 0.15, 0.03),
            line("Oct 22, 2026 at 14:00 | 10 points", 0.15, 0.37, 0.7, 0.025),
            line("AC ENG 20A LEC E: ACADEMIC WRITING", 0.15, 0.49, 0.75, 0.025),
            line("(20004)", 0.15, 0.53, 0.2, 0.025),
            line("[Asynchronous Class 10/22] Academic", 0.15, 0.58, 0.7, 0.03),
            line("Language and Style", 0.15, 0.62, 0.5, 0.03),
            line("Oct 22, 2026 at 23:59 | 10 points", 0.15, 0.68, 0.7, 0.025)
        ])
        let cards = AssignmentParser().parse(documents: [canvas])
        try require(cards.count == 2, "Canvas must not split the embedded 10/22 date into a phantom task")
        try require(cards.contains { $0.assignmentName == "Mini-Lecture/Formative Assessment - Ch4" && $0.courseCode == "I&C SCI 31" }, "Full Canvas computing card")
        try require(cards.contains { $0.assignmentName == "[Asynchronous Class 10/22] Academic Language and Style" && $0.courseCode == "AC ENG 20A" }, "Full Canvas writing card")

        let due = DeadlineParser.parse("November 3, 2026 at 11:59 PM EST")!
        var candidate = AssignmentCandidate(courseCode: "CM-UY 2211", assignmentName: "Experiment 3 Lab Report A2LB", dueDate: due.date, hasExplicitTime: true,
            timeZoneIdentifier: due.timeZoneIdentifier, sourcePlatform: .gradescope, sourceImages: ["private-photo.jpg"], sectionCode: "A2LB")
        let own = CourseProfile(name: "CM-UY 2211", section: "A2LB")
        try require(SectionSelection.matches(candidate, profile: own), "Own section visible")
        candidate.sectionCode = "B1LB"
        try require(!SectionSelection.matches(candidate, profile: own), "Other section filtered")
        candidate.sectionCode = nil; candidate.assignmentName = "Shared worksheet"
        try require(SectionSelection.matches(candidate, profile: own), "Shared tasks retained")
        let now = due.date.addingTimeInterval(-3 * 86400)
        var saved = SavedAssignment(candidate: candidate)
        let alerts = PlannerAlertSchedule.pending(tasks: [saved], now: now)
        try require(alerts.count == 2, "Two configurable app alerts")
        try require(alerts.map(\.date).contains(due.date.addingTimeInterval(-86400)), "Day-before anchored to deadline")
        try require(alerts.map(\.date).contains(due.date.addingTimeInterval(-7200)), "Two-hours-before anchored to deadline")
        try require(saved.candidate.sourceImages.isEmpty, "No screenshots/filenames in synced tasks")
        let same = SavedAssignment(candidate: candidate)
        try require(same.id == saved.id, "Deterministic cross-device task identity")
        saved.isCompleted = true
        try require(PlannerAlertSchedule.pending(tasks: [saved], now: now).isEmpty, "Completion cancels app alerts")
        saved.isCompleted = false; saved.isDeleted = true
        try require(PlannerAlertSchedule.pending(tasks: [saved], now: now).isEmpty, "Deletion cancels app alerts")
        try require(PlannerAlertSchedule.pending(tasks: [same], now: now, limit: 1).count == 1, "Bound notification queue")
        let data = try JSONEncoder().encode(same)
        let decoded = try JSONDecoder().decode(SavedAssignment.self, from: data)
        try require(decoded.id == same.id, "Persistent/synced round trip")
        var deleted = same
        deleted.workflow = .google; deleted.googleAccountID = "synthetic-account"; deleted.googleEventID = "synthetic-event"
        deleted.isDeleted = true; deleted.eraseDeletedContent()
        try require(deleted.candidate.assignmentName.isEmpty && deleted.googleEventID != nil, "Pending deletion retains only cleanup links, not task content")
        deleted.exportedAt = Date().addingTimeInterval(1); deleted.eraseDeletedContent()
        try require(deleted.googleAccountID == nil && deleted.googleEventID == nil, "Completed deletion strips account and event links")
        let allDay = DeadlineParser.parse("November 1, 2026", fallbackTimeZone: "America/New_York")!
        var dayTask = SavedAssignment(candidate: AssignmentCandidate(courseCode: "", assignmentName: "Date-only task", dueDate: allDay.date,
            hasExplicitTime: false, timeZoneIdentifier: "America/New_York", sourcePlatform: .unknown, sourceImages: []))
        dayTask.dateOnlyAlertHour = 9
        var eastern = Calendar(identifier: .gregorian); eastern.timeZone = TimeZone(identifier: "America/New_York")!
        let morningAlerts = PlannerAlertSchedule.pending(tasks: [dayTask], now: allDay.date.addingTimeInterval(-3 * 86400))
        try require(morningAlerts.count == 2 && morningAlerts.allSatisfy { eastern.component(.hour, from: $0.date) == 9 }, "Date-only morning alerts preserve local hour across DST")
        try require(!dayTask.isOverdue(at: allDay.date.addingTimeInterval(12 * 3600)), "Date-only task not overdue at noon")
        try require(dayTask.isOverdue(at: allDay.date.addingTimeInterval(2 * 86400)), "Date-only task overdue after day ends")
        print("2.1 Gradescope/Canvas, courses, sections, identities, privacy and notification regression tests passed.")
    }
}
