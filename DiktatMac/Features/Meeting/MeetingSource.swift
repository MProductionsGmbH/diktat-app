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

    /// The two cards on the meeting page. An online meeting without the own microphone
    /// (`systemOnly`) is the online card with its switch turned off.
    static let cards: [MeetingSource] = [.room, .online]

    /// The card this source belongs to.
    var card: MeetingSource { self == .room ? .room : .online }

    /// The source the online card stands for, with or without the own microphone.
    static func online(withMicrophone: Bool) -> MeetingSource { withMicrophone ? .online : .systemOnly }

    var title: String {
        switch self {
        case .room: return String(localized: "Im Raum")
        case .online: return String(localized: "Online-Meeting")
        case .systemOnly: return String(localized: "Online ohne Mikrofon")
        }
    }

    var subtitle: String {
        switch self {
        case .room: return String(localized: "Mikrofon des Computers")
        case .online: return String(localized: "System-Audio + Mikrofon")
        case .systemOnly: return String(localized: "Nur System-Audio")
        }
    }

    var explanation: String {
        switch self {
        case .room:
            return String(localized: "Nimmt das Mikrofon des Computers auf, gedacht f\u{00FC}r Meetings im Raum.")
        case .online:
            return String(localized: "Die anderen kommen \u{00FC}ber das System-Audio (was dein Mac abspielt, etwa aus Teams, Zoom oder Meet), du \u{00FC}ber dein Mikrofon. Im Transkript bist du \u{201E}Ich\u{201C}. Mit Kopfh\u{00F6}rern wird es am saubersten.")
        case .systemOnly:
            return String(localized: "Nimmt nur das System-Audio auf, also was dein Mac abspielt. Was du selbst sagst, fehlt im Transkript. Gedacht f\u{00FC}r Webinare und Videos.")
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
