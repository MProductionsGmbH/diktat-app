import SwiftUI

/// The tab "Meetings" in the settings: what a meeting records, what it needs from macOS, and
/// the speaker models. The meeting page itself holds the choices made per meeting.
struct MeetingSettingsPane: View {
    @Bindable var appState: AppState
    @AppStorage(MeetingSource.storageKey) private var storedSource = ""
    @AppStorage(MeetingSource.legacyStorageKey) private var legacySystemAudio = false
    @State private var permission = SystemAudioPermission.status
    @State private var speakerModels = SpeakerModels.State.current
    @State private var isLoadingSpeakerModels = false
    @State private var speakerModelError: String?

    private var source: Binding<MeetingSource> {
        Binding(
            get: {
                MeetingSource.resolve(
                    stored: storedSource,
                    legacySystemAudio: legacySystemAudio,
                    canRecordSystemAudio: MeetingController.canRecordSystemAudio
                )
            },
            set: { storedSource = $0.rawValue }
        )
    }

    var body: some View {
        SettingsSection(title: String(localized: "Meetings"), isBeta: true) {
            if MeetingController.canRecordSystemAudio {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Standardquelle")
                        .font(.ui(12))
                        .foregroundStyle(.secondary)
                    SegmentedToggle(options: MeetingSource.allCases, selection: source, label: { $0.title })
                    Text(source.wrappedValue.explanation)
                        .font(.ui(12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle(isOn: $appState.appSettings.summarizesMeetings) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nach dem Meeting zusammenfassen")
                        .font(.ui(11.5))
                    Text("Diktat schreibt nach dem Meeting eine Zusammenfassung mit Entscheidungen und To-dos. Ausgeschaltet bekommst du nur das Transkript mit den Personen, die Zusammenfassung kannst du sp\u{00E4}ter starten.")
                        .font(.ui(12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.trailingSwitch)

            if MeetingController.canRecordSystemAudio {
                Toggle(isOn: $appState.appSettings.suggestsMeetingOnCall) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bei Anrufen eine Aufnahme vorschlagen")
                            .font(.ui(11.5))
                        Text("\u{00D6}ffnet Teams, Zoom, Meet oder eine andere Anruf-App das Mikrofon, zeigt Diktat eine Mitteilung. Dazu sieht Diktat nur, welche Apps Ton nutzen, nie was gesprochen wird. Aufgenommen wird erst, wenn du es startest.")
                            .font(.ui(12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.trailingSwitch)
            }
        }

        if MeetingController.canRecordSystemAudio {
            SettingsSection(title: String(localized: "Ton des Macs")) {
                permissionContent
            }
        }

        SettingsSection(title: String(localized: "Sprecher-Erkennung")) {
            speakerContent
        }

        SettingsSection(title: String(localized: "Aufnahmen")) {
            Text("Transkript und Zusammenfassung bleiben verschl\u{00FC}sselt auf diesem Mac. Die Aufnahme selbst wird nach der Auswertung gel\u{00F6}scht. Bitte frag alle, bevor du aufnimmst.")
                .font(.ui(12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                appState.mainWindowPage = .meetings
                appState.onOpenMainWindow?(.meetings)
            } label: {
                Label("Meetings \u{00F6}ffnen", systemImage: "person.2.wave.2")
            }
            .buttonStyle(.subtle)
        }
    }

    // MARK: - System sound permission

    @ViewBuilder
    private var permissionContent: some View {
        Text("F\u{00FC}r Online-Meetings nimmt Diktat den Ton auf, den dein Mac abspielt, zum Beispiel die Stimmen aus Teams, Zoom oder Meet. Dazu braucht Diktat die Freigabe \u{201E}Systemaudio-Aufnahme\u{201C} von macOS.")
            .font(.ui(12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        switch permission {
        case .authorized:
            Label("Die Freigabe ist erteilt.", systemImage: "checkmark.circle.fill")
                .font(.ui(12, .medium))
                .foregroundStyle(DiktatTheme.ready)
        case .notDetermined:
            Label("macOS hat noch nicht gefragt. Das passiert beim ersten Meeting mit Ton des Macs.", systemImage: "questionmark.circle")
                .font(.ui(12, .medium))
                .foregroundStyle(.secondary)
            Button {
                SystemAudioPermission.request { _ in permission = SystemAudioPermission.status }
            } label: {
                Label("Jetzt freigeben", systemImage: "lock.open")
            }
            .buttonStyle(.subtle)
        case .denied:
            Label("Die Freigabe fehlt. Ohne sie kommt kein Ton an.", systemImage: "exclamationmark.triangle.fill")
                .font(.ui(12, .medium))
                .foregroundStyle(DiktatTheme.danger)
            Button {
                NSWorkspace.shared.open(SystemAudioPermission.settingsURL)
            } label: {
                Label("Einstellungen \u{00F6}ffnen", systemImage: "gearshape")
            }
            .buttonStyle(.subtle)
        case .unavailable:
            Text("Ob die Freigabe erteilt ist, l\u{00E4}sst sich nicht pr\u{00FC}fen. Fehlt sie, zeigt Diktat es nach dem Meeting.")
                .font(.ui(12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Speaker models

    @ViewBuilder
    private var speakerContent: some View {
        Text("Unterscheidet in Meetings die Stimmen (Person 1, Person 2 \u{2026}). Die Modelle sind rund 20\u{202F}MB gro\u{00DF} und laufen auf diesem Mac.")
            .font(.ui(12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 10) {
            switch speakerModels {
            case .installed:
                Label("Installiert", systemImage: "checkmark.circle.fill")
                    .font(.ui(12, .medium))
                    .foregroundStyle(DiktatTheme.ready)
            case .missing:
                Label("Nicht installiert", systemImage: "arrow.down.circle")
                    .font(.ui(12, .medium))
                    .foregroundStyle(.secondary)
                Button {
                    loadSpeakerModels()
                } label: {
                    Label(isLoadingSpeakerModels ? "Wird geladen \u{2026}" : "Jetzt laden", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.subtle)
                    .disabled(isLoadingSpeakerModels)
            }
        }

        if let speakerModelError {
            Text(speakerModelError)
                .font(.ui(12))
                .foregroundStyle(DiktatTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func loadSpeakerModels() {
        isLoadingSpeakerModels = true
        speakerModelError = nil
        Task {
            do {
                try await SpeakerDiarizer.shared.prepare()
            } catch {
                speakerModelError = String(localized: "Die Modelle lie\u{00DF}en sich nicht laden. Das geht nur mit Internet. (\(error.localizedDescription))")
            }
            speakerModels = SpeakerModels.State.current
            isLoadingSpeakerModels = false
        }
    }
}

enum SpeakerModels {
    enum State {
        case installed, missing

        /// The models are a folder of files; an empty or missing folder means they still have to load.
        static var current: State {
            let files = (try? FileManager.default.contentsOfDirectory(atPath: SpeakerDiarizer.modelsDirectoryURL.path)) ?? []
            return files.isEmpty ? .missing : .installed
        }
    }
}
