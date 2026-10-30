import Foundation

/// The language of the interface, picked in "Allgemein" and independent of the dictation language.
/// It is stored the way macOS stores a per-app language (`AppleLanguages` in the app's own defaults), so
/// every text, including those from `String(localized:)`, follows it after a restart.
enum AppLanguage: String, CaseIterable, Identifiable {
    /// The app follows macOS.
    case system
    case german
    case english

    var id: String { rawValue }

    /// Languages are shown in their own name, so a user who cannot read the current one still finds theirs.
    var displayName: String {
        switch self {
        case .system: return String(localized: "Automatisch")
        case .german: return "Deutsch"
        case .english: return "English"
        }
    }

    /// The language code for the interface; nil follows the system.
    var interfaceCode: String? {
        switch self {
        case .system: return nil
        case .german: return "de"
        case .english: return "en"
        }
    }

    private static let key = "AppleLanguages"

    /// What is set for this app (not what macOS has): the system default when nothing is set.
    static func stored(domain: String = Bundle.main.bundleIdentifier ?? "app.diktat.mac", defaults: UserDefaults = .standard) -> AppLanguage {
        let languages = defaults.persistentDomain(forName: domain)?[key] as? [String]
        switch languages?.first?.lowercased().prefix(2) {
        case "de": return .german
        case "en": return .english
        default: return .system
        }
    }

    func store(defaults: UserDefaults = .standard) {
        if let interfaceCode {
            defaults.set([interfaceCode], forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
    }

    /// The language the running app shows its texts in: German or English.
    static var running: String {
        Bundle.main.preferredLocalizations.first?.lowercased().prefix(2).description ?? "de"
    }

    /// Whether the texts on screen differ from the chosen language, so a restart is due.
    func needsRestart(runningCode: String = AppLanguage.running, systemCodes: [String] = Locale.preferredLanguages) -> Bool {
        let wanted: String
        if let interfaceCode {
            wanted = interfaceCode
        } else {
            // The app only has German and English; any other system language falls back to German.
            let first = systemCodes.first?.lowercased().prefix(2).description ?? "de"
            wanted = first == "en" ? "en" : "de"
        }
        return wanted != runningCode
    }
}

/// The language dictation listens for. Automatic lets the speech models detect it for every
/// dictation, which is the default; a fixed language is for short sentences they get wrong.
enum DictationLanguage: String, CaseIterable, Identifiable {
    case automatic
    case german
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return String(localized: "Automatisch")
        case .german: return "Deutsch"
        case .english: return "English"
        }
    }

    /// The value of the dictation language setting: "auto" lets the speech models detect the language.
    var code: String {
        switch self {
        case .automatic: return "auto"
        case .german: return "de"
        case .english: return "en"
        }
    }

    init(code: String) {
        switch code.lowercased().prefix(2) {
        case "de": self = .german
        case "en": self = .english
        default: self = .automatic
        }
    }
}
