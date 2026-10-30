import Foundation

/// How the five bars of the Diktat mark move while recording, for the pill at the bottom of the
/// screen and the symbol in the menu bar alike: still and small while it is quiet, swinging
/// out only when someone speaks.
enum VoiceBarMotion {
    /// The height of a bar, as a share of its full height, when nothing is said.
    static let rest = 0.42
    /// Below this input level (0...1, see `AudioRecorder.audioLevel`) the room counts as quiet:
    /// room noise reads about 0.1, speech 0.4 and above.
    static let gate = 0.12

    /// - Parameters:
    ///   - index: The bar, 0 to 4.
    ///   - level: The input level 0...1.
    ///   - phase: A running angle, so the bars do not all swing alike.
    static func scale(index: Int, level: Float, phase: Double) -> Double {
        let voice = min(1, max(0, (Double(level) - gate) / 0.5))
        let wobble = 0.5 + 0.5 * sin(phase + Double(index) * 1.3)
        return rest + (1 - rest) * voice * (0.55 + 0.45 * wobble)
    }
}
