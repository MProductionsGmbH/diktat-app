import Foundation

/// The macOS permission "System Audio Recording" (Privacy & Security > Screen & System Audio
/// Recording). Without it a Core Audio tap delivers silence and no error, so Diktat asks the
/// permission system beforehand. macOS has no public call for that; this uses the same private
/// one the system itself uses. If it is missing (a future macOS), `status` says so and the
/// recording simply starts, as before.
enum SystemAudioPermission {
    enum Status: Equatable {
        case authorized
        case denied
        case notDetermined
        /// The permission system cannot be asked.
        case unavailable
    }

    private static let service = "kTCCServiceAudioCapture" as CFString
    private static let library = dlopen("/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC", RTLD_NOW)

    private typealias Preflight = @convention(c) (CFString, CFDictionary?) -> Int
    private typealias Request = @convention(c) (CFString, CFDictionary?, @escaping (Bool) -> Void) -> Void

    /// What the permission system answers: 0 allowed, 1 refused, 2 not asked yet. Nil without the call.
    static var rawAnswer: Int? {
        guard let library, let symbol = dlsym(library, "TCCAccessPreflight") else { return nil }
        return unsafeBitCast(symbol, to: Preflight.self)(service, nil)
    }

    static var status: Status {
        guard let answer = rawAnswer else { return .unavailable }
        switch answer {
        case 0: return .authorized
        case 1: return .denied
        default: return .notDetermined
        }
    }

    /// Shows the macOS question. `completion` runs on the main thread.
    static func request(completion: @escaping @MainActor (Bool) -> Void) {
        guard let library, let symbol = dlsym(library, "TCCAccessRequest") else {
            Task { @MainActor in completion(true) }
            return
        }
        let request = unsafeBitCast(symbol, to: Request.self)
        request(service, nil) { granted in
            Task { @MainActor in completion(granted) }
        }
    }

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")!
}
