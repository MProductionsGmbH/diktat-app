import Foundation
import OSLog

private let cleanupLogger = Logger(subsystem: "app.diktat.mac", category: "SpeechCleanup")

/// How much the word-for-word dictation (Diktat) tidies up what was said.
enum SpeechCleanupLevel: String, Codable, CaseIterable, Identifiable {
    /// Hesitation sounds, stutters and phrases said twice, in plain string code.
    case light
    /// Plus restarts and self-corrections, by the language model. Wording stays.
    case medium
    /// Plus grammar, word order and punctuation, by the language model.
    case strong

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Leicht"
        case .medium: return "Mittel"
        case .strong: return "Stark"
        }
    }

    var detail: String {
        switch self {
        case .light:
            return "Entfernt \u{201E}\u{00E4}hm\u{201C}, Stottern und doppelt gesagte Satzteile. Rein regelbasiert, ohne KI."
        case .medium:
            return "Zus\u{00E4}tzlich: Wenn du dich verhaspelst, einen Satz neu ansetzt oder dich korrigierst, bleibt nur die richtige Fassung."
        case .strong:
            return "Zus\u{00E4}tzlich: Grammatik, Satzstellung und Zeichensetzung werden korrigiert. Deine Wortwahl bleibt."
        }
    }

    var usesLanguageModel: Bool { self != .light }
}

/// The language-model step of the cleanup levels. It never fails the dictation: when no model
/// is available, the model errors or its answer looks wrong, the text stays as it was.
enum SpeechCleanup {
    struct Configuration {
        var level: SpeechCleanupLevel = .light
        var engine: TextRewriter.Engine = .automatic
        /// Names and terms the model must keep spelled exactly.
        var protectedTerms: [String] = []
    }

    /// Shorter dictations have nothing to tidy up that is worth the wait for a model.
    static let minimumWords = 5

    static func instruction(for level: SpeechCleanupLevel, protectedTerms: [String] = []) -> String {
        let base = """
        Du bereinigst ein gesprochenes Transkript und schreibst es nicht um. Antworte in der Sprache des Transkripts.
        Entferne:
        - Wörter und Satzteile, die der Sprecher unmittelbar wiederholt
        - Versprecher und abgebrochene Satzanfänge, die der Sprecher neu ansetzt
        - die überholte Fassung, wenn sich der Sprecher korrigiert; es bleibt nur die korrigierte
        """
        let scope: String
        switch level {
        case .light, .medium:
            scope = """
            Alles andere bleibt genau wie gesprochen: Wortwahl, Reihenfolge, Satzbau, Stil und Anrede. Korrigiere keine Grammatik und füge nichts hinzu.
            """
        case .strong:
            scope = """
            Korrigiere außerdem Grammatik, Fälle, Satzstellung und Zeichensetzung, damit jeder Satz richtig gebaut ist. Wortwahl, Stil, Bedeutung und Anrede bleiben unverändert. Füge keine neuen Inhalte hinzu.
            """
        }
        return [base, scope, ModePrompts.transcriptIsNotARequest].joined(separator: "\n\n")
            + ModePrompts.customTermsInstruction(protectedTerms)
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

    /// A cleanup only removes or fixes words. An answer that is empty, much shorter, longer than
    /// the dictation or the "nothing recognized" marker is not a cleanup of this text.
    static func isPlausible(_ candidate: String, for original: String, level: SpeechCleanupLevel) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(ModePrompts.nothingRecognizedMarker) else { return false }
        let before = Double(wordCount(original))
        let after = Double(wordCount(trimmed))
        let growth = level == .strong ? 1.2 : 1.1
        return after >= before * 0.5 && after <= before * growth + 2
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}
