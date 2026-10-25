import SwiftUI
import ReminderSnapCore

enum CourseColors {
    static let values: [Color] = [.cyan, .orange, .purple, .green, .pink, .yellow, .blue, .mint]
    @MainActor static func color(_ name: String, model: AppModel) -> Color {
        let id = CourseNormalizer.tag(from: name)
        if let index = model.planner.courses.first(where: { $0.id == id })?.colorIndex {
            return values[abs(index) % values.count]
        }
        let index = name.utf8.reduce(0) { ($0 * 31 + Int($1)) % values.count }
        return values[index]
    }
}

struct TaskCalendarView: View {
    @EnvironmentObject private var model: AppModel
    let compact: Bool
    @State private var filter = ""
    @State private var scope = 0
    @State private var selected = Set<UUID>()
    @State private var selecting = false
    @State private var showingDelete = false
    @State private var showingRemoveBlocks = false
    private let calendar = Calendar.current
    private var assignments: [SavedAssignment] { model.calendarAssignments }
    private var courseNames: [String] { Array(Set(assignments.map(\.candidate.courseCode))).sorted() }
    private var displayed: [SavedAssignment] {
        assignments.filter {
            (filter.isEmpty || $0.candidate.courseCode == filter) &&
            (scope == 2 || !$0.isCompleted) &&
            (scope != 1 || calendar.isDate(displayDay($0), inSameDayAs: model.calendarDate))
        }
    }
    private var monthStart: Date { calendar.date(from: calendar.dateComponents([.year, .month], from: model.calendarDate)) ?? Date() }
    private var offset: Int { (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7 }
    private var dayCount: Int { calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heading
                if model.showSampleCalendar {
                    HStack {
                        Label(model.copy("Sample calendar · no real tasks or alerts", "示例日历 · 不创建真实任务或通知"), systemImage: "sparkles")
                        Spacer()
                        Button(model.copy("Exit demo", "退出示例")) { model.showSampleCalendar = false }
                    }.font(.caption).foregroundStyle(Studio.amber)
                }
                if !model.planner.ready && !model.showSampleCalendar {
                    ProgressView(model.copy("Opening your assignments…", "正在打开作业日历…"))
                }
                if let error = model.planner.error {
                    Label(error, systemImage: "icloud.slash").font(.caption).foregroundStyle(Studio.amber)
                }
                Panel(padding: compact ? 14 : 22) { monthGrid }
                legend
                if !model.plannerNotificationsEnabled && !assignments.isEmpty && !model.showSampleCalendar {
                    Panel(padding: 16) {
                        HStack(alignment: .top) {
                            Image(systemName: "bell.badge").foregroundStyle(Studio.amber)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(model.copy("Let deadlines come to you.", "让截止提醒主动找到你。")).font(.headline)
                                Text(model.copy("Enable ReminderSnap alerts. You don’t need another calendar app.", "开启 ReminderSnap 通知，无需使用其他日历应用。")).font(.caption).foregroundStyle(Studio.muted)
                                Button(model.copy("Enable notifications", "开启通知")) { model.enableAppNotifications() }.buttonStyle(QuietButtonStyle())
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                HStack {
                    Picker(model.copy("Show", "显示"), selection: $scope) {
                        Text(model.copy("Upcoming", "待完成")).tag(0)
                        Text(model.copy("Selected day", "所选日期")).tag(1)
                        Text(model.copy("All", "全部")).tag(2)
                    }.pickerStyle(.segmented).frame(maxWidth: 430)
                    Spacer(minLength: 0)
                    Button(model.copy(selecting ? "Done" : "Select", selecting ? "完成" : "选择")) {
                        selecting.toggle(); selected = []
                    }.buttonStyle(.plain).disabled(model.showSampleCalendar)
                }
                if selecting {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button(model.copy("Select all", "全选")) { selected = Set(displayed.map(\.id)) }.buttonStyle(.plain)
                            Text("\(selected.count)").foregroundStyle(Studio.muted)
                            Spacer()
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) { selectionActions }
                            VStack(alignment: .leading, spacing: 12) { selectionActions }
                        }
                    }.font(.caption)
                }
                if displayed.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(displayed) { task in
                            AssignmentRow(task: task, selected: selecting ? selected.contains(task.id) : nil) {
                                if selecting {
                                    if selected.contains(task.id) { selected.remove(task.id) } else { selected.insert(task.id) }
                                } else { model.selectedSavedTask = task }
                            }
                        }
                    }
                }
            }.padding(compact ? 20 : 32).frame(maxWidth: 1080).frame(maxWidth: .infinity)
        }
        .sheet(item: $model.selectedSavedTask) { task in SavedTaskDetailView(task: task).environmentObject(model) }
        .confirmationDialog(model.copy("Delete selected assignments?", "删除所选作业？"), isPresented: $showingDelete, titleVisibility: .visible) {
            Button(model.copy("Remove from ReminderSnap only", "仅从 ReminderSnap 移除"), role: .destructive) { remove(linked: false) }
            Button(model.copy("Also delete linked reminders/events", "同时删除关联提醒和日程"), role: .destructive) { remove(linked: true) }
            Button(model.copy("Cancel", "取消"), role: .cancel) { }
        } message: {
            Text(model.copy("App alerts are cancelled. Linked deletion is limited to items created by ReminderSnap. Offline calendar updates may remain pending.", "应用通知会取消。仅删除 ReminderSnap 创建的关联条目，离线时外部更新可能需要等待。"))
        }
        .confirmationDialog(model.copy("Remove selected planning blocks?", "移除所选计划时间块？"), isPresented: $showingRemoveBlocks, titleVisibility: .visible) {
            Button(model.copy("Remove blocks · keep assignments", "移除时间块 · 保留作业"), role: .destructive) {
                model.removeLinkedCalendarBlocks(selected); selected = []; selecting = false
            }
            Button(model.copy("Cancel", "取消"), role: .cancel) { }
        } message: {
            Text(model.copy("Your saved assignments, app notifications and linked Apple reminders remain. Only planning events created by ReminderSnap are removed. Linked updates may wait for the original device or a network connection.", "已保存作业、应用通知与关联 Apple 提醒均保留，仅移除 ReminderSnap 创建的计划日程。可能需要原始设备或联网后完成。"))
        }
    }

    @ViewBuilder private var selectionActions: some View {
        Button { showingRemoveBlocks = true } label: {
            Label(model.copy("Remove linked blocks", "移除关联时间块"), systemImage: "calendar.badge.minus")
        }
        .accessibilityIdentifier("calendar.removeLinkedBlocks")
        .disabled(!assignments.contains { selected.contains($0.id) && ($0.workflow == .google || $0.appleCalendar) })
        Button(role: .destructive) { showingDelete = true } label: {
            Label(model.copy("Delete selected", "删除所选"), systemImage: "trash")
        }.disabled(selected.isEmpty)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: model.copy("Your assignment center", "你的作业中心"))
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.copy("A clearer day ahead.", "让每一天更有把握。"))
                        .font(.system(size: compact ? 27 : 36, weight: .medium)).tracking(-1)
                    Text(model.copy("\(assignments.filter { !$0.isCompleted }.count) assignments to do", "\(assignments.filter { !$0.isCompleted }.count) 项待完成作业"))
                        .font(.caption).foregroundStyle(Studio.muted)
                }
                Spacer(minLength: 0)
                if !compact {
                    Button { model.page = .addReminder } label: { Label(model.copy("Import Tasks", "导入任务"), systemImage: "plus") }.buttonStyle(SilverButtonStyle(small: true))
                }
            }
            HStack(spacing: 6) {
                Image(systemName: model.planner.iCloudAvailable ? "icloud" : "internaldrive")
                Text(model.copy(model.planner.syncState, chineseSyncState))
            }.font(.system(size: 10)).foregroundStyle(Studio.muted)
        }
    }
    private var chineseSyncState: String {
        if model.planner.syncState.contains("pending") { return "已在本机保存 · 等待 iCloud 同步" }
        if model.planner.syncState.contains("Syncing") { return "正在与 iCloud 同步…" }
        if model.planner.syncState.contains("attention") { return "iCloud 需要处理 · 更改已保存在本机" }
        return model.planner.iCloudAvailable ? "通过你的 iCloud 账户同步" : "保存在本机 · 启用 iCloud 可跨设备同步"
    }
    private var monthGrid: some View {
        VStack(spacing: 16) {
            HStack {
                Text(monthStart.formatted(.dateTime.month(.wide).year())).font(.system(size: 20, weight: .medium))
                Spacer()
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").padding(8) }.buttonStyle(.plain).accessibilityLabel(model.copy("Previous month", "上个月"))
                Button(model.copy("Today", "今天")) { model.calendarDate = Date() }.font(.caption).buttonStyle(.plain)
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").padding(8) }.buttonStyle(.plain).accessibilityLabel(model.copy("Next month", "下个月"))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 5) {
                ForEach(0..<7, id: \.self) { index in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(calendar.firstWeekday - 1 + index) % 7])
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(Studio.muted)
                }
                ForEach(0..<(offset + dayCount), id: \.self) { index in
                    if index < offset { Color.clear.frame(height: compact ? 45 : 60) }
                    else { dayCell(index - offset + 1) }
                }
            }
        }
    }
    private func dayCell(_ number: Int) -> some View {
        let date = calendar.date(byAdding: .day, value: number - 1, to: monthStart) ?? monthStart
        let tasks = assignments.filter { !$0.isCompleted && calendar.isDate(displayDay($0), inSameDayAs: date) }
        let chosen = calendar.isDate(date, inSameDayAs: model.calendarDate)
        return Button {
            model.calendarDate = date; scope = 1
        } label: {
            VStack(spacing: 6) {
                Text("\(number)").font(.system(size: 13, weight: chosen ? .bold : .regular))
                    .foregroundStyle(calendar.isDateInToday(date) ? Studio.green : Studio.silver)
                HStack(spacing: 3) {
                    ForEach(Array(tasks.prefix(3).enumerated()), id: \.offset) { _, task in
                        Circle().fill(CourseColors.color(task.candidate.courseCode, model: model)).frame(width: 4, height: 4)
                    }
                    if tasks.count > 3 { Text("+").font(.system(size: 8)) }
                }.frame(height: 5)
            }.frame(maxWidth: .infinity).frame(height: compact ? 45 : 60)
                .background(chosen ? Color.white.opacity(0.11) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10)).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(date.formatted(date: .complete, time: .omitted) + ", \(tasks.count) " + model.copy("assignments", "项作业"))
    }
    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.copy("Course colours", "课程颜色图例")).font(.system(size: 10, weight: .medium)).foregroundStyle(Studio.muted)
                Spacer()
                if !filter.isEmpty { Button(model.copy("Show all", "显示全部")) { filter = "" }.font(.caption).buttonStyle(.plain) }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 125 : 160), alignment: .leading)], alignment: .leading, spacing: 10) {
                ForEach(courseNames, id: \.self) { name in
                    Button { filter = filter == name ? "" : name } label: {
                        HStack(spacing: 7) {
                            Circle().fill(CourseColors.color(name, model: model)).frame(width: 7, height: 7)
                            Text(name.isEmpty ? model.copy("Uncategorized", "未分类") : name).lineLimit(1)
                        }.font(.system(size: 11)).foregroundStyle(filter.isEmpty || filter == name ? Studio.silver : Studio.muted)
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private var emptyState: some View {
        Panel {
            VStack(alignment: .leading, spacing: 15) {
                Image(systemName: "calendar.badge.plus").font(.system(size: 32, weight: .light)).foregroundStyle(Studio.muted)
                Text(model.copy(assignments.isEmpty ? "One snapshot. Your assignments, together." : "No assignments in this view.", assignments.isEmpty ? "一张截图，让作业井然有序。" : "当前视图没有作业。")).font(.headline)
                Text(model.copy("Import a course screenshot or photo. Check the details, then see your deadlines here. No school login needed.", "导入课程截图或照片，核对后即可在这里查看截止日期，无需登录学校账户。"))
                    .font(.caption).foregroundStyle(Studio.muted)
                ViewThatFits {
                    HStack { emptyButtons }
                    VStack(alignment: .leading) { emptyButtons }
                }
            }
        }
    }
    @ViewBuilder private var emptyButtons: some View {
        Button { model.page = .addReminder } label: { Label(model.copy("Import Tasks", "导入任务"), systemImage: "plus") }.buttonStyle(SilverButtonStyle(small: true))
        Button(model.copy("Show me how", "看看怎么用")) { model.showingSetup = true }.buttonStyle(QuietButtonStyle())
    }
    private func displayDay(_ task: SavedAssignment) -> Date {
        guard let due = task.candidate.dueDate else { return .distantFuture }
        var source = Calendar(identifier: .gregorian)
        source.timeZone = task.candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var components = source.dateComponents([.year, .month, .day], from: due); components.hour = 12
        return calendar.date(from: components) ?? due
    }
    private func shiftMonth(_ amount: Int) {
        model.calendarDate = calendar.date(byAdding: .month, value: amount, to: monthStart) ?? monthStart
    }
    private func remove(linked: Bool) {
        model.deleteAssignments(selected, linked: linked); selected = []; selecting = false
    }
}

struct AssignmentRow: View {
    @EnvironmentObject private var model: AppModel
    let task: SavedAssignment
    var selected: Bool? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 13) {
                RoundedRectangle(cornerRadius: 2).fill(CourseColors.color(task.candidate.courseCode, model: model)).frame(width: 3)
                if let selected { Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3) }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(task.candidate.courseCode.isEmpty ? model.copy("Uncategorized", "未分类") : task.candidate.courseCode)
                            .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Studio.muted)
                        Spacer()
                        if task.isCompleted { Image(systemName: "checkmark.circle.fill").foregroundStyle(Studio.green) }
                        else if task.isOverdue() {
                            Text(model.copy("Overdue", "已逾期")).font(.system(size: 10)).foregroundStyle(Studio.amber)
                        }
                    }
                    Text(task.candidate.assignmentName).font(.system(size: 15, weight: .medium)).strikethrough(task.isCompleted).multilineTextAlignment(.leading)
                    HStack(spacing: 10) {
                        Label(taskDate(task.candidate, language: model.language, includeTime: true), systemImage: "clock")
                        if task.alertsEnabled { Image(systemName: "bell") }
                        if task.workflow != .inApp {
                            Image(systemName: task.needsExport ? "arrow.triangle.2.circlepath" : "link")
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                    }.font(.system(size: 10)).foregroundStyle(Studio.muted)
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Studio.surface)
                .clipShape(RoundedRectangle(cornerRadius: 13)).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct SavedTaskDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var task: SavedAssignment
    @State private var deleting = false
    @State private var saveConflict = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.copy("Assignment details", "作业详情")).font(.title2.weight(.medium))
                Spacer()
                Button(model.copy("Done", "完成")) { dismiss() }.buttonStyle(QuietButtonStyle())
            }.padding(22)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FieldLabel(title: model.copy("Course · optional", "课程 · 可选")) { TextField(model.copy("Uncategorized", "未分类"), text: $task.candidate.courseCode).studioField() }
                    FieldLabel(title: model.copy("Assignment", "作业")) { TextField("", text: $task.candidate.assignmentName, axis: .vertical).studioField() }
                    if task.candidate.dueDate != nil {
                        DatePicker(model.copy("Real deadline", "真实截止日期"), selection: Binding(get: { task.candidate.dueDate! }, set: { task.candidate.dueDate = $0 }), displayedComponents: task.candidate.hasExplicitTime ? [.date, .hourAndMinute] : [.date])
                            .environment(\.timeZone, task.candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current)
                    }
                    Toggle(model.copy("Include a time", "指定时间"), isOn: $task.candidate.hasExplicitTime)
                    TextField(model.copy("Timezone", "时区"), text: Binding(get: { task.candidate.timeZoneIdentifier ?? TimeZone.current.identifier }, set: { task.candidate.timeZoneIdentifier = $0 })).studioField()
                    Toggle(model.copy("Completed", "已完成"), isOn: $task.isCompleted)
                    Toggle(model.copy("ReminderSnap notifications", "ReminderSnap 通知"), isOn: $task.alertsEnabled)
                    if task.alertsEnabled && task.candidate.hasExplicitTime {
                        LeadTimeEditor(values: $task.alertLeadTimes, purpose: model.copy("Before the real deadline", "在真实截止日期之前"))
                    } else if task.alertsEnabled {
                        Stepper(value: $task.dateOnlyAlertHour, in: 0...23) {
                            Text(model.copy("That morning & previous morning: \(task.dateOnlyAlertHour):00", "当天与前一天早晨：\(task.dateOnlyAlertHour):00"))
                        }.font(.caption)
                    }
                    if task.workflow != .inApp {
                        Panel(padding: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(task.workflow == .google ? "Google Calendar" : model.copy("Linked Apple apps", "关联 Apple 应用"), systemImage: "link")
                                Text(task.exportError ?? (task.needsExport ? model.copy("Calendar update pending. Apple links update on the original exporting device.", "日历更新待处理；Apple 关联条目由最初导出的设备更新。") : model.copy("Saved to your selected calendar.", "已保存到所选日历。")))
                                    .font(.caption).foregroundStyle(Studio.muted)
                                Button(model.copy("Show in my workflow", "在我的工作流中查看")) { model.openDestination(task) }.buttonStyle(QuietButtonStyle())
                                Toggle(model.copy("Show a companion planning block", "显示伴随计划时间块"), isOn: $task.companionBlock)
                            }
                        }
                    }
                    Button(role: .destructive) { deleting = true } label: { Label(model.copy("Delete assignment", "删除作业"), systemImage: "trash") }
                }.padding(22)
            }
            Button(model.copy("Save changes", "保存更改")) {
                if task.isSample { dismiss(); return }
                if model.updateSavedAssignment(task) { dismiss() } else { saveConflict = true }
            }.buttonStyle(SilverButtonStyle()).disabled(task.candidate.assignmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || task.candidate.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) == nil)
                .padding(20)
        }.background(Studio.background).foregroundStyle(Studio.silver).preferredColorScheme(.dark)
        .alert(model.copy("Your linked task", "你的关联任务"), isPresented: Binding(get: { !model.workflowNotice.isEmpty }, set: { if !$0 { model.workflowNotice = "" } })) {
            Button(model.copy("OK", "好")) { model.workflowNotice = "" }
        } message: { Text(model.workflowNotice) }
        .alert(model.copy("Check the saved assignment", "请检查已保存的作业"), isPresented: $saveConflict) {
            Button(model.copy("Reload saved version", "重新加载已保存版本")) {
                if let current = model.savedAssignments.first(where: { $0.id == task.id }) { task = current }
                else { dismiss() }
            }
            Button(model.copy("Keep editing", "继续编辑"), role: .cancel) { }
        } message: { Text(model.t(model.statusMessage)) }
        .confirmationDialog(model.copy("Delete this assignment?", "删除这项作业？"), isPresented: $deleting, titleVisibility: .visible) {
            Button(model.copy("Remove from ReminderSnap only", "仅从 ReminderSnap 移除"), role: .destructive) { model.deleteAssignments([task.id], linked: false); dismiss() }
            Button(model.copy("Also delete linked items", "同时删除关联条目"), role: .destructive) { model.deleteAssignments([task.id], linked: true); dismiss() }
        }
        #if os(macOS)
        .frame(width: 560, height: 740)
        #endif
    }
}
