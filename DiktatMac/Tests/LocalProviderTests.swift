import XCTest

final class LocalProviderTests: XCTestCase {
    func testOllamaAndLMStudioAddressesAreLocalServers() {
        XCTAssertTrue(AIProviderConfig(provider: .custom).isLocalServer)
        XCTAssertTrue(AIProviderConfig(provider: .custom, baseURL: "http://127.0.0.1:1234/v1").isLocalServer)
        XCTAssertTrue(AIProviderConfig(provider: .custom, baseURL: "http://studio.local:11434/v1").isLocalServer)
    }

    func testHostedProvidersAreNotLocalServers() {
        XCTAssertFalse(AIProviderConfig(provider: .openAI).isLocalServer)
        XCTAssertFalse(AIProviderConfig(provider: .custom, baseURL: "https://proxy.example.com/v1").isLocalServer)
    }

    func testStripsThinkingBlocksOfReasoningModels() {
        XCTAssertEqual(AIClient.strippingReasoning("<think>\nErst prüfen.\nDann kürzen.\n</think>\n\nWir treffen uns am Donnerstag."),
                       "Wir treffen uns am Donnerstag.")
        XCTAssertEqual(AIClient.strippingReasoning("Kein Denkblock hier."), "Kein Denkblock hier.")
        XCTAssertEqual(AIClient.strippingReasoning("<think>nur Gedanken</think>"), "")
    }

    func testThinkingIsSwitchedOffOnlyForQwen3OnALocalServer() {
        XCTAssertTrue(AIClient.switchesOffThinking(AIProviderConfig(provider: .custom, model: "qwen3.5:9b")))
        XCTAssertFalse(AIClient.switchesOffThinking(AIProviderConfig(provider: .custom, model: "llama3.2")))
        XCTAssertFalse(AIClient.switchesOffThinking(AIProviderConfig(provider: .openAI, model: "qwen3:8b")))
    }

    func testNoThinkSwitchOnlyForQwen3OnALocalServer() {
        let qwen = AIProviderConfig(provider: .custom, model: "qwen3:8b")
        XCTAssertTrue(AIClient.systemMessage("Anweisung", for: qwen).hasSuffix("/no_think"))
        XCTAssertEqual(AIClient.systemMessage("Anweisung", for: AIProviderConfig(provider: .custom, model: "llama3.2")), "Anweisung")
        let hosted = AIProviderConfig(provider: .custom, model: "qwen3:8b", baseURL: "https://proxy.example.com/v1")
        XCTAssertEqual(AIClient.systemMessage("Anweisung", for: hosted), "Anweisung")
    }

    func testOnlyLoopbackAddressesAreOnThisMac() {
        XCTAssertTrue(AIProviderConfig(provider: .custom).isOnThisMac)
        XCTAssertTrue(AIProviderConfig(provider: .custom, baseURL: "http://127.0.0.1:1234/v1").isOnThisMac)
        XCTAssertTrue(AIProviderConfig(provider: .custom, baseURL: "http://[::1]:11434/v1").isOnThisMac)
        // Another device in the home network is a local server, but not this Mac: no meetings.
        let studio = AIProviderConfig(provider: .custom, baseURL: "http://studio.local:11434/v1")
        XCTAssertTrue(studio.isLocalServer)
        XCTAssertFalse(studio.isOnThisMac)
        XCTAssertFalse(AIProviderConfig(provider: .custom, baseURL: "https://proxy.example.com/v1").isOnThisMac)
        XCTAssertFalse(AIProviderConfig(provider: .openAI, baseURL: "http://localhost:11434/v1").isOnThisMac)
    }
}
