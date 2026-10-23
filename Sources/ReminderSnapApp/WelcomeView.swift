import SwiftUI
import ReminderSnapCore

struct WelcomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                BrandMark(size: 32)
                Text("ReminderSnap").font(.headline)
                Spacer()
                Picker(model.copy("Language", "语言"), selection: $model.language) {
                    Text("English").tag(AppLanguage.english); Text("简体中文").tag(AppLanguage.simplifiedChinese)
                }.labelsHidden().fixedSize()
                Button(model.copy("Skip", "跳过")) { model.finishSetup() }.buttonStyle(.plain).font(.caption)
            }.padding(22)
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { index in
                            Capsule().fill(index <= step ? Studio.silver : Studio.elevated).frame(height: 3)
                        }
                    }
                    Text(title).font(.system(size: 31, weight: .medium)).tracking(-1).fixedSize(horizontal: false, vertical: true)
                    Text(detail).font(.system(size: 14)).foregroundStyle(Studio.muted).fixedSize(horizontal: false, vertical: true)
                    if step < 3 { PurposeVisual(scene: step).id(step) }
                    if step == 2 {
                        Button(model.copy("Enable ReminderSnap notifications", "开启 ReminderSnap 通知")) { model.enableAppNotifications() }.buttonStyle(QuietButtonStyle())
                        if model.notifications.authorized { Label(model.copy("Notifications allowed", "已允许通知"), systemImage: "checkmark.circle").font(.caption).foregroundStyle(Studio.green) }
                    }
                    if step == 3 {
                        WorkflowChoices()
                        if model.workflow == .apple { AppleConnectionsSection() }
                        if model.workflow == .google { GoogleConnectionPanel() }
                        Button(model.copy("Try it · show my workflow", "体验一下 · 查看我的工作流")) { model.trySelectedWorkflow() }
                            .buttonStyle(SilverButtonStyle()).accessibilityIdentifier("onboarding.sample")
                        Text(model.copy("The in-app sample is only a preview. External calendar tests ask before creating one labelled test task.", "应用内示例仅供预览，外部日历测试会先询问，再创建一项带标记的测试任务。"))
                            .font(.caption).foregroundStyle(Studio.muted)
                    }
                    Label(model.copy("No school login. Recognition stays on your device.", "无需学校登录，识别保留在设备上。"), systemImage: "lock.shield")
                        .font(.system(size: 11)).foregroundStyle(Studio.muted)
                    if !model.t(model.setupMessage).isEmpty { Text(model.t(model.setupMessage)).font(.caption).foregroundStyle(Studio.amber) }
                }.padding(24)
            }.id(step)
            HStack {
                if step > 0 { Button(model.copy("Back", "返回")) { withAnimation { step -= 1 } }.buttonStyle(QuietButtonStyle()) }
                Spacer()
                Text("\(step + 1) / 4").font(.caption.monospaced()).foregroundStyle(Studio.muted)
                Button(model.copy(step == 3 ? "Open my calendar" : "Continue", step == 3 ? "打开作业日历" : "继续")) {
                    if step == 3 { model.finishSetup() } else { withAnimation { step += 1 } }
                }.buttonStyle(SilverButtonStyle()).accessibilityIdentifier("onboarding.continue")
            }.padding(20).background(Studio.sidebar)
        }.background(Studio.background).foregroundStyle(Studio.silver).preferredColorScheme(.dark)
        #if os(macOS)
        .frame(width: 650, height: 760)
        #endif
    }
    private var title: String {
        switch step {
        case 0: return model.copy("Less checking.\nLess copying.", "少一点反复查看，\n少一点手动输入。")
        case 1: return model.copy("One snapshot.\nYour assignment center.", "一张截图，\n你的作业中心。")
        case 2: return model.copy("Know what’s next.\nBefore it’s due.", "提前知道，\n从容完成。")
        default: return model.copy("Your assignments.\nYour workflow.", "你的作业，\n你的使用方式。")
        }
    }
    private var detail: String {
        switch step {
        case 0: return model.copy("Different course sites. Deadlines everywhere. Bring them together without typing reminders one by one.", "课程平台各不相同，截止日期分散各处。不必逐项输入提醒，把它们集中在一起。")
        case 1: return model.copy("Screenshot or photograph your assignments. Check titles, dates and your class section. Save them to your calendar.", "截取或拍下作业页面，核对名称、日期和班级，即可保存到作业日历。")
        case 2: return model.copy("See deadlines by course. Get a reminder one day and two hours before—or choose your own times.", "按课程查看截止日期，在一天前和两小时前收到提醒，也可以自行修改通知时间。")
        default: return model.copy("Stay here, or optionally connect Apple apps or Google Calendar. Sign in only when you need the connection.", "留在这里，或按需连接 Apple 应用和 Google 日历，仅在需要连接时登录。")
        }
    }
}

/// Native, offline visual demo. It is not OCR input and never writes real data.
struct PurposeVisual: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let scene: Int
    @State private var revealed = false
    var body: some View {
        Panel(padding: 20) {
            VStack(spacing: 18) {
                if scene == 0 {
                    HStack(spacing: 9) {
                        sourceCard("Canvas", "CS 31", .cyan)
                        sourceCard("Gradescope", "CM 2211", .purple)
                        sourceCard("WebAssign", "MA 2034", .orange)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.title2)
                        Text(model.copy("Check a site. Copy a date. Repeat.", "查看平台、复制日期，一遍又一遍。" )).font(.caption)
                    }.foregroundStyle(Studio.muted)
                } else if scene == 1 {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12).fill(Studio.background)
                            VStack(alignment: .leading, spacing: 9) {
                                Text(model.copy("Assignments", "作业列表")).font(.system(size: 10, weight: .bold))
                                ForEach(0..<3) { _ in Capsule().fill(Studio.muted.opacity(0.3)).frame(height: 4) }
                            }.padding(13)
                            Image(systemName: "viewfinder").font(.system(size: 59, weight: .ultraLight)).foregroundStyle(Studio.silver.opacity(0.6))
                        }.frame(width: 108, height: 115)
                        Image(systemName: "arrow.right").foregroundStyle(Studio.muted)
                        VStack(alignment: .leading, spacing: 11) {
                            demoTask("CS 31", model.copy("Python assignment", "Python 作业"), .cyan)
                            demoTask("CM 2211 · A2LB", model.copy("Lab report", "实验报告"), .purple)
                        }.opacity(revealed ? 1 : 0.15).offset(x: revealed ? 0 : 8)
                    }
                    Label(model.copy("Import → confirm → your calendar", "导入 → 核对 → 作业日历"), systemImage: "checkmark.circle").font(.caption).foregroundStyle(Studio.muted)
                } else {
                    HStack(alignment: .top, spacing: 15) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.copy("YOUR TASK CALENDAR", "作业日历")).font(.system(size: 9, design: .monospaced)).foregroundStyle(Studio.muted)
                            HStack(spacing: 9) {
                                ForEach(21..<25) { number in
                                    VStack(spacing: 6) {
                                        Text("\(number)").font(.caption)
                                        Circle().fill(number == 23 ? .cyan : .clear).frame(width: 5, height: 5)
                                    }.padding(8).background(number == 23 ? Studio.elevated : .clear).clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            demoTask("CS 31", model.copy("Due 23:59", "23:59 截止"), .cyan)
                        }
                    }
                    HStack(alignment: .top, spacing: 12) {
                        BrandMark(size: 30)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("ReminderSnap").font(.system(size: 11, weight: .semibold))
                            Text(model.copy("Python assignment · due in 2 hours", "Python 作业 · 距离截止还有 2 小时")).font(.system(size: 12))
                            Text(model.copy("Notification preview", "通知预览")).font(.system(size: 9)).foregroundStyle(Studio.muted)
                        }
                        Spacer(minLength: 0)
                    }.padding(15).background(Studio.elevated).clipShape(RoundedRectangle(cornerRadius: 15))
                        .opacity(revealed ? 1 : 0.2).offset(y: revealed ? 0 : 12)
                }
            }.frame(maxWidth: .infinity)
        }.onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.65)) { revealed = true } }
    }
    private func sourceCard(_ name: String, _ course: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(name).font(.system(size: 9, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.6)).frame(height: 4)
            Text(course).font(.system(size: 9, design: .monospaced)).foregroundStyle(Studio.muted)
            Image(systemName: "square.and.pencil").font(.title3).foregroundStyle(Studio.muted)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Studio.background).clipShape(RoundedRectangle(cornerRadius: 12))
    }
    private func demoTask(_ course: String, _ title: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3)
            VStack(alignment: .leading, spacing: 5) {
                Text(course).font(.system(size: 9, design: .monospaced)).foregroundStyle(color)
                Text(title).font(.system(size: 11, weight: .medium))
            }
        }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Studio.elevated).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
