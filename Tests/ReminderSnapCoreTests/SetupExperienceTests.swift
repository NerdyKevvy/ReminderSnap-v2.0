import Foundation
import ReminderSnapCore

enum SetupExperienceTests {
    @MainActor static func run() async throws {
        try guidePersistence()
        try approvalFeedback()
        try await latePermissionRefresh()
        print("Setup guide migration, approval feedback and late permission-refresh tests passed.")
    }

    private static func require(_ value: Bool, _ message: String) throws {
        if !value { throw NSError(domain: "SetupExperienceTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    @MainActor private static func guidePersistence() throws {
        let suite = "ReminderSnap.SetupTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw NSError(domain: "SetupExperienceTests", code: 2)
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        try require(SetupGuideProgress(defaults: defaults).needsPresentation, "Fresh install skipped the guide")
        // Reproduce TestFlight retaining a pre-update completion preference.
        defaults.set(true, forKey: "ReminderSnap.SetupCompleted.v2")
        let upgraded = SetupGuideProgress(defaults: defaults)
        try require(upgraded.needsPresentation, "Old completion flag suppressed the revised guide")
        try require(SetupGuideProgress(defaults: defaults).needsPresentation, "An interrupted guide was marked complete")
        upgraded.complete()
        try require(!SetupGuideProgress(defaults: defaults).needsPresentation, "Completed guide reappeared after relaunch")
        defaults.set(SetupGuideProgress.currentRevision + 1, forKey: SetupGuideProgress.completionKey)
        try require(!SetupGuideProgress(defaults: defaults).needsPresentation, "Downgrade repeated a newer completed guide")
    }

    private static func approvalFeedback() throws {
        var existing = PermissionSetupProgress()
        existing.observe(reminders: .full, calendar: .full)
        try require(!existing.restartRecommended, "Existing access requests a restart on every launch")

        var progress = PermissionSetupProgress()
        progress.observe(reminders: .notDetermined, calendar: .notDetermined)
        progress.recordApproval(reminders: false)
        progress.observe(reminders: .notDetermined, calendar: .notDetermined)
        try require(progress.restartRecommended, "Successful grant has no restart guidance")
        try require(progress.awaitingConfirmation(reminders: false, permission: .notDetermined), "Successful callback was shown as unrequested access")
        try require(!PermissionState.notDetermined.canReadAndWrite, "UI acknowledgement enabled unauthorized saving")
        try require(!progress.awaitingConfirmation(reminders: true, permission: .notDetermined), "Calendar grant leaked to Reminders")
        try require(progress.awaitingConfirmation(reminders: false, permission: .writeOnly), "Stale add-only status was not explained")

        progress.observe(reminders: .notDetermined, calendar: .full)
        try require(!progress.awaitingConfirmation(reminders: false, permission: .full), "Confirmed full access still shown as pending")
        try require(progress.restartRecommended, "Guidance disappeared before relaunch")
        progress.observe(reminders: .notDetermined, calendar: .denied)
        try require(!progress.awaitingConfirmation(reminders: false, permission: .denied), "Revocation shown as approved")
        try require(!progress.awaitingConfirmation(reminders: false, permission: .notDetermined), "Revoked approval was retained")

        var returnedFromSettings = PermissionSetupProgress()
        returnedFromSettings.observe(reminders: .denied, calendar: .denied)
        returnedFromSettings.observe(reminders: .full, calendar: .full)
        try require(returnedFromSettings.restartRecommended, "Settings grant had no reopen advice")
        var relaunched = PermissionSetupProgress()
        relaunched.observe(reminders: .full, calendar: .full)
        try require(!relaunched.restartRecommended, "Restart notice survived a real relaunch")
    }

    @MainActor private static func latePermissionRefresh() async throws {
        var count = 0
        var status: PermissionState = .notDetermined
        let loop = PermissionRefreshLoop(delays: [0, 0, 0, 0, 0, 0]) { _ in
            count += 1
            if count == 5 { status = .full }
            return true
        }
        loop.start()
        await loop.waitForCompletion()
        try require(count == 6 && status == .full, "Refresh did not accommodate a later system update")
    }
}
