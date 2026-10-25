import Foundation
import ReminderSnapCore

@main enum CourseStoreCheck {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReminderSnap-course-check-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PlannerStore(storeDirectory: root)
        await store.open()
        func require(_ condition: @autoclosure () -> Bool, _ text: String) throws {
            guard condition() else { throw NSError(domain: "CourseStoreCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: text]) }
        }
        try require(store.ready && !store.iCloudAvailable, "Must use isolated local test storage")
        let profile = CourseProfile(name: "Misread history", section: "A2LB", year: 2026, colorIndex: 3)
        try store.save(profile)
        var task = SavedAssignment(candidate: AssignmentCandidate(courseCode: profile.name, assignmentName: "Essay 1", dueDate: Date(), hasExplicitTime: true, sourcePlatform: .unknown, sourceImages: []), workflow: .google)
        task.googleEventID = "synthetic-event"; task.googleCalendarID = "synthetic-calendar"
        task.googleAccountID = "synthetic-account"; task.exportedAt = Date()
        try store.save(task)
        let other = SavedAssignment(candidate: AssignmentCandidate(courseCode: "Biology", assignmentName: "Lab", dueDate: Date(), hasExplicitTime: true, sourcePlatform: .unknown, sourceImages: []))
        try store.save(other)
        try store.replaceCourse(profile, with: profile.renamed("Correct history"))
        let renamed = store.courses.first!
        try require(store.courses.count == 1 && renamed.name == "Correct history", "Rename left duplicate course")
        let edited = store.tasks.first { $0.id == task.id }!
        try require(edited.candidate.courseCode == "Correct history" && edited.googleEventID == "synthetic-event" && edited.needsExport, "Rename lost task identity/link or did not queue linked edit")
        try require(store.tasks.first { $0.id == other.id }?.candidate.courseCode == "Biology", "Rename touched unrelated course")
        var archived = renamed; archived.isArchived = true; archived.modifiedAt = Date()
        try store.replaceCourse(renamed, with: archived)
        try store.deleteCourse(archived)
        try require(store.courses.isEmpty && store.tasks.count == 2, "Deleting preferences deleted assignments")
        store.reload()
        try require(store.courses.isEmpty, "Deleted course resurfaced after reload")
        let reopened = PlannerStore(storeDirectory: root)
        await reopened.open()
        try require(reopened.ready && reopened.courses.isEmpty && reopened.tasks.count == 2, "Course/task changes did not persist after reopening")
        print("Isolated course-store checks passed: rename, retained links, unrelated tasks, archive, deletion tombstone and reopen. No personal databases or calendars accessed.")
    }
}
