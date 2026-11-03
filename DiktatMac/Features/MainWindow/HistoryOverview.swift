import Foundation

/// What the history page of the main window shows: results grouped by day, narrowed by a search, and the
/// optional counts. Pure logic, so it is tested without the window.
enum HistoryOverview {
    enum Day: Equatable {
        case today
        case yesterday
        case date(Date)
    }

    struct Group<Item> {
        let day: Day
        let items: [Item]
    }

    /// The items, newest first, in groups per calendar day.
    static func groups<Item>(
        _ items: [Item],
        date: (Item) -> Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Group<Item>] {
        var result: [Group<Item>] = []
        var currentStart: Date?
        var current: [Item] = []
        func flush() {
            guard let start = currentStart, !current.isEmpty else { return }
            let kind: Day
            if calendar.isDate(start, inSameDayAs: now) {
                kind = .today
            } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(start, inSameDayAs: yesterday) {
                kind = .yesterday
            } else {
                kind = .date(start)
            }
            result.append(Group(day: kind, items: current))
        }
        for item in items.sorted(by: { date($0) > date($1) }) {
            let start = calendar.startOfDay(for: date(item))
            if start != currentStart {
                flush()
                currentStart = start
                current = []
            }
            current.append(item)
        }
        flush()
        return result
    }

    /// Case and accents do not matter; an empty search matches everything.
    static func matches(_ text: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    struct Statistics: Equatable {
        let words: Int
        let dictations: Int

        var wordsPerDictation: Int {
            dictations == 0 ? 0 : Int((Double(words) / Double(dictations)).rounded())
        }
    }

    static func statistics(of texts: [String]) -> Statistics {
        Statistics(words: texts.reduce(0) { $0 + wordCount($1) }, dictations: texts.count)
    }
}
