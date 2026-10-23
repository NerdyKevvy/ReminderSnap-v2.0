import Foundation
import EventKit
import SwiftUI

struct LinkedAppleEventReference: Identifiable {
    let id: String
    let taskID: UUID
}

#if os(iOS)
import EventKitUI
import UIKit

/// Apple's supported event viewer shows the actual linked calendar record,
/// without relying on private/undocumented Calendar or Reminders URL schemes.
struct LinkedAppleEventPreview: UIViewControllerRepresentable {
    let reference: LinkedAppleEventReference
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator { dismiss() } }
    func makeUIViewController(context: Context) -> UINavigationController {
        let store = context.coordinator.store
        if let event = store.event(withIdentifier: reference.id),
           (event.notes ?? "").components(separatedBy: "\n").contains("ReminderSnap-Task: " + reference.taskID.uuidString) {
            let controller = EKEventViewController()
            controller.event = event; controller.allowsEditing = false
            controller.delegate = context.coordinator
            return UINavigationController(rootViewController: controller)
        }
        let unavailable = UIHostingController(rootView: VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark").font(.largeTitle)
            Text(model.copy("The linked event is not available on this device yet. Check Calendar permissions and account sync.", "本设备尚未找到关联日程，请检查日历权限与账户同步。"))
                .multilineTextAlignment(.center)
            Button(model.copy("Done", "完成")) { dismiss() }
        }.padding(30))
        return UINavigationController(rootViewController: unavailable)
    }
    func updateUIViewController(_ controller: UINavigationController, context: Context) { }
    final class Coordinator: NSObject, EKEventViewDelegate {
        let store = EKEventStore()
        let close: () -> Void
        init(close: @escaping () -> Void) { self.close = close }
        func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) { close() }
    }
}
#endif
