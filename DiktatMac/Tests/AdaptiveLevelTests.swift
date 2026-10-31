import XCTest

final class AdaptiveLevelTests: XCTestCase {
    func testAQuietMicrophoneStillUsesTheFullScale() {
        var level = AdaptiveLevel()
        // A webcam: speech peaks around 0.39 and mostly sits near 0.1 to 0.25.
        var loudest: Float = 0
        for raw in stride(from: Float(0.1), through: 0.39, by: 0.03) {
            loudest = max(loudest, level.normalize(raw))
        }
        XCTAssertEqual(level.normalize(0.39), 1, accuracy: 0.001)
        XCTAssertEqual(loudest, 1, accuracy: 0.001)
        XCTAssertGreaterThan(level.normalize(0.25), 0.4, "ordinary speech is well above the dots")
    }

    func testRoomNoiseStaysAtZero() {
        var level = AdaptiveLevel()
        for raw in [Float(0), 0.01, 0.03, 0.05, 0.04] {
            XCTAssertEqual(level.normalize(raw), 0)
        }
    }

    func testALoudMicrophoneDoesNotClip() {
        var level = AdaptiveLevel()
        XCTAssertEqual(level.normalize(0.9), 1, accuracy: 0.001)
        XCTAssertLessThan(level.normalize(0.45), 0.6)
    }

    func testTheScaleFallsBackAfterALoudMoment() {
        var level = AdaptiveLevel()
        _ = level.normalize(0.9)
        let right = level.normalize(0.3)
        for _ in 0..<150 { _ = level.normalize(0.1) }   // about seven and a half seconds
        XCTAssertGreaterThan(level.normalize(0.3), right + 0.2)
        XCTAssertGreaterThanOrEqual(level.peak, AdaptiveLevel.minimumPeak)
    }

    func testResetStartsFromTheFloorScale() {
        var level = AdaptiveLevel()
        _ = level.normalize(0.9)
        level.reset()
        XCTAssertEqual(level.peak, AdaptiveLevel.minimumPeak, accuracy: 0.0001)
    }
}
