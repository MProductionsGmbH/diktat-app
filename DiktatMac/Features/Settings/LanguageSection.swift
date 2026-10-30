import AppKit
import SwiftUI

/// "Sprache": the language of the app and, separately, the language dictation listens for.
/// The interface changes after a restart of the app, which the button does. Dictation stays on
/// automatic detection unless a language is picked.
struct LanguageSection: View {
    @Bindable var appState: AppState
    @State private var interface: AppLanguage = AppLanguage.stored()

    private var interfaceSelection: Binding<AppLanguage> {
        Binding(
            get: { interface },
            set: { language in
                interface = language
                language.store()
            }
        )
    }

    private var dictationSelection: Binding<DictationLanguage> {
        Binding(
            get: { DictationLanguage(code: appState.transcriptionSettings.language) },
            set: { appState.transcriptionSettings.language = $0.code }
        )
    }

    var body: some View {
        SettingsSection(title: String(localized: "Sprache")) {
            caption(String(localized: "Sprache der App"))
            SegmentedToggle(options: AppLanguage.allCases, selection: interfaceSelection, label: { $0.displayName })
            Text("Automatisch: Die App folgt macOS.")
                .font(.ui(11.5))
                .foregroundStyle(.secondary)

            if interface.needsRestart() {
                HStack(spacing: 10) {
                    Text("Die Sprache der App ändert sich nach einem Neustart.")
                        .font(.ui(12))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Jetzt neu starten") { Self.relaunch() }
                        .buttonStyle(.filledAction)
                }
            }

            caption(String(localized: "Diktiersprache"))
                .padding(.top, 4)
            SegmentedToggle(options: DictationLanguage.allCases, selection: dictationSelection, label: { $0.displayName })
            switch DictationLanguage(code: appState.transcriptionSettings.language) {
            case .automatic:
                note(String(localized: "Diktat erkennt bei jedem Diktat selbst, ob du Deutsch oder Englisch sprichst. Wähle eine Sprache, wenn es bei kurzen Sätzen danebenliegt."))
            case .german:
                note(String(localized: "Diktat hört nur auf Deutsch. Sprichst du Englisch, wird daraus deutscher Text."))
            case .english:
                note(String(localized: "Diktat hört nur auf Englisch. Sprichst du Deutsch, wird daraus englischer Text."))
            }
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.ui(12, .semibold))
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.ui(11.5))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Starts a new copy of the app and quits this one, so the stored language applies.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
