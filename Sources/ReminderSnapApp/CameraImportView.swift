#if os(iOS)
import SwiftUI
import UIKit
import AVFoundation
import ReminderSnapCore

struct CameraImportView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var captured: UIImage?
    @State private var pages: [Data] = []
    @State private var crop = CGRect(x: 0, y: 0, width: 1, height: 1)

    var body: some View {
        Group {
            if let image = captured {
                VStack(spacing: 18) {
                    HStack {
                        Text(model.copy("Keep names and deadlines together.", "保留作业名称与截止日期。" )).font(.headline)
                        Spacer()
                        Button(model.copy("Cancel", "取消")) { dismiss() }
                    }.padding(.horizontal)
                    Text(model.copy("Drag over the image to crop. Avoid glare and keep text large. Retake if letters look blurry.", "在图片上拖动以裁剪，避开反光并保持文字清晰。若模糊，请重拍。"))
                        .font(.caption).foregroundStyle(Studio.muted).padding(.horizontal)
                    GeometryReader { geometry in
                        let ratio = min(geometry.size.width / image.size.width, geometry.size.height / image.size.height)
                        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                        ZStack(alignment: .topLeading) {
                            Image(uiImage: image).resizable().frame(width: size.width, height: size.height)
                            Rectangle().stroke(Studio.silver, style: StrokeStyle(lineWidth: 2, dash: [7]))
                                .frame(width: crop.width * size.width, height: crop.height * size.height)
                                .offset(x: crop.minX * size.width, y: crop.minY * size.height)
                                .allowsHitTesting(false)
                        }.frame(width: size.width, height: size.height).contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 5).onChanged { value in
                                let x1 = min(1, max(0, value.startLocation.x / size.width))
                                let y1 = min(1, max(0, value.startLocation.y / size.height))
                                let x2 = min(1, max(0, value.location.x / size.width))
                                let y2 = min(1, max(0, value.location.y / size.height))
                                crop = CGRect(x: min(x1, x2), y: min(y1, y2), width: abs(x2 - x1), height: abs(y2 - y1))
                            })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    if image.size.width * image.scale * crop.width < 700 {
                        Label(model.copy("Small crop: move closer and retake if text is hard to read.", "裁剪区域较小：若文字难辨，请靠近屏幕重拍。"), systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(Studio.amber).padding(.horizontal)
                    }
                    HStack {
                        Button(model.copy("Retake", "重拍")) { captured = nil; crop = CGRect(x: 0, y: 0, width: 1, height: 1) }.buttonStyle(QuietButtonStyle())
                        Button(model.copy("Reset crop", "重置裁剪")) { crop = CGRect(x: 0, y: 0, width: 1, height: 1) }.buttonStyle(QuietButtonStyle())
                    }
                    HStack {
                        Button(model.copy("Add another", "再拍一张")) {
                            if let data = cropped(image) { pages.append(data); captured = nil; crop = CGRect(x: 0, y: 0, width: 1, height: 1) }
                        }.buttonStyle(QuietButtonStyle()).disabled(pages.count >= 19)
                        Button(model.copy("Read \(pages.count + 1) photo(s)", "识别 \(pages.count + 1) 张照片")) {
                            guard let data = cropped(image) else { return }
                            let images = pages + [data]
                            model.showingCamera = false; dismiss(); model.importPhotoData(images)
                        }.buttonStyle(SilverButtonStyle(small: true))
                    }.padding(.bottom)
                }.background(Studio.background).foregroundStyle(Studio.silver)
            } else {
                CameraPicker(chinese: model.language == .simplifiedChinese, onPhoto: { captured = $0 }, onCancel: { dismiss() })
                    .ignoresSafeArea()
            }
        }.preferredColorScheme(.dark)
    }
    private func cropped(_ image: UIImage) -> Data? {
        // Normalize camera orientation before translating the crop to pixels.
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 4800 / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard crop.width > 0.03, crop.height > 0.03, let cg = normalized.cgImage else { return normalized.jpegData(compressionQuality: 0.95) }
        let rect = CGRect(x: crop.minX * CGFloat(cg.width), y: crop.minY * CGFloat(cg.height), width: crop.width * CGFloat(cg.width), height: crop.height * CGFloat(cg.height)).integral
        guard let result = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: result).jpegData(compressionQuality: 0.95)
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let chinese: Bool
    let onPhoto: (UIImage) -> Void
    let onCancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let camera = UIImagePickerController(); camera.sourceType = .camera
        camera.cameraCaptureMode = .photo; camera.delegate = context.coordinator
        let overlay = UIView(frame: UIScreen.main.bounds); overlay.isUserInteractionEnabled = false
        let label = UILabel(frame: CGRect(x: 20, y: 105, width: overlay.bounds.width - 40, height: 78))
        label.text = chinese ? "对准作业名称与截止日期\n靠近屏幕 · 保持平稳 · 避开反光" : "Keep task names + deadlines visible\nMove closer · Hold steady · Avoid glare"
        label.textColor = .white; label.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        label.textAlignment = .center; label.numberOfLines = 3; label.font = .systemFont(ofSize: 14, weight: .medium)
        label.layer.cornerRadius = 12; label.clipsToBounds = true
        overlay.addSubview(label); camera.cameraOverlayView = overlay
        return camera
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPhoto(image) }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onCancel() }
    }
}

extension AppModel {
    func takePhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            statusMessage = LocalizedMessage(verbatim: copy("No camera is available. Use Photos or Choose Files.", "此设备无法使用摄像头，请选择照片或文件。")); return
        }
        Task {
            let allowed: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: allowed = true
            case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .video)
            default: allowed = false
            }
            if allowed { showingCamera = true }
            else { statusMessage = LocalizedMessage(verbatim: copy("Camera access is off. Enable it in Settings, or import a photo instead.", "摄像头权限已关闭，可在设置中开启，或直接导入照片。")) }
        }
    }
}
#endif
