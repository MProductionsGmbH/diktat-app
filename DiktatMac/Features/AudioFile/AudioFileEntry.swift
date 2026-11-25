import Foundation

/// A transcribed audio file as the page "Audiodatei" lists it. Only the text is kept, never
/// the sound: the file itself is read once and left where it is.
struct AudioFileEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let fileName: String
    let duration: TimeInterval
    /// What was said, as transcribed.
    let transcript: String
    /// What the page shows: the transcript or the latest rewrite of it.
    var text: String
    /// The mode `text` was written in, as the raw value of `WorkflowType`.
    var mode: String
}

/// How long the texts of transcribed audio files stay. Pure logic, so it is tested without
/// the store.
enum AudioFileRetention {
    /// Seven days, then the text disappears.
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    /// The entries that are still kept at `now`, newest first.
    static func kept(_ entries: [AudioFileEntry], now: Date) -> [AudioFileEntry] {
        entries
            .filter { now.timeIntervalSince($0.createdAt) < maxAge }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
