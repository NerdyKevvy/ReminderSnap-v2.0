import SwiftUI
import UniformTypeIdentifiers
import ReminderSnapCore

struct ReviewView: View {
    @EnvironmentObject private var model: AppModel
    let compact: Bool
    @State private var editingItem: ImportItem?
    @State private var search = ""
    @State private var onlyWarnings = false
    @State private var showingText = false
    @State private var dropping = false
    var visibleIDs: [UUID] {
        model.visibleImportItems.filter { item in
            (!onlyWarnings || !item.candidate.warnings.isEmpty || item.candidate.dueDate == nil || item.candidate.courseCode.isEmpty) &&
            (search.isEmpty || item.candidate.reminderTitle.localizedCaseInsensitiveContains(search))
        }.map(\.id)
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 20 : 25) {
                    heading
                    CaptureView(compact: compact)
                    if model.isDemo { sampleBanner }
                    if model.previewSaved || model.saveCompleted { successBanner }
                    if model.isProcessing {
                        Panel {
                            HStack(spacing: 15) {
                                ProgressView().controlSize(.small)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(model.copy("Making sense of your deadlines", "正在识别截止日期")).font(.headline)
                                    Text(model.t(model.statusMessage)).font(.caption).foregroundStyle(Studio.muted)
                                }
                                Spacer()
                                if model.canCancelImport { Button(model.copy("Cancel", "取消")) { model.cancelImport() }.buttonStyle(QuietButtonStyle()) }
                            }
                        }
                    }
                    if !model.items.isEmpty {
                        controls
                        LazyVStack(spacing: 12) {
                            ForEach(visibleIDs, id: \.self) { id in
                                if let index = model.items.firstIndex(where: { $0.id == id }) {
                                    TaskCard(item: $model.items[index], compact: compact) { editingItem = model.items[index] }
                                }
                            }
                        }
                        if visibleIDs.isEmpty { Text(model.copy("No tasks match your filter.", "没有符合筛选条件的任务。")).foregroundStyle(Studio.muted).padding() }
                    } else if !model.isProcessing {
                        Label(model.copy("Your tasks will appear here. Check each deadline before saving.", "任务将在这里显示，请核对截止日期后再保存。"), systemImage: "checklist")
                            .font(.system(size: 13)).foregroundStyle(Studio.muted).padding(.vertical, 20)
                    }
                    if !model.documents.isEmpty && !model.isProcessing {
                        Button { showingText = true } label: { Label(model.copy("Inspect recognized text", "查看识别文本"), systemImage: "text.alignleft") }.buttonStyle(QuietButtonStyle())
                    }
                    if !model.isProcessing && !model.isDemo {
                        Text(model.t(model.statusMessage)).font(.system(size: 12)).foregroundStyle(Studio.muted).textSelection(.enabled)
                    }
                }.padding(compact ? 22 : 34).frame(maxWidth: 1120, alignment: .leading).frame(maxWidth: .infinity)
            }
            if !model.items.isEmpty { saveBar }
        }
        // Only the import/review workspace is a drop target. Navigation remains independent.
        .contentShape(Rectangle())
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $dropping) { model.importDroppedProviders($0) }
        .overlay {
            if dropping {
                RoundedRectangle(cornerRadius: 16).stroke(Studio.silver, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .padding(8).allowsHitTesting(false)
            }
        }
        .onValueChange(model.items.first?.id) { _ in search = ""; onlyWarnings = false }
        .sheet(item: $editingItem) { item in
            TaskEditorView(draft: item) { updated in
                if let index = model.items.firstIndex(where: { $0.id == updated.id }) {
                    model.items[index] = updated
                    model.previewSaved = false; model.saveCompleted = false
                }
            }.environmentObject(model)
        }
        .sheet(isPresented: $showingText) { ReadingInspector().environmentObject(model) }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.items.isEmpty {
                Eyebrow(text: model.copy("One simple flow", "一个页面，三个步骤"))
                Text(model.copy("Import. Check. Save.", "导入、核对、保存。"))
                    .font(.system(size: compact ? 28 : 34, weight: .medium)).tracking(-1)
            } else {
                Text(model.copy("Check your tasks.", "核对你的任务。"))
                    .font(.system(size: 24, weight: .medium)).tracking(-0.5)
            }
            HStack(spacing: 12) {
                Text(model.copy("\(model.items.count) tasks", "\(model.items.count) 项任务"))
                Text("·").foregroundStyle(Studio.muted.opacity(0.4))
                Text(model.copy("\(model.selectedCount) selected", "已选 \(model.selectedCount) 项"))
                if model.reviewCount > 0 {
                    Pill(text: model.copy("\(model.reviewCount) to check", "\(model.reviewCount) 项待核对"), color: Studio.amber)
                }
            }.font(.system(size: 12)).foregroundStyle(Studio.muted)
        }
    }

    private var sampleBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkle").foregroundStyle(Studio.amber)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.copy("Safe sample mode", "安全的示例模式" )).font(.system(size: 12, weight: .semibold))
                Text(model.copy("Edit these examples and test the save flow. Nothing is added to Apple’s apps.", "编辑示例并体验保存流程，不会向 Apple 应用添加任务。"))
                    .font(.system(size: 11)).foregroundStyle(Studio.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(15).background(Studio.amber.opacity(0.055)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var successBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Studio.green)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.copy(model.isDemo ? "That’s the flow." : "Saved to your assignment calendar.", model.isDemo ? "保存流程体验完成。" : "已保存到作业日历。" )).font(.system(size: 13, weight: .semibold))
                Text(model.t(model.statusMessage)).font(.system(size: 11)).foregroundStyle(Studio.muted)
            }
            Spacer()
        }.padding(16).background(Studio.green.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Studio.muted)
                    TextField(model.copy("Find a task or course", "搜索任务或课程"), text: $search).textFieldStyle(.plain)
                }.font(.system(size: 12)).padding(11).background(Studio.surface).clipShape(RoundedRectangle(cornerRadius: 10))
                Menu {
                    Toggle(model.copy("Show other class sections", "显示其他班级"), isOn: $model.showOtherSections)
                    Toggle(model.copy("Show submitted assignments", "显示已提交作业"), isOn: $model.includeSubmitted)
                    Toggle(model.copy("Needs review only", "仅显示待核对"), isOn: $onlyWarnings)
                    Button(model.copy("Select all", "全选")) { model.setAllSelected(true) }
                    Button(model.copy("Select none", "全不选")) { model.setAllSelected(false) }
                    Divider()
                    Button(model.copy("All notifications on", "开启全部通知")) { model.setAllNotifications(true) }
                    Button(model.copy("All notifications off", "关闭全部通知")) { model.setAllNotifications(false) }
                    Button(model.copy("All calendar blocks on", "开启全部日历时间块")) { model.setAllCompanionEvents(true) }
                    Button(model.copy("All calendar blocks off", "关闭全部日历时间块")) { model.setAllCompanionEvents(false) }.disabled(model.outputMode == .calendar)
                } label: { Image(systemName: "slider.horizontal.3").frame(width: 30, height: 26) }.fixedSize()
                    .accessibilityLabel(model.copy("Batch actions", "批量操作"))
            }
            HStack {
                Button(model.copy("Select all", "全选")) { model.setAllSelected(true) }.buttonStyle(.plain)
                Text("/").foregroundStyle(Studio.muted.opacity(0.4))
                Button(model.copy("None", "全不选")) { model.setAllSelected(false) }.buttonStyle(.plain)
                Spacer()
                Button(model.copy("Fix details", "补全信息")) { model.showingMissingDetails = true }.buttonStyle(.plain)
                if onlyWarnings { Text(model.copy("Needs review", "待核对")).foregroundStyle(Studio.amber) }
                else { Text(model.copy("Click a task to refine it", "点击任务以编辑" )).foregroundStyle(Studio.muted) }
            }.font(.system(size: 10, weight: .medium))
        }.disabled(model.isProcessing)
    }

    private var saveBar: some View {
        VStack(spacing: 12) {
            if compact {
                Text(destinationText).font(.system(size: 10)).foregroundStyle(Studio.muted).lineLimit(1)
                saveButton.frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.copy("\(model.selectedCount) tasks selected", "已选 \(model.selectedCount) 项任务")).font(.system(size: 13, weight: .medium))
                        Text(destinationText).font(.system(size: 11)).foregroundStyle(Studio.muted)
                    }
                    Spacer()
                    saveButton
                }
            }
        }.padding(.horizontal, compact ? 22 : 34).padding(.vertical, compact ? 14 : 20)
            .background(Studio.sidebar).overlay(alignment: .top) { Rectangle().fill(Studio.line).frame(height: 1) }
    }

    private var destinationText: String {
        if model.isDemo { return model.copy("Sample mode · no real reminders or events", "示例模式 · 不创建真实提醒或日程") }
        return model.copy("Save to your assignment calendar · external calendar optional", "保存到作业日历 · 外部日历可选")
    }
    private var saveButton: some View {
        Button {
            if model.isDemo { model.simulateSave() }
            else { model.addSelected() }
        } label: {
            HStack(spacing: 10) {
                Text(model.copy(model.isDemo ? "Test save" : "Save selected", model.isDemo ? "体验保存" : "保存所选任务"))
                Image(systemName: "arrow.right")
            }.frame(maxWidth: compact ? .infinity : nil)
        }.buttonStyle(SilverButtonStyle()).disabled(model.isProcessing)
            .opacity(model.selectedCount == 0 ? 0.45 : 1)
            .accessibilityIdentifier("import.save")
    }
}

struct TaskCard: View {
    @EnvironmentObject private var model: AppModel
    @Binding var item: ImportItem
    let compact: Bool
    let edit: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: compact ? 12 : 17) {
            Button { item.isSelected.toggle(); model.previewSaved = false; model.saveCompleted = false } label: {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23, weight: .ultraLight)).foregroundStyle(item.isSelected ? Studio.silver : Studio.muted.opacity(0.5))
                    .frame(width: 28, height: 32)
            }.buttonStyle(.plain).accessibilityLabel(model.copy("Select ", "选择 ") + item.candidate.assignmentName)
            Button(action: edit) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 8) {
                        Text(item.candidate.courseTag.isEmpty ? model.copy("Uncategorized", "未分类") : item.candidate.courseTag).font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(0.5).foregroundStyle(Studio.muted)
                        Spacer(minLength: 0)
                        if item.status != .ready {
                            Pill(text: model.t(item.status.label), color: item.status == .needsReview ? Studio.amber : Studio.muted)
                        } else if !compact { Pill(text: model.copy("Ready", "就绪"), color: Studio.green) }
                    }
                    Text(item.candidate.titleOverride ?? item.candidate.assignmentName).font(.system(size: compact ? 15 : 17, weight: .medium))
                        .foregroundStyle(Studio.silver).multilineTextAlignment(.leading).lineLimit(2)
                    HStack(spacing: 11) {
                        Label(taskDate(item.candidate, language: model.language, includeTime: true), systemImage: "calendar")
                        if item.appAlertsEnabled { Image(systemName: "bell") }
                        if item.companionEventEnabled && model.outputMode.usesCalendar { Image(systemName: "rectangle.split.3x1") }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.system(size: 10))
                    }.font(.system(size: 10)).foregroundStyle(Studio.muted)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.padding(compact ? 16 : 21).background(item.isSelected ? Studio.surface : Studio.surface.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(item.isSelected ? Color.white.opacity(0.12) : Studio.line, lineWidth: 1).allowsHitTesting(false))
            .disabled(model.isProcessing)
    }
}
