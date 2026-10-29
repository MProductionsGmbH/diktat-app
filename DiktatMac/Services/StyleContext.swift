import Foundation

/// Where the dictated text goes, so it can be written in the tone that suits it: a message to a
/// friend reads differently from a mail to a client.
enum StyleContext: String, Codable, CaseIterable, Identifiable {
    case personal
    case work
    case email
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .personal: return String(localized: "Pers\u{00F6}nlich")
        case .work: return String(localized: "Arbeit")
        case .email: return String(localized: "E-Mail")
        case .other: return String(localized: "Andere")
        }
    }

    /// Shown under the tabs, so it is clear where the style applies.
    var appsNote: String {
        switch self {
        case .personal: return String(localized: "Gilt in WhatsApp, Telegram, Signal, Discord und Nachrichten.")
        case .work: return String(localized: "Gilt in Slack und Teams, auch im Browser.")
        case .email: return String(localized: "Gilt in Mail, Outlook, Spark und anderen Mail-Programmen, auch Gmail im Browser.")
        case .other: return String(localized: "Gilt in allen anderen Programmen.")
        }
    }

    var defaultTone: StyleTone {
        switch self {
        case .personal: return .casual
        case .work, .other: return .neutral
        case .email: return .formal
        }
    }

    private static let bundleIDs: [String: StyleContext] = [
        "net.whatsapp.WhatsApp": .personal, "ru.keepcoder.Telegram": .personal,
        "org.telegram.desktop": .personal, "org.whispersystems.signal-desktop": .personal,
        "com.hnc.Discord": .personal, "com.apple.MobileSMS": .personal,
        "com.tinyspeck.slackmacgap": .work, "com.microsoft.teams2": .work,
        "com.microsoft.teams": .work, "us.zoom.xos": .work,
        "com.apple.mail": .email, "com.microsoft.Outlook": .email,
        "com.readdle.SparkDesktop": .email, "com.readdle.smartemail-macos": .email,
        "it.bloop.airmail2": .email, "com.mimestream.Mimestream": .email,
        "com.superhuman.electron": .email, "com.freron.MailMate": .email,
    ]

    /// Websites in a browser, matched like the rules in "Modus je App": a host also covers its subdomains.
    private static let hosts: [(host: String, context: StyleContext)] = [
        ("web.whatsapp.com", .personal), ("web.telegram.org", .personal),
        ("discord.com", .personal), ("messenger.com", .personal),
        ("app.slack.com", .work), ("slack.com", .work),
        ("teams.microsoft.com", .work), ("linkedin.com", .work),
        ("mail.google.com", .email), ("outlook.office.com", .email),
        ("outlook.live.com", .email), ("outlook.office365.com", .email),
        ("mail.proton.me", .email), ("app.hey.com", .email),
    ]

    /// The context of the app, or of the website when the app is a browser.
    static func context(bundleID: String?, host: String?) -> StyleContext {
        if let host {
            let normalized = host.lowercased()
            if let match = hosts.first(where: { normalized == $0.host || normalized.hasSuffix("." + $0.host) }) {
                return match.context
            }
        }
        if let bundleID, let context = bundleIDs[bundleID] {
            return context
        }
        return .other
    }
}

/// How the text reads: the sentence marks it ends with and, when the AI written-style level
/// rewrites it, the wording.
enum StyleTone: String, Codable, CaseIterable, Identifiable {
    case formal
    case neutral
    case casual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .formal: return String(localized: "Formell")
        case .neutral: return String(localized: "Normal")
        case .casual: return String(localized: "Locker")
        }
    }

    var detail: String {
        switch self {
        case .formal: return String(localized: "Mit KI-Schreibstil: sachlich und h\u{00F6}flich formuliert")
        case .neutral: return String(localized: "Mit KI-Schreibstil: klar und neutral formuliert")
        case .casual: return String(localized: "Ohne Punkt am Ende, mit KI-Schreibstil ungezwungen formuliert")
        }
    }

    /// The same dictated sentence for every tone, so the settings show what each tone changes.
    static let exampleSpoken = String(localized: "hey alex war echt sch\u{00F6}n heute mit dir zu reden ich melde mich n\u{00E4}chste woche wegen dem termin")

    /// The sentence after the cleanup levels Leicht to Stark: punctuation set, and only the period
    /// at the end follows the tone.
    var exampleCleaned: String {
        apply(to: String(localized: "Hey Alex, war echt sch\u{00F6}n, heute mit dir zu reden. Ich melde mich n\u{00E4}chste Woche wegen dem Termin."))
    }

    /// What the model of KI-Schreibstil made of it in this tone (answers of Apple Intelligence; a
    /// model words it a little differently each time).
    var exampleRewritten: String {
        switch self {
        case .formal:
            return apply(to: String(localized: "Hallo Alex, es war wirklich sch\u{00F6}n, heute mit dir zu sprechen. Ich melde mich n\u{00E4}chste Woche bez\u{00FC}glich des Termins."))
        case .neutral:
            return apply(to: String(localized: "Hey Alex, es war wirklich sch\u{00F6}n, heute mit dir zu reden. Ich melde mich n\u{00E4}chste Woche wegen des Termins."))
        case .casual:
            return apply(to: String(localized: "Hey Alex, war echt sch\u{00F6}n, heute mit dir zu reden. Ich melde mich n\u{00E4}chste Woche wegen des Termins."))
        }
    }

    /// The tone for the model of the AI written-style level.
    var rewriteTone: TextImprovementSettings.TextTone {
        switch self {
        case .formal: return .formal
        case .neutral: return .neutral
        case .casual: return .casual
        }
    }

    /// Rule-based part: the casual tone leaves the period off the end, as people do in a chat.
    /// A question or exclamation mark and an ellipsis stay.
    func apply(to text: String) -> String {
        guard self == .casual else { return text }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix("."), !trimmed.hasSuffix("..") else { return text }
        return String(trimmed.dropLast())
    }
}

/// The tone per context, as the user set it.
struct StyleSettings: Codable, Equatable {
    private var tones: [String: StyleTone] = [:]

    func tone(for context: StyleContext) -> StyleTone {
        tones[context.rawValue] ?? context.defaultTone
    }

    mutating func setTone(_ tone: StyleTone, for context: StyleContext) {
        tones[context.rawValue] = tone
    }
}
