import Foundation

/// Finds a model server on this Mac, so nobody has to type an address: Ollama answers on port
/// 11434 and LM Studio on 1234, on every Mac that runs them with the default settings.
enum LocalServerDiscovery {
    struct Server: Equatable, Identifiable {
        let name: String
        /// The OpenAI-compatible base URL the app talks to.
        let baseURL: String
        let models: [String]

        var id: String { baseURL }
    }

    static let ollamaBaseURL = "http://localhost:11434/v1"
    static let lmStudioBaseURL = "http://localhost:1234/v1"

    /// Names from Ollama's `/api/tags`. Models that only create embeddings cannot write text.
    static func ollamaModels(from data: Data) -> [String] {
        struct Tags: Decodable {
            struct Model: Decodable { let name: String }
            let models: [Model]
        }
        guard let tags = try? JSONDecoder().decode(Tags.self, from: data) else { return [] }
        return writingModels(tags.models.map(\.name))
    }

    /// Ids from an OpenAI-style `/v1/models` list, which LM Studio serves.
    static func openAIModels(from data: Data) -> [String] {
        struct List: Decodable {
            struct Model: Decodable { let id: String }
            let data: [Model]
        }
        guard let list = try? JSONDecoder().decode(List.self, from: data) else { return [] }
        return writingModels(list.data.map(\.id))
    }

    private static func writingModels(_ names: [String]) -> [String] {
        names
            .filter { !$0.lowercased().contains("embed") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Asks both servers at once. A server that does not answer within two seconds is not there.
    static func discover() async -> [Server] {
        async let ollama = fetch("http://localhost:11434/api/tags")
        async let lmStudio = fetch("http://localhost:1234/v1/models")
        var servers: [Server] = []
        if let data = await ollama {
            servers.append(Server(name: "Ollama", baseURL: ollamaBaseURL, models: ollamaModels(from: data)))
        }
        if let data = await lmStudio {
            servers.append(Server(name: "LM Studio", baseURL: lmStudioBaseURL, models: openAIModels(from: data)))
        }
        return servers
    }

    private static func fetch(_ address: String) async -> Data? {
        guard let url = URL(string: address) else { return nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        let session = URLSession(configuration: configuration)
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }
}
