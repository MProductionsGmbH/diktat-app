import Foundation

/// The recordings of meetings on disk: "<id>.wav" for the microphone and "<id>-system.caf" for
/// what the Mac played.
enum MeetingAudioFiles {
    /// The names in `names` that are recordings of none of the meetings `ids`. Files that are
    /// no recording (the list of meetings, a file put aside) are never named.
    static func orphaned(in names: [String], keeping ids: Set<UUID>) -> [String] {
        names.filter { name in
            let stem: String
            if name.hasSuffix("-system.caf") {
                stem = String(name.dropLast("-system.caf".count))
            } else if name.hasSuffix(".wav") {
                stem = String(name.dropLast(".wav".count))
            } else {
                return false
            }
            guard let id = UUID(uuidString: stem) else { return false }
            return !ids.contains(id)
        }
    }
}
