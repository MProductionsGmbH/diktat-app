import Foundation

/// Scales the input level to the microphone at hand. A webcam microphone a metre away reaches 0.3 when
/// someone speaks, a headset 0.8; the bars of the recording pill and the menu bar symbol should use their
/// full height for both. The loudest recent level counts as full scale, falling back slowly (about two
/// seconds to half), and never below a floor, so room noise does not fill the scale.
struct AdaptiveLevel {
    /// The level that counts as full scale at least: a quiet room stays quiet on the bars.
    static let minimumPeak: Float = 0.25
    /// Below this the input counts as silence.
    static let floor: Float = 0.05
    /// Per call; the recorder calls it every 50 ms, so this halves in about two seconds.
    private static let decay: Float = 0.985

    private(set) var peak: Float = AdaptiveLevel.minimumPeak

    mutating func normalize(_ raw: Float) -> Float {
        peak = max(raw, peak * Self.decay, Self.minimumPeak)
        return min(1, max(0, (raw - Self.floor) / (peak - Self.floor)))
    }

    mutating func reset() {
        peak = Self.minimumPeak
    }
}
