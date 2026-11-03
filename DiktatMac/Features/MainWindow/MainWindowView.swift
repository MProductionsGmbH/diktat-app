import SwiftUI

/// The pages of the main window. The menu bar stays the center of Diktat; the window is for what needs room:
/// the history, the modes, meetings and the settings (the dictionary is one of its tabs).
enum MainWindowPage: String, CaseIterable, Identifiable {
    case history
    case modes
    case meetings
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: return String(localized: "Verlauf")
        case .modes: return String(localized: "Modi")
        case .meetings: return String(localized: "Meetings")
        case .settings: return String(localized: "Einstellungen")
        }
    }

    var icon: String {
        switch self {
        case .history: return "clock"
        case .modes: return "slider.horizontal.3"
        case .meetings: return "person.2.wave.2"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindowView: View {
    @Bindable var appState: AppState

    static let sidebarWidth: CGFloat = 220

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: Self.sidebarWidth)

            Divider().opacity(0.6)

            VStack(spacing: 0) {
                switch appState.mainWindowPage {
                case .history:
                    MainHistoryPage(appState: appState)
                case .modes:
                    MainModesPage(appState: appState)
                case .meetings:
                    MainMeetingsPage(appState: appState)
                case .settings:
                    MainSettingsPage(appState: appState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DiktatSurface.windowBackground)
        }
        .tint(DiktatTheme.accent)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandRow()
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 18)

            VStack(spacing: 2) {
                ForEach(MainWindowPage.allCases) { page in
                    SidebarItem(
                        page: page,
                        isSelected: appState.mainWindowPage == page,
                        badge: page == .meetings && (appState.meeting.isRecording || appState.meeting.isProcessing)
                    ) {
                        appState.mainWindowPage = page
                    }
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 4) {
                Label("Alles auf diesem Mac", systemImage: "lock.fill")
                    .font(.ui(12, .semibold))
                    .foregroundStyle(DiktatTheme.ready)
                Text("Kein Konto, keine Telemetrie. Audio wird nach dem Diktat gelöscht.")
                    .font(.ui(11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(DiktatTheme.ready.opacity(0.12)))

            Text(MainWindowView.versionText)
                .font(.ui(11))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.top, 10)
        }
        .padding(12)
        .frame(maxHeight: .infinity)
        .background(DiktatTheme.inset.opacity(0.7))
    }

    static var versionText: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = (info["CFBundleShortVersionString"] as? String) ?? "?"
        return "v\(version)"
    }
}

private struct SidebarItem: View {
    let page: MainWindowPage
    let isSelected: Bool
    let badge: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: page.icon)
                    .font(.ui(14, .semibold))
                    .frame(width: 20)
                Text(page.title)
                    .font(.ui(13.5, isSelected ? .semibold : .regular))
                Spacer(minLength: 0)
                if badge {
                    Circle().fill(DiktatTheme.danger).frame(width: 8, height: 8)
                }
            }
            .foregroundStyle(isSelected ? DiktatTheme.onTonal : Color.primary)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? DiktatTheme.tonal : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The frame every page shares: a title, optional trailing controls and a scrolling body in a readable width.
struct MainPage<Trailing: View, Content: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.ui(24, .bold))
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 12)
                    trailing
                }
                content
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - History

struct MainHistoryPage: View {
    @Bindable var appState: AppState
    @State private var query = ""

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        let entries = appState.history.entries
        let shown = entries.filter { HistoryOverview.matches($0.text, query: query) }

        MainPage(title: String(localized: "Verlauf")) {
            if !entries.isEmpty {
                Button("Alles löschen") {
                    withAnimation(.easeOut(duration: 0.15)) { appState.history.clear() }
                }
                .buttonStyle(.subtle)
                .font(.ui(12))
                .foregroundStyle(.secondary)
            }
        } content: {
            if appState.appSettings.historyRetention == .off {
                emptyState(
                    icon: "clock.badge.xmark",
                    title: String(localized: "Verlauf ist aus"),
                    detail: String(localized: "In den Einstellungen unter „Aufnahme & Einfügen“ einschalten.")
                )
            } else if entries.isEmpty {
                emptyState(
                    icon: "clock",
                    title: String(localized: "Noch nichts im Verlauf"),
                    detail: String(localized: "Ergebnisse bleiben \(retentionHint) nur auf diesem Mac, verschlüsselt.")
                )
            } else {
                if appState.appSettings.showsHistoryStatistics {
                    statistics(of: entries)
                }

                searchField

                if shown.isEmpty {
                    emptyState(
                        icon: "magnifyingglass",
                        title: String(localized: "Nichts gefunden"),
                        detail: String(localized: "Kein Eintrag enthält diesen Suchbegriff.")
                    )
                } else {
                    ForEach(Array(HistoryOverview.groups(shown, date: \.createdAt).enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 6) {
                            SectionHeader(title: dayTitle(group.day))
                            ForEach(group.items) { entry in
                                HistoryRow(
                                    entry: entry,
                                    workflowName: appState.displayName(for: entry.workflow),
                                    timestamp: Self.timeFormatter.string(from: entry.createdAt),
                                    onPaste: { appState.pasteFromHistory(entry) },
                                    onCopy: { appState.copyToClipboard(entry.text) },
                                    onDelete: {
                                        withAnimation(.easeOut(duration: 0.15)) { appState.history.remove(entry) }
                                    }
                                )
                            }
                        }
                    }
                }

                Text(String(localized: "Nur auf diesem Mac, \(retentionHint)."))
                    .font(.ui(11.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func statistics(of entries: [TranscriptHistoryEntry]) -> some View {
        let stats = HistoryOverview.statistics(of: entries.map(\.text))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                StatCard(value: stats.words.formatted(.number.locale(AppLocale.current)), label: String(localized: "Wörter"))
                StatCard(value: stats.dictations.formatted(.number.locale(AppLocale.current)), label: String(localized: "Diktate"))
                StatCard(value: stats.wordsPerDictation.formatted(.number.locale(AppLocale.current)), label: String(localized: "Wörter pro Diktat"))
            }
            Text("Nur auf diesem Mac aus dem Verlauf berechnet. Abschaltbar unter Einstellungen.")
                .font(.ui(11.5))
                .foregroundStyle(.tertiary)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.ui(13))
                .foregroundStyle(.secondary)
            TextField("Verlauf durchsuchen", text: $query)
                .textFieldStyle(.plain)
                .font(.ui(13))
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .glassPanel(cornerRadius: 10)
    }

    private func dayTitle(_ day: HistoryOverview.Day) -> String {
        switch day {
        case .today: return String(localized: "Heute")
        case .yesterday: return String(localized: "Gestern")
        case .date(let date): return Self.dayFormatter.string(from: date)
        }
    }

    private var retentionHint: String {
        switch appState.appSettings.historyRetention {
        case .off: return ""
        case .day: return String(localized: "24 Stunden")
        case .week: return String(localized: "7 Tage")
        }
    }

    private func emptyState(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.ui(26, .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.ui(13.5, .semibold))
            Text(detail)
                .font(.ui(12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

private struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.ui(22, .bold))
            Text(label)
                .font(.ui(12))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Modes

struct MainModesPage: View {
    @Bindable var appState: AppState

    var body: some View {
        MainPage(title: String(localized: "Modi")) {
            EmptyView()
        } content: {
            Text("Jeder Modus hat sein eigenes Kürzel. Du hältst es, sprichst, und Diktat schreibt den Text so, wie der Modus es verlangt. Ein Klick startet einen Modus auch ohne Kürzel.")
                .font(.ui(12.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(Array(WorkflowType.mainMenuCases.enumerated()), id: \.element) { index, type in
                    if index > 0 {
                        Divider().opacity(0.5).padding(.leading, 62).padding(.trailing, 12)
                    }
                    WorkflowRowView(
                        type: type,
                        enabled: appState.isWorkflowAvailable(type),
                        customName: appState.displayName(for: type),
                        subtitle: appState.workflowSubtitle(for: type),
                        hotkeyLabel: appState.hotkeyLabel(for: type)
                    ) {
                        appState.startWorkflow(type)
                    }
                }
            }
            .padding(.vertical, 4)
            .glassPanel()

            AppModeRulesSection(appState: appState)
        }
    }
}

// MARK: - Meetings

struct MainMeetingsPage: View {
    @Bindable var appState: AppState

    var body: some View {
        MeetingView(appState: appState, embedded: true)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Settings

struct MainSettingsPage: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Text("Einstellungen")
                .font(.ui(24, .bold))
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity)

            SettingsContentView(appState: appState, inWindow: true)
                .frame(maxWidth: 752)
                .frame(maxWidth: .infinity)
        }
    }
}

/// In "Allgemein" of the window: what belongs to the window itself, and how Diktat treats data.
struct MainWindowSettingsSection: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection(title: String(localized: "Fenster")) {
                Toggle(isOn: $appState.appSettings.showsHistoryStatistics) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Statistik im Verlauf zeigen")
                            .font(.ui(12.5, .semibold))
                        Text("Wörter und Diktate aus dem Verlauf. Nur auf diesem Mac berechnet.")
                            .font(.ui(11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.trailingSwitch)
                Text("Das Dock-Symbol erscheint nur, solange dieses Fenster offen ist. Sonst bleibt Diktat unsichtbar in der Menüleiste.")
                    .font(.ui(12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsSection(title: String(localized: "Datenschutz")) {
                Text("Diktat hat kein Konto und kein Backend. Audio, Text und Verlauf bleiben auf diesem Mac. Das Internet erreichen nur der Download der Sprachmodelle (Hugging Face), der Update-Check (GitHub, abschaltbar) und, wenn du einen eigenen Anbieter einträgst, der erkannte Text.")
                    .font(.ui(12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
