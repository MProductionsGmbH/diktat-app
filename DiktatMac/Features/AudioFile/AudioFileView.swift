import SwiftUI

/// Popover page for a transcribed audio file (Voice Memo, WhatsApp voice message, ...).
/// Where a request to choose an audio file came from, so the result shows up there again.
enum AudioFileRequest {
    static let window = "window"
}

struct AudioFileView: View {
    @Bindable var appState: AppState
    /// In the main window: only the content, the page around it has title and file button.
    var embedded = false

    private var controller: AudioFileController { appState.audioFile }

    var body: some View {
        if embedded {
            content
        } else {
            popoverPage
        }
    }

    private var popoverPage: some View {
        VStack(spacing: 0) {
            PageHeader(title: String(localized: "Audiodatei"), onBack: {
                controller.close()
                appState.page = .main
            })

            Divider().opacity(0.16)

            ScrollView {
                content
                    .padding(16)
            }

            Divider().opacity(0.16)

            HStack {
                Spacer()
                Button {
                    NotificationCenter.default.post(name: .chooseAudioFile, object: nil)
                } label: {
                    Label("Andere Datei ...", systemImage: "folder")
                        .font(.ui(12, .medium))
                }
                .buttonStyle(.glassAction)
                .disabled(controller.isWorking)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(height: 520)
    }

    private var content: some View {
                VStack(alignment: .leading, spacing: 12) {
                    if !controller.fileName.isEmpty {
                        fileRow
                    }

                    switch controller.phase {
                    case .idle:
                        EmptyView()
                    case .working(let message):
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text(message)
                                .font(.ui(12.5))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .glassPanel()
                    case .failed(let message):
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.ui(12.5))
                            .foregroundStyle(DiktatTheme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .glassPanel()
                    case .done:
                        result
                    }

                    Text("Die Datei wird auf diesem Mac transkribiert und nicht ver\u{00E4}ndert.")
                        .font(.ui(11))
                        .foregroundStyle(.tertiary)

                    if !embedded {
                        AudioFileHistoryList(appState: appState)
                            .padding(.top, 6)
                    }
                }
    }

    private var fileRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.ui(15, .semibold))
                .foregroundStyle(DiktatTheme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(controller.fileName)
                    .font(.ui(12.5, .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if controller.duration > 0 {
                    Text(Self.durationText(controller.duration))
                        .font(.ui(11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    static func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        return String(localized: "\(seconds / 60):\(String(format: "%02d", seconds % 60)) min")
    }

    private var result: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: controller.mode.icon)
                Text(appState.displayName(for: controller.mode))
                Spacer()
                if controller.copied {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(DiktatTheme.ready)
                        Text("In der Zwischenablage")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .font(.ui(11, .semibold))
            .foregroundStyle(.secondary)

            Text(controller.text)
                .font(.ui(13))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button {
                    controller.copy(appState: appState)
                } label: {
                    Label("Kopieren", systemImage: "doc.on.doc")
                        .font(.ui(12, .medium))
                }
                .buttonStyle(.glassAction)

                if appState.canRewrite {
                    Menu {
                        ForEach([WorkflowType.textImprover, .dampfAblassen, .emojiText].filter { $0 != controller.mode }, id: \.self) { mode in
                            Button(appState.displayName(for: mode)) {
                                controller.rewrite(as: mode, appState: appState)
                            }
                        }
                        if controller.mode != .tapTalk {
                            Divider()
                            Button("Original-Transkript") {
                                controller.showTranscript(appState: appState)
                            }
                        }
                    } label: {
                        Label("Umschreiben als ...", systemImage: "wand.and.stars")
                            .font(.ui(12, .medium))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
        .padding(14)
        .glassPanel()
    }
}

/// The audio files transcribed in the last seven days: open one again, copy its text or delete
/// it. Shown on the page "Audiodatei" only, never in the history of dictations.
struct AudioFileHistoryList: View {
    @Bindable var appState: AppState
    @State private var deleting: AudioFileEntry?

    private var controller: AudioFileController { appState.audioFile }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    var body: some View {
        let entries = appState.audioFiles.entries

        if appState.appSettings.historyRetention == .off {
            Text("Fr\u{00FC}here Dateien werden nicht aufbewahrt, weil der Verlauf in den Einstellungen aus ist.")
                .font(.ui(11.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        } else if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: String(localized: "Transkribierte Dateien"))

                ForEach(entries) { entry in
                    AudioFileHistoryRow(
                        entry: entry,
                        detail: "\(Self.dateFormatter.string(from: entry.createdAt)), \(AudioFileView.durationText(entry.duration))",
                        isShown: controller.entryID == entry.id,
                        isDisabled: controller.isWorking,
                        onOpen: { controller.open(entry) },
                        onCopy: { appState.copyToClipboard(entry.text) },
                        onDelete: { deleting = entry }
                    )
                }

                Text("Die Texte bleiben 7 Tage, nur auf diesem Mac und verschl\u{00FC}sselt. Die Tondatei speichert Diktat nicht.")
                    .font(.ui(11.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .confirmationDialog(
                String(localized: "Den Text von \u{201E}\(deleting?.fileName ?? "")\u{201C} l\u{00F6}schen?"),
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("L\u{00F6}schen", role: .destructive) {
                    if let entry = deleting {
                        withAnimation(.easeOut(duration: 0.15)) { controller.delete(entry, appState: appState) }
                    }
                    deleting = nil
                }
                Button("Abbrechen", role: .cancel) { deleting = nil }
            } message: {
                Text("Die Audiodatei selbst bleibt, wo sie ist.")
            }
        }
    }
}

private struct AudioFileHistoryRow: View {
    let entry: AudioFileEntry
    let detail: String
    let isShown: Bool
    let isDisabled: Bool
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var didCopy = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "waveform")
                        .font(.ui(12, .semibold))
                        .foregroundStyle(isShown ? AnyShapeStyle(DiktatTheme.accent) : AnyShapeStyle(.secondary))
                        .frame(width: 18)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.fileName)
                            .font(.ui(12.5, .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(detail)
                            .font(.ui(11))
                            .foregroundStyle(.secondary)
                        Text(entry.text)
                            .font(.ui(11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .allowsHitTesting(!isShown)
            .help(isShown ? String(localized: "Wird oben angezeigt") : String(localized: "Text wieder anzeigen"))

            HStack(spacing: 10) {
                Button {
                    onCopy()
                    didCopy = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopy = false }
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                }
                .help("Text kopieren")
                .accessibilityLabel(Text("Text kopieren"))

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .help("Text l\u{00F6}schen")
                .accessibilityLabel(Text("Text l\u{00F6}schen"))
            }
            .font(.ui(11.5, .medium))
            .foregroundStyle(.secondary)
            .buttonStyle(SubtleButtonStyle())
            .padding(.top, 1)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(isShown ? 0.07 : (isHovered ? 0.05 : 0.03)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(DiktatTheme.accent.opacity(isShown ? 0.55 : 0), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}
