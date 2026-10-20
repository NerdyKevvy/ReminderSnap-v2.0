import SwiftUI
import UniformTypeIdentifiers
import ReminderSnapCore

struct StudioShell: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var phase

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 780
            HStack(spacing: 0) {
                if !compact { sidebar }
                VStack(spacing: 0) {
                    topbar(compact: compact)
                    Rectangle().fill(Studio.line).frame(height: 1).allowsHitTesting(false)
                    if model.permissionSetup.restartRecommended {
                        PermissionRestartNotice(compact: true)
                            .padding(.horizontal, compact ? 18 : 32).padding(.vertical, 12)
                    }
                    Group {
                        switch model.page {
                        case .addReminder: ReviewView(compact: compact)
                        case .settings: PreferencesView(compact: compact)
                        case .userGuide: ConnectionsView(compact: compact)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    if compact { bottomBar }
                }.frame(maxWidth: .infinity)
            }
            .background(Studio.background).foregroundStyle(Studio.silver)
        }
        .preferredColorScheme(.dark).tint(Studio.silver)
        .environment(\.locale, model.language.locale)
        .fileImporter(isPresented: $model.showingImporter, allowedContentTypes: [.image, .pdf], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): model.importScreenshots(urls)
            case .failure(let error): model.statusMessage = LocalizedMessage(verbatim: error.localizedDescription)
            }
        }
        .sheet(isPresented: $model.showingSetup) { WelcomeView().environmentObject(model) }
        .alert(model.copy("Clear this import?", "清空本次导入？"), isPresented: $model.showingClearConfirmation) {
            Button(model.copy("Cancel", "取消"), role: .cancel) { }
            Button(model.copy("Clear All", "清空全部"), role: .destructive) { model.clear() }
        } message: {
            Text(model.copy("Remove the review list and temporary recognized text. Saved Apple reminders, calendar blocks and your source files will not be deleted.", "移除待核对任务与临时识别文本，不会删除已保存的 Apple 提醒事项、日历时间块或原始文件。"))
        }
        .task(id: phase) {
            guard phase == .active else { return }
            // Give SwiftUI one scheduling turn to attach the presentation host.
            await Task.yield()
            guard !Task.isCancelled else { return }
            model.sceneBecameActive()
        }
        .onValueChange(model.selectedListID) { _ in model.destinationChanged() }
        .onValueChange(model.selectedCalendarID) { _ in model.destinationChanged() }
        .onValueChange(model.outputMode) { _ in model.destinationChanged() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                BrandMark(size: 35)
                VStack(alignment: .leading, spacing: 3) {
                    Text("ReminderSnap").font(.system(size: 16, weight: .semibold))
                    Text(model.copy("A LITTLE LESS ADMIN", "让截止日期井然有序")).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(Studio.muted)
                }
            }.padding(.top, 30).padding(.bottom, 35)
            ForEach(StudioPage.allCases) { page in
                Button { model.page = page } label: {
                    HStack(spacing: 12) {
                        Image(systemName: page.icon).frame(width: 18)
                        Text(page.title(model)).font(.system(size: 13, weight: model.page == page ? .semibold : .regular))
                        Spacer(minLength: 0)
                        if page == .addReminder && !model.items.isEmpty {
                            Text("\(model.items.count)").font(.system(size: 10, weight: .medium, design: .monospaced))
                        }
                    }
                    .foregroundStyle(model.page == page ? Studio.silver : Studio.muted)
                    .padding(.horizontal, 13).padding(.vertical, 15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(model.page == page ? Color.white.opacity(0.065) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("navigation.\(page.rawValue)")
                .accessibilityAddTraits(model.page == page ? .isSelected : [])
                .padding(.bottom, 5)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Label(model.copy("On-device by design", "始终本地处理"), systemImage: "lock.shield")
                    .font(.system(size: 11, weight: .medium))
                Text(model.copy("Your files stay with you.\nYour tasks live in Apple’s apps.", "文件留在设备上。\n任务保存在 Apple 应用中。"))
                    .font(.system(size: 11)).foregroundStyle(Studio.muted).lineSpacing(4)
            }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.025)).clipShape(RoundedRectangle(cornerRadius: 12))
            Text("REMINDERSNAP · 2.0").font(.system(size: 9, design: .monospaced)).tracking(0.5)
                .foregroundStyle(Studio.muted).padding(.vertical, 22).padding(.horizontal, 6)
        }.padding(.horizontal, 17).frame(width: 218).background(Studio.sidebar)
            .overlay(alignment: .trailing) { Rectangle().fill(Studio.line).frame(width: 1).allowsHitTesting(false) }
    }

    private func topbar(compact: Bool) -> some View {
        HStack(spacing: 10) {
            if compact { BrandMark(size: 27) }
            Text(model.page.title(model)).font(.system(size: compact ? 16 : 13, weight: .semibold))
            Spacer(minLength: 4)
            if model.page == .addReminder {
                Button { model.showingClearConfirmation = true } label: {
                    Label(model.copy("Clear All", "清空全部"), systemImage: "trash")
                }.buttonStyle(QuietButtonStyle()).disabled(!model.canClearImport)
                    .accessibilityIdentifier("import.clearAll")
                    .help(model.copy("Clear only this import, never saved Apple data", "仅清空本次导入，不删除已保存的数据"))
            }
        }.padding(.horizontal, compact ? 18 : 32).padding(.vertical, 13)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(StudioPage.allCases) { page in
                Button { model.page = page } label: {
                    VStack(spacing: 5) {
                        Image(systemName: page.icon).font(.system(size: 19))
                        Text(page.title(model)).font(.system(size: 10, weight: .medium))
                    }.frame(maxWidth: .infinity).frame(height: 52)
                        .foregroundStyle(model.page == page ? Studio.silver : Studio.muted)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("navigation.\(page.rawValue)")
                    .accessibilityAddTraits(model.page == page ? .isSelected : [])
            }
        }.padding(.vertical, 6).background(Studio.sidebar)
            .overlay(alignment: .top) { Rectangle().fill(Studio.line).frame(height: 1).allowsHitTesting(false) }
    }
}
