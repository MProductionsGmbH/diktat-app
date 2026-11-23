import XCTest

final class ListDisplayTests: XCTestCase {
    func testBulletPointsGetABullet() {
        let summary = "Entscheidungen\n- Der Workshop findet online statt\n\nTo-dos\n- Paul: Angebot schicken"
        XCTAssertEqual(
            ListDisplay.bullets(summary),
            "Entscheidungen\n\u{2022} Der Workshop findet online statt\n\nTo-dos\n\u{2022} Paul: Angebot schicken"
        )
    }

    func testOtherDashesStay() {
        XCTAssertEqual(ListDisplay.bullets("Zahlen -5 % zum Vorjahr\n-Keine"), "Zahlen -5 % zum Vorjahr\n-Keine")
    }

    // MARK: Markdown marks a model adds on its own

    func testMarkdownHeadingsBecomePlainLines() {
        XCTAssertEqual(ListDisplay.plain("**Zusammenfassung**\nText.\n\n## To-dos\n- **Paul:** Angebot"), "Zusammenfassung\nText.\n\nTo-dos\n- Paul: Angebot")
        XCTAssertEqual(ListDisplay.plain("**Entscheidungen:**\n- Keine"), "Entscheidungen\n- Keine")
    }

    func testBulletStarsAndPlainTextStay() {
        XCTAssertEqual(ListDisplay.plain("* Punkt eins\n5 * 3 = 15"), "* Punkt eins\n5 * 3 = 15")
    }

    func testHeadingsAreMarkedAndTheTitleIsNotRepeated() {
        let lines = ListDisplay.lines("**Zusammenfassung**\nEs ging um den Workshop.\n\n**To-dos**\n- Paul: Angebot", droppingTitle: "Zusammenfassung")
        XCTAssertEqual(lines.first, ListDisplay.Line(text: "Es ging um den Workshop.", isHeading: false))
        XCTAssertTrue(lines.contains(ListDisplay.Line(text: "To-dos", isHeading: true)))
        XCTAssertTrue(lines.contains(ListDisplay.Line(text: "\u{2022} Paul: Angebot", isHeading: false)))
    }

    func testOtherFirstHeadingsStay() {
        let lines = ListDisplay.lines("Themen\n- Workshop", droppingTitle: "Zusammenfassung")
        XCTAssertEqual(lines.first, ListDisplay.Line(text: "Themen", isHeading: true))
    }
}
