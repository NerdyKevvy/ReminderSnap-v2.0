import Foundation
import CryptoKit

public enum PlannerWorkflow: String, Codable, CaseIterable, Identifiable, Sendable {
    case inApp, apple, google
    public var id: String { rawValue }
}

public enum GoogleCalendarEventLink {
    /// Google's event links otherwise use the browser's default account, which
    /// can differ from the account connected to this device.
    public static func url(_ eventLink: String, email: String) -> URL? {
        guard !email.trimmed.isEmpty,
              var components = URLComponents(string: eventLink),
              components.scheme == "https",
              components.host == "calendar.google.com" ||
                (components.host == "www.google.com" && components.path == "/calendar/event") else { return nil }
        components.host = "calendar.google.com"
        var query = components.queryItems ?? []
        query.removeAll { $0.name == "authuser" }
        query.append(URLQueryItem(name: "authuser", value: email.trimmed))
        components.queryItems = query
        return components.url
    }
}

public struct CourseProfile: Identifiable, Codable, Sendable {
    public var id: String
    public var name: String
    public var section: String
    public var year: Int?
    public var timeZoneIdentifier: String
    public var colorIndex: Int
    public var modifiedAt: Date
    public var isArchived: Bool?
    public var isDeleted: Bool?

    public init(name: String, section: String = "", year: Int? = nil,
                timeZoneIdentifier: String = TimeZone.current.identifier, colorIndex: Int = 0) {
        self.name = name; self.id = CourseNormalizer.tag(from: name)
        self.section = section; self.year = year; self.timeZoneIdentifier = timeZoneIdentifier
        self.colorIndex = colorIndex; self.modifiedAt = Date()
    }

    public func renamed(_ name: String) -> CourseProfile {
        var copy = self
        copy.name = name.trimmed; copy.id = CourseNormalizer.tag(from: copy.name)
        copy.modifiedAt = Date()
        return copy
    }

    public func tombstone() -> CourseProfile {
        var copy = self
        copy.isDeleted = true; copy.name = ""; copy.section = ""; copy.year = nil
        copy.modifiedAt = Date()
        return copy
    }
}

public struct SavedAssignment: Identifiable, Codable, Sendable {
    public var id: UUID
    public var candidate: AssignmentCandidate
    public var createdAt: Date
    public var modifiedAt: Date
    public var isCompleted: Bool
    public var isDeleted: Bool
    public var isSample: Bool
    public var alertsEnabled: Bool
    public var alertLeadTimes: [TimeInterval]
    public var dateOnlyAlertHour: Int
    public var workflow: PlannerWorkflow
    public var exportOwner: String
    public var exportedAt: Date?
    public var exportError: String?
    public var appleReminders: Bool
    public var appleCalendar: Bool
    public var companionBlock: Bool
    public var googleCalendarID: String?
    public var googleEventID: String?
    public var googleEventURL: String?
    public var googleAccountID: String?
    public var deleteLinkedItems: Bool?
    public var isTestItem: Bool?
    public var removeCalendarBlockRequested: Bool?

    public init(candidate: AssignmentCandidate, workflow: PlannerWorkflow = .inApp,
                alertsEnabled: Bool = true, alertLeadTimes: [TimeInterval] = [86400, 7200],
                exportOwner: String = "", isSample: Bool = false) {
        let year = candidate.dueDate.map { date -> Int in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
            return calendar.component(.year, from: date)
        } ?? 0
        let ambiguous = candidate.assignmentName.range(of: #"^(?:Homework|Lab|Worksheet)(?:\s+[A-Z])?$"#, options: [.regularExpression, .caseInsensitive]) != nil
        self.id = Self.stableID(candidate.identityKey + "|" + String(year) + (ambiguous ? "|" + String(candidate.dueDate?.timeIntervalSince1970 ?? 0) : ""))
        self.candidate = candidate
        // Keep source images and OCR out of persistent/synced records.
        self.candidate.sourceImages = []; self.candidate.warnings = []
        self.candidate.sourceDeadlineText = nil
        self.createdAt = Date(); self.modifiedAt = Date()
        self.isCompleted = false; self.isDeleted = false; self.isSample = isSample
        self.alertsEnabled = alertsEnabled; self.alertLeadTimes = Array(Set(alertLeadTimes)).sorted(by: >)
        self.dateOnlyAlertHour = 9; self.workflow = workflow; self.exportOwner = exportOwner
        self.appleReminders = false; self.appleCalendar = false; self.companionBlock = true
    }

    public var needsExport: Bool {
        workflow != .inApp && (exportedAt == nil || modifiedAt > exportedAt!)
    }

    /// Preserve only the identity and pending link cleanup information after a
    /// deletion. Offline replicas still need a tombstone, not the assignment.
    public mutating func eraseDeletedContent() {
        guard isDeleted else { return }
        candidate = AssignmentCandidate(courseCode: "", assignmentName: "", dueDate: nil,
            hasExplicitTime: false, timeZoneIdentifier: nil, sourcePlatform: .unknown, sourceImages: [])
        alertsEnabled = false; alertLeadTimes = []; exportError = nil
        if !needsExport {
            googleCalendarID = nil; googleEventID = nil; googleEventURL = nil; googleAccountID = nil
            exportOwner = ""; appleReminders = false; appleCalendar = false
            workflow = .inApp; deleteLinkedItems = nil; removeCalendarBlockRequested = nil
        }
    }

    public func isOverdue(at now: Date = Date()) -> Bool {
        guard !isCompleted, !isDeleted, let due = candidate.dueDate else { return false }
        if candidate.hasExplicitTime { return due < now }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        return (calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: due)) ?? due) <= now
    }

    public static func stableID(_ text: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(text.utf8)).prefix(16))
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

public struct PlannedAlert: Identifiable, Equatable, Sendable {
    public var id: String
    public var taskID: UUID
    public var date: Date
    public var title: String
}

public enum PlannerAlertSchedule {
    /// Keep a bounded, nearest-first schedule. Never schedule in the past.
    /// Date-only entries use an explicit morning preference, not midnight UTC.
    public static func pending(tasks: [SavedAssignment], now: Date = Date(), limit: Int = 60) -> [PlannedAlert] {
        var output: [PlannedAlert] = []
        for task in tasks where !task.isDeleted && !task.isCompleted && task.alertsEnabled && !task.isSample {
            guard let due = task.candidate.dueDate else { continue }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = task.candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
            let anchor = task.candidate.hasExplicitTime ? due :
                (calendar.date(bySettingHour: task.dateOnlyAlertHour, minute: 0, second: 0, of: due) ?? due)
            let offsets = task.candidate.hasExplicitTime ? task.alertLeadTimes : [0, 86400]
            for offset in Set(offsets.filter { $0.isFinite && $0 >= 0 && $0 <= 365 * 86400 }) {
                let date = task.candidate.hasExplicitTime ? anchor.addingTimeInterval(-offset) :
                    (calendar.date(byAdding: .day, value: offset == 0 ? 0 : -1, to: anchor) ?? anchor.addingTimeInterval(-offset))
                guard date > now else { continue }
                output.append(PlannedAlert(id: "assignment.\(task.id.uuidString).\(Int(offset))", taskID: task.id,
                                           date: date, title: task.candidate.reminderTitle))
            }
        }
        return Array(output.sorted { $0.date < $1.date }.prefix(max(0, limit)))
    }
}

public enum SectionSelection {
    public static func matches(_ candidate: AssignmentCandidate, profile: CourseProfile?) -> Bool {
        guard profile?.isArchived != true, let selected = profile?.section.trimmed, !selected.isEmpty,
              let section = candidate.sectionCode ?? LayoutInterpreter.section(in: candidate.assignmentName) else { return true }
        return selected.caseInsensitiveCompare(section) == .orderedSame
    }
}
