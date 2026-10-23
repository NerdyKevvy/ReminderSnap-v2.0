import SwiftUI
import ReminderSnapCore

enum StudioPage: String, CaseIterable, Identifiable {
    case calendar, addReminder, settings, userGuide
    var id: String { rawValue }
    var icon: String {
        switch self { case .calendar: return "calendar"; case .addReminder: return "plus.square"; case .settings: return "slider.horizontal.3"; case .userGuide: return "book.closed" }
    }
    @MainActor func title(_ model: AppModel) -> String {
        switch self {
        case .calendar: return model.copy("Your Task Calendar", "作业日历")
        case .addReminder: return model.copy("Import Tasks", "导入任务")
        case .settings: return model.copy("Settings", "设置")
        case .userGuide: return model.copy("User Guide", "使用指南")
        }
    }
}

enum Studio {
    static let background = Color(red: 0.055, green: 0.061, blue: 0.073)
    static let sidebar = Color(red: 0.075, green: 0.081, blue: 0.095)
    static let surface = Color(red: 0.092, green: 0.101, blue: 0.116)
    static let elevated = Color(red: 0.125, green: 0.136, blue: 0.154)
    static let silver = Color(red: 0.89, green: 0.91, blue: 0.94)
    static let muted = Color(red: 0.58, green: 0.62, blue: 0.68)
    static let line = Color.white.opacity(0.085)
    static let green = Color(red: 0.58, green: 0.78, blue: 0.66)
    static let amber = Color(red: 0.88, green: 0.71, blue: 0.44)
}

struct SilverButtonStyle: ButtonStyle {
    var small = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: small ? 12 : 14, weight: .semibold))
            .foregroundStyle(Studio.background)
            .padding(.horizontal, small ? 13 : 20).padding(.vertical, small ? 9 : 13)
            .background(LinearGradient(colors: [Color.white, Studio.silver.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium)).foregroundStyle(Studio.silver)
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(configuration.isPressed ? Studio.elevated : Color.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Studio.line, lineWidth: 1).allowsHitTesting(false))
    }
}

struct Panel<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(Studio.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Studio.line, lineWidth: 1).allowsHitTesting(false))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(2).foregroundStyle(Studio.muted)
    }
}

struct Pill: View {
    let text: String
    var icon: String? = nil
    var color: Color = Studio.muted
    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }.font(.system(size: 10, weight: .medium)).foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(color.opacity(0.09)).clipShape(Capsule())
    }
}

struct BrandMark: View {
    var size: CGFloat = 42
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27).fill(Studio.elevated)
            RoundedRectangle(cornerRadius: size * 0.27).stroke(LinearGradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            Image(systemName: "viewfinder").font(.system(size: size * 0.63, weight: .ultraLight)).foregroundStyle(Studio.silver)
            Image(systemName: "checkmark").font(.system(size: size * 0.3, weight: .medium)).foregroundStyle(Studio.silver)
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct FieldLabel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Studio.muted)
            content
        }
    }
}

extension View {
    @ViewBuilder func onValueChange<Value: Equatable>(_ value: Value, perform: @escaping (Value) -> Void) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in perform(newValue) }
        } else {
            self.onChange(of: value, perform: perform)
        }
    }

    func studioField() -> some View {
        self.textFieldStyle(.plain).font(.system(size: 14)).padding(12)
            .background(Studio.background.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Studio.line, lineWidth: 1).allowsHitTesting(false))
    }
}

func taskDate(_ task: AssignmentCandidate, language: AppLanguage, includeTime: Bool = false) -> String {
    guard let date = task.dueDate else { return language == .english ? "Set deadline" : "设置截止时间" }
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.timeZone = task.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
    formatter.dateFormat = includeTime && task.hasExplicitTime ? "MMM d · HH:mm" : "MMM d, yyyy"
    return formatter.string(from: date)
}
