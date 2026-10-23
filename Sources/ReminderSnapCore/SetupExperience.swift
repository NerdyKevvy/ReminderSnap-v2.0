import Foundation

/// Version the experience, not the installation. TestFlight and App Store updates
/// can retain preferences from an earlier build with the same bundle identifier.
@MainActor
public final class SetupGuideProgress {
    public static let currentRevision = 2
    public static let completionKey = "ReminderSnap.Onboarding.CompletedRevision"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var needsPresentation: Bool {
        defaults.integer(forKey: Self.completionKey) < Self.currentRevision
    }

    public func complete() {
        defaults.set(Self.currentRevision, forKey: Self.completionKey)
    }
}

/// A successful permission callback is useful feedback, but is not a substitute
/// for the system's actual authorization status when enabling reads or saves.
/// Restart advice is session-only: a real relaunch starts a new confirmation.
public struct PermissionSetupProgress {
    public private(set) var restartRecommended = false
    private var reminderRequestApproved = false
    private var calendarRequestApproved = false
    private var previousReminder: PermissionState?
    private var previousCalendar: PermissionState?

    public init() {}

    public mutating func recordApproval(reminders: Bool) {
        if reminders { reminderRequestApproved = true }
        else { calendarRequestApproved = true }
        restartRecommended = true
    }

    public mutating func observe(reminders: PermissionState, calendar: PermissionState) {
        if let previousReminder, previousReminder != .full, reminders == .full {
            restartRecommended = true
        }
        if let previousCalendar, previousCalendar != .full, calendar == .full {
            restartRecommended = true
        }
        if reminders == .denied || reminders == .restricted { reminderRequestApproved = false }
        if calendar == .denied || calendar == .restricted { calendarRequestApproved = false }
        previousReminder = reminders
        previousCalendar = calendar
    }

    public func awaitingConfirmation(reminders: Bool, permission: PermissionState) -> Bool {
        let approved = reminders ? reminderRequestApproved : calendarRequestApproved
        return approved && (permission == .notDetermined || permission == .writeOnly)
    }
}
