import XCTest

final class AudioFileRetentionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func entry(_ name: String, daysAgo: Double) -> AudioFileEntry {
        AudioFileEntry(
            id: UUID(), createdAt: now.addingTimeInterval(-daysAgo * 86_400), fileName: name, duration: 60,
            transcript: "Text", text: "Text", mode: "tapTalk"
        )
    }

    func testTextsStaySevenDays() {
        let kept = AudioFileRetention.kept([entry("neu", daysAgo: 0), entry("sechs Tage", daysAgo: 6.9)], now: now)
        XCTAssertEqual(kept.map(\.fileName), ["neu", "sechs Tage"])
    }

    func testTextsDisappearAfterSevenDays() {
        let kept = AudioFileRetention.kept([entry("genau sieben", daysAgo: 7), entry("alt", daysAgo: 30), entry("gestern", daysAgo: 1)], now: now)
        XCTAssertEqual(kept.map(\.fileName), ["gestern"])
    }

    func testNewestComesFirst() {
        let kept = AudioFileRetention.kept([entry("vorgestern", daysAgo: 2), entry("heute", daysAgo: 0.1), entry("gestern", daysAgo: 1)], now: now)
        XCTAssertEqual(kept.map(\.fileName), ["heute", "gestern", "vorgestern"])
    }

    func testAnEntrySurvivesSavingAndLoading() throws {
        let original = entry("Sprachmemo.m4a", daysAgo: 1)
        let loaded = try JSONDecoder().decode([AudioFileEntry].self, from: JSONEncoder().encode([original]))
        XCTAssertEqual(loaded, [original])
    }
}
