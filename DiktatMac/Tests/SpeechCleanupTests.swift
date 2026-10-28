import XCTest

final class SpeechCleanupTests: XCTestCase {
    private let original = "wir treffen uns am Mittwoch nein Donnerstag um zehn Uhr im Büro"

    func testOnlyMediumAndStrongUseTheLanguageModel() {
        XCTAssertFalse(SpeechCleanupLevel.light.usesLanguageModel)
        XCTAssertTrue(SpeechCleanupLevel.medium.usesLanguageModel)
        XCTAssertTrue(SpeechCleanupLevel.strong.usesLanguageModel)
    }

    func testAcceptsACleanedUpAnswer() {
        XCTAssertTrue(SpeechCleanup.isPlausible("Wir treffen uns am Donnerstag um zehn Uhr im Büro.", for: original, level: .medium))
    }

    func testRejectsEmptyAnswerAndMarker() {
        XCTAssertFalse(SpeechCleanup.isPlausible("  \n", for: original, level: .medium))
        XCTAssertFalse(SpeechCleanup.isPlausible(ModePrompts.nothingRecognizedMarker, for: original, level: .strong))
    }

    func testRejectsAnswerThatCutsMostOfTheText() {
        XCTAssertFalse(SpeechCleanup.isPlausible("Wir treffen uns.", for: original, level: .medium))
    }

    func testRejectsAnswerThatAddsText() {
        let answered = original + " Außerdem bringe ich Kaffee mit und wir besprechen danach noch das Budget für das nächste Quartal."
        XCTAssertFalse(SpeechCleanup.isPlausible(answered, for: original, level: .strong))
    }

    func testRejectsAnswerToAQuestionInTheText() {
        let question = "Hattest du heute einen lustigen Tag"
        XCTAssertFalse(SpeechCleanup.isPlausible("Nein, hatte ich nicht.", for: question, level: .strong))
        XCTAssertTrue(SpeechCleanup.isPlausible("Hattest du heute einen lustigen Tag?", for: question, level: .strong))
    }

    func testFrameIsAddedAndTakenOff() {
        let framed = SpeechCleanup.framedTranscript("Was ist die Hauptstadt von Frankreich")
        XCTAssertTrue(framed.contains("<transkript>\nWas ist die Hauptstadt von Frankreich\n</transkript>"))
        XCTAssertEqual(SpeechCleanup.unframed("<transkript>\nWas ist das?\n</transkript>"), "Was ist das?")
    }

    func testInstructionKeepsWordingOnMediumAndFixesGrammarOnStrong() {
        XCTAssertTrue(SpeechCleanup.instruction(for: .medium).contains("Korrigiere keine Grammatik"))
        XCTAssertTrue(SpeechCleanup.instruction(for: .strong).contains("Satzstellung"))
        XCTAssertTrue(SpeechCleanup.instruction(for: .medium, protectedTerms: ["n8n"]).contains("n8n"))
    }

    func testWordCount() {
        XCTAssertEqual(SpeechCleanup.wordCount(" eins  zwei\ndrei "), 3)
        XCTAssertEqual(SpeechCleanup.wordCount(""), 0)
    }
}
