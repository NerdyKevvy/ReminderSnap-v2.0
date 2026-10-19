import Foundation
import ReminderSnapCore

enum Version16Tests {
    static func run() async throws {
        try localization()
        try await permissions()
        print("v1.6 localization and permission-refresh regression tests passed.")
    }
    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "ReminderSnap16Test", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    private static func localization() throws {
        try require(Localizer.translatedKeys.count > 180, "Translation catalog incomplete")
        for key in Localizer.translatedKeys {
            let arguments = Array(repeating: "Safe_%_中文", count: key.components(separatedBy: "%@").count - 1)
            let translated = Localizer.text(key, language: .simplifiedChinese)
            try require(translated.components(separatedBy: "%@").count == key.components(separatedBy: "%@").count, "Mismatched placeholders: \(key)")
            let formatted = Localizer.text(key, language: .simplifiedChinese, arguments: arguments)
            try require(!formatted.isEmpty, "Empty translation: \(key)")
        }
        let name = "Math 100% — Homework"
        let message: LocalizedMessage = "Found \(3) task(s). Review titles, dates, and warnings before saving."
        try require(message.rendered(in: .english).hasPrefix("Found 3"), "English dynamic message")
        try require(message.rendered(in: .simplifiedChinese).hasPrefix("找到 3"), "Existing message does not switch language")
        try require(Localizer.text("Could not open: %@", language: .simplifiedChinese, arguments: [name]).contains(name), "User content changed")
        let combined = LocalizedMessage.joined([message, "Temporary recognized text cleared."])
        try require(combined.rendered(in: .simplifiedChinese).contains("临时识别文本"), "Combined status message")
        try require(AppLanguage.resolve(saved: "zh-Hans", preferredLanguages: ["en-US"]) == .simplifiedChinese, "Saved language not honored")
        try require(AppLanguage.resolve(saved: nil, preferredLanguages: ["zh-CN"]) == .simplifiedChinese, "Chinese system default")
        try require(AppLanguage.resolve(saved: "invalid", preferredLanguages: ["en-US"]) == .english, "Invalid preference fallback")
    }
    @MainActor private static func permissions() async throws {
        for state in [PermissionState.notDetermined, .denied, .restricted, .writeOnly] {
            try require(!state.canReadAndWrite, "Partial/denied access treated as full")
        }
        try require(PermissionState.full.canReadAndWrite, "Full access was rejected")
        var calls: [Bool] = []
        var busy = true
        var inventoryStale = true
        let loop = PermissionRefreshLoop(delays: [0, 0, 0]) { reconnect in
            calls.append(reconnect)
            if busy { busy = false; return false }
            if reconnect { inventoryStale = false }
            return true
        }
        loop.start(reconnect: true)
        loop.start(reconnect: true)
        await loop.waitForCompletion()
        try require(calls == [true, true, false], "Refresh was not coalesced or reconnect lost during a write")
        try require(!inventoryStale, "Stale destination session was not refreshed")
        calls = []
        loop.start()
        await loop.waitForCompletion()
        try require(calls == [false, false, false], "Background refresh resets the store unnecessarily")

        var state: PermissionState = .notDetermined
        var inventory: [String] = []
        var observed: [PermissionState] = []
        let delayed = PermissionRefreshLoop(delays: [0, 0, 0]) { _ in
            observed.append(state)
            if observed.count == 1 { state = .full }
            else if observed.count == 2 { inventory = ["Writable calendar"] }
            return true
        }
        delayed.start(reconnect: true)
        await delayed.waitForCompletion()
        try require(observed == [.notDetermined, .full, .full] && !inventory.isEmpty, "Delayed authorization did not settle without restart")
        state = .denied
        observed = []
        let revoked = PermissionRefreshLoop(delays: [0]) { _ in observed.append(state); return true }
        revoked.start(reconnect: true)
        await revoked.waitForCompletion()
        try require(observed == [.denied], "Revoked access still shown as granted")
        // A granted permission is distinct from an empty destination inventory.
        inventory = []
        try require(PermissionState.full.canReadAndWrite && inventory.isEmpty, "Inventory incorrectly controls permission")
    }
}
