import SwiftUI

/// Popover page for meetings in the room: start with consent, record, evaluate, then read
/// the result with people, summary and transcript. Earlier meetings are listed on the start.
struct MeetingView: View {
    @Bindable var appState: AppState
    /// The popover height; snapshots render the whole page.
    var height: CGFloat = 560
    /// In the main window: no back header, and the height is the window's.
    var embedded = false
    /// For snapshots: shows the rename editor of this person without a click.
    var previewRenaming: Int?

    @State private var renaming: Int?
    private var renamedSpeaker: Int? { renaming ?? previewRenaming }
    @State private var newName = ""
    /// The tick "Stimme für künftige Meetings merken" of the person being renamed.
    @State private var rememberVoice = true
    @FocusState private var nameFieldFocused: Bool
    @State private var isResummarizing = false
    @State private var copied: CopyTarget?
    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    /// A meeting in the list, or the failed one, about to be deleted.
    @State private var deleting: UUID?
    @State private var renamingTitle = false
    @State private var newTitle = ""
    @AppStorage(MeetingSource.storageKey) private var storedSource = ""
    @AppStorage(MeetingSource.legacyStorageKey) private var legacySystemAudio = false
    @State private var permission = SystemAudioPermission.status
    @State private var soundTest = SystemSoundTest()
    @AppStorage("DiktatMeetingLiveNotes") private var wantsLiveNotes = true
    @State private var copiedChatNote = false

    private enum CopyTarget { case summary, transcript, everything }

    private var meeting: MeetingController { appState.meeting }

    /// The Diktat accents, one per person.
    private static let personColors: [Color] = [
        DiktatColor.Source.day.primary, DiktatColor.Source.night.primary, DiktatColor.Source.evening.primary,
        DiktatColor.dynamic(light: 0x0B0EC1, dark: 0xB7F1F9), DiktatColor.dynamic(light: 0x5F287B, dark: 0xBB84DF),
        DiktatColor.dynamic(light: 0x3C277C, dark: 0xA592DD),
    ]

    var body: some View {
        VStack(spacing: 0) {
            if !embedded {
                PageHeader(title: "Meeting", onBack: {
                    // From a meeting back to the list of meetings, from the list back to the menu.
                    if showsMeeting {
                        meeting.close()
                    } else {
                        appState.page = .main
                    }
                })

                Divider().opacity(0.16)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let notice = meeting.notice, !isIdle {
                        NoticeRow(icon: "info.circle.fill", title: notice)
                    }

                    switch meeting.phase {
                    case .idle:
                        start
                    case .recording(let startedAt):
                        recording(since: startedAt)
                    case .processing(let step):
                        processing(step)
                    case .showing(let id):
                        if let record = meeting.store.meeting(id: id) {
                            result(record)
                        } else {
                            start
                        }
                    case .failed(let message, let id):
                        failure(message, meetingID: id)
                    }
                }
                .padding(16)
            }
        }
        .frame(height: embedded ? nil : height)
        .onAppear { permission = SystemAudioPermission.status }
        .onDisappear { soundTest.stop() }
        // Back from the system settings, where the permission may have been given.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permission = SystemAudioPermission.status
        }
    }

    private var isIdle: Bool {
        if case .idle = meeting.phase { return true }
        return false
    }

    /// One meeting (or its failure) is open, so "back" leads to the list of meetings.
    private var showsMeeting: Bool {
        switch meeting.phase {
        case .showing, .failed: return true
        case .idle, .recording, .processing: return false
        }
    }

    // MARK: - Start

    private var start: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Meeting aufnehmen", systemImage: "person.2.wave.2.fill")
                    .font(.ui(15, .semibold))
                    .foregroundStyle(DiktatTheme.accent)
                Text("Diktat nimmt ein Meeting auf, im Raum oder online, erkennt, wer spricht, und schreibt auf Wunsch eine Zusammenfassung mit To-dos. Alles l\u{00E4}uft auf diesem Mac, die Aufnahme wird nach der Auswertung gel\u{00F6}scht.")
                    .font(.ui(12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPanel()

            NoticeRow(
                icon: "hand.raised.fill",
                title: String(localized: "Bitte vorher alle Anwesenden informieren und um ihr Einverst\u{00E4}ndnis bitten."),
                tint: DiktatTheme.danger
            )

            if MeetingController.canRecordSystemAudio {
                sourcePicker
            }

            Toggle(isOn: $wantsLiveNotes) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Live-Notizen")
                            .font(.ui(12.5, .medium))
                        BetaBadge()
                    }
                    Text(LiveNotesController.isAvailable
                         ? "Während des Meetings erscheinen laufend Notizen mit Themen, Entscheidungen und To-dos. Diktat aktualisiert sie alle zweieinhalb Minuten aus dem, was gesagt wurde. Alles bleibt auf diesem Mac."
                         : "Brauchen Apple Intelligence, ein lokales Sprachmodell (Einstellungen, Modelle) oder ein Modell auf diesem Mac, etwa Ollama.")
                        .font(.ui(11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.trailingSwitch)
            .disabled(!LiveNotesController.isAvailable)
            .padding(14)
            .glassPanel()

            Toggle(isOn: $appState.appSettings.summarizesMeetings) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nach dem Meeting zusammenfassen")
                        .font(.ui(12.5, .medium))
                    Group {
                        if appState.appSettings.summarizesMeetings {
                            Text("Diktat schreibt nach dem Meeting eine Zusammenfassung mit Entscheidungen und To-dos. Das dauert etwas l\u{00E4}nger.")
                        } else {
                            Text("Du bekommst nur das Transkript mit den Personen, das geht schneller. Die Zusammenfassung kannst du sp\u{00E4}ter starten.")
                        }
                    }
                        .font(.ui(11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.trailingSwitch)
            .padding(14)
            .glassPanel()

            if let blocker = MeetingController.blocker {
                NoticeRow(
                    icon: "exclamationmark.triangle.fill",
                    title: blocker,
                    tint: DiktatTheme.danger,
                    actionTitle: ParakeetTranscriber.isSupported ? String(localized: "Einstellungen") : nil,
                    action: ParakeetTranscriber.isSupported ? {
                        // The window has its own pages; `page` is the popover's.
                        if embedded {
                            appState.mainWindowPage = .settings
                        } else {
                            appState.page = .settings
                        }
                    } : nil
                )
            }

            Button {
                startMeeting()
            } label: {
                Text("Alle sind einverstanden, starten")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.filledAction)
            .disabled(MeetingController.blocker != nil || (source.usesSystemAudio && permission == .denied))

            Text(source.explanation)
                .font(.ui(11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            if !storedMeetings.isEmpty {
                earlierMeetings
            }
        }
    }

    private var recordingTitle: String {
        if meeting.pausedAt != nil { return String(localized: "Pausiert, nichts wird aufgenommen") }
        return meeting.isRecordingSystemAudio ? String(localized: "Aufnahme l\u{00E4}uft, mit System-Audio") : String(localized: "Aufnahme l\u{00E4}uft")
    }

    private var source: MeetingSource {
        get {
            MeetingSource.resolve(
                stored: storedSource,
                legacySystemAudio: legacySystemAudio,
                canRecordSystemAudio: MeetingController.canRecordSystemAudio
            )
        }
        nonmutating set { storedSource = newValue.rawValue }
    }

    /// A refused permission for the Mac's sound shows up before the meeting and not after it.
    private func startMeeting() {
        soundTest.stop()
        let chosen = source
        guard chosen.usesSystemAudio else {
            meeting.start(source: chosen, liveNotes: wantsLiveNotes)
            return
        }
        permission = SystemAudioPermission.status
        // Only a refusal stops the start. Not asked yet: starting the recording makes macOS ask,
        // as it always did, and a refusal then shows after the meeting.
        guard permission != .denied else { return }
        meeting.start(source: chosen, liveNotes: wantsLiveNotes)
    }

    /// Asked in the call's chat before starting, so everyone can agree in writing.
    static let chatNote = String(localized: "Ich w\u{00FC}rde dieses Meeting gern mit Diktat aufnehmen und auf meinem Mac transkribieren und zusammenfassen lassen. Ton und Text bleiben auf meinem Mac, die Aufnahme wird nach der Auswertung gel\u{00F6}scht. Ist das f\u{00FC}r alle in Ordnung?")

    /// Two sources side by side, then what the chosen one needs: for an online meeting the switch
    /// for the own microphone, the macOS permission, a test of the sound and the question for the chat.
    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Quelle")
                    .font(.ui(12.5, .medium))
                BetaBadge()
            }

            HStack(spacing: 8) {
                ForEach(MeetingSource.cards) { option in
                    sourceCard(option)
                }
            }

            if source.usesSystemAudio {
                Toggle(isOn: Binding(
                    get: { source.usesMicrophone },
                    set: { source = .online(withMicrophone: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mein Mikrofon mit aufnehmen")
                            .font(.ui(12.5, .medium))
                        Text(source.usesMicrophone
                             ? "Das System-Audio enth\u{00E4}lt nur die anderen. Dein Mikrofon bringt dazu, was du selbst sagst."
                             : "Ausgeschaltet fehlt im Transkript, was du selbst sagst. Gedacht f\u{00FC}r Webinare und Videos.")
                            .font(.ui(11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.trailingSwitch)

                permissionRow
                soundTestRow
            }

            if source == .online {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Self.chatNote, forType: .string)
                    copiedChatNote = true
                } label: {
                    Label(copiedChatNote ? "Kopiert, im Chat einf\u{00FC}gen" : "Frage f\u{00FC}r den Chat kopieren", systemImage: copiedChatNote ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.subtle)
            }
        }
        .padding(14)
        .glassPanel()
    }

    private func sourceCard(_ option: MeetingSource) -> some View {
        let isSelected = source.card == option
        return Button {
            soundTest.stop()
            // The online card keeps the choice of its microphone switch.
            if source.card != option { source = option }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.ui(17, .semibold))
                    .frame(height: 22)
                Text(option.title)
                    .font(.ui(12, .semibold))
                    .multilineTextAlignment(.center)
                Text(isSelected ? source.subtitle : option.subtitle)
                    .font(.ui(10.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? DiktatTheme.onTonal : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? DiktatTheme.accent.opacity(0.14) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? DiktatTheme.accent : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.title), \(isSelected ? source.subtitle : option.subtitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var permissionRow: some View {
        switch permission {
        case .authorized:
            Label("Freigabe f\u{00FC}r das System-Audio ist erteilt.", systemImage: "checkmark.circle.fill")
                .font(.ui(11.5))
                .foregroundStyle(DiktatTheme.ready)
        case .notDetermined:
            VStack(alignment: .leading, spacing: 6) {
                Text("macOS fragt einmal nach der Freigabe f\u{00FC}r das System-Audio. Ohne sie kommt kein Ton an.")
                    .font(.ui(11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    SystemAudioPermission.request { _ in permission = SystemAudioPermission.status }
                } label: {
                    Label("Jetzt freigeben", systemImage: "lock.open")
                }
                .buttonStyle(.subtle)
            }
        case .denied:
            NoticeRow(
                icon: "exclamationmark.triangle.fill",
                title: String(localized: "Die Freigabe f\u{00FC}r das System-Audio fehlt. Erlaube Diktat unter Datenschutz & Sicherheit > Bildschirm- und Systemaudioaufnahme."),
                tint: DiktatTheme.danger,
                actionTitle: String(localized: "Einstellungen \u{00F6}ffnen"),
                action: { NSWorkspace.shared.open(SystemAudioPermission.settingsURL) }
            )
        case .unavailable:
            EmptyView()
        }
    }

    private var soundTestRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    if soundTest.isRunning {
                        soundTest.stop()
                    } else {
                        soundTest.start()
                        permission = SystemAudioPermission.status
                    }
                } label: {
                    Label(soundTest.isRunning ? "Test beenden" : "Ton testen", systemImage: soundTest.isRunning ? "stop.fill" : "waveform")
                }
                .buttonStyle(.subtle)
                .disabled(permission == .denied)

                if soundTest.isRunning {
                    LevelBar(level: soundTest.level)
                        .frame(height: 6)
                        .accessibilityLabel("Pegel des Tons vom Mac")
                }
            }
            if soundTest.isRunning {
                Text(soundTest.isHearingSound
                     ? "Das System-Audio kommt an."
                     : "Noch kein Ton. Spiel etwas ab, zum Beispiel das Meeting oder ein Video.")
                    .font(.ui(11))
                    .foregroundStyle(soundTest.isHearingSound ? DiktatTheme.ready : Color.secondary)
            } else if let problem = soundTest.problem {
                Text(problem)
                    .font(.ui(11))
                    .foregroundStyle(DiktatTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Pr\u{00FC}ft, ob das System-Audio bei Diktat ankommt. Spiel dazu etwas ab, zum Beispiel das Meeting. Es wird nichts aufgenommen.")
                    .font(.ui(11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var storedMeetings: [MeetingRecord] {
        meeting.store.meetings.filter { $0.id != meeting.recordingID }
    }

    private var earlierMeetings: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: String(localized: "Meetings"))
            VStack(spacing: 0) {
                ForEach(Array(storedMeetings.enumerated()), id: \.element.id) { index, record in
                    if index > 0 {
                        Divider().opacity(0.5).padding(.horizontal, 12)
                    }
                    Button {
                        if record.status == .done {
                            meeting.show(record.id)
                        } else {
                            meeting.process(record.id)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.title)
                                    .font(.ui(12.5, .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(record.status == .done ? summaryLine(record) : String(localized: "Noch nicht ausgewertet, die Aufnahme liegt auf diesem Mac. Klicken zum Auswerten."))
                                    .font(.ui(11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.ui(10, .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .trailing) {
                        // Visible, so nobody has to know about the right click.
                        Button {
                            deleting = record.id
                        } label: {
                            Image(systemName: "trash")
                                .font(.ui(11, .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 26, height: 26)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Meeting l\u{00F6}schen")
                        .accessibilityLabel(String(localized: "\(record.title) l\u{00F6}schen"))
                        .padding(.trailing, 30)
                    }
                    .contextMenu {
                        Button("L\u{00F6}schen", role: .destructive) { deleting = record.id }
                    }
                }
            }
            .padding(.vertical, 2)
            .glassPanel()
        }
        .confirmationDialog(
            "Meeting l\u{00F6}schen?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("L\u{00F6}schen", role: .destructive) {
                if let deleting { meeting.delete(deleting) }
                deleting = nil
            }
            Button("Abbrechen", role: .cancel) { deleting = nil }
        } message: {
            Text("Transkript, Zusammenfassung und eine noch nicht ausgewertete Aufnahme werden gel\u{00F6}scht.")
        }
    }

    // MARK: - Recording and processing

    private func recording(since startedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let problem = meeting.problem {
                ProblemBanner(problem: problem)
            }

            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(meeting.pausedAt == nil ? DiktatTheme.danger : Color.secondary)
                        .frame(width: 9, height: 9)
                    Text(recordingTitle)
                        .font(.ui(13, .semibold))
                    Spacer()
                    if let pausedAt = meeting.pausedAt {
                        Text(Self.clock(pausedAt.timeIntervalSince(startedAt)))
                            .font(.ui(13, .semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        TimelineView(.periodic(from: startedAt, by: 1)) { context in
                            Text(Self.clock(context.date.timeIntervalSince(startedAt)))
                                .font(.ui(13, .semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                WaveformView(audioLevel: meeting.audioLevel, isRecording: true, accentColor: DiktatTheme.accent)
                    .frame(height: 36)
                    .frame(maxWidth: .infinity)

                if let name = meeting.microphoneName {
                    // Which microphone hears the room, so a wrong one is noticed at the start.
                    Label(String(localized: "Mikrofon: \(name)"), systemImage: "mic.fill")
                        .font(.ui(11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .glassPanel()
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(DiktatTheme.danger, lineWidth: meeting.problem == nil ? 0 : 2)
            )

            if let live = meeting.liveNotes {
                LiveNotesCard(live: live)
            }

            Text("Du kannst das Men\u{00FC} schlie\u{00DF}en, die Aufnahme l\u{00E4}uft weiter. Das Symbol in der Men\u{00FC}leiste zeigt sie an. Bitte den Mac nicht zuklappen.")
                .font(.ui(12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                meeting.stop()
            } label: {
                Label("Beenden und auswerten", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.filledAction)

            Button {
                if meeting.pausedAt == nil { meeting.pause() } else { meeting.resume() }
            } label: {
                Label(meeting.pausedAt == nil ? "Pausieren" : "Fortsetzen", systemImage: meeting.pausedAt == nil ? "pause.fill" : "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.subtle)

            Button("Verwerfen", role: .destructive) {
                confirmDiscard = true
            }
            .buttonStyle(.subtle)
            .frame(maxWidth: .infinity)
            .confirmationDialog("Aufnahme verwerfen?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Verwerfen", role: .destructive) { meeting.discard() }
                Button("Weiter aufnehmen", role: .cancel) {}
            } message: {
                Text("Die Aufnahme wird gel\u{00F6}scht und nicht ausgewertet. Das l\u{00E4}sst sich nicht r\u{00FC}ckg\u{00E4}ngig machen.")
            }
        }
    }

    private func processing(_ step: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(step)
                    .font(.ui(12.5, .medium))
            }
            Text("Bei langen Meetings dauert das ein paar Minuten, alles l\u{00E4}uft auf diesem Mac. Beim ersten Mal l\u{00E4}dt Diktat dazu einmalig das Modell f\u{00FC}r die Stimmen.")
                .font(.ui(11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private func failure(_ message: String, meetingID: UUID?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.ui(12.5))
                .foregroundStyle(DiktatTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .glassPanel()

            if let meetingID, meeting.store.meeting(id: meetingID)?.status == .pending {
                // The promise "deleted after the evaluation" holds once it succeeds; until then
                // the recording is still here, and that is said.
                Text("Die Aufnahme bleibt auf diesem Mac, bis du sie auswertest oder l\u{00F6}schst.")
                    .font(.ui(11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if let meetingID, meeting.store.meeting(id: meetingID)?.status == .pending {
                    Button("Erneut auswerten") { meeting.process(meetingID) }
                        .buttonStyle(.filledAction)
                }
                Button("Zur\u{00FC}ck") { meeting.close() }
                    .buttonStyle(.glassAction)
                Spacer()
                if let meetingID, meeting.store.meeting(id: meetingID) != nil {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Text("L\u{00F6}schen")
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .buttonStyle(.subtle)
                    .confirmationDialog("Meeting l\u{00F6}schen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("L\u{00F6}schen", role: .destructive) { meeting.delete(meetingID) }
                    } message: {
                        Text("Die Aufnahme wird gel\u{00F6}scht und kann nicht mehr ausgewertet werden.")
                    }
                }
            }
        }
    }

    // MARK: - Result

    private func result(_ record: MeetingRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // The window has no back header; without this there is no way to the other meetings.
            if embedded {
                Button {
                    meeting.close()
                } label: {
                    Label("Alle Meetings", systemImage: "chevron.left")
                }
                .buttonStyle(.glassAction)
                .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .leading, spacing: 2) {
                Button {
                    newTitle = record.title
                    renamingTitle = true
                } label: {
                    HStack(spacing: 6) {
                        Text(record.title)
                            .font(.ui(15, .semibold))
                            .multilineTextAlignment(.leading)
                        Image(systemName: "pencil")
                            .font(.ui(10, .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Meeting umbenennen")
                .accessibilityLabel(String(localized: "\(record.title), umbenennen"))
                Text(summaryLine(record))
                    .font(.ui(11.5))
                    .foregroundStyle(.secondary)
            }
            .alert("Meeting umbenennen", isPresented: $renamingTitle) {
                TextField("Titel", text: $newTitle)
                Button("Sichern") { meeting.rename(record.id, to: newTitle) }
                Button("Abbrechen", role: .cancel) {}
            }

            // At the top: a long meeting would put them far below the transcript.
            HStack(spacing: 8) {
                // The bare transcript by person, e.g. to continue in another AI app.
                copyButton(String(localized: "Transkript kopieren"), target: .transcript, text: record.transcriptShareText)
                if record.summary != nil {
                    copyButton(String(localized: "Alles kopieren"), target: .everything, text: record.shareText)
                }
                Spacer()
            }

            summaryCard(record)

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: String(localized: "Personen: Klicken zum Umbenennen"))
                FlowLayout(spacing: 6) {
                    ForEach(record.speakers, id: \.self) { speaker in
                        Button {
                            newName = record.speakerNames[speaker] ?? ""
                            rememberVoice = true
                            renaming = speaker
                            nameFieldFocused = true
                        } label: {
                            HStack(spacing: 5) {
                                Circle().fill(color(for: speaker)).frame(width: 7, height: 7)
                                Text(record.name(for: speaker))
                                // Diktat set this name itself, from a voice it knows.
                                if meeting.isRecognised(speaker, in: record.id) {
                                    Text("erkannt")
                                        .font(.ui(10, .medium))
                                        .foregroundStyle(DiktatTheme.accent)
                                }
                                Image(systemName: "pencil")
                                    .font(.ui(9, .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .font(.ui(12, .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(DiktatTheme.card))
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let speaker = renamedSpeaker, record.speakers.contains(speaker) {
                    renameEditor(speaker, in: record)
                }
                ForEach(record.speakers, id: \.self) { speaker in
                    if speaker != renamedSpeaker, let name = meeting.suggestedName(for: speaker, in: record.id) {
                        voiceQuestion(speaker, name: name, in: record)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: String(localized: "Transkript"))
                ForEach(record.turns) { turn in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(record.name(for: turn.speaker))
                                .font(.ui(11.5, .semibold))
                                .foregroundStyle(color(for: turn.speaker))
                            Text(Self.clock(turn.start))
                                .font(.ui(11).monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        Text(turn.text)
                            .font(.ui(12.5))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassPanel()
                }
            }

            HStack(spacing: 8) {
                Spacer()
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Text("L\u{00F6}schen")
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(.subtle)
                    .confirmationDialog("Meeting l\u{00F6}schen?", isPresented: $confirmDelete) {
                        Button("L\u{00F6}schen", role: .destructive) { meeting.delete(record.id) }
                    }
            }
        }
    }

    private func summaryCard(_ record: MeetingRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Zusammenfassung", systemImage: "sparkles")
                    .font(.ui(12.5, .semibold))
                    .foregroundStyle(DiktatTheme.accent)
                Spacer()
                if isResummarizing {
                    ProgressView().controlSize(.small)
                }
            }

            if let summary = record.summary {
                // The card is titled "Zusammenfassung" already.
                SummaryText(text: summary, title: summary.contains("Summary") ? "Summary" : "Zusammenfassung")

                if let note = record.summaryNote {
                    Text(note)
                        .font(.ui(11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Automatisch erstellt. Bitte vor allem die Zust\u{00E4}ndigkeiten bei den To-dos kurz pr\u{00FC}fen.")
                    .font(.ui(11))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    copyButton(String(localized: "Kopieren"), target: .summary, text: ListDisplay.plain(summary))
                    Button {
                        resummarize(record.id)
                    } label: {
                        Label("Neu erstellen", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.glassAction)
                    .disabled(isResummarizing)
                }
            } else {
                Text(record.summaryNote ?? String(localized: "Noch keine Zusammenfassung."))
                    .font(.ui(12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Zusammenfassung erstellen") { resummarize(record.id) }
                    .buttonStyle(.glassAction)
                    .disabled(isResummarizing)
            }
        }
        .padding(14)
        .glassPanel()
    }

    private func copyButton(_ title: String, target: CopyTarget, text: String) -> some View {
        Button {
            appState.copyToClipboard(text)
            copied = target
        } label: {
            Label(copied == target ? "Kopiert" : title, systemImage: copied == target ? "checkmark" : "doc.on.doc")
                .lineLimit(1)
                .fixedSize()
        }
        .buttonStyle(.glassAction)
    }

    // MARK: - Helpers

    private func saveName() {
        guard let speaker = renaming, case .showing(let id) = meeting.phase else { return }
        let remembers = rememberVoice && meeting.canRememberVoice(of: speaker, in: id)
        meeting.rename(speaker: speaker, to: newName, in: id, rememberVoice: remembers)
        renaming = nil
    }

    /// Name and, where Diktat has a voiceprint of the person, the tick that makes it a known
    /// voice. Below the people instead of an alert, which cannot hold a tick.
    private func renameEditor(_ speaker: Int, in record: MeetingRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Person umbenennen")
                .font(.ui(12, .semibold))
            Text(String(localized: "Der Name ersetzt \u{201E}Person \(speaker)\u{201C} im Transkript."))
                .font(.ui(11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .font(.ui(12.5))
                .focused($nameFieldFocused)
                .onSubmit { saveName() }
            if meeting.canRememberVoice(of: speaker, in: record.id) {
                Toggle(isOn: $rememberVoice) {
                    Text("Stimme f\u{00FC}r k\u{00FC}nftige Meetings merken")
                        .font(.ui(12))
                }
                .toggleStyle(.checkbox)
            }
            HStack(spacing: 8) {
                Spacer()
                Button("Abbrechen") { renaming = nil }
                    .buttonStyle(.subtle)
                    .keyboardShortcut(.cancelAction)
                Button("Sichern") { saveName() }
                    .buttonStyle(.glassAction)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    /// Diktat is unsure whether a person is a voice it knows, and asks instead of guessing.
    private func voiceQuestion(_ speaker: Int, name: String, in record: MeetingRecord) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color(for: speaker)).frame(width: 7, height: 7)
            Text(record.name(for: speaker))
                .font(.ui(12, .medium))
            Text(String(localized: "Ist das \(name)?"))
                .font(.ui(12))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Ja") { meeting.answerSuggestion(for: speaker, in: record.id, isSame: true) }
                .buttonStyle(.subtle)
            Button("Nein") { meeting.answerSuggestion(for: speaker, in: record.id, isSame: false) }
                .buttonStyle(.subtle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private func resummarize(_ id: UUID) {
        isResummarizing = true
        copied = nil
        Task {
            await meeting.resummarize(id)
            isResummarizing = false
        }
    }

    private func summaryLine(_ record: MeetingRecord) -> String {
        let minutes = Int((record.duration / 60).rounded())
        let duration = minutes < 1 ? String(localized: "unter 1 Min.") : String(localized: "\(minutes) Min.")
        let people = record.speakers.count == 1 ? String(localized: "1 Person") : String(localized: "\(record.speakers.count) Personen")
        return "\(duration), \(people)"
    }

    private func color(for speaker: Int) -> Color {
        Self.personColors[(max(speaker, 1) - 1) % Self.personColors.count]
    }

    /// "4:05" or "1:02:05".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }
}

/// A problem with the running recording, as large as the page allows: whoever runs the meeting
/// has to see it at a glance, because what is not recorded is lost.
private struct ProblemBanner: View {
    let problem: MeetingProblem

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulses = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.ui(22, .bold))
                .opacity(pulses ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(problem.title)
                    .font(.ui(15, .bold))
                Text(problem.detail)
                    .font(.ui(12.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(nsColor: .systemRed)))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulses = true }
        }
    }
}

/// A thin bar that fills with the level, 0...1.
private struct LevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(DiktatTheme.accent)
                    .frame(width: max(4, proxy.size.width * CGFloat(min(1, max(0, level)))))
                    .animation(.linear(duration: 0.1), value: level)
            }
        }
    }
}
