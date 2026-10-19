import SwiftUI
import ReminderSnapCore

struct ConnectionsView: View {
    @EnvironmentObject private var model: AppModel
    let compact: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: model.copy("Help, whenever you need it", "随时为你提供帮助"))
                Text(model.copy("A place for every deadline.", "让截止日期各就其位。"))
                    .font(.system(size: compact ? 29 : 36, weight: .medium)).tracking(-1)
                Text(model.copy("Tasks stay in Reminders. Companion blocks live in a calendar you can hide at any time.", "任务保存在提醒事项中，伴随时间块保存在可随时隐藏的日历中。"))
                    .font(.system(size: 14)).foregroundStyle(Studio.muted).fixedSize(horizontal: false, vertical: true)
                GuideSteps()
                AppleConnectionsSection()
                GuideChecklist()
                Button(model.copy("Replay first-launch guide", "重新查看首次使用引导")) { model.showingSetup = true }.buttonStyle(QuietButtonStyle())
                Button(model.copy("Back to Add Reminder", "返回添加提醒")) { model.page = .addReminder }.buttonStyle(SilverButtonStyle())
            }.padding(compact ? 22 : 34).frame(maxWidth: 850, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
}

struct AppleConnectionsSection: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
                Text(model.copy("Connect your Apple apps", "连接 Apple 应用")).font(.title3.weight(.medium))
                FieldLabel(title: model.copy("Where to save", "保存位置")) {
                    Picker(model.copy("Output", "输出"), selection: $model.outputMode) {
                        ForEach(OutputMode.allCases) { Text(model.t($0.rawValue)).tag($0) }
                    }.pickerStyle(.menu)
                }
                if model.outputMode.usesReminders { DestinationPanel(reminders: true) }
                if model.outputMode.usesCalendar { DestinationPanel(reminders: false) }
                if model.isSettingUp || model.isRefreshingAccess { ProgressView(model.copy("Checking access…", "正在检查权限…")) }
                if !model.t(model.setupMessage).isEmpty {
                    Text(model.t(model.setupMessage)).font(.callout).foregroundStyle(Studio.amber).textSelection(.enabled)
                }
                ViewThatFits(in: .horizontal) {
                    HStack { connectionButtons }
                    VStack(alignment: .leading) { connectionButtons }
                }
        }.disabled(model.isProcessing || model.isSettingUp)
    }
    @ViewBuilder private var connectionButtons: some View {
                    Button(model.copy("Check again", "重新检查")) { model.checkAccessAgain() }.buttonStyle(QuietButtonStyle())
                    Button(model.copy("Open Settings", "打开设置")) { model.openSettings() }.buttonStyle(QuietButtonStyle())
    }
}

struct GuideChecklist: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(model.copy("Before your first real task", "保存第一个真实任务前"), systemImage: "checkmark.shield").font(.system(size: 14, weight: .medium))
                        Text(model.copy("Use iCloud destinations if you want Apple to sync between devices. ReminderSnap itself does not upload your files.", "选择 iCloud 目标可通过 Apple 在设备间同步。ReminderSnap 本身不会上传文件。"))
                        Text(model.copy("For native reminders in Calendar, use macOS 15 / iOS 18 or later and enable Scheduled Reminders in Calendar. Companion blocks are separate events and also work on older supported systems.", "在日历中查看原生提醒事项需要 macOS 15 / iOS 18 或更新系统，并在日历中开启「计划的提醒事项」。伴随时间块是独立日程，也支持较旧系统。"))
                        Text(model.copy("Choose a dedicated calendar such as “ReminderSnap Deadlines” so you can hide all companion blocks with one calendar checkbox.", "建议使用独立日历，例如「ReminderSnap Deadlines」，这样可通过日历的勾选框统一隐藏时间块。"))
                        Text(model.copy("Allow notifications for Apple Reminders and Calendar in system settings. Focus and device settings can silence alerts. Test one task before relying on notifications.", "请在系统设置中允许 Apple 提醒事项和日历发送通知。专注模式和设备设置可能会静音通知，正式使用前请先测试一个任务。"))
                        Text(model.copy("The real deadline never moves. A 23:59 deadline can have a separate 22:00–23:00 Calendar block. Extra alerts are delivered by Calendar; the deadline alert belongs to Reminders.", "真实截止时间不会改变。23:59 截止的任务可以配有独立的 22:00–23:00 日历时间块。额外通知由日历发送，截止时通知由提醒事项发送。"))
                        Text(model.copy("No access or no list? Open Settings, enable full Reminders/Calendar access, then return and choose Check again. Select an existing destination or create one above. No iCloud account here? Set it up in Apple’s apps first.", "没有权限或列表？请在系统设置中开启提醒事项/日历的完整访问权限，返回后点击「重新检查」。在上方选择或创建目标。若未显示 iCloud 账户，请先在 Apple 应用中完成设置。"))
                    }.font(.system(size: 12)).foregroundStyle(Studio.muted).lineSpacing(3)
                }
    }
}

struct GuideSteps: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 18) {
                step("1", model.copy("Add your files", "导入文件"), model.copy("Open Add Reminder. Drop images or PDFs, choose Files, or use Photos. Multiple screenshots can be read together.", "打开「添加提醒」，拖入图片或 PDF，或从文件/照片中选择。可以一次识别多张截图。"))
                step("2", model.copy("Check the list below", "核对下方列表"), model.copy("Review every title and deadline. Tap a task to edit. Fill in missing course/year information and resolve review warnings.", "核对每个标题与截止日期，点击任务即可编辑。补充缺少的课程/年份并处理待核对提示。"))
                step("3", model.copy("Save selected tasks", "保存所选任务"), model.copy("Connect destinations below, then save. Clear All only empties the current review; it never deletes saved reminders or events.", "在下方连接保存位置，然后保存任务。「清空全部」只清空本次待核对列表，不删除已保存的提醒或日程。"))
            }
        }
    }
    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(width: 28, height: 28).background(Studio.elevated).clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(Studio.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DestinationPanel: View {
    @EnvironmentObject private var model: AppModel
    let reminders: Bool
    @State private var name = ""
    @State private var accountID = ""
    private var access: Bool { reminders ? model.reminderAccess : model.calendarAccess }
    private var destinations: [DestinationChoice] { reminders ? model.reminderLists : model.calendars }
    private var accounts: [AccountChoice] { reminders ? model.reminderAccounts : model.calendarAccounts }
    private var selectedID: Binding<String> { reminders ? $model.selectedListID : $model.selectedCalendarID }
    private var chosenAccount: String { accountID.isEmpty ? (accounts.first?.id ?? "") : accountID }
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 13) {
                    Image(systemName: reminders ? "checklist" : "calendar").font(.system(size: 24, weight: .light)).frame(width: 34)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(reminders ? model.copy("Apple Reminders", "Apple 提醒事项") : model.copy("Apple Calendar", "Apple 日历")).font(.system(size: 17, weight: .medium))
                        Text(reminders ? model.copy("The real deadline & completion", "真实截止时间与完成状态") : model.copy("A little space to see what’s due", "直观展示即将到期的任务")).font(.system(size: 11)).foregroundStyle(Studio.muted)
                    }
                    Spacer(minLength: 0)
                    Pill(text: access ? model.copy("Allowed", "已授权") : model.copy("Not connected", "未连接"), color: access ? Studio.green : Studio.amber)
                }
                if access {
                    Picker(reminders ? model.copy("List", "列表") : model.copy("Calendar", "日历"), selection: selectedID) {
                        Text(model.copy("Choose a destination", "请选择目标")).tag("")
                        ForEach(destinations) { Text($0.label).tag($0.id) }
                    }.pickerStyle(.menu)
                    if !destinations.contains(where: { $0.id == selectedID.wrappedValue }) {
                        Text(model.copy("Choose or create a destination to finish connecting.", "选择或创建目标以完成连接。")).font(.caption).foregroundStyle(Studio.amber)
                    }
                    DisclosureGroup(reminders ? model.copy("Create a new list", "创建新列表") : model.copy("Create a dedicated calendar", "创建专用日历")) {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField(reminders ? model.copy("e.g. University", "例如：大学任务") : "ReminderSnap Deadlines", text: $name).studioField()
                            Picker(model.copy("Account", "账户"), selection: Binding(get: { chosenAccount }, set: { accountID = $0 })) {
                                ForEach(accounts) { Text($0.name).tag($0.id) }
                            }
                            if accounts.isEmpty {
                                Text(model.copy("No writable account is available. Configure an account in Apple’s app first.", "尚无可写入的账户，请先在 Apple 应用中设置账户。")).font(.caption).foregroundStyle(Studio.amber)
                            }
                            Button(reminders ? model.copy("Create list", "创建列表") : model.copy("Create calendar", "创建日历")) {
                                model.createDestination(name: name.trimmingCharacters(in: .whitespacesAndNewlines), accountID: chosenAccount, reminders: reminders)
                            }.buttonStyle(QuietButtonStyle()).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chosenAccount.isEmpty || model.isSettingUp)
                        }.padding(.top, 12)
                    }.font(.system(size: 12)).foregroundStyle(Studio.muted)
                } else {
                    Text(model.copy("Grant full access to select a destination and avoid duplicates. You can import and review without it. If access was denied, enable it in Settings and check again.", "授权完整访问权限后即可选择目标并避免重复添加。无需授权也可导入和核对。若权限已被拒绝，请在系统设置中开启后重新检查。" )).font(.system(size: 12)).foregroundStyle(Studio.muted)
                    Button(model.copy("Connect", "连接")) { model.connect(reminders: reminders) }.buttonStyle(SilverButtonStyle(small: true)).disabled(model.isSettingUp)
                }
            }
        }
    }
}
