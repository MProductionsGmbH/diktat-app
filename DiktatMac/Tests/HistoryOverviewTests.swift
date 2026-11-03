import XCTest

final class HistoryOverviewTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    func testGroupsByDayNewestFirst() {
        let now = date(3, 15)
        let items = [date(1, 9), date(3, 8), date(2, 17), date(3, 14), date(2, 10)]
        let groups = HistoryOverview.groups(items, date: { $0 }, now: now, calendar: calendar)
        XCTAssertEqual(groups.map(\.day), [.today, .yesterday, .date(calendar.startOfDay(for: date(1, 9)))])
        XCTAssertEqual(groups.map(\.items.count), [2, 2, 1])
        XCTAssertEqual(groups[0].items, [date(3, 14), date(3, 8)])
    }

    func testNoItemsNoGroups() {
        XCTAssertTrue(HistoryOverview.groups([Date](), date: { $0 }, calendar: calendar).isEmpty)
    }

    func testSearchIgnoresCaseAndAccents() {
        XCTAssertTrue(HistoryOverview.matches("Das Büro öffnet um acht", query: "buro"))
        XCTAssertTrue(HistoryOverview.matches("Das Büro öffnet um acht", query: " ACHT "))
        XCTAssertFalse(HistoryOverview.matches("Das Büro öffnet um acht", query: "neun"))
        XCTAssertTrue(HistoryOverview.matches("Alles", query: "  "))
    }

    func testStatistics() {
        let stats = HistoryOverview.statistics(of: ["Eins zwei drei", "Vier  fünf\nsechs sieben", ""])
        XCTAssertEqual(stats, HistoryOverview.Statistics(words: 7, dictations: 3))
        XCTAssertEqual(stats.wordsPerDictation, 2)
        XCTAssertEqual(HistoryOverview.statistics(of: []).wordsPerDictation, 0)
    }
}
