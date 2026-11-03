import Foundation

/// The speech model that turns a meeting into words with times. It is the model picked for dictation:
/// Whisper or Parakeet. Both give every word a time, which places it with a person.
enum MeetingTranscriber {
    /// The model picked in the settings; AppState keeps it current.
    nonisolated(unsafe) static var preferredModelName = LocalTranscriptionService.initialModelName

    /// The model a meeting uses: the picked one while it is installed, else the first installed.
    static var modelName: String {
        let name = LocalTranscriptionService.normalizedModelName(preferredModelName)
        // Both turbo builds are one entry in the list; use the build this Mac has.
        let picked = LocalTranscriptionService.turboModelNames.contains(name)
            ? LocalTranscriptionService.turboModelName(selected: name)
            : name
        return LocalTranscriptionService.resolvedModelName(picked)
    }

    /// Why a meeting cannot start, or nil.
    static var blocker: String? {
        guard ParakeetTranscriber.isSupported else {
            return String(localized: "Meetings brauchen einen Mac mit Apple-Chip.")
        }
        return LocalTranscriptionService.isModelInstalled(modelName)
            ? nil
            : String(localized: "F\u{00FC}r Meetings braucht Diktat ein Sprachmodell. Bitte in den Einstellungen unter Sprachmodell laden.")
    }

    static func words(audioURL: URL, language: String) async throws -> [TimedWord] {
        let model = modelName
        if model == ParakeetTranscriber.modelName {
            return try await ParakeetTranscriber.shared.transcribeWords(audioURL: audioURL, language: language)
        }
        return try await LocalTranscriptionService.shared.transcribeWords(audioURL: audioURL, language: language, modelName: model)
    }
}
