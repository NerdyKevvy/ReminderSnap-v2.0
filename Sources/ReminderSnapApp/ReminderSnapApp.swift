import SwiftUI
#if os(iOS)
import UIKit
#endif

@main
struct ReminderSnapApplication: App {
    @StateObject private var model = AppModel()
    #if os(iOS)
    @UIApplicationDelegateAdaptor(PlannerApplicationDelegate.self) private var appDelegate
    #endif
    var body: some Scene {
        #if os(macOS)
        // One workspace avoids shared sheets/drop handlers across multiple windows.
        Window("ReminderSnap", id: "main") {
            StudioShell().environmentObject(model).frame(minWidth: 850, minHeight: 640)
        }
        .defaultSize(width: 1180, height: 820)
        .commands {
            CommandGroup(after: .newItem) {
                Button(model.copy("Import files…", "导入文件…")) { model.chooseScreenshots() }
                    .keyboardShortcut("o").disabled(model.isProcessing || model.showingSetup)
                Button(model.copy("Clear Import…", "清空导入…")) { model.showingClearConfirmation = true }
                    .keyboardShortcut(.delete, modifiers: [.command, .shift]).disabled(!model.canClearImport || model.showingSetup)
            }
            CommandGroup(replacing: .help) {
                Button(model.copy("User Guide", "使用指南")) { model.page = .userGuide }
                Button(model.copy("First-launch walkthrough", "首次使用引导")) { model.showingSetup = true }
            }
        }
        #else
        WindowGroup { StudioShell().environmentObject(model) }
        #endif
    }
}

#if os(iOS)
final class PlannerApplicationDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // CloudKit's silent change notifications are independent of the user's
        // opt-in to visible assignment alerts. No device token goes to us.
        application.registerForRemoteNotifications()
        return true
    }
}
#endif
