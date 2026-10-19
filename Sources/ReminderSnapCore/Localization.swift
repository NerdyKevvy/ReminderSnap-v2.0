import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    public var id: String { rawValue }
    public var title: String { self == .english ? "English" : "简体中文" }
    public var locale: Locale { Locale(identifier: rawValue) }
    public static let preferenceKey = "ReminderSnap.AppLanguage"
    public static var current: AppLanguage {
        resolve(saved: UserDefaults.standard.string(forKey: preferenceKey), preferredLanguages: Locale.preferredLanguages)
    }
    public static func resolve(saved: String?, preferredLanguages: [String]) -> AppLanguage {
        if let saved, let language = Self(rawValue: saved) { return language }
        return preferredLanguages.first?.hasPrefix("zh") == true ? .simplifiedChinese : .english
    }
}

public enum Localizer {
    public static func text(_ key: String, language: AppLanguage = .current, arguments: [String] = []) -> String {
        let format = language == .simplifiedChinese ? ChineseCatalog.strings[key] ?? key : key
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: language.locale, arguments: arguments.map { $0 as CVarArg })
    }
    public static var translatedKeys: Set<String> { Set(ChineseCatalog.strings.keys) }
}

/// Preserve message keys and values separately, so switching languages also
/// updates already-visible status messages without reimporting assignments.
public struct LocalizedMessage: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    private indirect enum Storage {
        case format(String, [String]), verbatim(String), joined([LocalizedMessage], String)
    }
    private let storage: Storage
    public init(stringLiteral value: String) { storage = .format(value, []) }
    public init(_ key: String, arguments: [String] = []) { storage = .format(key, arguments) }
    public init(verbatim: String) { storage = .verbatim(verbatim) }
    public init(stringInterpolation: StringInterpolation) { storage = .format(stringInterpolation.key, stringInterpolation.arguments) }
    public var isEmpty: Bool { rendered(in: .english).isEmpty }
    public func rendered(in language: AppLanguage) -> String {
        switch storage {
        case .format(let key, let arguments): return Localizer.text(key, language: language, arguments: arguments)
        case .verbatim(let text): return text
        case .joined(let messages, let separator): return messages.map { $0.rendered(in: language) }.joined(separator: separator)
        }
    }
    public static func joined(_ messages: [LocalizedMessage], separator: String = " ") -> LocalizedMessage {
        LocalizedMessage(storage: .joined(messages, separator))
    }
    private init(storage: Storage) { self.storage = storage }
    public struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []
        public init(literalCapacity: Int, interpolationCount: Int) { arguments.reserveCapacity(interpolationCount) }
        public mutating func appendLiteral(_ literal: String) { key += literal.replacingOccurrences(of: "%", with: "%%") }
        public mutating func appendInterpolation<T>(_ value: T) { key += "%@"; arguments.append(String(describing: value)) }
    }
}
