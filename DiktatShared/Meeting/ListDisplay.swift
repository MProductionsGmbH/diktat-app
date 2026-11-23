import Foundation

/// Public Sans kerns a hyphen and the space after it so tightly that "- Punkt" reads as
/// "-Punkt". Summaries and notes therefore show their bullet points with "•"; copied text
/// keeps "- ", which mail and notes apps read as a list.
enum ListDisplay {
    static func bullets(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { $0.hasPrefix("- ") ? "\u{2022} " + $0.dropFirst(2) : $0 }
            .joined(separator: "\n")
    }

    /// The headings a summary and the live notes are made of, in both languages.
    private static let headings: Set<String> = [
        "zusammenfassung", "summary", "entscheidungen", "decisions", "to-dos", "todos", "to-do",
        "themen", "topics", "offene fragen", "open questions",
    ]

    /// Whether a line is one of the headings, with or without a colon.
    static func isHeading(_ line: String) -> Bool {
        headings.contains(line.trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespaces)).lowercased())
    }

    /// Without the Markdown marks a small model adds on its own: "**To-dos**", "## Themen",
    /// "- **Paul:** Angebot schicken". Bullet points and everything else stay as they are.
    static func plain(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { line in
                var line = line.replacingOccurrences(of: #"^\s{0,3}#{1,6}\s+"#, with: "", options: .regularExpression)
                line = line.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
                line = line.replacingOccurrences(of: #"__(.+?)__"#, with: "$1", options: .regularExpression)
                if isHeading(line) {
                    line = line.trimmingCharacters(in: CharacterSet(charactersIn: ": ").union(.whitespaces))
                }
                return line
            }
            .joined(separator: "\n")
    }

    struct Line: Equatable {
        let text: String
        let isHeading: Bool
    }

    /// What a card shows: no Markdown marks, "•" for bullet points, headings marked as such.
    /// - Parameter droppingTitle: A first heading that only repeats the title of the card
    ///   ("Zusammenfassung" under "Zusammenfassung") is left out.
    static func lines(_ text: String, droppingTitle: String? = nil) -> [Line] {
        var lines = bullets(plain(text)).components(separatedBy: "\n").map { Line(text: $0, isHeading: isHeading($0)) }
        if let droppingTitle, let first = lines.firstIndex(where: { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }),
           lines[first].isHeading, lines[first].text.lowercased() == droppingTitle.lowercased() {
            lines.remove(at: first)
        }
        return lines
    }
}
