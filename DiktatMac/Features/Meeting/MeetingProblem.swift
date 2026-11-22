import Foundation

/// Something is wrong with a running recording, and whoever runs the meeting has to know now:
/// what is not recorded cannot be brought back afterwards. Shown large on the meeting page, in
/// the floating pill, in the menu bar and as a notification with a sound.
enum MeetingProblem: Int, CaseIterable, Comparable {
    /// No microphone opens; the capture keeps trying.
    case microphoneLost
    /// The microphone is open but delivers digital silence: muted, or a MacBook with the lid closed.
    case microphoneSilent
    /// The output device is gone, so the Mac's sound cannot be recorded; the capture keeps trying.
    case systemAudioLost

    /// The most urgent first.
    static func < (lhs: MeetingProblem, rhs: MeetingProblem) -> Bool { lhs.rawValue < rhs.rawValue }

    /// How long a microphone may deliver nothing but digital silence before it counts as a problem.
    static let silenceBeforeWarning: TimeInterval = 5
    /// Digital silence reads about -120 dB; the quietest real room is far above -110.
    static let silenceLevelDB: Float = -110

    var title: String {
        switch self {
        case .microphoneLost: return String(localized: "Das Mikrofon ist nicht erreichbar")
        case .microphoneSilent: return String(localized: "Das Mikrofon liefert keinen Ton")
        case .systemAudioLost: return String(localized: "Das System-Audio ist nicht erreichbar")
        }
    }

    var detail: String {
        switch self {
        case .microphoneLost:
            return String(localized: "Diktat findet gerade kein Mikrofon und versucht es weiter. Bis dahin fehlt im Transkript, was gesagt wird. Ist das Mikrofon angeschlossen?")
        case .microphoneSilent:
            return String(localized: "Vom Mikrofon kommt nur Stille. Bis es wieder Ton liefert, fehlt im Transkript, was gesagt wird. Ist es stumm geschaltet oder das MacBook zugeklappt?")
        case .systemAudioLost:
            return String(localized: "Das Ausgabeger\u{00E4}t ist weg. Diktat versucht es weiter. Bis dahin fehlen im Transkript die anderen.")
        }
    }

    /// For the floating pill, which has room for two words.
    var shortLabel: String {
        switch self {
        case .microphoneLost, .microphoneSilent: return String(localized: "Mikrofon pr\u{00FC}fen")
        case .systemAudioLost: return String(localized: "Ton pr\u{00FC}fen")
        }
    }
}

/// Tells when a microphone has delivered nothing but digital silence for too long.
struct MicrophoneSilenceTracker {
    private var silentSince: Date?

    /// Takes the level of the newest audio and says whether the silence now is a problem.
    mutating func isSilentTooLong(powerDB: Float, now: Date = Date()) -> Bool {
        guard powerDB < MeetingProblem.silenceLevelDB else {
            silentSince = nil
            return false
        }
        let since = silentSince ?? now
        silentSince = since
        return now.timeIntervalSince(since) >= MeetingProblem.silenceBeforeWarning
    }

    mutating func reset() {
        silentSince = nil
    }
}
