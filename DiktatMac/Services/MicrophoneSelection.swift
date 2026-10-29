import Foundation

/// A microphone macOS knows about. The UID stays the same when the device is unplugged and
/// connected again, so that is what the setting stores.
struct InputDevice: Identifiable, Equatable, Hashable {
    let uid: String
    let name: String

    var id: String { uid }
}

/// Which microphone a recording uses: the one the user picked, or what macOS has as default.
enum MicrophoneSelection {
    enum Resolution: Equatable {
        /// Nothing picked: the recording follows the Mac's default input.
        case systemDefault
        case device(InputDevice)
        /// A device was picked but is not connected now; the recording uses the default input.
        case missing(uid: String)
    }

    static func resolve(preferredUID: String?, available: [InputDevice]) -> Resolution {
        guard let preferredUID, !preferredUID.isEmpty else { return .systemDefault }
        if let device = available.first(where: { $0.uid == preferredUID }) {
            return .device(device)
        }
        return .missing(uid: preferredUID)
    }
}
