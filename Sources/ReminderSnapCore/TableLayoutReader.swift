import Foundation
import CoreGraphics

/// Recover column roles first, then rows. Correct a modest shared baseline
/// slope so a photograph need not have perfectly horizontal text.
enum TableLayoutReader {
    static func parse(_ document: OCRDocument, context: ImportContext) -> [AssignmentCandidate]? {
        let lines = document.lines
        func label(_ line: OCRLine) -> String {
            TaskTextPolicy.clean(line.text).lowercased().trimmingCharacters(in: .punctuationCharacters)
        }
        guard let name = lines.first(where: { ["name", "assignment", "current assignments"].contains(label($0)) }),
              let due = lines.first(where: { label($0).hasPrefix("due") && !DeadlineParser.containsDate($0.text) && abs($0.topDownY - name.topDownY) < 0.12 }) else { return nil }
        let headers = lines.filter {
            abs($0.topDownY - name.topDownY) < 0.12 &&
            (["name", "assignment", "current assignments", "status", "submission status", "released", "release date", "score", "scores"].contains(label($0)) || $0.text == due.text)
        }.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        guard headers.count >= 3 else { return nil }
        let heights = lines.map(\.boundingBox.height).filter { $0 > 0 }.sorted()
        let h = heights.isEmpty ? CGFloat(0.02) : heights[heights.count / 2]
        let meanX = headers.map(\.centerX).reduce(0, +) / CGFloat(headers.count)
        let meanY = headers.map(\.topDownY).reduce(0, +) / CGFloat(headers.count)
        let denominator = headers.reduce(CGFloat(0)) { $0 + pow($1.centerX - meanX, 2) }
        let slope = denominator > 0.01 ? max(-0.18, min(0.18, headers.reduce(CGFloat(0)) {
            $0 + ($1.centerX - meanX) * ($1.topDownY - meanY)
        } / denominator)) : 0
        func y(_ line: OCRLine) -> CGFloat { line.topDownY - slope * (line.centerX - name.centerX) }
        let headerY = headers.map(y).max() ?? name.topDownY
        let nextName = headers.first { $0.boundingBox.minX > name.boundingBox.minX + h }
        let titleRight = (nextName?.boundingBox.minX ?? due.boundingBox.minX) - h * 0.35
        let previousDue = headers.last { $0.centerX < due.centerX && $0.text != due.text }
        let nextDue = headers.first { $0.centerX > due.centerX }
        let dueLeft = previousDue.map { ($0.boundingBox.minX + due.boundingBox.minX) / 2 } ?? due.boundingBox.minX - h * 2
        let dueRight = nextDue.map { ($0.boundingBox.minX + due.boundingBox.maxX) / 2 } ?? 1.1
        let dates = lines.filter {
            y($0) > headerY + h * 0.5 && $0.centerX > dueLeft && $0.centerX < dueRight &&
            DeadlineParser.containsDate($0.text) && !$0.text.localizedCaseInsensitiveContains("late") &&
            !$0.text.localizedCaseInsensitiveContains("starts")
        }.sorted { y($0) < y($1) }
        guard !dates.isEmpty else { return nil }
        let course = context.courseOverrides[document.sourceName] ?? CourseEvidence.code(in: document, before: name.topDownY) ?? context.course
        let year = LayoutInterpreter.courseYear(document.fullText) ?? context.year
        let zone = due.text.firstRegexMatch(pattern: #"\(([^)]+)\)"#)?.capture(1)
        let webAssign = document.fullText.localizedCaseInsensitiveContains("webassign") ||
            document.fullText.localizedCaseInsensitiveContains("current assignments")
        return dates.enumerated().compactMap { index, date in
            let lower = index == 0 ? headerY + h * 0.5 : (y(dates[index - 1]) + y(date)) / 2
            let upper = index + 1 < dates.count ? (y(date) + y(dates[index + 1])) / 2 : y(date) + max(h * 3, 0.035)
            let row = lines.filter { y($0) > lower && y($0) < upper }
            let fragments = row.filter {
                $0.boundingBox.minX >= name.boundingBox.minX - h * 2 && $0.centerX < titleRight &&
                !TaskTextPolicy.isMetadata($0.text) && !DeadlineParser.containsDate($0.text) &&
                CourseNormalizer.code(from: $0.text) == nil
            }.sorted { y($0) < y($1) }
            // A wrapped assignment number alone is valid only next to a name.
            let numbers = row.filter {
                $0.centerX < titleRight && $0.boundingBox.minX >= name.boundingBox.minX - h * 2 &&
                $0.text.trimmed.range(of: #"^\d{1,3}$"#, options: .regularExpression) != nil
            }
            let combined = (fragments + numbers).sorted { y($0) < y($1) }
            let title = combined.map { TaskTextPolicy.clean($0.text) }.joined(separator: " ")
            guard TaskTextPolicy.isAssignmentTitle(title) else { return nil }
            var dateText = date.text
            if let zone, dateText.range(of: #"\b(?:EDT|EST|UTC|GMT|PDT|PST|CDT|CST|MDT|MST)\b"#, options: .regularExpression) == nil { dateText += " " + zone }
            var candidate = LayoutInterpreter.make(title: title, course: course, date: dateText, year: year,
                platform: webAssign ? .webAssign : .gradescope, document: document, context: context)
            let metadata = row.filter { $0.centerX >= titleRight && $0.text != date.text }
            candidate.submissionStatus = metadata.first { TaskTextPolicy.isStatus($0.text) }.map { TaskTextPolicy.clean($0.text) }
            if webAssign, let score = metadata.first(where: { TaskTextPolicy.isScore($0.text) }),
               let total = score.text.firstRegexMatch(pattern: #"/\s*(\d+)"#)?.capture(1) {
                candidate.questionCount = Int(total)
            }
            if title.range(of: #"^(?:Homework|Lab|Worksheet)(?:\s+[A-Z])?$"#, options: [.regularExpression, .caseInsensitive]) != nil {
                candidate.warnings.append("Assignment number may be missing or unclear; compare the screenshot.")
            }
            if combined.contains(where: { $0.confidence < 0.65 }) || date.confidence < 0.65 {
                candidate.warnings.append("Some text has low recognition confidence; verify it.")
            }
            return candidate
        }
    }
}
