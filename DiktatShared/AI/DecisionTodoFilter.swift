import Foundation

/// Removes decisions that only repeat a to-do. Small on-device models like to list "Den Raum buchen"
/// under "Entscheidungen" although somebody just took it on as a task. A decision goes when most of its
/// words are in one to-do; when in doubt it stays. A decision with a number or date that the to-do does
/// not have also stays ("Preise um 5 % erhöhen" is more than the to-do "Preise prüfen").
enum DecisionTodoFilter {
    private static let stopWords: Set<String> = [
        // German
        "der", "die", "das", "den", "dem", "des", "ein", "eine", "einer", "eines", "einen", "einem", "und", "oder",
        "mit", "zur", "zum", "von", "vom", "wird", "werden", "wurde", "wurden", "ist", "sind", "war", "nicht", "auch",
        "dass", "bei", "für", "auf", "aus", "nach", "über", "unter", "bis", "wir", "sie", "man", "dann", "noch", "nur",
        "person", "soll", "sollen", "wird", "wurde",
        // English
        "the", "and", "are", "was", "were", "will", "with", "for", "from", "that", "this", "then", "also", "not",
        "they", "should", "shall", "have", "has", "been", "person",
    ]

    private static let sections: [String: Section] = [
        "zusammenfassung": .summary, "summary": .summary,
        "entscheidungen": .decisions, "decisions": .decisions,
        "to-dos": .todos, "todos": .todos, "to-do": .todos,
    ]

    private enum Section { case summary, decisions, todos }

    private static let bullet = try! NSRegularExpression(pattern: #"^\s*(?:[-*•–]|\d+[.)])\s+"#)

    static func filtered(_ summary: String) -> String {
        let lines = summary.components(separatedBy: "\n")

        var section: Section?
        var todos: [Set<String>] = []
        for line in lines {
            if let found = heading(of: line) {
                section = found
            } else if section == .todos, let text = bulletText(of: line) {
                todos.append(words(of: todoTask(text)))
            }
        }
        guard !todos.isEmpty else { return summary }

        var result: [String] = []
        var inDecisions = false
        var germanHeading = true
        var kept = 0
        var dropped = 0
        var placeholderAt: Int?
        func flushDecisions() {
            if inDecisions, kept == 0, dropped > 0, let index = placeholderAt {
                result.insert(germanHeading ? "- Keine" : "- None", at: index)
            }
            inDecisions = false
            kept = 0
            dropped = 0
            placeholderAt = nil
        }

        section = nil
        for line in lines {
            if let found = heading(of: line) {
                flushDecisions()
                section = found
                if found == .decisions {
                    inDecisions = true
                    germanHeading = bare(line) == "entscheidungen"
                }
                result.append(line)
                continue
            }
            if section == .decisions, let text = bulletText(of: line) {
                if isNone(text) {
                    kept += 1
                } else if repeatsATodo(text, todos: todos) {
                    dropped += 1
                    if placeholderAt == nil { placeholderAt = result.count }
                    continue
                } else {
                    kept += 1
                }
            }
            result.append(line)
        }
        flushDecisions()
        return result.joined(separator: "\n")
    }

    private static func heading(of line: String) -> Section? {
        sections[bare(line)]
    }

    /// "Entscheidungen", "**Decisions:**" or "## To-dos" become their bare lowercased name.
    private static func bare(_ line: String) -> String {
        line.trimmingCharacters(in: CharacterSet(charactersIn: "#*: ").union(.whitespaces)).lowercased()
    }

    private static func bulletText(of line: String) -> String? {
        guard let match = bullet.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range, in: line) else { return nil }
        return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    private static func isNone(_ text: String) -> Bool {
        ["keine", "none", "noch keine", "none yet"].contains(text.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")))
    }

    /// "Person 2: Den Raum buchen (bis Freitag)" -> "Den Raum buchen".
    private static func todoTask(_ text: String) -> String {
        var task = text
        if let colon = task.firstIndex(of: ":"), task.distance(from: task.startIndex, to: colon) <= 30 {
            task = String(task[task.index(after: colon)...])
        }
        return task.replacingOccurrences(of: #"\([^()]*\)"#, with: " ", options: .regularExpression)
    }

    private static func repeatsATodo(_ decision: String, todos: [Set<String>]) -> Bool {
        let decisionWords = words(of: decision)
        guard !decisionWords.isEmpty else { return false }
        let numbers = numbers(in: decision)
        return todos.contains { todo in
            guard !todo.isEmpty else { return false }
            let shared = decisionWords.intersection(todo).count
            guard Double(shared) / Double(decisionWords.count) >= 0.6 else { return false }
            return numbers.isSubset(of: todo)
        }
    }

    /// Digits as they are said ("12", "5"): a date or an amount that only the decision names.
    private static func numbers(in text: String) -> Set<String> {
        Set(text.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }.map { "#" + $0 })
    }

    /// Significant words, lightly stemmed so "geklärt" and "klären" meet: no stop words, no words
    /// under three letters, endings stripped once, then the first six letters. Numbers count as words
    /// ("#12").
    private static func words(of text: String) -> Set<String> {
        var result = Set<String>(numbers(in: text))
        let endings = ["ungen", "ung", "ern", "en", "et", "st", "te", "t", "e", "n", "s"]
        for raw in text.lowercased().components(separatedBy: CharacterSet.letters.inverted) where raw.count >= 3 {
            if stopWords.contains(raw) { continue }
            var word = raw
            for ending in endings where word.hasSuffix(ending) && word.count - ending.count >= 4 {
                word = String(word.dropLast(ending.count))
                break
            }
            result.insert(String(word.prefix(6)))
        }
        return result
    }
}
