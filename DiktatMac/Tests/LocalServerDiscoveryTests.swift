import XCTest

final class LocalServerDiscoveryTests: XCTestCase {
    func testReadsOllamaModelsSortedAndWithoutEmbeddingModels() {
        let json = #"{"models":[{"name":"qwen3.5:9b"},{"name":"nomic-embed-text:latest"},{"name":"gemma4:12b"}]}"#
        XCTAssertEqual(LocalServerDiscovery.ollamaModels(from: Data(json.utf8)), ["gemma4:12b", "qwen3.5:9b"])
    }

    func testReadsLMStudioModels() {
        let json = #"{"object":"list","data":[{"id":"qwen3-8b"},{"id":"text-embedding-nomic"}]}"#
        XCTAssertEqual(LocalServerDiscovery.openAIModels(from: Data(json.utf8)), ["qwen3-8b"])
    }

    func testUnreadableAnswerGivesNoModels() {
        XCTAssertEqual(LocalServerDiscovery.ollamaModels(from: Data("<html>".utf8)), [])
        XCTAssertEqual(LocalServerDiscovery.openAIModels(from: Data("{}".utf8)), [])
    }
}
