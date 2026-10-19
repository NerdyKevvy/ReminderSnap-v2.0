import Foundation

public struct ParsedDeadline: Sendable {
    public let date: Date
    public let hasExplicitTime: Bool
    public let timeZoneIdentifier: String?
}

public enum DeadlineParser {
    private static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
    private static let monthPattern = "(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)"
    public static func containsDate(_ text: String) -> Bool { dateFields(text) != nil }
    public static func hasYear(_ text: String) -> Bool { dateFields(text)?.year != nil }
    public static func beginsWithDate(_ text: String) -> Bool {
        let weekday = "(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun)"
        return text.range(of: #"^\s*(?:"# + weekday + #"\s*,?\s*)?(?:"# + monthPattern + #"\.?\s+\d|\d{1,2}\s+"# + monthPattern + #"|\d{1,2}/\d{1,2}|20\d{2}-\d{1,2}-\d{1,2})"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
    public static func titleBeforeDate(_ text: String) -> String? {
        guard !beginsWithDate(text) else { return nil }
        let weekday = "(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun)"
        let dateStart = "(?:" + monthPattern + #"\.?\s+\d{1,2}|\d{1,2}\s+"# + monthPattern + #"|20\d{2}-\d{1,2}-\d{1,2}|\d{1,2}/\d{1,2})"#
        return text.firstRegexMatch(pattern: #"^\s*(.+?)\s+(?:"# + weekday + #"\s*,?\s*)?"# + dateStart, options: [.caseInsensitive])?.capture(1)?.trimmed
    }

    /// Never invent a year or silently roll an invalid date forward.
    public static func parse(_ rawText: String, fallbackYear: Int? = nil, fallbackTimeZone: String? = nil) -> ParsedDeadline? {
        let text = rawText.replacingOccurrences(of: #"(\d)(?:st|nd|rd|th)\b"#, with: "$1", options: [.regularExpression, .caseInsensitive])
        guard let fields = dateFields(text), let year = fields.year ?? fallbackYear, (1900...2199).contains(year) else { return nil }
        let abbreviation = text.firstRegexMatch(pattern: #"\b(EDT|EST|UTC|GMT|CDT|CST|MDT|MST|PDT|PST)\b"#, options: [.caseInsensitive])?.capture(1)?.uppercased()
        let zone = timeZone(for: abbreviation) ?? fallbackTimeZone.flatMap(TimeZone.init(identifier:)) ?? .current
        var hour = 0, minute = 0
        var explicitTime = false
        if let match = text.firstRegexMatch(pattern: #"\b(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?\b"#, options: [.caseInsensitive]),
           let h = match.capture(1).flatMap(Int.init), let m = match.capture(2).flatMap(Int.init) {
            hour = h; minute = m; explicitTime = true
            if let period = match.capture(3)?.uppercased(), !period.isEmpty {
                guard (1...12).contains(hour) else { return nil }
                hour = hour % 12 + (period == "PM" ? 12 : 0)
            }
        } else if let match = text.firstRegexMatch(pattern: #"\b(\d{1,2})\s*(AM|PM)\b"#, options: [.caseInsensitive]),
                  let h = match.capture(1).flatMap(Int.init) {
            guard (1...12).contains(h) else { return nil }
            hour = h % 12 + (match.capture(2)?.uppercased() == "PM" ? 12 : 0)
            explicitTime = true
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        var components = DateComponents()
        components.timeZone = zone
        components.year = year; components.month = fields.month; components.day = fields.day
        components.hour = hour; components.minute = minute
        guard let date = calendar.date(from: components) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard check.year == year, check.month == fields.month, check.day == fields.day,
              check.hour == hour, check.minute == minute else { return nil }
        return ParsedDeadline(date: date, hasExplicitTime: explicitTime, timeZoneIdentifier: zone.identifier)
    }

    private static func dateFields(_ text: String) -> (year: Int?, month: Int, day: Int)? {
        if let m = text.firstRegexMatch(pattern: #"\b(20\d{2})-(\d{1,2})-(\d{1,2})\b"#),
           let year = m.capture(1).flatMap(Int.init), let month = m.capture(2).flatMap(Int.init), let day = m.capture(3).flatMap(Int.init) {
            return (year, month, day)
        }
        if let m = text.firstRegexMatch(pattern: #"\b(\d{1,2})/(\d{1,2})(?:/(20\d{2}))?\b"#),
           let month = m.capture(1).flatMap(Int.init), let day = m.capture(2).flatMap(Int.init) {
            return (m.capture(3).flatMap(Int.init), month, day)
        }
        if let m = text.firstRegexMatch(pattern: #"\b("# + monthPattern + #")\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?:\s*,?\s*(20\d{2}))?\b"#, options: [.caseInsensitive]),
           let name = m.capture(1), let month = months.firstIndex(of: String(name.lowercased().prefix(3))), let day = m.capture(2).flatMap(Int.init) {
            return (m.capture(3).flatMap(Int.init), month + 1, day)
        }
        if let m = text.firstRegexMatch(pattern: #"\b(\d{1,2})(?:st|nd|rd|th)?\s+("# + monthPattern + #")\.?(?:\s*,?\s*(20\d{2}))?\b"#, options: [.caseInsensitive]),
           let name = m.capture(2), let month = months.firstIndex(of: String(name.lowercased().prefix(3))), let day = m.capture(1).flatMap(Int.init) {
            return (m.capture(3).flatMap(Int.init), month + 1, day)
        }
        return nil
    }

    private static func timeZone(for abbreviation: String?) -> TimeZone? {
        switch abbreviation {
        case "EDT", "EST": return TimeZone(identifier: "America/New_York")
        case "CDT", "CST": return TimeZone(identifier: "America/Chicago")
        case "MDT", "MST": return TimeZone(identifier: "America/Denver")
        case "PDT", "PST": return TimeZone(identifier: "America/Los_Angeles")
        case "UTC", "GMT": return TimeZone(secondsFromGMT: 0)
        default: return nil
        }
    }
}
