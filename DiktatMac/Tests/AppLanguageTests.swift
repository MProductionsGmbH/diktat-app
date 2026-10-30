import XCTest

final class AppLanguageTests: XCTestCase {
    private func freshDefaults() -> (UserDefaults, String) {
        let name = "app.diktat.tests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    func testNothingStoredFollowsTheSystem() {
        let (defaults, name) = freshDefaults()
        XCTAssertEqual(AppLanguage.stored(domain: name, defaults: defaults), .system)
    }

    func testStoredLanguageRoundTrips() {
        let (defaults, name) = freshDefaults()
        AppLanguage.english.store(defaults: defaults)
        XCTAssertEqual(AppLanguage.stored(domain: name, defaults: defaults), .english)
        AppLanguage.german.store(defaults: defaults)
        XCTAssertEqual(AppLanguage.stored(domain: name, defaults: defaults), .german)
        AppLanguage.system.store(defaults: defaults)
        XCTAssertEqual(AppLanguage.stored(domain: name, defaults: defaults), .system)
    }

    func testRegionalCodesCount() {
        let (defaults, name) = freshDefaults()
        defaults.set(["en-CH"], forKey: "AppleLanguages")
        XCTAssertEqual(AppLanguage.stored(domain: name, defaults: defaults), .english)
    }

    func testDictationLanguageIsIndependentAndAutomaticByDefault() {
        XCTAssertEqual(DictationLanguage(code: "auto"), .automatic)
        XCTAssertEqual(DictationLanguage(code: "de"), .german)
        XCTAssertEqual(DictationLanguage(code: "en"), .english)
        XCTAssertEqual(DictationLanguage(code: "fr"), .automatic)
        XCTAssertEqual(DictationLanguage.allCases.map(\.code), ["auto", "de", "en"])
        XCTAssertEqual(TranscriptionSettings().language, DictationLanguage.automatic.code)
    }

    func testRestartIsDueOnlyWhenTheShownLanguageDiffers() {
        XCTAssertFalse(AppLanguage.english.needsRestart(runningCode: "en", systemCodes: ["de-CH"]))
        XCTAssertTrue(AppLanguage.english.needsRestart(runningCode: "de", systemCodes: ["de-CH"]))
        XCTAssertTrue(AppLanguage.german.needsRestart(runningCode: "en", systemCodes: ["en-US"]))
        // Automatic: follows the system, and any language but English falls back to German.
        XCTAssertFalse(AppLanguage.system.needsRestart(runningCode: "de", systemCodes: ["fr-FR"]))
        XCTAssertTrue(AppLanguage.system.needsRestart(runningCode: "de", systemCodes: ["en-US"]))
    }

    func testAForcedDictationLanguageWinsOverTheDetectedOne() {
        XCTAssertEqual(PromptLanguage.resolve(setting: "en", text: "Das ist ein deutscher Satz mit genug Wörtern."), .english)
        XCTAssertEqual(PromptLanguage.resolve(setting: "de", text: "This is an English sentence with enough words."), .german)
        XCTAssertEqual(PromptLanguage.resolve(setting: "auto", text: "This is an English sentence with enough words."), .english)
        XCTAssertEqual(PromptLanguage.resolve(setting: "auto", text: ""), .german)
    }
}
