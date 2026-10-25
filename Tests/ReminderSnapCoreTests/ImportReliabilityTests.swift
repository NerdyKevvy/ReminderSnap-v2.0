import Foundation
import ReminderSnapCore

enum ImportReliabilityTests {
    static func run() throws {
        func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw NSError(domain: "ImportReliability", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }
        func line(_ text: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 0.15, slope: CGFloat = 0) -> OCRLine {
            OCRLine(text: text, boundingBox: CGRect(x: x, y: 1 - y - slope * (x + w / 2) - 0.007, width: w, height: 0.014))
        }
        for noise in ["* Status", "† Released", "20.0 / 20.0t", "19.5 / 20.0†", "• Submitted", "- / 100", "100.0%"] {
            try require(!TaskTextPolicy.isAssignmentTitle(noise), "Metadata escaped final gate: \(noise)")
        }
        for title in ["Problem Set 2", "History of the 20th Century", "Score analysis report", "Status of wetlands project"] {
            try require(TaskTextPolicy.isAssignmentTitle(title), "Over-filtered real assignment: \(title)")
        }
        var variations = 0
        for slope in [CGFloat(-0.08), 0, 0.07] {
            for left in [CGFloat(0.02), 0.13] {
                for statusBeforeDue in [true, false] {
                    let nameX = left, statusX: CGFloat = statusBeforeDue ? 0.37 : 0.77
                    let dueX: CGFloat = statusBeforeDue ? 0.77 : 0.48
                    var lines = [line("MA-UY 1124 Fall 2026", left, 0.04, 0.4, slope: slope),
                        line("Name", nameX, 0.15, 0.08, slope: slope),
                        line("* Status", statusX, 0.15, 0.10, slope: slope),
                        line("Due (EDT)", dueX, 0.15, 0.1, slope: slope)]
                    for index in 0..<4 {
                        let y = CGFloat(0.25) + CGFloat(index) * 0.15
                        lines += [line("Problem Set \(index)", nameX, y, 0.22, slope: slope),
                            line(index % 2 == 0 ? "20.0 / 20.0t" : "No Submission", statusX, y + 0.004, 0.15, slope: slope),
                            line("Nov \(index + 2), 2026 11:59 PM", dueX, y + 0.01, 0.20, slope: slope)]
                    }
                    let parsed = AssignmentParser().parse(documents: [OCRDocument(sourceName: "layout-\(variations)", lines: lines)])
                    try require(parsed.count == 4, "Slanted/reordered layout \(variations) omitted or invented assignments: \(parsed.map(\.assignmentName))")
                    try require(Set(parsed.map(\.assignmentName)) == Set((0..<4).map { "Problem Set \($0)" }), "Wrong title in layout \(variations)")
                    try require(parsed.allSatisfy { $0.dueDate != nil && $0.courseTag == "#MA1124" }, "Wrong course/date in layout \(variations)")
                    variations += 1
                }
            }
        }
        let unknown = OCRDocument(sourceName: "unknown-course", lines: [line("Essay 1", 0.1, 0.3), line("Due Nov 4, 2026 23:59", 0.1, 0.36, 0.4)])
        let known = OCRDocument(sourceName: "known-course", lines: [line("HIST 101 Fall 2026", 0.1, 0.1, 0.4), line("Essay 2", 0.1, 0.3), line("Due Nov 6, 2026 23:59", 0.1, 0.36, 0.4)])
        let mixed = AssignmentParser().parse(documents: [known, unknown])
        try require(mixed.first { $0.assignmentName == "Essay 1" }?.courseCode == "", "Unknown image inherited another image's course")
        let corrected = AssignmentParser().parse(documents: [known, unknown], context: ImportContext(courseOverrides: ["known-course": "History of Art", "unknown-course": "BIO 202"]))
        try require(corrected.first { $0.assignmentName == "Essay 2" }?.courseCode == "History of Art", "Per-image correction failed")
        try require(corrected.first { $0.assignmentName == "Essay 1" }?.courseCode == "BIO 202", "Per-image context leaked")
        let oldContext = ImportContext(course: "History", year: 2026, courseOverrides: ["photo": "History"])
        let next = oldContext.startingNewImport(replacingReview: true)
        try require(next.course.isEmpty && next.year == nil && next.courseOverrides.isEmpty, "Course context survived a new import")
        try require(oldContext.startingNewImport(replacingReview: false).course == "History", "Explicit first-import context lost")
        let profile = CourseProfile(name: "Wrong Course", section: "A2LB", year: 2026, colorIndex: 3)
        let renamed = profile.renamed("Biology")
        try require(renamed.name == "Biology" && renamed.id == "#BIOLOGY" && renamed.section == "A2LB", "Rename did not retain preferences")
        let marker = profile.tombstone()
        try require(marker.id == profile.id && marker.isDeleted == true && marker.name.isEmpty, "Course deletion marker cannot suppress an offline copy")
        var archived = profile; archived.isArchived = true
        var task = AssignmentCandidate(courseCode: "Wrong Course", assignmentName: "Lab report B1LB", dueDate: Date(), hasExplicitTime: true, sourcePlatform: .unknown, sourceImages: [], sectionCode: "B1LB")
        try require(SectionSelection.matches(task, profile: archived), "Archived section still filtered new imports")
        task.assignmentName = "20 / 20t"
        try require(!TaskTextPolicy.maySelectAutomatically(task), "A score can still be selected automatically")
        task.assignmentName = "Essay"; task.warnings = ["Some text has low recognition confidence; verify it."]
        try require(!TaskTextPolicy.maySelectAutomatically(task), "Uncertain OCR selected automatically")
        let encoded = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(CourseProfile.self, from: encoded)
        try require(decoded.isDeleted == nil && decoded.isArchived == nil, "Old course profiles lost decode compatibility")
        print("Import reliability: metadata rejection, \(variations) slanted/reordered tables, isolated course context, course rename/archive/tombstones passed.")
    }
}
