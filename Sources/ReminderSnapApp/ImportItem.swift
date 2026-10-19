import Foundation
import ReminderSnapCore

enum ImportStatus: Equatable {
    case ready
    case duplicate
    case updateDeadline
    case needsReview

    var label: String {
        switch self {
        case .ready: return "Ready"
        case .duplicate: return "Already exists"
        case .updateDeadline: return "Deadline changed"
        case .needsReview: return "Needs review"
        }
    }
}

struct ImportItem: Identifiable {
    let id: UUID
    var candidate: AssignmentCandidate
    var isSelected: Bool
    var status: ImportStatus
    var deadlineNotificationEnabled: Bool
    var companionEventEnabled: Bool
    var companionEventStartAlertEnabled: Bool
    var companionEventAdditionalLeadTimes: [TimeInterval]

    init(
        candidate: AssignmentCandidate,
        deadlineNotificationEnabled: Bool,
        companionEventEnabled: Bool,
        companionEventStartAlertEnabled: Bool,
        companionEventAdditionalLeadTimes: [TimeInterval]
    ) {
        self.id = candidate.id
        self.candidate = candidate
        self.isSelected = candidate.dueDate != nil && !candidate.courseCode.isEmpty
        self.status = candidate.warnings.isEmpty ? .ready : .needsReview
        self.deadlineNotificationEnabled = deadlineNotificationEnabled
        self.companionEventEnabled = companionEventEnabled
        self.companionEventStartAlertEnabled = companionEventStartAlertEnabled
        self.companionEventAdditionalLeadTimes = companionEventAdditionalLeadTimes
    }
}
