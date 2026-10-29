import SwiftUI

/// "Lokales Sprachmodell für Meetings": a model server on this Mac (Ollama, LM Studio) and
/// the Gemma variants this Mac can run, how large they are, and download, cancel or remove.
struct LocalLanguageModelSection: View {
    @Bindable var appState: AppState
    private var store: LocalModelStore { .shared }
    private let memoryGB = LocalModelVariant.installedMemoryGB

    var body: some View {
        SettingsSection(title: String(localized: "Lokales Sprachmodell f\u{00FC}r Meetings"), isBeta: true) {
            Text("Optional. Meetings k\u{00F6}nnen auf diesem Mac genauer zusammengefasst werden als mit Apple Intelligence, vor allem lange. Der Text verl\u{00E4}sst den Mac nicht. W\u{00E4}hle ein Modell, das schon auf deinem Mac l\u{00E4}uft (Ollama, LM Studio), oder lade Gemma, ohne Zusatzprogramm.")
                .font(.ui(12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            serverRow
            Divider().opacity(0.5)

            ForEach(LocalModelVariant.all) { variant in
                row(variant)
                if variant != LocalModelVariant.all.last {
                    Divider().opacity(0.5)
                }
            }

            Text(footnote)
                .font(.ui(11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footnote: String {
        let mac = LocalModelVariant.isAppleSilicon
            ? String(localized: "Dieser Mac hat \(memoryGB) GB Arbeitsspeicher.")
            : String(localized: "Dieser Mac hat keinen Apple-Chip.")
        return mac + String(localized: " Ist Gemma geladen, nutzen Meetings es, wenn kein eigener Server gew\u{00E4}hlt ist. Gemma 4 von Google, Lizenz Apache 2.0.")
    }

    // MARK: - Model server on this Mac

    private var localServer: AIProviderConfig? {
        guard let config = appState.aiProvider, config.isLocalServer else { return nil }
        return config
    }

    private var usesServer: Bool {
        localServer != nil && appState.appSettings.rewriteEngine == .provider
    }

    private var serverRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Ollama oder LM Studio")
                    .font(.ui(12.5, .semibold))
                if usesServer { badge(String(localized: "Wird genutzt")) }
                Spacer(minLength: 8)
                serverAction
            }
            Text(serverDetails)
                .font(.ui(11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var serverDetails: String {
        guard let config = localServer else {
            return String(localized: "Ein Modell, das auf diesem Mac schon l\u{00E4}uft, zum Beispiel Qwen \u{00FC}ber Ollama. Kein zus\u{00E4}tzlicher Download. Adresse und Modellname tr\u{00E4}gst du unten unter Modell-Anbieter ein.")
        }
        let model = config.model.isEmpty ? config.provider.defaultModel : config.model
        if usesServer {
            return String(localized: "\(model) auf \(config.baseURL). Meetings, Gl\u{00E4}ttung und KI-Modi nutzen es. Der Text verl\u{00E4}sst den Mac nicht.")
        }
        return String(localized: "\(model) auf \(config.baseURL) ist eingerichtet. Meetings nutzen es erst, wenn bei KI-Modi \u{201E}Immer Modell-Anbieter\u{201C} steht.")
    }

    @ViewBuilder
    private var serverAction: some View {
        if localServer == nil {
            Button("Einrichten") { appState.aiProvider = AIProviderConfig(provider: .custom) }
                .controlSize(.small)
        } else if !usesServer {
            Button("Jetzt nutzen") { appState.appSettings.rewriteEngine = .provider }
                .controlSize(.small)
        }
    }

    private func row(_ variant: LocalModelVariant) -> some View {
        let support = variant.support()
        let state = store.state(of: variant)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(variant.name)
                    .font(.ui(12.5, .semibold))
                if store.preferredInstalled == variant {
                    badge(String(localized: "Wird genutzt"))
                } else if LocalModelVariant.recommended() == variant, state != .installed {
                    badge(String(localized: "Passt zu diesem Mac"))
                }
                Spacer(minLength: 8)
                action(variant, state: state, support: support)
            }

            Text(details(variant, support: support))
                .font(.ui(11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            switch state {
            case .downloading(let fraction):
                ProgressView(value: fraction)
                    .controlSize(.small)
                Text(String(localized: "\(Int(fraction * 100)) %. Du kannst Diktat weiter nutzen."))
                    .font(.ui(11))
                    .foregroundStyle(.secondary)
            case .failed(let message):
                Text(message)
                    .font(.ui(11.5))
                    .foregroundStyle(DiktatTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            default:
                EmptyView()
            }
        }
    }

    private func details(_ variant: LocalModelVariant, support: LocalModelVariant.Support) -> String {
        let size = String(localized: "Download \(LocalModelStore.gigabytes(variant.downloadSize))")
        let memory = String(format: "%.0f", variant.memoryInUse.rounded(.up))
        let needs = String(localized: "braucht beim Zusammenfassen etwa \(memory) GB Arbeitsspeicher, empfohlen ab \(variant.minimumMemoryGB) GB")
        switch support {
        case .available:
            return "\(variant.purpose). \(size), \(needs)."
        case .unavailable(let reason):
            return "\(variant.purpose). \(size). \(reason)"
        }
    }

    @ViewBuilder
    private func action(_ variant: LocalModelVariant, state: LocalModelStore.State, support: LocalModelVariant.Support) -> some View {
        switch state {
        case .notInstalled, .failed:
            Button(state == .notInstalled ? "Laden" : "Erneut laden") { store.download(variant) }
                .controlSize(.small)
                .disabled(support != .available)
        case .downloading:
            Button("Abbrechen") { store.cancel(variant) }
                .controlSize(.small)
        case .installed:
            Button("Entfernen", role: .destructive) { store.remove(variant) }
                .controlSize(.small)
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.ui(10.5, .semibold))
            .foregroundStyle(DiktatTheme.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(DiktatTheme.accent.opacity(0.12)))
    }
}
