import Foundation
import WhisperKit

/// How both apps run Whisper on a dictation: language detection and dropping text that
/// Whisper most likely invented.
///
/// No dictionary prompt: with WhisperKit 0.18 and Large v3 Turbo, any `promptTokens`
/// (even a single word) made the decoder stop at once and return an empty text.
enum WhisperDictation {
    /// - Parameter language: A language code to listen for only; nil detects the spoken language.
    static func transcribe(_ pipeline: WhisperKit, audioPath: String, language: String? = nil) async throws -> String {
        let samples = try AudioProcessor.loadAudioAsFloatArray(fromPath: audioPath)
        // By default no fixed language: Whisper follows a given language strictly and turns English
        // speech into German. Detection keeps every dictation in its spoken language. A language the
        // user picked in the settings is followed on purpose.
        let options = DecodingOptions(task: .transcribe, language: language, detectLanguage: language == nil)
        let results = try await pipeline.transcribe(audioArray: samples, decodeOptions: options)
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if HallucinationFilter.isInvented(text, voicedSeconds: HallucinationFilter.voicedSeconds(samples)) {
            return ""
        }
        return HallucinationFilter.removingTrailingCredits(text)
    }
}
