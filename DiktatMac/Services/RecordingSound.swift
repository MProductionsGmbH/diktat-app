import AppKit

/// The soft "plop" when a recording starts, so you hear that Diktat listens before you speak.
@MainActor
enum RecordingSound {
    /// Held while it plays; a sound released too early is cut off.
    private static var current: NSSound?

    static func playStart() {
        guard let url = Bundle.main.url(forResource: "start", withExtension: "wav"),
              let sound = NSSound(contentsOf: url, byReference: true) else { return }
        sound.volume = 0.6
        current = sound
        sound.play()
    }
}
