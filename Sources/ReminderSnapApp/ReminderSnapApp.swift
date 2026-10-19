import SwiftUI

@main
struct ReminderSnapApplication: App {
    @StateObject private var model = AppModel()
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
                Button(model.copy("Clear All…", "清空全部…")) { model.showingClearConfirmation = true }
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
