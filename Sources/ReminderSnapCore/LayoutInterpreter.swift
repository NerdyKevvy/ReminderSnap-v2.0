import Foundation
import CoreGraphics

/// Reconstruct semantic rows/cards before parsing dates. Never treat a status,
/// release date, or a date embedded in an assignment name as a separate task.
enum LayoutInterpreter {
    static func parse(_ document: OCRDocument, context: ImportContext) -> [AssignmentCandidate]? {
        let lines = document.lines.sorted { $0.topDownY < $1.topDownY }
        let labels = Set(lines.map { clean($0.text).lowercased() })
        if labels.contains("released"), labels.contains("status"),
           labels.contains(where: { $0.hasPrefix("due") }) {
            return table(document, context: context)
        }
        // Canvas mobile calendar cards expose a full timestamp and points.
        let courseCount = Set(lines.compactMap { CourseNormalizer.code(from: $0.text) }).count
        let mobileNavigationCount = lines.filter { ["dashboard", "to-do", "inbox", "notifications"].contains(clean($0.text).lowercased()) }.count
        if lines.contains(where: { $0.text.lowercased().contains("points") }),
           courseCount > 1 || mobileNavigationCount >= 2,
           lines.filter({ deadlineAnchor($0.text) }).count >= 1,
           lines.contains(where: { CourseNormalizer.code(from: $0.text) != nil }) {
            return cards(document, context: context)
        }
        return nil
    }

    private static func table(_ document: OCRDocument, context: ImportContext) -> [AssignmentCandidate] {
        let lines = document.lines
        guard let name = lines.first(where: { clean($0.text).lowercased() == "name" }),
              let status = lines.first(where: { clean($0.text).lowercased() == "status" }),
              let release = lines.first(where: { clean($0.text).lowercased() == "released" }),
              let due = lines.first(where: { clean($0.text).lowercased().hasPrefix("due") }) else { return [] }
        let headerY = max(name.topDownY, status.topDownY, release.topDownY, due.topDownY)
        let heights = lines.map(\.boundingBox.height).filter { $0 > 0 }.sorted()
        let h = heights.isEmpty ? CGFloat(0.02) : heights[heights.count / 2]
        let nameLimit = status.boundingBox.minX - h
        let deadlineLimit = (release.boundingBox.minX + due.boundingBox.minX) / 2
        let heading = lines.filter { $0.topDownY < headerY }.map(\.text).joined(separator: " ")
        let course = CourseNormalizer.code(from: heading) ?? context.course
        let year = courseYear(document.fullText) ?? context.year
        let zone = due.text.firstRegexMatch(pattern: #"\(([^)]+)\)"#)?.capture(1)
        let dates = lines.filter {
            $0.topDownY > headerY && $0.boundingBox.minX > deadlineLimit && deadlineAnchor($0.text) &&
            !$0.text.localizedCaseInsensitiveContains("late")
        }.sorted { $0.topDownY < $1.topDownY }
        var results: [AssignmentCandidate] = []
        for (index, date) in dates.enumerated() {
            let previous = index == 0 ? headerY : dates[index - 1].topDownY
            let next = index + 1 < dates.count ? dates[index + 1].topDownY : min(1.1, date.topDownY + max(h * 6, 0.1))
            let lower = index == 0 ? headerY : (previous + date.topDownY) / 2
            let upper = (date.topDownY + next) / 2
            let row = lines.filter { $0.topDownY > lower && $0.topDownY < upper }
            let titles = row.filter {
                $0.boundingBox.minX >= name.boundingBox.minX - h * 2 && $0.boundingBox.minX < nameLimit &&
                titleFragment($0.text)
            }.sorted { $0.topDownY < $1.topDownY }
            let title = titles.map { clean($0.text) }.joined(separator: " ")
            let statusText = row.filter {
                $0.centerX > nameLimit && $0.boundingBox.minX < release.boundingBox.minX - h &&
                statusLabel($0.text)
            }.map(\.text).joined(separator: " ")
            let text = date.text + (zone.map { " " + $0 } ?? "")
            var candidate = make(title: title, course: course, date: text, year: year,
                                 platform: .gradescope, document: document, context: context)
            candidate.sectionCode = section(in: title)
            candidate.submissionStatus = statusText.isEmpty ? nil : clean(statusText)
            if title.isEmpty { candidate.warnings.append("Assignment name missing; tap this task to enter it.") }
            if title.range(of: #"^(?:Homework|Lab|Worksheet)(?:\s+[A-Z])?$"#, options: [.regularExpression, .caseInsensitive]) != nil {
                candidate.warnings.append("Assignment number may be missing or unclear; compare the screenshot.")
            }
            results.append(candidate)
        }
        return results
    }

    private static func cards(_ document: OCRDocument, context: ImportContext) -> [AssignmentCandidate] {
        let lines = document.lines.sorted { $0.topDownY < $1.topDownY }
        let anchors = lines.filter { deadlineAnchor($0.text) && !isTitleWithEmbeddedDate($0.text) }
        var results: [AssignmentCandidate] = []
        var previousY: CGFloat = 0
        for anchor in anchors {
            let region = lines.filter {
                $0.topDownY > previousY && $0.topDownY < anchor.topDownY &&
                abs($0.boundingBox.minX - anchor.boundingBox.minX) < 0.15
            }
            defer { previousY = anchor.topDownY }
            guard let courseLine = region.last(where: { CourseNormalizer.code(from: $0.text) != nil }),
                  let course = CourseNormalizer.code(from: courseLine.text) else { continue }
            let afterCourse = region.filter { $0.topDownY > courseLine.topDownY }
            // A course name can wrap. Use the largest text-height cluster below
            // its code: Canvas titles are at least as large as course text.
            let candidates = afterCourse.filter { titleFragment($0.text) && !navigation($0.text) }
            guard !candidates.isEmpty else { continue }
            let maxHeight = candidates.map(\.boundingBox.height).max() ?? 0
            var titleLines = candidates.filter { $0.boundingBox.height >= maxHeight * 0.84 }
            if titleLines.count > 1, let first = titleLines.first,
               first.text.lowercased().hasPrefix("programming"),
               courseLine.text.localizedCaseInsensitiveContains("python") {
                titleLines.removeFirst()
            }
            // Course continuation often has the same font size. A code suffix
            // like "(20004)" belongs to the course, not the assignment.
            titleLines.removeAll { $0.text.trimmed.range(of: #"^\(?\d{4,6}\)?$"#, options: .regularExpression) != nil }
            let title = titleLines.map { clean($0.text) }.joined(separator: " ")
            guard !title.isEmpty else { continue }
            results.append(make(title: title, course: course, date: anchor.text,
                                year: courseYear(document.fullText) ?? context.year,
                                platform: .canvas, document: document, context: context))
        }
        return results
    }

    static func make(title: String, course: String, date: String, year: Int?, platform: SourcePlatform,
                     document: OCRDocument, context: ImportContext) -> AssignmentCandidate {
        let deadline = DeadlineParser.parse(date, fallbackYear: year, fallbackTimeZone: context.timeZoneIdentifier)
        var warnings: [String] = []
        if course.isEmpty { warnings.append("Course missing; choose a course or keep this task uncategorized.") }
        if !DeadlineParser.hasYear(date) {
            warnings.append(year == nil ? "Year missing; choose a batch year and re-read." : "Year supplied by the course or batch context; verify it.")
        }
        if deadline == nil { warnings.append("Deadline could not be validated; correct it before adding.") }
        return AssignmentCandidate(courseCode: course, assignmentName: title, dueDate: deadline?.date,
                                   hasExplicitTime: deadline?.hasExplicitTime ?? false,
                                   timeZoneIdentifier: deadline?.timeZoneIdentifier ?? context.timeZoneIdentifier,
                                   sourcePlatform: platform, sourceImages: [document.sourceName], warnings: warnings,
                                   sectionCode: section(in: title), sourceDeadlineText: date)
    }

    static func courseYear(_ text: String) -> Int? {
        if let match = text.firstRegexMatch(pattern: #"\b(?:Fall|Spring|Summer|Winter)\s+(20\d{2})\b"#, options: [.caseInsensitive]),
           let value = match.capture(1) { return Int(value) }
        return nil
    }
    static func section(in text: String) -> String? {
        text.firstRegexMatch(pattern: #"\b([A-Z]\d{1,2}L[AB]|[A-Z]\d{1,2}LB)\b"#)?.capture(1)
    }
    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: #"^[\s•●○◦·✓✔☑]+"#, with: "", options: .regularExpression).trimmed
    }
    private static func statusLabel(_ text: String) -> Bool {
        let value = clean(text).lowercased()
        return ["submitted", "no submission", "not submitted", "not complete", "completed"].contains(value) ||
            value.range(of: #"^\d+(?:\.\d+)?\s*/\s*\d+(?:\.\d+)?$"#, options: .regularExpression) != nil
    }
    private static func titleFragment(_ text: String) -> Bool {
        let value = clean(text)
        return !value.isEmpty && !statusLabel(value) && !navigation(value) &&
            !["name", "status", "released", "due", "attachments"].contains(value.lowercased()) &&
            !value.localizedCaseInsensitiveContains("days left") && !value.localizedCaseInsensitiveContains("hours left") &&
            (!DeadlineParser.containsDate(value) || isTitleWithEmbeddedDate(value))
    }
    private static func navigation(_ text: String) -> Bool {
        ["dashboard", "calendar", "calendars", "to-do", "notifications", "inbox", "october", "2026", "sun", "mon", "tue", "wed", "thu", "fri", "sat"].contains(clean(text).lowercased())
    }
    private static func isTitleWithEmbeddedDate(_ text: String) -> Bool {
        text.trimmed.hasPrefix("[") || text.localizedCaseInsensitiveContains("asynchronous class")
    }
    private static func deadlineAnchor(_ text: String) -> Bool {
        DeadlineParser.containsDate(text) && !text.localizedCaseInsensitiveContains("starts") &&
            !text.localizedCaseInsensitiveContains("class started") && !text.localizedCaseInsensitiveContains("late due")
    }
}
