import XCTest

final class MicrophoneSelectionTests: XCTestCase {
    private let builtIn = InputDevice(uid: "BuiltInMicrophoneDevice", name: "MacBook Pro-Mikrofon")
    private let studio = InputDevice(uid: "AppleUSBAudioEngine:Studio:1", name: "Studio-Mikrofon")

    func testNothingPickedFollowsTheSystemDefault() {
        XCTAssertEqual(MicrophoneSelection.resolve(preferredUID: nil, available: [builtIn, studio]), .systemDefault)
        XCTAssertEqual(MicrophoneSelection.resolve(preferredUID: "", available: [builtIn, studio]), .systemDefault)
    }

    func testPickedDeviceIsUsedWhileConnected() {
        XCTAssertEqual(
            MicrophoneSelection.resolve(preferredUID: studio.uid, available: [builtIn, studio]),
            .device(studio)
        )
    }

    func testPickedDeviceThatIsGoneIsReportedMissing() {
        XCTAssertEqual(
            MicrophoneSelection.resolve(preferredUID: studio.uid, available: [builtIn]),
            .missing(uid: studio.uid)
        )
    }

    func testPickedDeviceComesBackWhenPluggedInAgain() {
        XCTAssertEqual(MicrophoneSelection.resolve(preferredUID: studio.uid, available: []), .missing(uid: studio.uid))
        XCTAssertEqual(MicrophoneSelection.resolve(preferredUID: studio.uid, available: [studio]), .device(studio))
    }
}
