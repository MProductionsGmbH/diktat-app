import XCTest

final class StyleContextTests: XCTestCase {
    func testKnownAppsFallIntoTheirContext() {
        XCTAssertEqual(StyleContext.context(bundleID: "net.whatsapp.WhatsApp", host: nil), .personal)
        XCTAssertEqual(StyleContext.context(bundleID: "com.tinyspeck.slackmacgap", host: nil), .work)
        XCTAssertEqual(StyleContext.context(bundleID: "com.apple.mail", host: nil), .email)
        XCTAssertEqual(StyleContext.context(bundleID: "com.apple.TextEdit", host: nil), .other)
        XCTAssertEqual(StyleContext.context(bundleID: nil, host: nil), .other)
    }

    func testWebsiteInABrowserWinsOverTheBrowser() {
        XCTAssertEqual(StyleContext.context(bundleID: "com.google.Chrome", host: "mail.google.com"), .email)
        XCTAssertEqual(StyleContext.context(bundleID: "com.apple.Safari", host: "app.slack.com"), .work)
        XCTAssertEqual(StyleContext.context(bundleID: "com.google.Chrome", host: "example.com"), .other)
    }

    func testHostMatchesSubdomainsButNotLookalikes() {
        XCTAssertEqual(StyleContext.context(bundleID: nil, host: "eu.linkedin.com"), .work)
        XCTAssertEqual(StyleContext.context(bundleID: nil, host: "notlinkedin.com"), .other)
    }

    func testDefaultTonesAndOverrides() {
        var settings = StyleSettings()
        XCTAssertEqual(settings.tone(for: .email), .formal)
        XCTAssertEqual(settings.tone(for: .personal), .casual)
        settings.setTone(.formal, for: .personal)
        XCTAssertEqual(settings.tone(for: .personal), .formal)
        XCTAssertEqual(settings.tone(for: .email), .formal)
    }

    func testSettingsSurviveEncoding() throws {
        var settings = StyleSettings()
        settings.setTone(.casual, for: .work)
        let decoded = try JSONDecoder().decode(StyleSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.tone(for: .work), .casual)
    }

    func testToneExamplesShowWhatEachToneChanges() {
        XCTAssertTrue(StyleTone.formal.exampleCleaned.hasSuffix("Termin."))
        XCTAssertTrue(StyleTone.casual.exampleCleaned.hasSuffix("Termin"))
        XCTAssertNotEqual(StyleTone.formal.exampleRewritten, StyleTone.casual.exampleRewritten)
        XCTAssertNotEqual(StyleTone.formal.exampleRewritten, StyleTone.neutral.exampleRewritten)
        XCTAssertFalse(StyleTone.casual.exampleRewritten.hasSuffix("."))
    }

    func testCasualToneDropsOnlyTheFinalPeriod() {
        XCTAssertEqual(StyleTone.casual.apply(to: "Bis morgen. Ich freue mich."), "Bis morgen. Ich freue mich")
        XCTAssertEqual(StyleTone.casual.apply(to: "Kommst du morgen?"), "Kommst du morgen?")
        XCTAssertEqual(StyleTone.casual.apply(to: "Wir sehen uns..."), "Wir sehen uns...")
        XCTAssertEqual(StyleTone.formal.apply(to: "Bis morgen."), "Bis morgen.")
        XCTAssertEqual(StyleTone.neutral.apply(to: "Bis morgen."), "Bis morgen.")
    }
}
