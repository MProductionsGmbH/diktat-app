import Foundation

/// Which buffers of an aggregate device's input belong to the system sound tap.
///
/// The aggregate device that carries the tap also carries the output device that clocks it.
/// When that device has an input of its own (a headset, a speakerphone, a virtual device such
/// as "Microsoft Teams Audio"), every callback delivers that input first and the tap after it.
/// Reading the first buffer then records the device's microphone instead of what the Mac plays.
/// The tap always comes last.
enum TapBufferSelection {
    /// The indices of the tap's buffers among `bufferCount` delivered ones: one buffer for an
    /// interleaved format, one per channel otherwise. Nil when there are too few.
    static func range(bufferCount: Int, isInterleaved: Bool, channelCount: Int) -> Range<Int>? {
        let needed = isInterleaved ? 1 : max(1, channelCount)
        guard bufferCount >= needed else { return nil }
        return (bufferCount - needed)..<bufferCount
    }
}
