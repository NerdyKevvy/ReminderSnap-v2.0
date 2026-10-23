import SwiftUI
import ReminderSnapCore

struct TaskEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var draft: ImportItem
    @State private var checked = false
    let onApply: (ImportItem) -> Void

    private var valid: Bool {
        draft.candidate.dueDate != nil &&
        !draft.candidate.assignmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: model.copy("Make it yours", "确认任务详情"))
                    Text(model.copy("Task details", "任务详情")).font(.title2.weight(.medium))
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").padding(9) }.buttonStyle(.plain)
                    .accessibilityLabel(model.copy("Cancel", "取消"))
            }.padding(24)
            Divider().overlay(Studio.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    FieldLabel(title: model.copy("Course · optional", "课程 · 可选")) {
                        TextField("MA-UY 2034", text: $draft.candidate.courseCode).studioField()
                    }
                    FieldLabel(title: model.copy("Task name", "任务名称")) {
                        TextField(model.copy("Assignment name", "作业名称"), text: $draft.candidate.assignmentName, axis: .vertical).studioField()
                    }
                    DisclosureGroup(model.copy("Custom reminder title", "自定义提醒标题")) {
                        TextField(model.copy("Leave blank for automatic formatting", "留空以自动生成标题"), text: Binding(get: { draft.candidate.titleOverride ?? "" }, set: { draft.candidate.titleOverride = $0.isEmpty ? nil : $0 }), axis: .vertical).studioField().padding(.top, 10)
                    }.font(.system(size: 12)).foregroundStyle(Studio.muted)
                    Panel(padding: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(model.copy("ReminderSnap notifications", "ReminderSnap 通知"), isOn: $draft.appAlertsEnabled)
                            if draft.appAlertsEnabled && draft.candidate.hasExplicitTime {
                                LeadTimeEditor(values: $draft.appAlertLeadTimes, purpose: model.copy("Before the actual deadline", "在真实截止时间之前"))
                            } else if draft.appAlertsEnabled {
                                Text(model.copy("Date-only tasks use \(model.dateOnlyAlertHour):00 that morning and the previous morning. Change the default in Settings.", "仅日期任务会在当天及前一天的 \(model.dateOnlyAlertHour):00 通知，可在设置中调整默认时间。"))
                                    .font(.caption).foregroundStyle(Studio.muted)
                            }
                            Text(model.copy("Enable notifications in Settings on this device. No calendar connection is required.", "请在本机设置中开启通知，无需连接其他日历应用。")).font(.caption).foregroundStyle(Studio.muted)
                        }
                    }
                    Panel(padding: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(model.copy("The real deadline", "真实截止时间")).font(.system(size: 14, weight: .semibold))
                            if draft.candidate.dueDate != nil {
                                DatePicker(model.copy("Due", "截止"), selection: Binding(get: { draft.candidate.dueDate ?? Date() }, set: { draft.candidate.dueDate = $0 }), displayedComponents: draft.candidate.hasExplicitTime ? [.date, .hourAndMinute] : [.date])
                                    .environment(\.timeZone, draft.candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current)
                                Toggle(model.copy("Include a time", "指定时间"), isOn: $draft.candidate.hasExplicitTime)
                            } else {
                                Button(model.copy("Choose a deadline", "选择截止日期")) { draft.candidate.dueDate = Date() }.buttonStyle(QuietButtonStyle())
                            }
                            TextField(model.copy("Timezone", "时区"), text: Binding(get: { draft.candidate.timeZoneIdentifier ?? TimeZone.current.identifier }, set: { draft.candidate.timeZoneIdentifier = $0 })).studioField()
                        }
                    }
                    if !draft.candidate.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(model.copy("Check against your original", "请核对原始内容"), systemImage: "exclamationmark.circle").foregroundStyle(Studio.amber)
                            ForEach(draft.candidate.warnings, id: \.self) { Text(model.t($0)).font(.caption).foregroundStyle(Studio.muted) }
                            Toggle(model.copy("I have checked these details", "我已核对这些详情"), isOn: $checked)
                        }.font(.system(size: 12))
                    }
                    if model.outputMode.usesCalendar || model.outputMode == .google {
                    Panel(padding: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            Toggle(model.copy("Calendar companion block", "日历伴随时间块"), isOn: $draft.companionEventEnabled)
                            Text(model.copy("For 23:59 deadlines: a 22:00–23:00 block on the same date. Your reminder’s actual deadline never changes.", "23:59 截止的任务会在当天创建 22:00–23:00 的日历时间块，真实截止时间不变。"))
                                .font(.caption).foregroundStyle(Studio.muted)
                            Text(model.copy("If ReminderSnap notifications are off, the linked calendar uses this task’s alert times instead. Planning blocks never change the real deadline.", "若关闭 ReminderSnap 通知，关联日历将使用本任务的通知时间。计划块不会改变真实截止日期。"))
                                .font(.caption).foregroundStyle(Studio.muted)
                        }
                    }
                    }
                    FieldLabel(title: model.copy("Title preview", "标题预览")) {
                        Text(draft.candidate.reminderTitle).font(.system(size: 13)).textSelection(.enabled)
                    }
                }.padding(24)
            }
            HStack {
                Button(model.copy("Cancel", "取消")) { dismiss() }.buttonStyle(QuietButtonStyle())
                Spacer()
                Button(model.copy("Apply changes", "应用更改")) {
                    if checked { draft.candidate.warnings = [] }
                    draft.status = draft.candidate.warnings.isEmpty ? .ready : .needsReview
                    onApply(draft); dismiss()
                }.buttonStyle(SilverButtonStyle()).disabled(!valid).opacity(valid ? 1 : 0.4)
            }.padding(20).background(Studio.sidebar)
        }.background(Studio.background).foregroundStyle(Studio.silver).tint(Studio.silver).preferredColorScheme(.dark)
        #if os(macOS)
        .frame(width: 540, height: 730)
        #endif
    }
}

struct LeadTimeEditor: View {
    @EnvironmentObject private var model: AppModel
    @Binding var values: [TimeInterval]
    var purpose: String? = nil
    @State private var amount = "2"
    @State private var unit: Double = 3600
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(purpose ?? model.copy("Extra Calendar alerts · before the real deadline", "额外日历通知 · 相对于真实截止时间")).font(.system(size: 11, weight: .medium)).foregroundStyle(Studio.muted)
            if purpose != nil {
                Toggle(model.copy("Also notify at the deadline", "截止时也通知"), isOn: Binding(get: { values.contains(0) }, set: { enabled in
                    values.removeAll { $0 == 0 }
                    if enabled { values.append(0) }
                })).font(.caption).disabled(!values.contains(0) && values.count >= 4)
            }
            ForEach(values.sorted(by: >), id: \.self) { value in
                HStack {
                    Label(label(value), systemImage: "bell.badge").font(.system(size: 12))
                    Spacer()
                    Button { values.removeAll { $0 == value } } label: { Image(systemName: "minus.circle").foregroundStyle(Studio.muted) }
                        .buttonStyle(.plain).accessibilityLabel(model.copy("Remove alert ", "移除通知 ") + label(value))
                }
            }
            HStack(spacing: 8) {
                TextField("2", text: $amount).studioField().frame(width: 66)
                Picker(model.copy("Unit", "单位"), selection: $unit) {
                    Text(model.copy("minutes", "分钟")).tag(60.0)
                    Text(model.copy("hours", "小时")).tag(3600.0)
                    Text(model.copy("days", "天")).tag(86400.0)
                }.labelsHidden()
                Spacer(minLength: 0)
                Button(model.copy("Add", "添加")) {
                    guard let number = Double(amount), number.isFinite, number > 0 else { return }
                    let seconds = min(365 * 86400, max(60, number * unit))
                    values = Array(Set(values + [seconds])).sorted(by: >)
                }.buttonStyle(QuietButtonStyle()).disabled(values.count >= 4 || Double(amount).map { !$0.isFinite || $0 <= 0 } != false)
            }
            Text(purpose == nil ? model.copy("Up to four extra alerts. Delivery depends on Calendar notifications and Focus settings.", "最多四个额外通知。通知送达受日历通知与专注模式设置影响。") : model.copy("Up to four alert times. Device notification permissions and Focus settings apply.", "最多四个通知时间，送达受设备通知权限和专注模式影响。"))
                .font(.system(size: 10)).foregroundStyle(Studio.muted)
        }
    }
    private func label(_ seconds: TimeInterval) -> String {
        if seconds == 0 { return model.copy("At the deadline", "截止时") }
        let number: Double, suffix: String
        if seconds.truncatingRemainder(dividingBy: 86400) == 0 { number = seconds / 86400; suffix = model.copy("day(s) before", "天前") }
        else if seconds.truncatingRemainder(dividingBy: 3600) == 0 { number = seconds / 3600; suffix = model.copy("hour(s) before", "小时前") }
        else { number = seconds / 60; suffix = model.copy("minute(s) before", "分钟前") }
        return String(format: "%g", number) + " " + suffix
    }
}

struct ReadingInspector: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(model.copy("Recognized text", "已识别的文本")).font(.title2)
                Spacer()
                Button(model.copy("Done", "完成")) { dismiss() }.buttonStyle(QuietButtonStyle())
            }
            Text(model.t(model.readingSummary)).font(.caption).foregroundStyle(Studio.muted)
            HStack {
                TextField(model.copy("Course", "课程"), text: $model.batchCourse).studioField()
                TextField(model.copy("Year", "年份"), text: $model.batchYear).studioField().frame(width: 90)
            }
            Button(model.copy("Re-interpret with this context", "按此信息重新解析")) { model.rereadText(); dismiss() }
                .buttonStyle(QuietButtonStyle())
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Array(model.documents.enumerated()), id: \.offset) { _, document in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(document.sourceName).font(.headline)
                            Text(document.fullText).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Text(model.copy("Text is kept only for this session. Clear the import to release it.", "文本仅保留在当前会话中，清空导入即可释放。")).font(.caption).foregroundStyle(Studio.muted)
        }.padding(24).background(Studio.background).foregroundStyle(Studio.silver).preferredColorScheme(.dark)
        #if os(macOS)
        .frame(width: 680, height: 600)
        #endif
    }
}
