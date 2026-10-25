import SwiftUI
import PhotosUI
import ReminderSnapCore

/// Import controls live above the results in the same workspace, not on a separate page.
struct CaptureView: View {
    @EnvironmentObject private var model: AppModel
    let compact: Bool
    @State private var photos: [PhotosPickerItem] = []
    @State private var loadingPhotos = false
    @State private var contextExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Panel(padding: compact || !model.items.isEmpty ? 16 : 25) {
                VStack(alignment: .leading, spacing: 18) {
                    if model.items.isEmpty { HStack(spacing: 14) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 27, weight: .light))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.copy("Drop screenshots or PDFs here", "将截图或 PDF 拖到这里"))
                                .font(.system(size: compact ? 17 : 20, weight: .medium))
                            Text(model.copy("Read locally. Your task list appears below.", "本地识别，任务直接显示在下方。"))
                                .font(.system(size: 12)).foregroundStyle(Studio.muted)
                        }
                    } }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { importButtons }
                        VStack(alignment: .leading, spacing: 10) { importButtons }
                    }.disabled(model.isProcessing || loadingPhotos)
                    if loadingPhotos { ProgressView(model.copy("Loading selected photos…", "正在读取所选照片…")).font(.caption) }
                    if !model.items.isEmpty {
                        Text(model.copy("A new import replaces this review list; saved Apple tasks are unchanged. Select multiple files together for one batch.", "新导入会替换当前待核对列表，不影响已保存的任务。请一次选择多个文件以合并识别。"))
                            .font(.system(size: 11)).foregroundStyle(Studio.muted)
                    }
                }
            }
            DisclosureGroup(isExpanded: $contextExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.copy("Context applies to this import only. Use Fix details after reading to correct the course for each image.", "补充信息仅用于本次导入。识别后可通过“补全信息”逐张修正课程。"))
                        .font(.system(size: 11)).foregroundStyle(Studio.muted)
                    HStack(spacing: 10) {
                        FieldLabel(title: model.copy("Course", "课程")) { TextField("MA-UY 2034", text: $model.batchCourse).studioField() }
                        FieldLabel(title: model.copy("Year", "年份")) { TextField("2026", text: $model.batchYear).studioField() }.frame(width: 90)
                    }
                    Picker(model.copy("Timezone", "时区"), selection: $model.batchTimeZone) {
                        Text(model.copy("Device timezone", "设备时区")).tag("")
                        Text("New York").tag("America/New_York")
                        Text("Los Angeles").tag("America/Los_Angeles")
                        Text("Shanghai").tag("Asia/Shanghai")
                        Text("UTC").tag("GMT")
                    }.font(.system(size: 12))
                }.padding(.top, 12)
            } label: {
                Label(model.copy("Missing course or year? Add context", "缺少课程或年份？补充信息"), systemImage: "crop")
                    .font(.system(size: 12, weight: .medium))
            }.padding(15).background(Studio.surface.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(model.isProcessing || loadingPhotos)
        }
        .onValueChange(photos) { selection in
            guard !selection.isEmpty else { return }
            loadingPhotos = true
            Task {
                var images: [Data] = []
                do {
                    for photo in selection {
                        if let data = try await photo.loadTransferable(type: Data.self) { images.append(data) }
                    }
                    model.importPhotoData(images)
                } catch { model.statusMessage = LocalizedMessage(verbatim: error.localizedDescription) }
                photos = []; loadingPhotos = false
            }
        }
    }

    @ViewBuilder private var importButtons: some View {
        let photosTitle = model.copy("Photos", "照片")
        Button { model.chooseScreenshots() } label: { Label(model.copy("Choose Files", "选择文件"), systemImage: "plus") }
            .buttonStyle(SilverButtonStyle(small: true)).accessibilityIdentifier("import.chooseFiles")
        PhotosPicker(selection: $photos, maxSelectionCount: 20, matching: .images) {
            Label(photosTitle, systemImage: "photo.on.rectangle")
        }.buttonStyle(QuietButtonStyle())
        #if os(iOS)
        Button { model.takePhoto() } label: { Label(model.copy("Take Photo", "拍摄照片"), systemImage: "camera") }
            .buttonStyle(QuietButtonStyle()).accessibilityIdentifier("import.camera")
        #endif
        if model.items.isEmpty {
            Button(model.copy("Try Sample", "体验示例")) { model.showSample() }
                .buttonStyle(QuietButtonStyle()).accessibilityIdentifier("import.sample")
        }
    }
}
