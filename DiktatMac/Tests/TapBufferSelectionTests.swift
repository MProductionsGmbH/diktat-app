import XCTest

final class TapBufferSelectionTests: XCTestCase {
    /// Speakers or a display: the tap is all there is.
    func testTapAloneIsTheOnlyBuffer() {
        XCTAssertEqual(TapBufferSelection.range(bufferCount: 1, isInterleaved: true, channelCount: 2), 0..<1)
    }

    /// A headset or "Microsoft Teams Audio" as output: its own input comes first, the tap last.
    /// Reading the first buffer recorded the headset's microphone instead of the Mac's sound.
    func testTapComesAfterTheInputOfTheOutputDevice() {
        XCTAssertEqual(TapBufferSelection.range(bufferCount: 2, isInterleaved: true, channelCount: 2), 1..<2)
        XCTAssertEqual(TapBufferSelection.range(bufferCount: 3, isInterleaved: true, channelCount: 2), 2..<3)
    }

    func testOneBufferPerChannelWhenNotInterleaved() {
        XCTAssertEqual(TapBufferSelection.range(bufferCount: 2, isInterleaved: false, channelCount: 2), 0..<2)
        XCTAssertEqual(TapBufferSelection.range(bufferCount: 3, isInterleaved: false, channelCount: 2), 1..<3)
    }

    func testTooFewBuffersGiveNothing() {
        XCTAssertNil(TapBufferSelection.range(bufferCount: 0, isInterleaved: true, channelCount: 2))
        XCTAssertNil(TapBufferSelection.range(bufferCount: 1, isInterleaved: false, channelCount: 2))
    }
}
