import Foundation
import CoreGraphics

public enum SourcePlatform: String, Codable, Sendable {
    case gradescope = "Gradescope"
    case webAssign = "WebAssign"
    case brightspace = "Brightspace"
    case canvas = "Canvas"
    case moodle = "Moodle"
    case unknown = "Unknown"
}

public struct OCRLine: Sendable {
    public let text: String
    public let boundingBox: CGRect
    public let confidence: Float

    public init(text: String, boundingBox: CGRect, confidence: Float = 1) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }

    public var centerX: CGFloat { boundingBox.midX }
    public var topDownY: CGFloat { 1 - boundingBox.midY }
}

public struct OCRDocument: Sendable {
    public let sourceName: String
    public let lines: [OCRLine]
    public let readingMethod: String

    public init(sourceName: String, lines: [OCRLine], readingMethod: String = "Image text recognition") {
        self.sourceName = sourceName
        self.lines = lines
        self.readingMethod = readingMethod
    }

    public var fullText: String {
        lines.map(\.text).joined(separator: "\n")
    }
}

public struct ImportContext: Sendable {
    public var course: String
    public var year: Int?
    public var timeZoneIdentifier: String?
    public init(course: String = "", year: Int? = nil, timeZoneIdentifier: String? = nil) {
        self.course = course; self.year = year; self.timeZoneIdentifier = timeZoneIdentifier
    }
}

public struct DestinationChoice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let account: String
    public var label: String { "\(name) — \(account)" }
    public init(id: String, name: String, account: String) {
        self.id = id; self.name = name; self.account = account
    }
}

public struct AccountChoice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

public struct AssignmentCandidate: Identifiable, Codable, Sendable {
    public var id: UUID
    public var courseCode: String
    public var assignmentName: String
    public var assignmentType: String?
    public var questionCount: Int?
    public var dueDate: Date?
    public var hasExplicitTime: Bool
    public var timeZoneIdentifier: String?
    public var sourcePlatform: SourcePlatform
    public var sourceImages: [String]
    public var warnings: [String]
    public var titleOverride: String?

    public init(
        id: UUID = UUID(),
        courseCode: String,
        assignmentName: String,
        assignmentType: String? = nil,
        questionCount: Int? = nil,
        dueDate: Date?,
        hasExplicitTime: Bool,
        timeZoneIdentifier: String? = nil,
        sourcePlatform: SourcePlatform,
        sourceImages: [String],
        warnings: [String] = [],
        titleOverride: String? = nil
    ) {
        self.id = id
        self.courseCode = courseCode
        self.assignmentName = assignmentName
        self.assignmentType = assignmentType
        self.questionCount = questionCount
        self.dueDate = dueDate
        self.hasExplicitTime = hasExplicitTime
        self.timeZoneIdentifier = timeZoneIdentifier
        self.sourcePlatform = sourcePlatform
        self.sourceImages = sourceImages
        self.warnings = warnings
        self.titleOverride = titleOverride
    }

    public var courseTag: String {
        CourseNormalizer.tag(from: courseCode)
    }

    public var reminderTitle: String {
        if let titleOverride, !titleOverride.trimmed.isEmpty {
            return titleOverride.trimmed
        }
        var parts = [courseTag, assignmentName.trimmed]
        if let assignmentType, !assignmentType.isEmpty,
           !assignmentName.localizedCaseInsensitiveContains("(\(assignmentType))") {
            parts.append("(\(assignmentType))")
        }
        if let questionCount {
            parts.append("\(questionCount) Questions")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " ")
    }

    public var identityKey: String {
        AssignmentIdentity.key(courseTag: courseTag, title: assignmentName)
    }
}

/// A reviewed assignment plus its due-time Reminders notification choice.
public struct ReminderWriteRequest: Sendable {
    public let candidate: AssignmentCandidate
    public let deadlineNotificationEnabled: Bool

    public init(
        candidate: AssignmentCandidate,
        deadlineNotificationEnabled: Bool
    ) {
        self.candidate = candidate
        self.deadlineNotificationEnabled = deadlineNotificationEnabled
    }
}

public struct CompanionEventRequest: Sendable {
    public let candidate: AssignmentCandidate
    public let notifyAtStart: Bool
    public let additionalNotificationLeadTimes: [TimeInterval]

    public init(
        candidate: AssignmentCandidate,
        notifyAtStart: Bool,
        additionalNotificationLeadTimes: [TimeInterval]
    ) {
        self.candidate = candidate
        self.notifyAtStart = notifyAtStart
        self.additionalNotificationLeadTimes = additionalNotificationLeadTimes
    }
}

public enum CourseNormalizer {
    public static func code(from text: String) -> String? {
        let pattern = #"\b([A-Z]{2,4})\s*-\s*UY\s*[: -]?\s*(\d{4})\b"#
        guard let match = text.firstRegexMatch(pattern: pattern, options: [.caseInsensitive]),
              let department = match.capture(1),
              let number = match.capture(2) else { return nil }
        return "\(department.uppercased())-UY \(number)"
    }

    public static func tag(from courseCode: String) -> String {
        if let normalized = code(from: courseCode),
           let match = normalized.firstRegexMatch(
               pattern: #"([A-Z]{2,4})-UY\s*(\d{4})"#,
               options: [.caseInsensitive]
           ),
           let department = match.capture(1),
           let number = match.capture(2) {
            return "#\(department.uppercased())\(number)"
        }

        let compact = courseCode.uppercased().filter { $0.isLetter || $0.isNumber }
        return compact.isEmpty ? "#COURSE" : "#\(compact)"
    }
}

public enum AssignmentIdentity {
    public static func key(courseTag: String, title: String) -> String {
        let normalizedTitle = title
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmed

        if let match = normalizedTitle.firstRegexMatch(
            pattern: #"\b(H\d+)\s*[_ ]?\s*([SF])\s*(\d{2,4})\b"#,
            options: [.caseInsensitive]
        ), let assignmentNumber = match.capture(1), let term = match.capture(2), let year = match.capture(3) {
            // Date is intentionally absent: moving a deadline updates the same
            // task. Term is present: H1 in Spring is not H1 in Fall.
            return "\(courseTag.lowercased())|\(assignmentNumber.lowercased())|\(term.lowercased())\(year)"
        }

        // These are presentation details added by reminderTitle, not task IDs.
        let plainTitle = normalizedTitle
            .replacingOccurrences(of: #"\s+\d+\s+(?:Questions?|Points?)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s*\((?:Homework|Assignment|Quiz|Exam|Project|Lab|Worksheet)\)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
        let alphanumeric = plainTitle.lowercased().filter { $0.isLetter || $0.isNumber }
        return "\(courseTag.lowercased())|\(alphanumeric)"
    }

    public static func fromReminderTitle(_ title: String) -> String {
        let parts = title.trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        guard let tag = parts.first, tag.hasPrefix("#") else {
            return key(courseTag: "#COURSE", title: title)
        }
        return key(courseTag: tag, title: parts.count > 1 ? parts[1] : "")
    }

    /// Old marker/registry keys are read only for migration. Their owning
    /// event's current title must also match, so an old H1 marker cannot
    /// accidentally adopt a task from a different semester.
    public static func legacyKeys(for candidate: AssignmentCandidate) -> [String] {
        [candidate.assignmentName, candidate.reminderTitle].map { title in
            let normalized = title.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmed
            if let match = normalized.firstRegexMatch(pattern: #"\b(H\d+)\s*[_ ]?\s*S\s*\d+\b"#, options: [.caseInsensitive]),
               let number = match.capture(1) {
                return "\(candidate.courseTag.lowercased())|\(number.lowercased())"
            }
            let withoutTag = normalized.hasPrefix(candidate.courseTag + " ") ? String(normalized.dropFirst(candidate.courseTag.count + 1)) : normalized
            return "\(candidate.courseTag.lowercased())|\(withoutTag.lowercased().filter { $0.isLetter || $0.isNumber })"
        }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func firstRegexMatch(
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let result = regex.firstMatch(in: self, range: range) else { return nil }
        return RegexMatch(source: self, result: result)
    }
}

struct RegexMatch {
    let source: String
    let result: NSTextCheckingResult

    func capture(_ index: Int) -> String? {
        guard index < result.numberOfRanges,
              let range = Range(result.range(at: index), in: source) else { return nil }
        return String(source[range])
    }
}
