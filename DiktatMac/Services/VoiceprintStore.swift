import Foundation
import Observation

/// Keeps the voices Diktat knows (`VoiceLibrary`) on this Mac: one file in Diktat's own folder,
/// encrypted with the device-bound key like the meetings, readable by this user only and left
/// out of backups. Nothing in it expires; it changes only when the user names, forgets or
/// deletes. Voiceprints never leave this file: not into a meeting's text, not to a language
/// model, not to another device.
@Observable
@MainActor
final class VoiceprintStore {
    private(set) var library = VoiceLibrary()
    /// False for tool runs and snapshots: nothing is read from or written to disk.
    private let isPersistent: Bool
    private let fileURL: URL

    /// `fileURL` is another place only for checks that must not touch the real voices.
    init(persistent: Bool = true, fileURL: URL = AppSupportPaths.voiceprintsURL) {
        isPersistent = persistent
        self.fileURL = fileURL
        #if DEBUG
        if Self.isSnapshotRun {
            library = Self.snapshotLibrary
            return
        }
        #endif
        guard persistent else { return }
        // A new version that never replaced the old one (a crash in between) is of no use.
        for url in strayFiles() where url.lastPathComponent.contains(Self.newMarker) {
            try? FileManager.default.removeItem(at: url)
        }
        defer { hasStrayFiles = !strayFiles().isEmpty }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        if let stored = try? Data(contentsOf: fileURL),
           let data = KeychainService.openData(stored),
           let library = try? JSONDecoder().decode(VoiceLibrary.self, from: data) {
            self.library = library
        } else {
            // Unreadable (another Mac's key, a damaged file): meetings are evaluated as before,
            // everybody stays "Person N". The file is kept aside instead of being overwritten.
            let aside = fileURL.deletingLastPathComponent()
                .appendingPathComponent(fileURL.lastPathComponent + Self.asideMarker + "\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: fileURL, to: aside)
        }
    }

    private static let asideMarker = ".unreadable-"
    private static let newMarker = ".new-"

    var voices: [KnownVoice] {
        library.voices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Also true for a file an earlier start could not read and put aside: it may hold
    /// voiceprints, and "Alle Stimmabdrücke löschen" is the way to remove it.
    var hasPrints: Bool { library.hasPrints || hasStrayFiles }

    private var hasStrayFiles = false

    /// Files next to the store that are not the store itself: one put aside as unreadable,
    /// or a new version a crash left behind before it replaced the old one.
    private func strayFiles() -> [URL] {
        let folder = fileURL.deletingLastPathComponent()
        let name = fileURL.lastPathComponent
        return ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
            .filter { $0.hasPrefix(name + Self.asideMarker) || $0.hasPrefix(name + Self.newMarker) }
            .map { folder.appendingPathComponent($0) }
    }

    // MARK: - Meetings

    func recognisedNames(prints: [Int: [Float]], speech: [Int: TimeInterval], enabled: Bool) -> [Int: String] {
        library.recognisedNames(prints: prints, speech: speech, enabled: enabled)
    }

    func register(meetingID: UUID, prints: [Int: [Float]], speech: [Int: TimeInterval], enabled: Bool) {
        guard enabled else { return }
        library.register(meetingID: meetingID, prints: prints, speech: speech, enabled: true, now: Date())
        save()
    }

    func canRemember(speaker: Int, in meetingID: UUID, enabled: Bool) -> Bool {
        library.canRemember(speaker: speaker, in: meetingID, enabled: enabled)
    }

    func name(speaker: Int, in meetingID: UUID, as name: String, remember: Bool, enabled: Bool) {
        change { $0.name(speaker: speaker, in: meetingID, as: name, remember: remember, enabled: enabled, now: Date()) }
    }

    /// The answer to "Ist das Anna?". Returns the name to set for a yes.
    func answer(speaker: Int, in meetingID: UUID, isSame: Bool, enabled: Bool) -> String? {
        var name: String?
        change { name = $0.answer(speaker: speaker, in: meetingID, isSame: isSame, enabled: enabled, now: Date()) }
        return name
    }

    func isRecognised(speaker: Int, in meetingID: UUID) -> Bool {
        library.isRecognised(speaker: speaker, in: meetingID)
    }

    func suggestion(for speaker: Int, in meetingID: UUID) -> KnownVoice? {
        library.suggestion(for: speaker, in: meetingID)
    }

    func removeMeeting(_ id: UUID) {
        change { $0.removeMeeting(id) }
    }

    // MARK: - Known voices

    func forget(_ voice: KnownVoice) {
        change { $0.forget(voice.id) }
    }

    func rename(_ voice: KnownVoice, to name: String) {
        change { $0.rename(voice.id, to: name) }
    }

    /// "Alle Stimmabdrücke löschen": the known voices, the prints of every meeting, and files
    /// an earlier start could not read and put aside.
    func removeAll() {
        library.removeAll()
        save()
        guard isPersistent else { return }
        for url in strayFiles() { try? FileManager.default.removeItem(at: url) }
        hasStrayFiles = !strayFiles().isEmpty
    }

    private func change(_ body: (inout VoiceLibrary) -> Void) {
        let before = library
        body(&library)
        if library != before { save() }
    }

    private func save() {
        guard isPersistent, !DiktatCleanupService.didRemoveUserData else { return }
        guard library.hasPrints || !library.meetings.isEmpty else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let sealed = try KeychainService.sealData(try JSONEncoder().encode(library))
            try writeProtected(sealed)
        } catch {
            // Known voices are a convenience; a failed write must never block a meeting.
        }
    }

    /// Replaces the file without a moment in which the voiceprints lie on disk readable by
    /// others or open to a backup: the new version is created empty with its protection
    /// (this user only, left out of backups), filled, and only then moved over the old one.
    /// The move keeps both, because they belong to the file and not to its name.
    private func writeProtected(_ data: Data) throws {
        var new = fileURL.deletingLastPathComponent()
            .appendingPathComponent(fileURL.lastPathComponent + Self.newMarker + UUID().uuidString)
        guard FileManager.default.createFile(atPath: new.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try new.setResourceValues(values)
            let handle = try FileHandle(forWritingTo: new)
            defer { try? handle.close() }
            try handle.write(contentsOf: data)
            try handle.synchronize()
            guard Darwin.rename(new.path, fileURL.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
        } catch {
            try? FileManager.default.removeItem(at: new)
            throw error
        }
    }

    // MARK: - Snapshots

    private static var isSnapshotRun: Bool {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "DiktatSnapshotDir") != nil
        #else
        return false
        #endif
    }

    #if DEBUG
    /// The meeting the snapshots show as a result, see `MacSnapshots`.
    static let snapshotMeetingID = UUID(uuidString: "5A3B1E00-0000-4000-8000-0000000000AC")!

    /// Two known voices; in the sample meeting Anna (person 3) was recognised and Diktat asks
    /// whether person 2 is Bea. The prints are made up.
    private static var snapshotLibrary: VoiceLibrary {
        var library = VoiceLibrary()
        let earlier = UUID()
        let aWeekAgo = Date().addingTimeInterval(-6 * 86_400)
        library.register(meetingID: earlier, prints: [1: [1, 0, 0], 2: [0, 0, 1]], speech: [1: 60, 2: 60], enabled: true, now: aWeekAgo)
        library.name(speaker: 1, in: earlier, as: "Anna", remember: true, enabled: true, now: aWeekAgo)
        library.name(speaker: 2, in: earlier, as: "Bea", remember: true, enabled: true, now: aWeekAgo)
        library.register(
            meetingID: snapshotMeetingID, prints: [1: [0.1, 1, 0], 2: [0, 0.8, 0.6], 3: [1, 0.1, 0]], speech: [1: 60, 2: 60, 3: 60],
            enabled: true, now: Date().addingTimeInterval(-3_600)
        )
        return library
    }
    #endif
}
