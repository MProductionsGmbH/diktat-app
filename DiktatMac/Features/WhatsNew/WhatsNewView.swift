import SwiftUI

/// What changed in this release. Shown once per `version`: on the next popover opening,
/// or right after the first dictation for people who only use the shortcuts.
enum WhatsNew {
    /// Names this set of notes; they are shown once per value. Change it together with the
    /// items when a release deserves a note. It is not shown: the title carries the version of
    /// the app itself.
    static let version = "0.1.17"

    /// The version of the running app, for the title.
    static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }

    struct Item: Identifiable {
        let icon: String
        let title: String
        let detail: String
        var id: String { title }
    }

    static let items: [Item] = [
        Item(
            icon: "doc.text",
            title: String(localized: "Audiodateien mit eigener Liste"),
            detail: String(localized: "Auf der Seite \u{201E}Audiodatei\u{201C} stehen jetzt die Texte der Dateien, die du in den letzten 7 Tagen transkribiert hast. Du kannst sie wieder \u{00F6}ffnen, kopieren oder l\u{00F6}schen. Im Verlauf erscheinen sie nicht mehr. Die Tondatei speichert Diktat weiterhin nicht.")
        ),
        Item(
            icon: "video.fill",
            title: String(localized: "Meetings: zwei Quellen"),
            detail: String(localized: "\u{201E}Im Raum\u{201C} nimmt das Mikrofon des Computers auf. \u{201E}Online-Meeting\u{201C} nimmt das System-Audio auf, also die anderen aus Teams, Zoom oder Meet, und dazu dein Mikrofon. Mit einem Headset kommen jetzt wirklich die anderen an. Bitte vorher alle fragen.")
        ),
        Item(
            icon: "waveform",
            title: String(localized: "Mundart und Schweizer Schreibweise"),
            detail: String(localized: "Unter Einstellungen > Modelle stehen zwei weitere Whisper-Modelle zur Wahl, die Schweizerdeutsch oft besser verstehen. Lange Aufnahmen verlieren keine Passagen mehr. Mit \u{201E}Schweizer Schreibweise\u{201C} in den Einstellungen schreibt Diktat ohne Eszett.")
        ),
    ]
}

struct WhatsNewView: View {
    @Bindable var appState: AppState

    private var needsSetup: Bool {
        !appState.isConfigured || !appState.canRewrite
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Neu in Diktat \(WhatsNew.appVersion)"))
                    .font(DiktatType.publicSans(20, .bold, relativeTo: .title3))
                Text("Einmal kurz, dann geht es weiter wie gewohnt.")
                    .font(.ui(12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().opacity(0.16)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(WhatsNew.items) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.ui(14, .semibold))
                            .foregroundStyle(DiktatTheme.accent)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.ui(13, .semibold))
                            Text(item.detail)
                                .font(.ui(11.5))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if !appState.isConfigured {
                    NoticeRow(
                        icon: "arrow.down.circle",
                        title: String(localized: "Noch ein Schritt"),
                        detail: String(localized: "Lade einmal ein lokales Sprachmodell, sonst kann Diktat nicht transkribieren.")
                    )
                } else if !appState.canRewrite {
                    NoticeRow(
                        icon: "key",
                        title: String(localized: "KI-Modi einrichten"),
                        detail: String(localized: "Ohne Apple Intelligence brauchen KI-Schreibstil, WTF und :-) einen eigenen API-Key.")
                    )
                }
            }
            .padding(16)

            Divider().opacity(0.16)

            HStack(spacing: 8) {
                Spacer()
                if needsSetup {
                    Button {
                        appState.markWhatsNewSeen()
                        appState.page = .settings
                    } label: {
                        Text("Einrichten")
                            .font(.ui(12, .medium))
                    }
                    .buttonStyle(.glassAction)
                }
                Button {
                    appState.markWhatsNewSeen()
                    appState.page = .main
                } label: {
                    Text("Verstanden")
                        .font(.ui(12, .semibold))
                }
                .buttonStyle(.glassAction)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
