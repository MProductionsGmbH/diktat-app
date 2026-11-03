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
        var text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Whisper decodes a stretch of room noise at the end as a window of its own and invents a closing
        // there ("Thank you."). Segments over hardly any speech are dropped before the text is built.
        let segments = results.flatMap(\.segments).map { segment -> HallucinationFilter.Segment in
            let from = min(samples.count, max(0, Int(Double(segment.start) * 16_000)))
            let to = min(samples.count, max(from, Int(Double(segment.end) * 16_000)))
            return HallucinationFilter.Segment(
                text: segment.text,
                voicedSeconds: HallucinationFilter.voicedSeconds(Array(samples[from..<to]))
            )
        }
        let kept = HallucinationFilter.removingSilentSegments(segments)
        if kept.count < segments.count {
            text = kept
                .map { HallucinationFilter.strippingTokens($0.text) }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if HallucinationFilter.isInvented(text, voicedSeconds: HallucinationFilter.voicedSeconds(samples)) {
            return ""
        }
        return HallucinationFilter.removingTrailingCredits(text)
    }

    /// The words of a recording with their times, for a meeting: every word is placed with a person by its time.
    /// Stretches of room noise that Whisper filled with an invented phrase are left out.
    static func words(_ pipeline: WhisperKit, audioPath: String, language: String? = nil) async throws -> [TimedWord] {
        let samples = try AudioProcessor.loadAudioAsFloatArray(fromPath: audioPath)
        var options = DecodingOptions(task: .transcribe, language: language, detectLanguage: language == nil)
        options.wordTimestamps = true
        let results = try await pipeline.transcribe(audioArray: samples, decodeOptions: options)
        let segments = results.flatMap(\.segments)
        let voiced = segments.map { segment -> Double in
            let from = min(samples.count, max(0, Int(Double(segment.start) * 16_000)))
            let to = min(samples.count, max(from, Int(Double(segment.end) * 16_000)))
            return HallucinationFilter.voicedSeconds(Array(samples[from..<to]))
        }
        // A quiet speaker far from the microphone must stay: only short segments can be invented.
        let flags = HallucinationFilter.keepFlags(voicedSeconds: voiced)
        var words: [TimedWord] = []
        for (index, segment) in segments.enumerated() {
            let segmentWords = segment.words ?? []
            if !flags[index], segmentWords.count <= 3 { continue }
            for word in segmentWords {
                let text = HallucinationFilter.strippingTokens(word.word)
                guard !text.isEmpty else { continue }
                words.append(TimedWord(text: text, start: TimeInterval(word.start), end: TimeInterval(word.end)))
            }
        }
        return words.sorted { $0.start < $1.start }
    }
}
