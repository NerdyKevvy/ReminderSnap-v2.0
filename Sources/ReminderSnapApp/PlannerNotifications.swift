import Foundation
import UserNotifications
import ReminderSnapCore

@MainActor
final class PlannerNotifications: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var authorized = false
    @Published private(set) var message = "Notifications are off on this device"
    @Published private(set) var scheduledCount = 0
    var openTask: ((UUID) -> Void)?
    private var generation = UUID()
    private var scheduling = false
    private var nextSchedule: (tasks: [SavedAssignment], enabled: Bool, chinese: Bool)?
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init(); center.delegate = self
    }
    func refresh() async {
        let settings = await center.notificationSettings()
        authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        message = authorized ? "Notifications allowed · Focus and system settings apply" : "Notifications are off · allow them in Settings"
    }
    func request() async {
        do { _ = try await center.requestAuthorization(options: [.alert, .badge, .sound]); await refresh() }
        catch { message = error.localizedDescription }
    }
    func schedule(tasks: [SavedAssignment], enabled: Bool, chinese: Bool) async {
        nextSchedule = (tasks, enabled, chinese)
        guard !scheduling else { return }
        scheduling = true; defer { scheduling = false }
        while let next = nextSchedule {
            nextSchedule = nil
            await applySchedule(tasks: next.tasks, enabled: next.enabled, chinese: next.chinese)
        }
    }
    private func applySchedule(tasks: [SavedAssignment], enabled: Bool, chinese: Bool) async {
        let token = UUID(); generation = token
        await refresh()
        guard token == generation else { return }
        let existing = await center.pendingNotificationRequests()
        guard token == generation else { return }
        let alerts = enabled && authorized ? PlannerAlertSchedule.pending(tasks: tasks) : []
        let wanted = Set(alerts.map(\.id))
        center.removePendingNotificationRequests(withIdentifiers: existing.map(\.identifier).filter { $0.hasPrefix("assignment.") && !wanted.contains($0) })
        if !enabled { scheduledCount = 0; return }
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.identifier, $0) })
        for alert in alerts {
            guard token == generation else { return }
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alert.date)
            components.timeZone = calendar.timeZone
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = chinese ? "作业即将截止，点击查看任务详情。" : "An assignment is coming up. Tap to see its deadline."
            content.sound = .default
            content.userInfo = ["taskID": alert.taskID.uuidString]
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            if let old = byID[alert.id], let oldTrigger = old.trigger as? UNCalendarNotificationTrigger,
               oldTrigger.nextTriggerDate() == trigger.nextTriggerDate(), old.content.title == content.title,
               old.content.body == content.body { continue }
            do { try await center.add(UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)) }
            catch { message = error.localizedDescription }
        }
        guard token == generation else { return }
        scheduledCount = alerts.count
        // Bound scheduling to leave room for test notifications. Never silently
        // claim unlimited notifications for an entire term on iOS.
        if alerts.count >= 60 {
            message = chinese ? "已安排最近 60 个通知；请定期打开应用以安排后续通知。" : "Next 60 alerts scheduled. Open the app regularly to refresh later alerts."
        }
    }
    func test(chinese: Bool) async {
        await request()
        guard authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "ReminderSnap"
        content.body = chinese ? "测试通知：你的作业通知已准备好。" : "Test notification: your assignment alerts are ready."
        content.sound = .default
        do { try await center.add(UNNotificationRequest(identifier: "test.notification", content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))) }
        catch { message = error.localizedDescription }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let text = response.notification.request.content.userInfo["taskID"] as? String,
              let id = UUID(uuidString: text) else { return }
        await MainActor.run { self.openTask?(id) }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
