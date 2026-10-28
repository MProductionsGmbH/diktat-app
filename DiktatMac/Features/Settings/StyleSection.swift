import SwiftUI

/// A choice shown as a card: title, one line of explanation and, when there is one, an example.
private struct ChoiceCard<Example: View>: View {
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let example: Example

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.ui(12.5, .semibold))
                    Spacer(minLength: 4)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.ui(13))
                            .foregroundStyle(DiktatTheme.accent)
                    }
                }
                Text(detail)
                    .font(.ui(11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                example
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? DiktatTheme.accent.opacity(0.07) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? DiktatTheme.accent : Color.primary.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// An example of what a level does: the text as spoken and as it comes out.
private struct BeforeAfter: View {
    let before: String
    let after: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(before)
                .font(.ui(11.5))
                .italic()
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Text(after)
                .font(.ui(11.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(DiktatTheme.accent.opacity(0.06)))
    }
}

private extension SpeechCleanupLevel {
    /// Examples of the goal, not promised results: a model words things a little differently each time.
    var example: (before: String, after: String) {
        switch self {
        case .light:
            return ("Ich \u{00E4}hm wollte wollte noch sagen, dass das Meeting morgen morgen beginnt.",
                    "Ich wollte noch sagen, dass das Meeting morgen beginnt.")
        case .medium:
            return ("Wir treffen uns am Mittwoch, nein, Donnerstag um zehn.",
                    "Wir treffen uns am Donnerstag um zehn.")
        case .strong:
            return ("wir hat gestern ein Treffen gehabt und die Kunde sind zufrieden",
                    "Wir hatten gestern ein Treffen, und die Kunden sind zufrieden.")
        case .style:
            return ("ich wollte fragen ob wir den Termin am Donnerstag \u{00E4}h ich meine Freitag verschieben k\u{00F6}nnen",
                    "Ich m\u{00F6}chte fragen, ob wir den Termin auf Freitag verschieben k\u{00F6}nnen.")
        }
    }
}

/// "Glättung": how much Diktat tidies up what was said, as cards with an example each.
struct CleanupLevelSection: View {
    @Bindable var appState: AppState
    /// Where the model step runs, so the privacy promise stays visible next to the choice.
    let engineNote: String

    var body: some View {
        SettingsSection(title: "Gl\u{00E4}ttung") {
            Text("Wie stark Diktat deinen Text aufr\u{00E4}umt. Antwortet das Sprachmodell nicht oder unplausibel, bleibt der Text, wie du ihn gesprochen hast.")
                .font(.ui(12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(SpeechCleanupLevel.allCases) { level in
                ChoiceCard(
                    title: level.displayName,
                    detail: level.detail,
                    isSelected: appState.appSettings.speechCleanupLevel == level
                ) {
                    appState.appSettings.speechCleanupLevel = level
                } example: {
                    BeforeAfter(before: level.example.before, after: level.example.after)
                }
            }

            if appState.appSettings.speechCleanupLevel.usesLanguageModel {
                Text(engineNote)
                    .font(.ui(12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Die Beispiele zeigen das Ziel. Ein Sprachmodell formuliert jedes Mal ein wenig anders.")
                .font(.ui(11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// "Stil je Kontext": the tone for personal messages, work, mail and everything else.
struct StyleContextSection: View {
    @Bindable var appState: AppState
    @State private var context: StyleContext = .personal

    var body: some View {
        SettingsSection(title: "Stil je Kontext") {
            Text("Diktat erkennt, wohin dein Text geht, und schreibt ihn im passenden Ton.")
                .font(.ui(12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SegmentedToggle(
                options: StyleContext.allCases,
                selection: $context,
                label: { $0.displayName }
            )

            Text(context.appsNote)
                .font(.ui(11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(StyleTone.allCases) { tone in
                ChoiceCard(
                    title: tone.displayName,
                    detail: tone.detail,
                    isSelected: appState.appSettings.styleSettings.tone(for: context) == tone
                ) {
                    appState.appSettings.styleSettings.setTone(tone, for: context)
                } example: {
                    Text(tone.example)
                        .font(.ui(11.5))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(DiktatTheme.accent.opacity(0.06)))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Bei der Gl\u{00E4}ttung \u{201E}Schreibstil\u{201C} formuliert das Sprachmodell auch im gew\u{00E4}hlten Ton. Sonst \u{00E4}ndert der Ton nur die Satzzeichen am Ende.")
                .font(.ui(11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
