import XCTest

final class VoiceBarMotionTests: XCTestCase {
    func testBarsStandStillAndSmallWhenItIsQuiet() {
        for level: Float in [0, 0.05, 0.1, 0.12] {
            for index in 0..<5 {
                for phase in stride(from: 0.0, to: 7.0, by: 0.7) {
                    XCTAssertEqual(VoiceBarMotion.scale(index: index, level: level, phase: phase), VoiceBarMotion.rest, accuracy: 0.0001)
                }
            }
        }
    }

    func testBarsSwingOutWhenSomeoneSpeaks() {
        let speaking = (0..<5).map { VoiceBarMotion.scale(index: $0, level: 0.5, phase: 1.0) }
        XCTAssertTrue(speaking.allSatisfy { $0 > VoiceBarMotion.rest + 0.2 })
        let loud = (0..<5).map { VoiceBarMotion.scale(index: $0, level: 1, phase: 2.0) }
        XCTAssertTrue(loud.allSatisfy { $0 > 0.6 && $0 <= 1 })
    }

    func testLouderIsNeverSmaller() {
        var last = 0.0
        for level in stride(from: Float(0), through: 1, by: 0.1) {
            let value = VoiceBarMotion.scale(index: 2, level: level, phase: 0.5)
            XCTAssertGreaterThanOrEqual(value, last - 0.0001)
            last = value
        }
    }
}
