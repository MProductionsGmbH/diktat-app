import Foundation
import OSLog

private let cleanupLogger = Logger(subsystem: "app.diktat.mac", category: "SpeechCleanup")

// The model call of the cleanup levels. Kept apart from SpeechCleanup.swift because it needs
// TextRewriter and TranscriptionQualityService, which the test bundle does not compile.
extension SpeechCleanup {
    struct Configuration {
        var level: SpeechCleanupLevel = .light
        var engine: TextRewriter.Engine = .automatic
        /// Names and terms the model must keep spelled exactly.
        var protectedTerms: [String] = []
    }

    /// Runs the model step for `medium` and `strong`; `light` and short text come back as given.
    static func polish(_ text: String, configuration: Configuration) async -> String {
        guard configuration.level.usesLanguageModel,
              wordCount(text) >= minimumWords,
              TextRewriter.canRewrite(engine: configuration.engine) else { return text }
        do {
            let rewritten = try await TextRewriter.rewrite(
                text,
                instruction: instruction(for: configuration.level, protectedTerms: configuration.protectedTerms),
                engine: configuration.engine,
                deterministic: true
            )
            let candidate = TranscriptionQualityService.cleanedTranscript(rewritten)
            guard isPlausible(candidate, for: text, level: configuration.level) else {
                cleanupLogger.info("Cleanup answer rejected, text kept as dictated")
                return text
            }
            return candidate
        } catch {
            cleanupLogger.error("Cleanup failed: \(error.localizedDescription, privacy: .public)")
            return text
        }
    }
}
