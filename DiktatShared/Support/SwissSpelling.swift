import Foundation

/// Swiss German writes "ss" where Germany and Austria write the sharp s: "Strasse", "gross",
/// "schliessen". With the setting on, everything Diktat writes follows that: dictations, the
/// texts of the AI modes, meeting transcripts, summaries and live notes.
enum SwissSpelling {
    /// The setting "Schweizer Schreibweise"; AppState keeps it current.
    nonisolated(unsafe) static var isEnabled = false

    /// Where "ss" is the rule: Switzerland and Liechtenstein. The setting starts on there.
    static func isUsual(inRegion region: String?) -> Bool {
        ["CH", "LI"].contains(region ?? "")
    }

    static var isUsualHere: Bool {
        isUsual(inRegion: Locale.current.region?.identifier)
    }

    static func apply(_ text: String) -> String {
        guard text.contains("\u{00DF}") || text.contains("\u{1E9E}") else { return text }
        return text
            .replacingOccurrences(of: "\u{00DF}", with: "ss")
            .replacingOccurrences(of: "\u{1E9E}", with: "SS")
    }

    /// `text` in the Swiss spelling when the setting is on, otherwise as it is.
    static func ifEnabled(_ text: String) -> String {
        isEnabled ? apply(text) : text
    }
}
