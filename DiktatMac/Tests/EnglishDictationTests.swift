import XCTest

final class EnglishDictationTests: XCTestCase {
    func testLanguageFollowsWhatWasSpoken() {
        XCTAssertEqual(PromptLanguage.detect(from: "I wanted to say that the meeting tomorrow starts at ten o'clock."), .english)
        XCTAssertEqual(PromptLanguage.detect(from: "Ich wollte noch sagen, dass das Meeting morgen um zehn Uhr beginnt."), .german)
    }

    func testTooLittleTextCountsAsGerman() {
        XCTAssertEqual(PromptLanguage.detect(from: ""), .german)
    }

    func testEnglishCleanupInstructionIsEnglishAndAnswersInTheTranscriptLanguage() {
        for level in SpeechCleanupLevel.allCases where level.usesLanguageModel {
            let text = SpeechCleanup.instruction(for: level, protectedTerms: ["n8n"], language: .english)
            XCTAssertTrue(text.contains("Reply in the language of the transcript"), "\(level)")
            XCTAssertTrue(text.contains("n8n"), "\(level)")
            XCTAssertFalse(text.contains("Du "), "\(level)")
        }
    }

    func testGermanCleanupInstructionIsUnchangedByDefault() {
        XCTAssertEqual(
            SpeechCleanup.instruction(for: .medium),
            SpeechCleanup.instruction(for: .medium, language: .german)
        )
        XCTAssertTrue(SpeechCleanup.instruction(for: .medium).contains("Du bereinigst"))
    }

    func testEnglishFrameIsTakenOffAgain() {
        let framed = SpeechCleanup.framedTranscript("hello there", language: .english)
        XCTAssertTrue(framed.contains("<transcript>"))
        XCTAssertEqual(SpeechCleanup.unframed(framed.components(separatedBy: "\n").dropFirst().joined(separator: "\n")), "hello there")
        XCTAssertEqual(SpeechCleanup.unframed("<transkript>hallo</transkript>"), "hallo")
    }

    func testEnglishModePromptsKeepTheSafetyRules() {
        let improvement = ModePrompts.textImprovement(TextImprovementSettings(), language: .english)
        XCTAssertTrue(improvement.contains("editor and writing assistant"))
        XCTAssertTrue(improvement.contains("not a message to you"))
        XCTAssertTrue(ModePrompts.emoji(EmojiTextSettings(), language: .english).contains("emojis"))
        XCTAssertTrue(ModePrompts.spokenTranscriptRules(for: .english).contains("corrects themselves"))
    }

    func testBuiltInVentPromptHasAnEnglishVersionButAnEditedOneStaysAsWritten() {
        var settings = DampfAblassenSettings()
        XCTAssertTrue(ModePrompts.dampfAblassen(settings, language: .english).contains("emotionally spoken transcript"))
        settings.systemPrompt = "Schreibe es freundlich."
        XCTAssertTrue(ModePrompts.dampfAblassen(settings, language: .english).hasPrefix("Schreibe es freundlich."))
    }

    func testToneIsKeptInTheEnglishRewrite() {
        var settings = TextImprovementSettings()
        settings.tone = .casual
        XCTAssertTrue(ModePrompts.textImprovement(settings, language: .english).contains("casual, natural tone"))
    }

    func testEnglishFillerWordsGoWhenTheLanguageIsDetected() {
        let processor = TranscriptPostProcessor(correctCustomTerms: false, removeFillerWords: true)
        XCTAssertEqual(processor.process("So um I think we should uh meet on Friday afternoon."), "So I think we should meet on Friday afternoon.")
    }

    func testGermanUmStaysAWord() {
        let processor = TranscriptPostProcessor(correctCustomTerms: false, removeFillerWords: true)
        XCTAssertEqual(processor.process("Wir treffen uns um zehn Uhr im Büro, äh, in der Zentrale."), "Wir treffen uns um zehn Uhr im Büro, in der Zentrale.")
    }
}

final class EnglishFrameTests: XCTestCase {
    func testStyleLevelAsksForARewriteNotACleanup() {
        // Apple Intelligence copied the text when the frame said "clean up" and the level had to rewrite.
        let style = SpeechCleanup.framedTranscript("hey alex", language: .english, level: .style)
        let medium = SpeechCleanup.framedTranscript("hey alex", language: .english, level: .medium)
        XCTAssertTrue(style.hasPrefix("Rewrite this transcript"))
        XCTAssertTrue(medium.hasPrefix("Clean up this transcript"))
    }
}
