import Foundation

/// Shared by every parser and the final save gate. OCR confidence measures
/// legibility, not whether a string represents an assignment.
public enum TaskTextPolicy {
    public static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: #"^[\s•●○◦·✓✔☑*†‡|:]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmed
    }

    public static func isScore(_ text: String) -> Bool {
        let value = clean(text)
        // An OCR footnote/stray glyph must not turn a grade into a task.
        return value.range(of: #"^(?:[-–—]|\d+(?:[.,]\d+)?)\s*[/／|]\s*\d+(?:[.,]\d+)?\s*(?:points?|pts?|[a-z†‡*%]{0,3})?$"#,
                           options: [.regularExpression, .caseInsensitive]) != nil ||
            value.range(of: #"^\d+(?:\.\d+)?\s*%$"#, options: .regularExpression) != nil
    }

    public static func isStatus(_ text: String) -> Bool {
        let value = clean(text).lowercased().trimmingCharacters(in: .punctuationCharacters)
        return ["submitted", "no submission", "not submitted", "not complete", "completed", "complete", "graded", "ungraded", "missing", "late", "not yet graded"].contains(value) || isScore(value)
    }

    public static func isMetadata(_ text: String) -> Bool {
        let value = clean(text).lowercased().trimmingCharacters(in: .punctuationCharacters)
        let labels: Set<String> = ["name", "assignment", "assignments", "status", "submission status", "completion status", "evaluation status", "score", "scores", "grade", "grades", "released", "release date", "due", "due date", "deadline", "attachments", "attachment", "no category", "view history", "dashboard", "calendar", "calendars", "inbox", "notifications", "to-do", "content", "modules", "help", "current assignments", "past assignments", "all assignments"]
        return value.isEmpty || labels.contains(value) || isStatus(value) ||
            value.range(of: #"^[-–—/|\d.,\s]+$"#, options: .regularExpression) != nil ||
            value.range(of: #"^(?:\d+\s+(?:weeks?|days?|hours?|minutes?)\s*)+(?:left|remaining)$"#, options: .regularExpression) != nil
    }

    public static func isAssignmentTitle(_ text: String) -> Bool {
        let value = clean(text)
        return value.filter(\.isLetter).count >= 2 && !isMetadata(value) &&
            !value.localizedCaseInsensitiveContains("http") && !value.localizedCaseInsensitiveContains("course id")
    }

    public static func maySelectAutomatically(_ candidate: AssignmentCandidate) -> Bool {
        candidate.dueDate != nil && isAssignmentTitle(candidate.assignmentName) &&
            !candidate.warnings.contains { warning in
                ["low recognition", "Conflicting deadlines", "number may be missing", "pairing is uncertain", "Year missing", "Course missing", "Course not visible"].contains { warning.localizedCaseInsensitiveContains($0) }
            }
    }
}

enum CourseEvidence {
    static func code(in document: OCRDocument, before boundary: CGFloat = 1) -> String? {
        let matches = document.lines.compactMap { line -> (String, CGFloat)? in
            guard line.topDownY < boundary, !line.text.localizedCaseInsensitiveContains("http"),
                  let code = CourseNormalizer.code(from: line.text) else { return nil }
            return (code, line.topDownY)
        }
        // Prefer page content to browser tabs. Multiple genuine course labels
        // need card-specific association instead of a document-wide guess.
        let page = matches.filter { $0.1 > 0.16 }
        let codes = Set((page.isEmpty ? matches : page).map(\.0))
        return codes.count == 1 ? codes.first : nil
    }
}
