import Foundation

public final class AssignmentParser {
    public init() {}

    public func parse(documents: [OCRDocument], context: ImportContext = ImportContext()) -> [AssignmentCandidate] {
        var candidates: [AssignmentCandidate] = []
        for document in documents {
            let context = context.scoped(to: document.sourceName)
            if let structured = LayoutInterpreter.parse(document, context: context), !structured.isEmpty {
                candidates += structured.map { source in
                    var value = source
                    if let chosen = context.courseOverrides[document.sourceName] { value.courseCode = chosen.trimmed }
                    return value
                }
                continue
            }
            let platform = detectPlatform(document)
            // An unrelated screenshot in the same batch is never evidence for
            // this page's course. Explicit per-source corrections take priority.
            let course = context.courseOverrides[document.sourceName] ?? courseCode(in: document) ?? context.course.trimmed
            let spatial = parseSpatial(document, course: course, platform: platform, context: context)
            candidates += spatial
            // A partial spatial result must not suppress every other row.
            // Remove only deadline observations already represented in it.
            let remaining = OCRDocument(sourceName: document.sourceName, lines: document.lines.filter { line in
                !spatial.contains { $0.sourceDeadlineText?.hasPrefix(line.text) == true && DeadlineParser.containsDate(line.text) }
            }, readingMethod: document.readingMethod)
            switch platform {
            case .gradescope:
                candidates += parseGradescope(remaining, course: course)
            case .webAssign:
                candidates += parseWebAssign(remaining, course: course)
            case .brightspace, .canvas, .moodle:
                candidates += parseFlexibleLayout(remaining, course: course, platform: platform)
            case .unknown:
                candidates += parseGeneric(remaining, course: course)
            }
        }

        return mergeDuplicates(candidates.filter { TaskTextPolicy.isAssignmentTitle($0.assignmentName) }).sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?):
                if left != right { return left < right }
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): break
            }
            return lhs.reminderTitle.localizedStandardCompare(rhs.reminderTitle) == .orderedAscending
        }
    }

    /// Use local line height and alignment, not hard-coded screen percentages.
    /// Platform-specific parsers remain a fallback for unusual legacy layouts.
    private func parseSpatial(_ document: OCRDocument, course: String, platform: SourcePlatform, context: ImportContext) -> [AssignmentCandidate] {
        let lines = document.lines
        let heights = lines.map { $0.boundingBox.height }.filter { $0 > 0 }.sorted()
        let lineHeight = heights.isEmpty ? CGFloat(0.02) : heights[heights.count / 2]
        let year = extractCourseYear(document.fullText) ?? context.year
        let zone = document.fullText.firstRegexMatch(pattern: #"Due\s*\((EDT|EST|UTC|GMT|CDT|CST|MDT|MST|PDT|PST)\)"#, options: [.caseInsensitive])?.capture(1)
        let pastHeader = lines.filter { $0.text.trimmed.uppercased() == "PAST ASSIGNMENTS" && $0.topDownY > 0.25 }.map(\.topDownY).min()
        var results: [AssignmentCandidate] = []
        for deadlineLine in lines where isPotentialDeadlineLine(deadlineLine.text) {
            let h = max(lineHeight, deadlineLine.boundingBox.height)
            if let pastHeader, deadlineLine.topDownY > pastHeader { continue }
            // A release date is not a deadline, even when both occur in one row.
            let headers = lines.filter {
                ["released", "release date", "due", "due date", "due (edt)", "due (est)"].contains($0.text.trimmed.lowercased()) &&
                $0.topDownY < deadlineLine.topDownY
            }
            if let header = headers.min(by: { abs($0.centerX - deadlineLine.centerX) < abs($1.centerX - deadlineLine.centerX) }),
               abs(header.centerX - deadlineLine.centerX) < max(header.boundingBox.width, deadlineLine.boundingBox.width) / 2,
               header.text.lowercased().hasPrefix("release") { continue }
            if platform == .gradescope, lines.contains(where: {
                isPotentialDeadlineLine($0.text) && abs($0.topDownY - deadlineLine.topDownY) < h &&
                $0.centerX > deadlineLine.centerX && !$0.text.lowercased().contains("late")
            }) { continue }

            let nameHeader = lines.filter {
                ["name", "assignment", "current assignments"].contains($0.text.trimmed.lowercased()) &&
                $0.topDownY < deadlineLine.topDownY
            }.max { $0.topDownY < $1.topDownY }
            let sameRow = lines.filter {
                plausibleTitle($0.text) &&
                (nameHeader == nil || $0.boundingBox.minX >= nameHeader!.boundingBox.minX - h * 2) &&
                $0.boundingBox.maxX <= deadlineLine.boundingBox.minX + h &&
                abs($0.topDownY - deadlineLine.topDownY) <= max(h, $0.boundingBox.height) * 2
            }.min {
                let left = abs($0.topDownY - deadlineLine.topDownY) * 2 + max(0, deadlineLine.boundingBox.minX - $0.boundingBox.maxX) * 0.2
                let right = abs($1.topDownY - deadlineLine.topDownY) * 2 + max(0, deadlineLine.boundingBox.minX - $1.boundingBox.maxX) * 0.2
                return left < right
            }
            let above = lines.filter { candidate in
                let delta = deadlineLine.topDownY - candidate.topDownY
                let aligned = abs(candidate.boundingBox.minX - deadlineLine.boundingBox.minX) <= h * 3 ||
                    candidate.boundingBox.intersects(CGRect(x: deadlineLine.boundingBox.minX, y: candidate.boundingBox.minY, width: deadlineLine.boundingBox.width, height: candidate.boundingBox.height))
                return plausibleTitle(candidate.text) && delta > 0 && delta <= h * 8 && aligned &&
                    !lines.contains(where: {
                        isPotentialDeadlineLine($0.text) && $0.topDownY > candidate.topDownY &&
                        $0.topDownY < deadlineLine.topDownY - h * 0.5 &&
                        abs($0.boundingBox.minX - deadlineLine.boundingBox.minX) < h * 3
                    })
            }.min {
                abs($0.topDownY - deadlineLine.topDownY) < abs($1.topDownY - deadlineLine.topDownY)
            }
            let titleLine = sameRow ?? above
            guard var title = embeddedTitle(in: deadlineLine.text) ?? titleLine?.text else { continue }
            if let titleLine, embeddedTitle(in: deadlineLine.text) == nil {
                // Join a wrapped title without absorbing status labels or the next task.
                let continuations = lines.filter {
                    plausibleTitle($0.text) && $0.text != titleLine.text &&
                    $0.topDownY > titleLine.topDownY + h * 0.5 &&
                    $0.topDownY < min(titleLine.topDownY + h * 2.5, deadlineLine.topDownY - h * 0.4) &&
                    abs($0.boundingBox.minX - titleLine.boundingBox.minX) < h * 1.5
                }.sorted { $0.topDownY < $1.topDownY }
                if !continuations.isEmpty { title += " " + continuations.prefix(2).map(\.text).joined(separator: " ") }
            }
            var dateText = deadlineLine.text
            // Dates and their times may be separate OCR observations or wrapped lines.
            let timeFragments = lines.filter {
                $0.text != deadlineLine.text && !DeadlineParser.containsDate($0.text) &&
                $0.text.range(of: #"^\s*(?:20\d{2}\s*(?:at\s+)?)?(?:(?:at\s+)?\d{1,2}:\d{2}\s*(?:AM|PM)?(?:\s+[A-Z]{3})?)?\s*$"#, options: [.regularExpression, .caseInsensitive]) != nil &&
                abs($0.topDownY - deadlineLine.topDownY) < h * 2.5 &&
                (abs($0.boundingBox.minX - deadlineLine.boundingBox.minX) < h * 3 || abs($0.topDownY - deadlineLine.topDownY) < h)
            }
            if let time = timeFragments.min(by: { abs($0.topDownY - deadlineLine.topDownY) < abs($1.topDownY - deadlineLine.topDownY) }) {
                dateText += " " + time.text
            }
            if let zone, dateText.range(of: #"\b(?:EDT|EST|UTC|GMT|CDT|CST|MDT|MST|PDT|PST)\b"#, options: .regularExpression) == nil {
                dateText += " " + zone
            }
            let deadline = DeadlineParser.parse(dateText, fallbackYear: year, fallbackTimeZone: context.timeZoneIdentifier)
            let split = splitAssignmentType(cleanAssignmentName(title))
            let scores = lines.filter {
                abs($0.topDownY - deadlineLine.topDownY) < h * 1.25 && $0.centerX > deadlineLine.centerX &&
                $0.text.range(of: #"^\s*(?:-|\d+)\s*/\s*\d+\s*$"#, options: .regularExpression) != nil
            }
            if platform == .webAssign, scores.contains(where: { !$0.text.trimmed.hasPrefix("-") }) { continue }
            let score = platform == .webAssign ? scoreDenominator(near: deadlineLine, lines: lines) : (nil, false)
            var warnings: [String] = []
            if course.isEmpty { warnings.append("Course missing; enter it before selecting this task.") }
            if !DeadlineParser.hasYear(dateText) {
                warnings.append(year == nil ? "Year missing; choose a batch year and re-read." : "Year supplied by the course or batch context; verify it.")
            }
            if deadline == nil { warnings.append("Deadline could not be validated; correct it before adding.") }
            if platform == .unknown { warnings.append("General layout; verify the title and deadline.") }
            if min(deadlineLine.confidence, titleLine?.confidence ?? 1) < 0.65 {
                warnings.append("Some text has low recognition confidence; verify it.")
            }
            if score.1 { warnings.append("Question count was inferred from an unclear score; verify it.") }
            results.append(AssignmentCandidate(
                courseCode: course, assignmentName: split.name, assignmentType: split.type,
                questionCount: score.0, dueDate: deadline?.date,
                hasExplicitTime: deadline?.hasExplicitTime ?? dateText.contains(":"),
                timeZoneIdentifier: deadline?.timeZoneIdentifier ?? context.timeZoneIdentifier,
                sourcePlatform: platform, sourceImages: [document.sourceName], warnings: warnings,
                sectionCode: LayoutInterpreter.section(in: split.name), sourceDeadlineText: dateText
            ))
        }
        return results
    }

    private func plausibleTitle(_ text: String) -> Bool {
        guard TaskTextPolicy.isAssignmentTitle(text), text.trimmed.count >= 3, !isNoiseTitle(text), !DeadlineParser.containsDate(text),
              CourseNormalizer.code(from: text) == nil else { return false }
        let lower = text.replacingOccurrences(of: #"^[\s•●○◦·✓✔☑]+"#, with: "", options: .regularExpression).trimmed.lowercased()
        return !["released", "release date", "late due", "due on", "starts", "not submitted", "no submission", "submitted"].contains(where: { lower.hasPrefix($0) }) &&
            lower.range(of: #"^(?:due|deadline|closes?)\b"#, options: .regularExpression) == nil &&
            !lower.contains("http") && !lower.contains(".com/") && !lower.contains(".edu") &&
            !["gradescope", "cengage | webassign", "webassign", "name"].contains(lower)
    }

    private func courseCode(in document: OCRDocument) -> String? {
        CourseEvidence.code(in: document)
    }

    public func detectPlatform(_ document: OCRDocument) -> SourcePlatform {
        let text = document.fullText.lowercased()
        if text.contains("gradescope") { return .gradescope }
        if text.contains("webassign") || text.contains("current assignments") { return .webAssign }
        if text.contains("brightspace") || text.contains("/d2l/") ||
            (text.contains("completion status") && text.contains("evaluation status")) {
            return .brightspace
        }
        if text.contains("instructure.com") || text.contains("canvas student") ||
            (text.contains("available until") && text.contains("submission")) {
            return .canvas
        }
        if text.contains("moodle") || text.contains("activity due") {
            return .moodle
        }
        return .unknown
    }

    private func parseGradescope(_ document: OCRDocument, course: String) -> [AssignmentCandidate] {
        let year = extractCourseYear(document.fullText)
        let headerTimeZone = document.fullText.firstRegexMatch(
            pattern: #"Due\s*\((EDT|EST|[A-Z]{3})\)"#,
            options: [.caseInsensitive]
        )?.capture(1)?.uppercased()

        let deadlineLines = document.lines.filter { line in
            isMonthDateLine(line.text) &&
            !line.text.localizedCaseInsensitiveContains("Late Due") &&
            line.centerX > 0.68
        }

        return deadlineLines.compactMap { deadlineLine in
            var deadlineText = deadlineLine.text
            if let headerTimeZone,
               deadlineText.range(of: #"\b[A-Z]{3}\b"#, options: .regularExpression) == nil {
                deadlineText += " \(headerTimeZone)"
            }
            guard let deadline = DeadlineParser.parse(deadlineText, fallbackYear: year),
                  let titleLine = closestTitleLine(
                    to: deadlineLine,
                    in: document.lines,
                    minimumX: 0.15,
                    maximumX: 0.34,
                    excluding: ["Name", "Status", "Released", "Dashboard", "No Submission", "• No Submission"]
                  ) else { return nil }

            var warnings: [String] = []
            if course.isEmpty { warnings.append("Course not visible; choose a course before adding.") }
            return AssignmentCandidate(
                courseCode: course,
                assignmentName: cleanAssignmentName(titleLine.text),
                dueDate: deadline.date,
                hasExplicitTime: deadline.hasExplicitTime,
                timeZoneIdentifier: deadline.timeZoneIdentifier,
                sourcePlatform: .gradescope,
                sourceImages: [document.sourceName],
                warnings: warnings
            )
        }
    }

    private func parseWebAssign(_ document: OCRDocument, course: String) -> [AssignmentCandidate] {
        let detailed = document.fullText.localizedCaseInsensitiveContains("DUE DATE") ||
            document.fullText.localizedCaseInsensitiveContains("ALL ASSIGNMENTS")
        let year = extractCourseYear(document.fullText)
        let pastHeaderY = document.lines
            .filter { candidate in
                candidate.text.uppercased() == "PAST ASSIGNMENTS" &&
                candidate.topDownY > 0.30 &&
                candidate.centerX < 0.30 &&
                document.lines.contains(where: { header in
                    header.text.uppercased() == "DUE DATE" &&
                    abs(header.topDownY - candidate.topDownY) < 0.015
                })
            }
            .map(\.topDownY)
            .min()
        let hasScoreColumn = document.lines.contains {
            $0.text.uppercased() == "SCORE" && $0.centerX > 0.65
        }

        let deadlineLines = document.lines.filter { line in
            isMonthDateLine(line.text) &&
            line.centerX > 0.45 &&
            !line.text.localizedCaseInsensitiveContains("Class Ends") &&
            !line.text.localizedCaseInsensitiveContains("Class Started")
        }

        return deadlineLines.compactMap { deadlineLine in
            if let pastHeaderY, deadlineLine.topDownY > pastHeaderY { return nil }
            if hasScoreColumn,
               let scoreLine = closestScoreLine(near: deadlineLine, lines: document.lines),
               !scoreLine.text.trimmed.hasPrefix("-") {
                return nil
            }
            guard let deadline = DeadlineParser.parse(deadlineLine.text, fallbackYear: year),
                  let titleLine = closestTitleLine(
                    to: deadlineLine,
                    in: document.lines,
                    minimumX: 0.04,
                    maximumX: detailed ? 0.58 : 0.54,
                    excluding: ["Name", "Due", "Due Date", "Current Assignments", "My Assignments"]
                  ) else { return nil }

            let parsedTitle = splitAssignmentType(cleanAssignmentName(titleLine.text))
            let score = detailed ? scoreDenominator(
                near: deadlineLine,
                lines: document.lines
            ) : (nil, false)

            var warnings: [String] = []
            if course.isEmpty { warnings.append("Course not visible; choose a course before adding.") }
            if score.1 { warnings.append("Question count was inferred from an unclear score; verify it.") }
            if parsedTitle.name.range(
                of: #"^H\d+_S\d+"#,
                options: [.regularExpression, .caseInsensitive]
            ) == nil {
                warnings.append("Assignment identifier may have been misread; verify the title.")
            }
            return AssignmentCandidate(
                courseCode: course,
                assignmentName: parsedTitle.name,
                assignmentType: parsedTitle.type,
                questionCount: score.0,
                dueDate: deadline.date,
                hasExplicitTime: deadline.hasExplicitTime,
                timeZoneIdentifier: deadline.timeZoneIdentifier,
                sourcePlatform: .webAssign,
                sourceImages: [document.sourceName],
                warnings: warnings
            )
        }
    }

    private func parseGeneric(_ document: OCRDocument, course: String) -> [AssignmentCandidate] {
        parseFlexibleLayout(document, course: course, platform: .unknown)
    }

    /// Parses card- and list-based learning systems. Unlike the fixed table
    /// parsers, this associates a labeled deadline with the nearest plausible
    /// title above it in the same visual column.
    private func parseFlexibleLayout(
        _ document: OCRDocument,
        course: String,
        platform: SourcePlatform
    ) -> [AssignmentCandidate] {
        let year = extractCourseYear(document.fullText)
        let deadlineLines = document.lines.filter { isPotentialDeadlineLine($0.text) }
        return deadlineLines.compactMap { deadlineLine in
            guard let deadline = DeadlineParser.parse(deadlineLine.text, fallbackYear: year),
                  let title = embeddedTitle(in: deadlineLine.text) ?? flexibleTitleLine(
                    above: deadlineLine,
                    in: document.lines
                  )?.text else { return nil }

            var warnings: [String] = []
            if course.isEmpty {
                warnings.append("Course not visible; choose a course before adding.")
            }
            if platform == .unknown {
                warnings.append("Unrecognized page layout; verify the extracted title and deadline.")
            }
            return AssignmentCandidate(
                courseCode: course,
                assignmentName: cleanAssignmentName(title),
                dueDate: deadline.date,
                hasExplicitTime: deadline.hasExplicitTime,
                timeZoneIdentifier: deadline.timeZoneIdentifier,
                sourcePlatform: platform,
                sourceImages: [document.sourceName],
                warnings: warnings
            )
        }
    }

    private func isPotentialDeadlineLine(_ text: String) -> Bool {
        let lower = text.lowercased()
        let ignoredPrefixes = [
            "starts", "start date", "available from", "released", "release date",
            "late due", "late deadline", "class starts", "class started", "class ends",
            "you were granted", "access granted", "posted", "last modified", "submitted"
        ]
        if ignoredPrefixes.contains(where: { lower.trimmed.hasPrefix($0) }) { return false }

        let hasDate = DeadlineParser.containsDate(text)
        guard hasDate else { return false }

        // Prefer explicit deadline labels, while still accepting bare dates in
        // assignment tables whose column header supplies the meaning.
        return DeadlineParser.beginsWithDate(text) ||
            DeadlineParser.titleBeforeDate(text).map { plausibleTitle($0) } == true ||
            text.range(of: #"\b(?:due|deadline|submit\s+by|closes?)\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func embeddedTitle(in text: String) -> String? {
        if let prefix = DeadlineParser.titleBeforeDate(text), plausibleTitle(prefix),
           prefix.range(of: #"\b(?:due|deadline|closes?)\b"#, options: [.regularExpression, .caseInsensitive]) == nil {
            return prefix
        }
        guard let match = text.firstRegexMatch(
            pattern: #"^\s*(.+?)\s+(?:due(?:\s+date)?(?:\s+(?:on|by))?|deadline|submit(?:ted)?\s+by|closes?)\b"#,
            options: [.caseInsensitive]
        ), let prefix = match.capture(1)?.trimmed,
           prefix.count >= 4,
           !isNoiseTitle(prefix) else { return nil }
        return prefix
    }

    private func flexibleTitleLine(above deadlineLine: OCRLine, in lines: [OCRLine]) -> OCRLine? {
        lines
            .filter { candidate in
                guard candidate.text != deadlineLine.text,
                      candidate.text.count >= 3,
                      plausibleTitle(candidate.text),
                      !isPotentialDeadlineLine(candidate.text) else { return false }
                let verticalDelta = deadlineLine.topDownY - candidate.topDownY
                guard verticalDelta >= -0.018, verticalDelta <= 0.12 else { return false }
                let horizontalDelta = abs(candidate.boundingBox.minX - deadlineLine.boundingBox.minX)
                return horizontalDelta < 0.38 && candidate.centerX < 0.82
            }
            .min { lhs, rhs in
                flexibleTitleScore(lhs, deadlineLine: deadlineLine) <
                    flexibleTitleScore(rhs, deadlineLine: deadlineLine)
            }
    }

    private func flexibleTitleScore(_ candidate: OCRLine, deadlineLine: OCRLine) -> CGFloat {
        let vertical = abs(deadlineLine.topDownY - candidate.topDownY)
        let horizontal = abs(candidate.boundingBox.minX - deadlineLine.boundingBox.minX)
        let belowPenalty: CGFloat = candidate.topDownY > deadlineLine.topDownY ? 0.30 : 0
        return vertical * 8 + horizontal * 0.7 + belowPenalty
    }

    private func isNoiseTitle(_ text: String) -> Bool {
        if TaskTextPolicy.isMetadata(text) { return true }
        let normalized = text
            .replacingOccurrences(of: #"^[\s•●○◦·✓✔☑]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmed
            .lowercased()
        let exactNoise: Set<String> = [
            "assignment", "assignments", "no category", "completion status", "evaluation status",
            "score", "status", "due", "due date", "deadline", "not complete", "complete", "no submission", "not submitted", "submitted", "released", "release date",
            "view history", "attachments", "attachment", "content", "announcements", "discussions",
            "quizzes", "grades", "help", "dashboard", "calendar", "modules", "submission",
            "submissions", "available until", "current assignments", "past assignments", "all assignments"
        ]
        if exactNoise.contains(normalized) { return true }
        if normalized.hasPrefix("starts ") || normalized.hasPrefix("available from ") ||
            normalized.hasPrefix("course id") || normalized.hasPrefix("fall 20") ||
            normalized.hasPrefix("spring 20") || normalized.hasPrefix("summer 20") ||
            normalized.hasPrefix("winter 20") {
            return true
        }
        if normalized.range(of: #"^[-–—/|\d. ]+$"#, options: .regularExpression) != nil { return true }
        return false
    }

    private func closestTitleLine(
        to deadlineLine: OCRLine,
        in lines: [OCRLine],
        minimumX: CGFloat,
        maximumX: CGFloat,
        excluding excluded: [String]
    ) -> OCRLine? {
        lines
            .filter { candidate in
                candidate.centerX > minimumX &&
                candidate.centerX < maximumX &&
                abs(candidate.topDownY - deadlineLine.topDownY) < 0.028 &&
                candidate.text.count >= 4 &&
                TaskTextPolicy.isAssignmentTitle(candidate.text) &&
                !excluded.contains { candidate.text.caseInsensitiveCompare($0) == .orderedSame } &&
                !candidate.text.localizedCaseInsensitiveContains("Course ID") &&
                !candidate.text.localizedCaseInsensitiveContains("Fall 20")
            }
            .min { lhs, rhs in
                let leftScore = abs(lhs.topDownY - deadlineLine.topDownY) + lhs.centerX * 0.005
                let rightScore = abs(rhs.topDownY - deadlineLine.topDownY) + rhs.centerX * 0.005
                return leftScore < rightScore
            }
    }

    private func closestScoreLine(near deadlineLine: OCRLine, lines: [OCRLine]) -> OCRLine? {
        lines
            .filter {
                $0.centerX > deadlineLine.centerX &&
                abs($0.topDownY - deadlineLine.topDownY) < 0.028
            }
            .min { abs($0.topDownY - deadlineLine.topDownY) < abs($1.topDownY - deadlineLine.topDownY) }
    }

    private func scoreDenominator(near deadlineLine: OCRLine, lines: [OCRLine]) -> (Int?, Bool) {
        guard let text = closestScoreLine(near: deadlineLine, lines: lines)?.text else {
            return (nil, false)
        }
        if let match = text.firstRegexMatch(pattern: #"/\s*(\d+)"#),
           let value = match.capture(1) {
            return (Int(value), false)
        }
        // Vision occasionally reads the slash in "- / 9" as the digit 1 ("- 19").
        if let match = text.firstRegexMatch(pattern: #"^\s*-\s*[|lI1]\s*(\d{1,3})\s*$"#),
           let value = match.capture(1) {
            return (Int(value), true)
        }
        return (nil, false)
    }

    private func splitAssignmentType(_ title: String) -> (name: String, type: String?) {
        guard let match = title.firstRegexMatch(
            pattern: #"^(.*?)\s*\(([^()]+)\)\s*$"#
        ), let name = match.capture(1), let type = match.capture(2) else {
            return (title.trimmed, nil)
        }
        return (name.trimmed, type.trimmed)
    }

    private func cleanAssignmentName(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+([,:;])"#, with: "$1", options: .regularExpression)
            .trimmed
        return cleaned.replacingOccurrences(
            of: #"^\s*(H\d+)\s*_?\s*S\s*(\d+)([:.]?)\s*"#,
            with: "$1_S$2$3 ",
            options: [.regularExpression, .caseInsensitive]
        ).trimmed
    }

    private func extractCourseYear(_ text: String) -> Int? {
        if let match = text.firstRegexMatch(
            pattern: #"\b(?:Fall|Spring|Summer|Winter)\s+(20\d{2})\b"#,
            options: [.caseInsensitive]
        ), let year = match.capture(1) {
            return Int(year)
        }
        return nil
    }

    private func isMonthDateLine(_ text: String) -> Bool {
        let month = #"(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)"#
        let weekday = #"(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun)"#
        return text.range(
            of: #"\b"# + weekday + #"?\s*,?\s*"# + month + #"\s+\d{1,2}\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil || text.range(
            of: #"\b(?:"# + weekday + #"\s*,?\s*)?\d{1,2}\s+"# + month + #"\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private func mergeDuplicates(_ candidates: [AssignmentCandidate]) -> [AssignmentCandidate] {
        var byKey: [String: AssignmentCandidate] = [:]
        var insertionOrder: [String] = []

        for candidate in candidates {
            // An unreadable/missing assignment number must not collapse all
            // visible rows called "Homework" into a single supposed duplicate.
            let ambiguous = candidate.assignmentName.trimmed.isEmpty ||
                candidate.assignmentName.range(of: #"^(?:Homework|Lab|Worksheet)(?:\s+[A-Z])?$"#, options: [.regularExpression, .caseInsensitive]) != nil
            let key = candidate.identityKey + (ambiguous ? "|" + (candidate.sourceDeadlineText ?? candidate.dueDate.map { String($0.timeIntervalSince1970) } ?? candidate.id.uuidString) : "")
            guard var existing = byKey[key] else {
                byKey[key] = candidate
                insertionOrder.append(key)
                continue
            }

            if richness(candidate) > richness(existing) {
                var replacement = candidate
                replacement.sourceImages = Array(Set(existing.sourceImages + candidate.sourceImages)).sorted()
                replacement.warnings = Array(Set(existing.warnings + candidate.warnings)).sorted()
                if datesConflict(existing.dueDate, candidate.dueDate) {
                    replacement.warnings.append("Conflicting deadlines found; verify the selected deadline.")
                }
                existing = replacement
            } else {
                existing.sourceImages = Array(Set(existing.sourceImages + candidate.sourceImages)).sorted()
                existing.warnings = Array(Set(existing.warnings + candidate.warnings)).sorted()
                if datesConflict(existing.dueDate, candidate.dueDate) {
                    existing.warnings.append("Conflicting deadlines found; verify the selected deadline.")
                }
            }
            byKey[key] = existing
        }

        return insertionOrder.compactMap { byKey[$0] }
    }

    private func richness(_ candidate: AssignmentCandidate) -> Int {
        candidate.assignmentName.count +
            (candidate.assignmentType == nil ? 0 : 20) +
            (candidate.questionCount == nil ? 0 : 20) +
            (candidate.courseCode.isEmpty ? 0 : 10)
    }

    private func datesConflict(_ lhs: Date?, _ rhs: Date?) -> Bool {
        guard let lhs, let rhs else { return false }
        return abs(lhs.timeIntervalSince(rhs)) > 60
    }
}
