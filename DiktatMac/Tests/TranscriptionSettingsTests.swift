import XCTest

final class TranscriptionSettingsTests: XCTestCase {
    private func decode(_ json: String) throws -> TranscriptionSettings {
        try JSONDecoder().decode(TranscriptionSettings.self, from: Data(json.utf8))
    }

    func testNewSettingsFollowTheSpokenLanguage() {
        XCTAssertEqual(TranscriptionSettings().language, "auto")
    }

    func testSettingsSavedBeforeEnglishSupportBecomeAutomatic() throws {
        XCTAssertEqual(try decode(#"{"language":"de"}"#).language, "auto")
        XCTAssertEqual(try decode("{}").language, "auto")
    }

    func testAnotherStoredLanguageIsKept() throws {
        XCTAssertEqual(try decode(#"{"language":"en"}"#).language, "en")
    }
}
