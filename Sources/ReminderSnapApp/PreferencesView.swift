import SwiftUI
import ReminderSnapCore

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel
    let compact: Bool
    @State private var showingPrivacy = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: model.copy("Your center. Your workflow.", "你的作业中心，你的使用方式。"))
                Text(model.copy("Make it work for you.", "让它符合你的习惯。"))
                    .font(.system(size: compact ? 29 : 36, weight: .medium)).tracking(-1)
                Panel {
                    Picker(model.copy("Language", "语言"), selection: $model.language) {
                        Text("English").tag(AppLanguage.english); Text("简体中文").tag(AppLanguage.simplifiedChinese)
                    }.pickerStyle(.menu)
                }
                WorkflowChoices()
                if model.workflow == .apple { AppleConnectionsSection() }
                if model.workflow == .google { GoogleConnectionPanel() }
                if model.savedAssignments.contains(where: { $0.isTestItem == true }) {
                    Button(model.copy("Remove onboarding test assignments & links", "移除引导测试作业及关联条目"), role: .destructive) { model.removeTestAssignments() }
                        .font(.caption)
                }
                notificationPanel
                syncPanel
                CourseManagementPanel()
                Panel {
                    VStack(alignment: .leading, spacing: 14) {
                        Label(model.copy("Linked calendar updates", "关联日历更新"), systemImage: "link").font(.headline)
                        Text(model.copy("Edits made in ReminderSnap update linked items. Apple links update on their original exporting device; Google needs the linked account connected here. Changes made externally are not imported automatically.", "ReminderSnap 中的修改会更新关联条目。Apple 关联由最初导出的设备更新；Google 需要在本机连接对应账户。外部修改不会自动导入。"))
                            .font(.caption).foregroundStyle(Studio.muted)
                        Button(model.copy("Retry linked updates", "重试关联更新")) { Task { await model.flushPendingExports() } }.buttonStyle(QuietButtonStyle())
                        Button(model.copy("Refresh existing links & alert settings", "刷新已有条目与通知设置")) { model.refreshLinkedAssignments() }
                            .buttonStyle(QuietButtonStyle()).disabled(model.isExporting)
                        Text(model.copy("\(model.planner.tasks.filter(\.needsExport).count) update(s) pending", "\(model.planner.tasks.filter(\.needsExport).count) 项更新待处理"))
                            .font(.caption).foregroundStyle(Studio.muted)
                    }
                }
                HStack {
                    Button(model.copy("Privacy Policy", "隐私政策")) { showingPrivacy = true }.buttonStyle(.plain)
                    Spacer(); Text("ReminderSnap 2.1").font(.caption).foregroundStyle(Studio.muted)
                }
                Link(model.copy("Support on GitHub", "在 GitHub 获取支持"), destination: URL(string: "https://github.com/NerdyKevvy/ReminderSnap-v2.0/blob/main/AppStore/SUPPORT.md")!)
            }.padding(compact ? 22 : 34).frame(maxWidth: 850).frame(maxWidth: .infinity)
        }.sheet(isPresented: $showingPrivacy) { PrivacyView().environmentObject(model) }
    }
    private var notificationPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 17) {
                Label(model.copy("ReminderSnap notifications", "ReminderSnap 通知"), systemImage: "bell.badge").font(.headline)
                Toggle(model.copy("Alerts on this device", "在此设备上通知"), isOn: Binding(get: { model.plannerNotificationsEnabled }, set: { enabled in
                    if enabled { model.enableAppNotifications() } else { model.plannerNotificationsEnabled = false }
                }))
                Text(model.language == .english ? model.notifications.message : (model.notifications.authorized ? "已允许通知，专注模式和系统设置仍会影响送达。" : "通知尚未开启，可在系统设置中允许。"))
                    .font(.caption).foregroundStyle(Studio.muted)
                LeadTimeEditor(values: $model.appAlertLeadTimes, purpose: model.copy("Defaults · before the real deadline", "默认通知 · 相对于真实截止时间"))
                Stepper(value: $model.dateOnlyAlertHour, in: 0...23) {
                    Text(model.copy("Date-only assignments: \(model.dateOnlyAlertHour):00", "仅日期作业：\(model.dateOnlyAlertHour):00"))
                }.font(.caption)
                Text(model.copy("Date-only tasks alert that morning and the previous morning. Timed tasks use your custom lead times. These defaults apply to new imports.", "仅日期任务会在当天和前一天早晨通知；指定时间的任务使用自定义提前量。默认设置应用于新导入的任务。"))
                    .font(.caption).foregroundStyle(Studio.muted)
                ViewThatFits {
                    HStack { notificationButtons }
                    VStack(alignment: .leading) { notificationButtons }
                }
                Text(model.copy("When ReminderSnap alerts are enabled, new linked exports suppress app-managed external alerts to avoid duplicates. After changing this preference, use ‘Refresh existing links & alert settings’ below. Alerts you added yourself are kept.", "开启 ReminderSnap 通知时，新关联导出不会重复设置本应用管理的外部通知。更改偏好后，请使用下方的“刷新已有条目与通知设置”。你自行添加的通知会保留。"))
                    .font(.caption).foregroundStyle(Studio.muted)
            }
        }
    }
    @ViewBuilder private var notificationButtons: some View {
        Button(model.copy("Send a test in 5 seconds", "5 秒后发送测试通知")) {
            Task { await model.notifications.test(chinese: model.language == .simplifiedChinese) }
        }.buttonStyle(QuietButtonStyle())
        Button(model.copy("System settings", "系统设置")) { model.openSettings() }.buttonStyle(.plain)
    }
    private var syncPanel: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Label(model.copy("Private iCloud sync", "私人 iCloud 同步"), systemImage: "icloud").font(.headline)
                Text(model.language == .english ? model.planner.syncState : (model.planner.iCloudAvailable ? "通过你的 iCloud 账户同步已确认作业。" : "当前仅保存在本机，请在系统设置中开启 iCloud。"))
                    .font(.caption).foregroundStyle(Studio.muted)
                if let error = model.planner.error { Text(error).font(.caption).foregroundStyle(Studio.amber) }
                Text(model.copy("Use the same Apple account on Mac and iPhone. Offline edits are kept locally; background sync may be delayed. Screenshots and raw OCR are not synced.", "Mac 与 iPhone 需使用同一 Apple 账户。离线修改保存在本机，后台同步可能延迟。截图和原始识别文本不会同步。"))
                    .font(.caption).foregroundStyle(Studio.muted)
                Button(model.copy("Check iCloud again", "重新检查 iCloud")) { Task { await model.planner.open(recheckAccount: true) } }.buttonStyle(QuietButtonStyle())
                #if DEBUG
                Button("Initialize development schema") { model.planner.initializeDevelopmentSchema() }.buttonStyle(QuietButtonStyle())
                #endif
                if model.planner.localAssignmentsAvailable {
                    Text(model.copy("Assignments created before iCloud was available are still in your separate local calendar. Copy them to this Apple account only if they are yours.", "启用 iCloud 前创建的作业仍保留在独立的本机日历。仅在确认属于你时复制到当前 Apple 账户。"))
                        .font(.caption).foregroundStyle(Studio.amber)
                    Button(model.copy("Copy my local assignments to iCloud", "将我的本机作业复制到 iCloud")) { Task { await model.planner.mergeLocalAssignments() } }.buttonStyle(QuietButtonStyle())
                }
            }
        }
    }
}

struct WorkflowChoices: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.copy("Where would you like to work?", "你想在哪里管理作业？")).font(.headline)
            ForEach(PlannerWorkflow.allCases) { workflow in
                Button { model.workflow = workflow } label: {
                    HStack(spacing: 13) {
                        Image(systemName: workflow == .inApp ? "calendar.badge.clock" : workflow == .apple ? "calendar" : "globe").font(.title2).frame(width: 30)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(workflow == .inApp ? model.copy("Stay with ReminderSnap", "留在 ReminderSnap") : workflow == .apple ? model.copy("Connect Apple apps", "连接 Apple 应用") : "Google Calendar").font(.system(size: 14, weight: .medium))
                            Text(workflow == .inApp ? model.copy("Your assignments and alerts. No extra login.", "作业日历与通知，无需额外登录。") : workflow == .apple ? model.copy("Optional reminders and planning blocks.", "可选提醒事项与计划时间块。") : model.copy("Sign in only when you choose to connect.", "仅在你选择连接时登录。"))
                                .font(.caption).foregroundStyle(Studio.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: model.workflow == workflow ? "checkmark.circle.fill" : "circle").foregroundStyle(model.workflow == workflow ? Studio.silver : Studio.muted)
                    }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
                        .background(model.workflow == workflow ? Studio.elevated : Studio.surface).clipShape(RoundedRectangle(cornerRadius: 13)).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            Text(model.copy("Every confirmed assignment also stays in your ReminderSnap calendar. Changing this choice affects new imports, not old exports.", "所有确认的作业都会保存在 ReminderSnap 日历中。更改选择影响新导入，不会改变旧的导出。"))
                .font(.caption).foregroundStyle(Studio.muted)
        }
    }
}

struct GoogleConnectionPanel: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 14) {
                Label("Google Calendar", systemImage: "globe").font(.headline)
                Text(model.googleCalendar.connected ? model.googleCalendar.email : model.copy("Connect only if you want your assignments in Google Calendar.", "仅当你希望在 Google 日历中显示作业时连接。"))
                    .font(.caption).foregroundStyle(Studio.muted)
                Text(model.copy("We request access to calendars created by this app, not your Gmail, school account, or unrelated calendar events. A dedicated ReminderSnap Assignments calendar will be created when you export your first task.", "仅请求访问本应用创建的日历，不读取 Gmail、学校账户或无关日程。首次导出任务时会创建独立的 ReminderSnap Assignments 日历。"))
                    .font(.caption).foregroundStyle(Studio.muted)
                if model.googleCalendar.connected {
                    Button(model.copy("Disconnect on this device", "在此设备断开连接")) { model.googleCalendar.disconnect() }.buttonStyle(QuietButtonStyle())
                } else {
                    Button(model.copy("Connect Google Calendar", "连接 Google 日历")) { model.connectGoogle() }.buttonStyle(SilverButtonStyle(small: true)).disabled(model.googleCalendar.busy)
                }
                if model.googleCalendar.busy { ProgressView() }
                if !model.googleCalendar.message.isEmpty { Text(model.googleCalendar.message).font(.caption).foregroundStyle(Studio.muted) }
                Text(model.copy("Google authorization is device-specific. Private iCloud sync for the in-app planner is independent of Google.", "Google 授权仅用于当前设备，应用内作业的私人 iCloud 同步与 Google 独立。"))
                    .font(.caption).foregroundStyle(Studio.muted)
            }
        }
    }
}

struct CourseProfileEditor: View {
    @EnvironmentObject private var model: AppModel
    let profile: CourseProfile
    @State private var editing = false
    var body: some View {
        HStack {
                Circle().fill(CourseColors.color(profile.name, model: model)).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 5) {
                    Text(profile.name).font(.system(size: 14, weight: .medium))
                    Text(profile.section.isEmpty ? model.copy("All sections · no filter", "全部班级 · 不筛选") : model.copy("My section: \(profile.section)", "我的班级：\(profile.section)"))
                        .font(.caption).foregroundStyle(Studio.muted)
                    if profile.isArchived == true { Text(model.copy("Archived", "已归档")).font(.caption).foregroundStyle(Studio.amber) }
                }
                Spacer()
                Button(model.copy("Edit", "编辑")) { editing = true }.buttonStyle(QuietButtonStyle())
        }.sheet(isPresented: $editing) { CourseProfileFields(original: profile, profile: profile).environmentObject(model) }
    }
}

struct CourseManagementPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var adding = false
    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(model.copy("Courses & sections", "课程与班级"), systemImage: "graduationcap").font(.headline)
                    Spacer()
                    Button(model.copy("Add course", "添加课程")) { adding = true }.buttonStyle(QuietButtonStyle())
                }
                Text(model.copy("Edit a mistaken course name, choose your class section, or archive a finished course. Course choices never carry over to unrelated imports.", "可修正识别错误的课程名、选择所在班级，或归档已结束的课程。课程选择不会沿用到无关的新导入。"))
                    .font(.caption).foregroundStyle(Studio.muted)
                ForEach(model.planner.courses) { CourseProfileEditor(profile: $0) }
                if model.planner.courses.isEmpty { Text(model.copy("No saved courses yet.", "尚无保存的课程。")).font(.caption).foregroundStyle(Studio.muted) }
            }
        }.sheet(isPresented: $adding) { CourseProfileFields(original: nil, profile: CourseProfile(name: "")).environmentObject(model) }
    }
}

struct CourseProfileFields: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let original: CourseProfile?
    @State var profile: CourseProfile
    @State private var deleting = false
    @State private var error = ""
    private let englishColors = ["Cyan", "Orange", "Purple", "Green", "Pink", "Yellow", "Blue", "Mint"]
    private let chineseColors = ["青色", "橙色", "紫色", "绿色", "粉色", "黄色", "蓝色", "薄荷色"]
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.copy(original == nil ? "Add course" : "Edit course", original == nil ? "添加课程" : "编辑课程")).font(.title2)
                Spacer(); Button(model.copy("Cancel", "取消")) { dismiss() }.buttonStyle(QuietButtonStyle())
            }.padding(22)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FieldLabel(title: model.copy("Course name or code", "课程名称或代码")) {
                        TextField(model.copy("e.g. History 101", "例如：中国历史"), text: $profile.name).studioField()
                    }
                    Text(model.copy("Renaming also updates saved assignments in this course and their linked entries. Existing task links are preserved.", "重命名会同时更新该课程中已保存作业及其关联条目，保留原有任务关联。"))
                        .font(.caption).foregroundStyle(Studio.muted)
                    FieldLabel(title: model.copy("My class section · optional", "我的班级代码 · 可选")) {
                        TextField(model.copy("e.g. A2LB · blank includes all", "例如 A2LB · 留空包含全部"), text: $profile.section).studioField()
                    }
                    Text(model.copy("Enter your section code, not the number of sections. Shared assignments stay visible.", "填写你所在的班级代码，并非班级数量。公共作业仍会显示。"))
                        .font(.caption).foregroundStyle(Studio.muted)
                    FieldLabel(title: model.copy("Course year · optional", "课程年份 · 可选")) {
                        TextField("2026", text: Binding(get: { profile.year.map(String.init) ?? "" }, set: { profile.year = Int($0) })).studioField()
                    }
                    FieldLabel(title: model.copy("Course timezone", "课程时区")) { TextField("America/New_York", text: $profile.timeZoneIdentifier).studioField() }
                    FieldLabel(title: model.copy("Calendar colour", "日历颜色")) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], alignment: .leading, spacing: 10) {
                            ForEach(CourseColors.values.indices, id: \.self) { index in
                                Button { profile.colorIndex = index } label: {
                                    HStack(spacing: 7) {
                                        Circle().fill(CourseColors.values[index]).frame(width: 13, height: 13)
                                        Text(model.language == .english ? englishColors[index] : chineseColors[index]).font(.caption)
                                        if profile.colorIndex == index { Image(systemName: "checkmark").font(.caption) }
                                    }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(profile.colorIndex == index ? Studio.silver.opacity(0.12) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if original != nil {
                        Toggle(model.copy("Archived · course has ended", "归档 · 课程已结束"), isOn: Binding(get: { profile.isArchived == true }, set: { profile.isArchived = $0 }))
                        Text(model.copy("Archived courses keep their assignments but stop supplying section and date preferences to new imports.", "归档后保留作业，但不再为新导入提供班级及日期偏好。"))
                            .font(.caption).foregroundStyle(Studio.muted)
                        Button(model.copy("Delete course preferences", "删除课程偏好"), role: .destructive) { deleting = true }
                    }
                    if !error.isEmpty { Text(error).font(.caption).foregroundStyle(Studio.amber) }
                }.padding(22)
            }
            Button(model.copy("Save course", "保存课程")) {
                if let original {
                    if model.editCourse(original, updated: profile) { dismiss() } else { error = model.t(model.statusMessage) }
                } else {
                    let value = profile.renamed(profile.name)
                    if model.planner.courses.contains(where: { $0.id == value.id }) { error = model.copy("This course already exists.", "该课程已存在。") }
                    else { model.saveProfile(value); dismiss() }
                }
            }.buttonStyle(SilverButtonStyle()).padding(20)
                .disabled(profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || TimeZone(identifier: profile.timeZoneIdentifier) == nil || profile.year.map { !(1900...2199).contains($0) } == true)
        }.background(Studio.background).foregroundStyle(Studio.silver).preferredColorScheme(.dark)
        .confirmationDialog(model.copy("Delete these course preferences?", "删除此课程偏好？"), isPresented: $deleting, titleVisibility: .visible) {
            Button(model.copy("Delete preferences", "删除偏好"), role: .destructive) { if let original { model.removeCourse(original) }; dismiss() }
        } message: { Text(model.copy("Saved assignments, reminders and calendar blocks are kept. Delete assignments separately from Your Task Calendar.", "保留已保存的作业、提醒和日历时间块。可在作业日历中另行删除任务。")) }
        #if os(macOS)
        .frame(width: 570, height: 730)
        #endif
    }
}

struct PrivacyView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(model.copy("Your privacy, yours.", "你的隐私，由你掌握。" )).font(.title2)
                Spacer(); Button(model.copy("Done", "完成")) { dismiss() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    item("viewfinder", model.copy("Recognition stays on-device", "识别保留在设备上"), model.copy("Photos, screenshots and PDFs are read locally with Apple Vision. We do not send them to an AI service or a developer server.", "照片、截图和 PDF 由 Apple Vision 本地读取，不发送到 AI 服务或开发者服务器。"))
                    item("icloud", model.copy("Private iCloud sync", "私人 iCloud 同步"), model.copy("Reviewed assignments and course preferences are saved locally and, when available, synchronized through your private iCloud database. Raw OCR and screenshots are not synchronized. Storage counts toward your iCloud allowance.", "已核对的作业和课程偏好保存在本机，并在可用时通过私人 iCloud 数据库同步。原始识别文本和截图不会同步，占用你的 iCloud 存储配额。"))
                    item("link", model.copy("Optional connections", "可选连接"), model.copy("Only selected tasks are exported to Apple apps or your authorized Google Calendar. Google authorization opens the secure system browser; credentials stay in this device’s Keychain. Your Google account ID is used to match linked calendars, and your email is shown only on this device. No Google analytics SDK is included. We do not request school credentials. Account providers handle exported data under their policies.", "仅将所选任务导出到 Apple 应用或已授权的 Google 日历。Google 授权通过安全系统浏览器进行，凭据保存在本机钥匙串。Google 账户标识用于匹配关联日历，邮箱仅在本机显示。不包含 Google 分析 SDK，不索取学校账户凭据。导出数据由账户服务商按其政策处理。"))
                    item("trash", model.copy("You control your data", "数据由你控制"), model.copy("Clear Import removes only temporary review data. Delete saved assignments from Your Task Calendar; choose separately whether to delete app-owned linked items. Minimal deletion markers may remain to prevent old offline copies reappearing. Revoke connections in Settings. No ads or school-account access.", "清空导入仅移除临时核对数据。可在作业日历中删除已保存作业，并单独选择是否删除本应用创建的关联条目。可能保留最小删除标记以防旧离线副本重新出现。可在设置中撤销连接，无广告、不访问学校账户。"))
                    Link(model.copy("Published privacy policy", "公开隐私政策"), destination: URL(string: "https://github.com/NerdyKevvy/ReminderSnap-v2.0/blob/main/AppStore/PRIVACY-POLICY.md")!)
                }
            }
        }.padding(24).background(Studio.background).foregroundStyle(Studio.silver).preferredColorScheme(.dark)
        #if os(macOS)
        .frame(width: 620, height: 660)
        #endif
    }
    private func item(_ icon: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.headline)
            Text(detail).font(.system(size: 13)).foregroundStyle(Studio.muted).lineSpacing(3)
        }
    }
}
