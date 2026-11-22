import XCTest

final class MeetingProblemTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    /// A short gap between two speakers is no problem; only lasting digital silence is.
    func testSilenceCountsOnlyAfterAWhile() {
        var tracker = MicrophoneSilenceTracker()
        XCTAssertFalse(tracker.isSilentTooLong(powerDB: -160, now: start))
        XCTAssertFalse(tracker.isSilentTooLong(powerDB: -160, now: start.addingTimeInterval(4.9)))
        XCTAssertTrue(tracker.isSilentTooLong(powerDB: -160, now: start.addingTimeInterval(5)))
        XCTAssertTrue(tracker.isSilentTooLong(powerDB: -120, now: start.addingTimeInterval(30)))
    }

    /// A quiet room is far above digital silence and never a problem.
    func testAQuietRoomIsNoSilence() {
        var tracker = MicrophoneSilenceTracker()
        for second in 0..<60 {
            XCTAssertFalse(tracker.isSilentTooLong(powerDB: -70, now: start.addingTimeInterval(Double(second))))
        }
    }

    func testSoundEndsTheSilence() {
        var tracker = MicrophoneSilenceTracker()
        _ = tracker.isSilentTooLong(powerDB: -160, now: start)
        XCTAssertTrue(tracker.isSilentTooLong(powerDB: -160, now: start.addingTimeInterval(6)))
        XCTAssertFalse(tracker.isSilentTooLong(powerDB: -40, now: start.addingTimeInterval(7)))
        // The clock starts again with the next silence.
        XCTAssertFalse(tracker.isSilentTooLong(powerDB: -160, now: start.addingTimeInterval(8)))
        XCTAssertFalse(tracker.isSilentTooLong(powerDB: -160, now: start.addingTimeInterval(12)))
        XCTAssertTrue(tracker.isSilentTooLong(powerDB: -160, now: start.addingTimeInterval(13)))
    }

    func testAPauseStartsTheClockAgain() {
        var tracker = MicrophoneSilenceTracker()
        _ = tracker.isSilentTooLong(powerDB: -160, now: start)
        tracker.reset()
        XCTAssertFalse(tracker.isSilentTooLong(powerDB: -160, now: start.addingTimeInterval(6)))
    }

    /// With several problems at once the page shows the most urgent.
    func testAMissingMicrophoneOutranksTheRest() {
        XCTAssertEqual([MeetingProblem.systemAudioLost, .microphoneSilent, .microphoneLost].min(), .microphoneLost)
        XCTAssertEqual([MeetingProblem.systemAudioLost, .microphoneSilent].min(), .microphoneSilent)
    }

    // MARK: Two cards

    func testTheOnlineCardCoversBothOnlineSources() {
        XCTAssertEqual(MeetingSource.cards, [.room, .online])
        XCTAssertEqual(MeetingSource.systemOnly.card, .online)
        XCTAssertEqual(MeetingSource.online.card, .online)
        XCTAssertEqual(MeetingSource.room.card, .room)
        XCTAssertEqual(MeetingSource.online(withMicrophone: true), .online)
        XCTAssertEqual(MeetingSource.online(withMicrophone: false), .systemOnly)
    }
}
