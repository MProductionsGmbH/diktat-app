import Foundation
import Observation

extension AudioFileEntry {
    var workflow: WorkflowType { WorkflowType(rawValue: mode) ?? .tapTalk }
}

/// The texts of transcribed audio files, shown on the page "Audiodatei" and nowhere else.
/// Stored only on this Mac, encrypted with the device-bound key, for seven days. With the
/// history turned off nothing is kept, as for dictations.
@Observable
@MainActor
final class AudioFileHistoryStore {
    private(set) var entries: [AudioFileEntry] = []
    private var isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
        entries = Self.load()
        prune()
    }

    /// Keeps the text of a transcribed file. Returns the entry's id, nil when nothing is kept.
    @discardableResult
    func add(fileName: String, duration: TimeInterval, transcript: String, text: String) -> UUID? {
        guard isEnabled, !text.isEmpty else { return nil }
        let entry = AudioFileEntry(
            id: UUID(), createdAt: Date(), fileName: fileName, duration: duration,
            transcript: transcript, text: text, mode: WorkflowType.tapTalk.rawValue
        )
        entries.insert(entry, at: 0)
        prune()
        save()
        return entry.id
    }

    /// The entry shows a rewrite of its transcript, or the transcript again.
    func update(_ id: UUID, text: String, mode: WorkflowType) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].text = text
        entries[index].mode = mode.rawValue
        save()
    }

    func remove(_ entry: AudioFileEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    /// The history setting "Aus" also keeps no audio file texts and deletes them at once.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled { clear() }
    }

    /// Drops entries older than seven days. Called on launch, on every new entry and when
    /// the page or the popover opens.
    func prune(now: Date = Date()) {
        guard isEnabled else {
            if !entries.isEmpty || FileManager.default.fileExists(atPath: AppSupportPaths.audioFilesURL.path) { clear() }
            return
        }
        let kept = AudioFileRetention.kept(entries, now: now)
        if kept != entries {
            entries = kept
            save()
        }
    }

    private func save() {
        guard !DiktatCleanupService.didRemoveUserData, !Self.isSnapshotRun else { return }
        guard !entries.isEmpty else {
            try? FileManager.default.removeItem(at: AppSupportPaths.audioFilesURL)
            return
        }
        do {
            try AppSupportPaths.ensureAppSupportDirectoryExists()
            let data = try JSONEncoder().encode(entries)
            try KeychainService.sealData(data).write(to: AppSupportPaths.audioFilesURL, options: .atomic)
        } catch {
            // The list is a convenience; a failed write must never block the transcription.
        }
    }

    private static var isSnapshotRun: Bool {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "DiktatSnapshotDir") != nil
        #else
        return false
        #endif
    }

    private static func load() -> [AudioFileEntry] {
        #if DEBUG
        // Snapshot runs show samples and never open the keychain.
        if isSnapshotRun {
            return [
                AudioFileEntry(
                    id: UUID(), createdAt: Date().addingTimeInterval(-5_400), fileName: "Sprachmemo Offerte.m4a", duration: 96,
                    transcript: "Kurz zur Offerte: Wir liefern die Anlage in der Kalenderwoche 12 und nehmen sie eine Woche sp\u{00E4}ter in Betrieb.",
                    text: "Kurz zur Offerte: Wir liefern die Anlage in der Kalenderwoche 12 und nehmen sie eine Woche sp\u{00E4}ter in Betrieb.",
                    mode: WorkflowType.tapTalk.rawValue
                ),
                AudioFileEntry(
                    id: UUID(), createdAt: Date().addingTimeInterval(-3 * 86_400), fileName: "WhatsApp Audio 2026-11-21.opus", duration: 41,
                    transcript: "Hoi, ich bin um vier beim Bahnhof. Nimmst du die Unterlagen mit?",
                    text: "Hoi, ich bin um vier beim Bahnhof. Nimmst du die Unterlagen mit?",
                    mode: WorkflowType.tapTalk.rawValue
                ),
            ]
        }
        #endif
        guard let encrypted = try? Data(contentsOf: AppSupportPaths.audioFilesURL),
              let data = KeychainService.openData(encrypted),
              let entries = try? JSONDecoder().decode([AudioFileEntry].self, from: data) else {
            return []
        }
        return entries
    }
}
