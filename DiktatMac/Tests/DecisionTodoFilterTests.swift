import XCTest

final class DecisionTodoFilterTests: XCTestCase {
    private func summary(decisions: [String], todos: [String], english: Bool = false) -> String {
        let (summaryHead, decisionsHead) = english ? ("Summary", "Decisions") : ("Zusammenfassung", "Entscheidungen")
        return """
        \(summaryHead)
        Es ging um den Workshop.

        \(decisionsHead)
        \(decisions.map { "- " + $0 }.joined(separator: "\n"))

        To-dos
        \(todos.map { "- " + $0 }.joined(separator: "\n"))
        """
    }

    /// The results of Apple's model on the test meeting "Workshop", as they came out.
    func testTaskListedAsDecisionIsRemovedAndTheRealDecisionStays() {
        let input = summary(
            decisions: ["Den Raum buchen", "Online statt im Büro machen"],
            todos: ["Person 2: Den Raum buchen", "Person 1: Die Einladung verschicken (bis Freitag)"]
        )
        let result = DecisionTodoFilter.filtered(input)
        XCTAssertFalse(result.contains("- Den Raum buchen"))
        XCTAssertTrue(result.contains("- Online statt im Büro machen"))
        XCTAssertTrue(result.contains("- Person 2: Den Raum buchen"), "the to-dos are never touched")
    }

    func testAllDecisionsRepeatingTodosLeaveNone() {
        let input = summary(
            decisions: ["Raum buchen", "Agenda und Unterlagen senden"],
            todos: ["Person 2: Raum buchen", "Person 1: Agenda und Unterlagen senden"]
        )
        let result = DecisionTodoFilter.filtered(input)
        XCTAssertTrue(result.contains("Entscheidungen\n- Keine\n"), result)
    }

    func testEnglishSummaryGetsAnEnglishPlaceholder() {
        let input = summary(decisions: ["Sign the contract"], todos: ["Person 2: Sign the contract (Wednesday)"], english: true)
        XCTAssertTrue(DecisionTodoFilter.filtered(input).contains("Decisions\n- None\n"))
    }

    func testStemmingMeetsGeklaertAndKlaeren() {
        let input = summary(
            decisions: ["Launch am 12. März", "Preise werden mit dem Vertrieb geklärt", "Landing-Page wird fertiggestellt"],
            todos: ["Person 3: Preise mit dem Vertrieb klären", "Person 1: Landing-Page fertigstellen (bis zum 5. März)"]
        )
        let result = DecisionTodoFilter.filtered(input)
        XCTAssertTrue(result.contains("- Launch am 12. März"))
        XCTAssertFalse(result.contains("- Preise werden mit dem Vertrieb geklärt"))
        XCTAssertFalse(result.contains("- Landing-Page wird fertiggestellt"))
    }

    func testADecisionWithANumberTheTodoLacksStays() {
        let input = summary(decisions: ["Preise um 5 % erhöhen"], todos: ["Person 1: Preise prüfen"])
        XCTAssertTrue(DecisionTodoFilter.filtered(input).contains("- Preise um 5 % erhöhen"))
    }

    func testADecisionThatSharesOnlyAWordStays() {
        let input = summary(decisions: ["Der Launch findet im März statt"], todos: ["Person 1: Launch vorbereiten"])
        XCTAssertTrue(DecisionTodoFilter.filtered(input).contains("- Der Launch findet im März statt"))
    }

    func testWithoutTodosNothingChanges() {
        let input = """
        Zusammenfassung
        Kurz.

        Entscheidungen
        - Raum buchen

        To-dos
        - Keine
        """
        XCTAssertEqual(DecisionTodoFilter.filtered(input), input)
    }

    func testItDoesNotChangeAnAlreadyCleanSummaryAndIsIdempotent() {
        let input = summary(decisions: ["Das Treffen ist am Donnerstag um zehn"], todos: ["Person 2: Raum buchen", "Person 1: Unterlagen schicken (bis morgen)"])
        XCTAssertEqual(DecisionTodoFilter.filtered(input), input)
        let first = DecisionTodoFilter.filtered(summary(decisions: ["Raum buchen"], todos: ["Person 2: Raum buchen"]))
        XCTAssertEqual(DecisionTodoFilter.filtered(first), first)
    }

    func testNoneInTheDecisionsStaysNone() {
        let input = summary(decisions: ["Keine"], todos: ["Person 1: Raum buchen"])
        XCTAssertEqual(DecisionTodoFilter.filtered(input), input)
    }
}
