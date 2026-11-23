import XCTest

final class SwissSpellingTests: XCTestCase {
    override func tearDown() {
        SwissSpelling.isEnabled = false
        super.tearDown()
    }

    func testSharpSBecomesDoubleS() {
        XCTAssertEqual(SwissSpelling.apply("Die Stra\u{00DF}e ist gro\u{00DF}, wir schlie\u{00DF}en um zehn."), "Die Strasse ist gross, wir schliessen um zehn.")
        XCTAssertEqual(SwissSpelling.apply("STRA\u{1E9E}E"), "STRASSE")
    }

    func testTextWithoutSharpSStaysAsItIs() {
        XCTAssertEqual(SwissSpelling.apply("Massnahme, Kasse, Fluss"), "Massnahme, Kasse, Fluss")
    }

    func testOnlyWithTheSetting() {
        SwissSpelling.isEnabled = false
        XCTAssertEqual(SwissSpelling.ifEnabled("gro\u{00DF}"), "gro\u{00DF}")
        SwissSpelling.isEnabled = true
        XCTAssertEqual(SwissSpelling.ifEnabled("gro\u{00DF}"), "gross")
    }

    func testStartsOnInSwitzerlandAndLiechtenstein() {
        XCTAssertTrue(SwissSpelling.isUsual(inRegion: "CH"))
        XCTAssertTrue(SwissSpelling.isUsual(inRegion: "LI"))
        XCTAssertFalse(SwissSpelling.isUsual(inRegion: "DE"))
        XCTAssertFalse(SwissSpelling.isUsual(inRegion: "AT"))
        XCTAssertFalse(SwissSpelling.isUsual(inRegion: nil))
    }

    /// A dictation goes through the post-processor; with the setting on it comes out Swiss.
    func testDictationsFollowTheSetting() {
        let processor = TranscriptPostProcessor(correctCustomTerms: false, removeFillerWords: false)
        SwissSpelling.isEnabled = true
        XCTAssertEqual(processor.process("Wir treffen uns in der Bahnhofstra\u{00DF}e."), "Wir treffen uns in der Bahnhofstrasse.")
        SwissSpelling.isEnabled = false
        XCTAssertEqual(processor.process("Wir treffen uns in der Bahnhofstra\u{00DF}e."), "Wir treffen uns in der Bahnhofstra\u{00DF}e.")
    }
}
