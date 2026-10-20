import SwiftUI
import ReminderSnapCore

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel
    let compact: Bool
    @State private var showingPrivacy = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: model.copy("Small details, your way", "让细节符合你的习惯"))
                Text(model.copy("Set your rhythm.", "设定你的节奏。"))
                    .font(.system(size: compact ? 29 : 36, weight: .medium)).tracking(-1)
                Panel {
                    Picker(model.copy("Language", "语言"), selection: $model.language) {
                        Text("English").tag(AppLanguage.english)
                        Text("简体中文").tag(AppLanguage.simplifiedChinese)
                    }.pickerStyle(.menu).accessibilityIdentifier("settings.language")
                }
                Panel {
                    VStack(alignment: .leading, spacing: 19) {
                        Text(model.copy("Defaults for the next import", "下次导入的默认设置")).font(.headline)
                        Toggle(model.copy("Notify at the reminder’s deadline", "提醒事项截止时通知"), isOn: Binding(get: { model.defaultDeadlineNotificationEnabled }, set: model.setDefaultDeadlineNotificationEnabled))
                        Toggle(model.copy("Include Calendar companion blocks", "添加日历伴随时间块"), isOn: Binding(get: { model.defaultCompanionEventsEnabled }, set: model.setDefaultCompanionEventsEnabled))
                            .disabled(model.outputMode == .calendar)
                        Toggle(model.copy("Notify when the block starts", "日历时间块开始时通知"), isOn: Binding(get: { model.defaultCompanionEventStartAlertEnabled }, set: model.setDefaultCompanionEventStartAlertEnabled))
                        Divider().overlay(Studio.line)
                        LeadTimeEditor(values: Binding(get: { model.defaultCompanionEventAdditionalLeadTimes }, set: model.setDefaultCompanionEventAdditionalLeadTimes))
                        Button(model.copy("Apply alert defaults to this import", "将通知默认设置应用到本次导入")) { model.applyNotificationDefaultsToAll() }.buttonStyle(QuietButtonStyle()).disabled(model.items.isEmpty)
                    }.font(.system(size: 13))
                }.disabled(model.isProcessing)
                Panel {
                    VStack(alignment: .leading, spacing: 16) {
                        Label(model.copy("Private. Local. Yours.", "私密、本地、属于你。"), systemImage: "lock.shield").font(.headline)
                        Text(model.copy("Apple Vision reads on this device. No account, server, advertising, or AI subscription. Your chosen Apple accounts handle any reminder and calendar syncing.", "Apple Vision 在设备本地识别。无需账户、服务器或 AI 订阅，也没有广告。提醒事项和日历同步由你选择的 Apple 账户处理。"))
                            .font(.system(size: 12)).foregroundStyle(Studio.muted).lineSpacing(4)
                        Button(model.copy("Privacy Policy", "隐私政策")) { showingPrivacy = true }.buttonStyle(QuietButtonStyle())
                        Link(model.copy("Support on GitHub", "在 GitHub 获取支持"), destination: URL(string: "https://github.com/NerdyKevvy/ReminderSnap-v2.0/blob/main/AppStore/SUPPORT.md")!)
                            .font(.system(size: 12))
                        Button(model.copy("Connections & setup help", "连接与设置帮助")) { model.page = .userGuide }.buttonStyle(QuietButtonStyle())
                        Text("ReminderSnap 2.0").font(.system(size: 11)).foregroundStyle(Studio.muted)
                    }
                }
            }.padding(compact ? 22 : 34).frame(maxWidth: 800, alignment: .leading).frame(maxWidth: .infinity)
        }.sheet(isPresented: $showingPrivacy) { PrivacyView().environmentObject(model) }
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                BrandMark(size: 38)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ReminderSnap").font(.headline)
                    Text(model.copy("GET STARTED · \(step + 1) OF 3", "开始使用 · 第 \(step + 1) / 3 步"))
                        .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Studio.muted)
                }
                Spacer()
                Picker(model.copy("Language", "语言"), selection: $model.language) {
                    Text("English").tag(AppLanguage.english)
                    Text("简体中文").tag(AppLanguage.simplifiedChinese)
                }.labelsHidden().fixedSize()
            }.padding(24)
            Divider().overlay(Studio.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if step == 0 {
                        Text(model.copy("Less typing.\nMore doing.", "少一点输入，\n多一点专注。"))
                            .font(.system(size: 36, weight: .medium)).tracking(-1)
                        Text(model.copy("Turn screenshots into real Apple reminders and optional Calendar blocks. Everything is read locally; nothing is saved until you choose to save.", "将截图变为真实的 Apple 提醒事项和可选的日历时间块。识别完全在本地进行，只有点击保存后才会创建任务。"))
                            .font(.system(size: 14)).foregroundStyle(Studio.muted).lineSpacing(4)
                        GuideSteps()
                    } else if step == 1 {
                        Text(model.copy("Choose where tasks belong.", "选择任务的保存位置。"))
                            .font(.system(size: 26, weight: .medium))
                        Text(model.copy("Connect only the apps you want to use. Choose an existing list, or expand Create a new list to name your own. You can also do this later in User Guide.", "只连接你需要使用的应用。选择现有列表，或展开「创建新列表」自定义名称。也可以稍后在「使用指南」中完成。"))
                            .font(.system(size: 13)).foregroundStyle(Studio.muted)
                        AppleConnectionsSection()
                    } else {
                        Text(model.copy("Ready for your first import.", "准备好导入第一个任务。"))
                            .font(.system(size: 26, weight: .medium))
                        Label(model.destinationNeedsRepair ? model.copy("Destinations can be connected later in User Guide.", "可以稍后在使用指南中连接保存位置。") : model.copy("Your selected destinations are ready.", "所选保存位置已就绪。"), systemImage: model.destinationNeedsRepair ? "info.circle" : "checkmark.circle")
                            .font(.system(size: 13)).foregroundStyle(model.destinationNeedsRepair ? Studio.amber : Studio.green)
                        GuideChecklist()
                        Text(model.copy("Want to explore first? The sample never writes to Reminders or Calendar.", "想先体验？示例模式永远不会向提醒事项或日历写入数据。"))
                            .font(.system(size: 12)).foregroundStyle(Studio.muted)
                        Button(model.copy("Try the safe sample", "体验安全示例")) { model.finishSetup(); model.showSample() }
                            .buttonStyle(QuietButtonStyle()).accessibilityIdentifier("onboarding.sample")
                    }
                }.padding(24)
            }.id(step)
            HStack(spacing: 12) {
                if step > 0 {
                    Button(model.copy("Back", "返回")) { step -= 1 }.buttonStyle(QuietButtonStyle())
                }
                Spacer(minLength: 0)
                Button(model.copy(step == 2 ? "Start Adding Reminders" : (step == 1 && model.destinationNeedsRepair ? "Set Up Later" : "Continue"), step == 2 ? "开始添加提醒" : (step == 1 && model.destinationNeedsRepair ? "稍后设置" : "继续"))) {
                    if step == 2 { model.finishSetup() } else { step += 1 }
                }.buttonStyle(SilverButtonStyle()).accessibilityIdentifier("onboarding.continue")
            }.padding(20).background(Studio.sidebar).disabled(model.isSettingUp)
        }.background(Studio.background).foregroundStyle(Studio.silver).tint(Studio.silver).preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        #if os(macOS)
        .frame(width: 620, height: 720)
        #endif
    }
}

struct PrivacyView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.copy("Privacy Policy", "隐私政策")).font(.title2.weight(.medium))
                Spacer()
                Button(model.copy("Done", "完成")) { dismiss() }.buttonStyle(QuietButtonStyle())
            }.padding(24)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(model.copy("Effective October 19, 2026", "生效日期：2026 年 10 月 19 日")).font(.caption).foregroundStyle(Studio.muted)
                    section("On-device recognition", "本地识别", "ReminderSnap uses Apple Vision to read images and PDFs on your device. It does not upload your files or assignment text to the developer or an AI service.", "ReminderSnap 使用 Apple Vision 在设备上读取图片和 PDF，不会将文件或作业文本上传给开发者或 AI 服务。")
                    section("Apple app access", "Apple 应用访问", "With your permission, the app reads your reminder lists, calendars and existing entries to choose destinations and prevent duplicates. Only tasks you select and save are written. Creating a list or calendar is a separate, explicit action. Apple and your selected account provider handle any synchronization.", "经过你的授权，应用读取提醒事项列表、日历及已有条目，以选择保存位置并避免重复。只有你选择并保存的任务才会写入。创建列表或日历需单独操作。同步由 Apple 及你选择的账户服务商处理。")
                    section("Storage and controls", "存储与控制", "Recognition text and review tasks are held in memory. Raw recognition documents are cleared after a successful save; review tasks remain until cleared, replaced by another import, or quitting. Temporary Photos copies are removed after reading or cancellation. Preferences, saved-entry identifiers and alert-management information remain on-device. Clear All never deletes source files or saved Apple entries. Revoke permissions in system settings; manage saved entries in Reminders or Calendar. Device backups follow your Apple settings.", "识别文本和待核对任务保留在内存中。成功保存后清除原始识别文档，核对列表中的任务会保留至清空、替换导入或退出。照片的临时副本在读取或取消后移除。偏好设置、已保存条目标识符及通知管理信息保存在本地。「清空全部」不会删除原始文件或已保存的 Apple 条目。你可以在系统设置中撤销权限，并在提醒事项或日历中管理已保存的内容。设备备份由你的 Apple 设置控制。")
                    section("No tracking", "不追踪", "The app includes no advertising, analytics SDK, developer account system, or tracking. If you contact support on GitHub, information you choose to send is handled by that service and used to respond. Do not post private screenshots or personal assignments in public issues.", "应用不含广告、分析 SDK、开发者账户系统或追踪。如通过 GitHub 联系支持，你主动提供的信息会由该服务处理并用于答复。请勿在公开问题中发布私人截图或个人作业内容。")
                    Link(model.copy("Contact support on GitHub", "通过 GitHub 联系支持"), destination: URL(string: "https://github.com/NerdyKevvy/ReminderSnap-v2.0/blob/main/AppStore/SUPPORT.md")!)
                    if let text = Bundle.main.object(forInfoDictionaryKey: "ReminderSnapPrivacyPolicyURL") as? String,
                       let url = URL(string: text), url.scheme == "https" {
                        Link(model.copy("Read the published policy", "阅读已发布的隐私政策"), destination: url)
                    }
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.background(Studio.background).foregroundStyle(Studio.silver).preferredColorScheme(.dark)
        #if os(macOS)
        .frame(width: 620, height: 700)
        #endif
    }
    private func section(_ title: String, _ chineseTitle: String, _ detail: String, _ chineseDetail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.copy(title, chineseTitle)).font(.headline)
            Text(model.copy(detail, chineseDetail)).font(.system(size: 13)).foregroundStyle(Studio.muted).lineSpacing(4)
        }
    }
}
