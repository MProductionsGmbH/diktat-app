import XCTest

final class PrivacyTests: XCTestCase {
    // MARK: Recordings without a meeting

    func testOnlyRecordingsOfUnknownMeetingsAreOrphans() {
        let kept = UUID()
        let gone = UUID()
        let names = [
            "\(kept.uuidString).wav", "\(kept.uuidString)-system.caf",
            "\(gone.uuidString).wav", "\(gone.uuidString)-system.caf",
            ".meetings", ".meetings.unreadable-1700000000", "notes.wav", "export.caf",
        ]
        XCTAssertEqual(
            Set(MeetingAudioFiles.orphaned(in: names, keeping: [kept])),
            ["\(gone.uuidString).wav", "\(gone.uuidString)-system.caf"]
        )
    }

    func testNothingIsAnOrphanWhileItsMeetingExists() {
        let id = UUID()
        XCTAssertEqual(MeetingAudioFiles.orphaned(in: ["\(id.uuidString).wav"], keeping: [id]), [])
    }

    // MARK: The key of "Eigene Adresse" belongs to one server

    private func custom(_ address: String) -> AIProviderConfig {
        AIProviderConfig(provider: .custom, baseURL: address)
    }

    func testAnotherHostIsAnotherServer() {
        XCTAssertTrue(custom("https://b.example.com/v1").movesCustomServer(from: custom("https://a.example.com/v1")))
        XCTAssertTrue(custom("http://localhost:11434/v1").movesCustomServer(from: custom("https://gateway.example.com/v1")))
    }

    func testAnotherPortOrSchemeIsAnotherServer() {
        XCTAssertTrue(custom("http://localhost:1234/v1").movesCustomServer(from: custom("http://localhost:11434/v1")))
        XCTAssertTrue(custom("http://gateway.example.com/v1").movesCustomServer(from: custom("https://gateway.example.com/v1")))
    }

    func testAnEditedPathKeepsTheServer() {
        XCTAssertFalse(custom("https://gateway.example.com/api/v1").movesCustomServer(from: custom("https://gateway.example.com/v1")))
        XCTAssertFalse(custom("https://Gateway.Example.com/v1").movesCustomServer(from: custom("https://gateway.example.com/v1")))
    }

    func testNamedProvidersNeverMove() {
        let openAI = AIProviderConfig(provider: .openAI)
        XCTAssertFalse(openAI.movesCustomServer(from: custom("https://gateway.example.com/v1")))
        XCTAssertFalse(custom("https://gateway.example.com/v1").movesCustomServer(from: openAI))
        XCTAssertFalse(custom("https://gateway.example.com/v1").movesCustomServer(from: nil))
    }

    /// "Der Text verlässt den Mac nicht" may only be said for this Mac itself.
    func testALocalNameIsNotThisMac() {
        XCTAssertTrue(custom("http://localhost:11434/v1").isOnThisMac)
        XCTAssertTrue(custom("http://127.0.0.1:1234/v1").isOnThisMac)
        XCTAssertFalse(custom("http://mac-studio.local:11434/v1").isOnThisMac)
        XCTAssertTrue(custom("http://mac-studio.local:11434/v1").isLocalServer)
    }
}
