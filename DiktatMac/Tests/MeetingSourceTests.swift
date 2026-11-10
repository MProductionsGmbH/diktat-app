import XCTest

final class MeetingSourceTests: XCTestCase {
    func testWithoutChoiceTheOldSwitchDecides() {
        XCTAssertEqual(MeetingSource.resolve(stored: "", legacySystemAudio: true, canRecordSystemAudio: true), .online)
        XCTAssertEqual(MeetingSource.resolve(stored: "", legacySystemAudio: false, canRecordSystemAudio: true), .room)
    }

    func testChoiceBeatsTheOldSwitch() {
        XCTAssertEqual(MeetingSource.resolve(stored: "systemOnly", legacySystemAudio: false, canRecordSystemAudio: true), .systemOnly)
        XCTAssertEqual(MeetingSource.resolve(stored: "room", legacySystemAudio: true, canRecordSystemAudio: true), .room)
    }

    func testUnknownChoiceFallsBackToTheOldSwitch() {
        XCTAssertEqual(MeetingSource.resolve(stored: "nonsense", legacySystemAudio: true, canRecordSystemAudio: true), .online)
    }

    func testWithoutSystemAudioOnlyTheRoomIsLeft() {
        XCTAssertEqual(MeetingSource.resolve(stored: "online", legacySystemAudio: true, canRecordSystemAudio: false), .room)
    }

    func testWhatEachSourceRecords() {
        XCTAssertTrue(MeetingSource.room.usesMicrophone)
        XCTAssertFalse(MeetingSource.room.usesSystemAudio)
        XCTAssertTrue(MeetingSource.online.usesMicrophone)
        XCTAssertTrue(MeetingSource.online.usesSystemAudio)
        XCTAssertFalse(MeetingSource.systemOnly.usesMicrophone)
        XCTAssertTrue(MeetingSource.systemOnly.usesSystemAudio)
    }
}

final class CallDetectionTests: XCTestCase {
    private func candidate(_ id: String, input: Bool = true, output: Bool = false) -> CallDetection.Candidate {
        CallDetection.Candidate(bundleID: id, isRunningInput: input, isRunningOutput: output)
    }

    func testCallAppWithOpenMicrophoneIsACall() {
        XCTAssertEqual(CallDetection.calls(in: [candidate("us.zoom.xos")]), ["Zoom"])
        XCTAssertEqual(CallDetection.calls(in: [candidate("com.microsoft.teams2")]), ["Teams"])
    }

    func testCallAppWithoutMicrophoneIsNot() {
        XCTAssertTrue(CallDetection.calls(in: [candidate("us.zoom.xos", input: false, output: true)]).isEmpty)
    }

    func testBrowserNeedsSoundInAndOut() {
        XCTAssertTrue(CallDetection.calls(in: [candidate("com.google.Chrome.helper", input: true, output: false)]).isEmpty)
        XCTAssertEqual(CallDetection.calls(in: [candidate("com.google.Chrome.helper", input: true, output: true)]), ["Browser"])
    }

    func testOtherAppsAreNoCalls() {
        XCTAssertTrue(CallDetection.calls(in: [candidate("com.apple.QuickTimePlayerX", input: true, output: true)]).isEmpty)
    }

    func testNoRepeatsForSeveralProcessesOfOneApp() {
        let processes = [candidate("us.zoom.xos"), candidate("us.zoom.xos.helper"), candidate("com.microsoft.teams2")]
        XCTAssertEqual(CallDetection.calls(in: processes), ["Zoom", "Teams"])
    }
}
