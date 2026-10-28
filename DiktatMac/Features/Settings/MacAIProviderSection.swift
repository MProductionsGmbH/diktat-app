import SwiftUI

/// Optional provider for Schreibstil, WTF and :-), connected with the user's own API key.
struct MacAIProviderSection: View {
    @Bindable var appState: AppState

    @State private var keyInput = ""
    @State private var testState: TestState = .idle
    @State private var search: SearchState = .idle

    private enum SearchState: Equatable {
        case idle
        case searching
        case found([LocalServerDiscovery.Server])
        case none
    }

    private enum TestState: Equatable {
        case idle
        case testing
        case ok
        case failed(String)
    }

    var body: some View {
        SettingsSection(title: "Modell-Anbieter") {
            Text("Optional. Mit Apple Intelligence laufen die KI-Modi auf diesem Mac. Ein eigener API-Key hilft, wenn Apple Intelligence fehlt oder mehr Qualität gefragt ist.")
                .font(.ui(12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Anbieter", selection: providerBinding) {
                Text("Keiner, nur auf diesem Mac").tag(AIProvider?.none)
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.displayName).tag(AIProvider?.some(provider))
                }
            }
            .controlSize(.small)

            if let config = appState.aiProvider {
                providerFields(config)
            }
        }
    }

    @ViewBuilder
    private func providerFields(_ config: AIProviderConfig) -> some View {
        let provider = config.provider

        HStack(spacing: 8) {
            SecureField(maskedKey(provider) ?? (provider.requiresAPIKey ? "API-Key einfügen" : "API-Key (optional)"), text: $keyInput)
                .textFieldStyle(.roundedBorder)
                .font(.ui(11.5))
            Button("Sichern") { saveKey(provider) }
                .buttonStyle(SubtleButtonStyle())
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }

        HStack(spacing: 10) {
            if maskedKey(provider) != nil {
                Label("API-Key gespeichert", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(DiktatTheme.ready)
                Button("Entfernen") {
                    APIKeyStore.delete(for: provider)
                    appState.aiKeyRevision += 1
                    testState = .idle
                }
                .buttonStyle(.plain)
                .foregroundStyle(DiktatTheme.danger)
            }
            Spacer()
            if let url = provider.keyHelpURL {
                Link("Key erstellen", destination: url)
            }
        }
        .font(.ui(10.5, .medium))

        HStack(spacing: 8) {
            Text("Modell")
                .font(.ui(12))
                .foregroundStyle(.secondary)
            TextField(provider.defaultModel, text: modelBinding)
                .textFieldStyle(.roundedBorder)
                .font(.ui(11.5))
        }

        if provider == .custom {
            HStack(spacing: 8) {
                Text("Adresse")
                    .font(.ui(12))
                    .foregroundStyle(.secondary)
                TextField(provider.defaultBaseURL, text: baseURLBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(.ui(11.5))
            }
            Text("OpenAI-kompatible Adresse. Ollama l\u{00E4}uft auf jedem Mac unter derselben Adresse (localhost, Port 11434), LM Studio unter Port 1234. Nur wenn du das ge\u{00E4}ndert hast oder ein anderer Rechner das Modell liefert, brauchst du eine andere.")
                .font(.ui(12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            localSearch
        }

        HStack(spacing: 8) {
            Button("Verbindung testen") { test(config) }
                .buttonStyle(SubtleButtonStyle())
                .disabled(testState == .testing)
            switch testState {
            case .idle: EmptyView()
            case .testing: ProgressView().controlSize(.small)
            case .ok: Label("Funktioniert", systemImage: "checkmark.circle.fill").foregroundStyle(DiktatTheme.ready)
            case .failed: Image(systemName: "xmark.octagon.fill").foregroundStyle(DiktatTheme.danger)
            }
        }
        .font(.ui(10.5, .medium))

        if case .failed(let message) = testState {
            Text(message)
                .font(.ui(12))
                .foregroundStyle(DiktatTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }

        Label {
            Text(config.isOnThisMac
                 ? "Die Texte der KI-Modi gehen an das Modell auf diesem Mac, wenn Apple Intelligence nicht übernimmt. Sie verlassen den Mac nicht. Das Programm muss dazu laufen."
                 : "Ab jetzt gehen die Texte der KI-Modi an \(provider.displayName), wenn Apple Intelligence nicht übernimmt. Die Sprache selbst bleibt auf diesem Mac. Es gelten die Bedingungen und Kosten des Anbieters. Der Key liegt im Schlüsselbund dieses Macs.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "arrow.up.forward.circle.fill")
                .foregroundStyle(DiktatTheme.accent)
        }
        .font(.ui(12))
        .foregroundStyle(.secondary)
    }

    // MARK: - Search on this Mac

    @ViewBuilder
    private var localSearch: some View {
        HStack(spacing: 8) {
            Button("Auf diesem Mac suchen") { searchLocalServers() }
                .buttonStyle(SubtleButtonStyle())
                .disabled(search == .searching)
            if search == .searching { ProgressView().controlSize(.small) }
        }
        .font(.ui(10.5, .medium))

        switch search {
        case .idle, .searching:
            EmptyView()
        case .none:
            Text("Kein Ollama und kein LM Studio gefunden. Ist das Programm gestartet? Ollama l\u{00E4}dst du auf ollama.com.")
                .font(.ui(12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .found(let servers):
            ForEach(servers) { server in
                if server.models.isEmpty {
                    Text("\(server.name) l\u{00E4}uft, hat aber noch kein Modell. In \(server.name) ein Modell laden und erneut suchen.")
                        .font(.ui(12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 8) {
                        Text(server.name)
                            .font(.ui(12))
                            .foregroundStyle(.secondary)
                        Picker("", selection: Binding(
                            get: { appState.aiProvider?.baseURL == server.baseURL ? (appState.aiProvider?.model ?? "") : "" },
                            set: { use(server, model: $0) }
                        )) {
                            Text("Modell w\u{00E4}hlen").tag("")
                            ForEach(server.models, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func searchLocalServers() {
        search = .searching
        Task {
            let servers = await LocalServerDiscovery.discover()
            search = servers.isEmpty ? .none : .found(servers)
            // One server with models: its address is known, only the model is left to pick.
            if servers.count == 1, let server = servers.first, !server.models.isEmpty {
                appState.aiProvider?.baseURL = server.baseURL
            }
        }
    }

    private func use(_ server: LocalServerDiscovery.Server, model: String) {
        guard !model.isEmpty else { return }
        appState.aiProvider?.baseURL = server.baseURL
        appState.aiProvider?.model = model
        testState = .idle
    }

    // MARK: - Bindings

    private var providerBinding: Binding<AIProvider?> {
        Binding(
            get: { appState.aiProvider?.provider },
            set: { provider in
                keyInput = ""
                testState = .idle
                appState.aiProvider = provider.map { AIProviderConfig(provider: $0) }
            }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { appState.aiProvider?.model ?? "" },
            set: { appState.aiProvider?.model = $0.trimmingCharacters(in: .whitespaces) }
        )
    }

    private var baseURLBinding: Binding<String> {
        Binding(
            get: { appState.aiProvider?.baseURL ?? "" },
            set: { appState.aiProvider?.baseURL = $0.trimmingCharacters(in: .whitespaces) }
        )
    }

    // MARK: - Actions

    private func maskedKey(_ provider: AIProvider) -> String? {
        _ = appState.aiKeyRevision
        return APIKeyStore.maskedKey(for: provider)
    }

    private func saveKey(_ provider: AIProvider) {
        APIKeyStore.save(keyInput, for: provider)
        keyInput = ""
        appState.aiKeyRevision += 1
        testState = .idle
    }

    private func test(_ config: AIProviderConfig) {
        testState = .testing
        Task {
            do {
                try await AIClient.testConnection(config: config)
                testState = .ok
            } catch {
                testState = .failed(error.localizedDescription)
            }
        }
    }
}
