import Foundation

/// Where the sound of a meeting comes from.
enum MeetingSource: String, CaseIterable, Identifiable {
    /// People in the room, heard by the microphone.
    case room
    /// An online meeting: the microphone is "Ich", the Mac's sound holds the other people.
    case online
    /// Only the Mac's sound, e.g. a webinar or a recording: the microphone stays off.
    case systemOnly

    var id: String { rawValue }

    static let storageKey = "DiktatMeetingSource"
    /// The switch "Online-Meeting" of earlier versions.
    static let legacyStorageKey = "DiktatMeetingSystemAudio"

    var usesMicrophone: Bool { self != .systemOnly }
    var usesSystemAudio: Bool { self != .room }

    var title: String {
        switch self {
        case .room: return String(localized: "Im Raum")
        case .online: return String(localized: "Online-Meeting")
        case .systemOnly: return String(localized: "Nur System-Audio")
        }
    }

    var subtitle: String {
        switch self {
        case .room: return String(localized: "Mikrofon")
        case .online: return String(localized: "Mikrofon + System-Audio")
        case .systemOnly: return String(localized: "Ohne Mikrofon")
        }
    }

    var explanation: String {
        switch self {
        case .room:
            return String(localized: "Nimmt nur das Mikrofon auf, gedacht f\u{00FC}r Meetings im Raum.")
        case .online:
            return String(localized: "Nimmt dein Mikrofon (Ich) und das System-Audio (die anderen) auf, etwa aus Teams, Zoom oder Meet. Mit Kopfh\u{00F6}rern wird das Transkript am saubersten.")
        case .systemOnly:
            return String(localized: "Nimmt nur das System-Audio auf, zum Beispiel f\u{00FC}r ein Webinar oder ein Video. Dein Mikrofon bleibt aus, alle Stimmen sind Personen.")
        }
    }

    var icon: String {
        switch self {
        case .room: return "person.2.wave.2.fill"
        case .online: return "video.fill"
        case .systemOnly: return "speaker.wave.2.fill"
        }
    }

    /// The stored choice. Without one, the old switch decides, so nobody loses their setting.
    static func resolve(stored: String, legacySystemAudio: Bool, canRecordSystemAudio: Bool) -> MeetingSource {
        let source = MeetingSource(rawValue: stored) ?? (legacySystemAudio ? .online : .room)
        return canRecordSystemAudio ? source : .room
    }

    /// What the stored choice is today.
    static func current(canRecordSystemAudio: Bool, defaults: UserDefaults = .standard) -> MeetingSource {
        resolve(
            stored: defaults.string(forKey: storageKey) ?? "",
            legacySystemAudio: defaults.bool(forKey: legacyStorageKey),
            canRecordSystemAudio: canRecordSystemAudio
        )
    }
}
