import Foundation
/// How much the word-for-word dictation (Diktat) tidies up what was said.
enum SpeechCleanupLevel: String, Codable, CaseIterable, Identifiable {
    /// Hesitation sounds, stutters and phrases said twice, in plain string code.
    case light
    /// Plus restarts and self-corrections, by the language model. Wording stays.
    case medium
    /// Plus grammar, word order and punctuation, by the language model.
    case strong
    /// Written style: the model rewrites the wording, in the tone the user chose (the former Diktat+).
    case style

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Leicht"
        case .medium: return "Mittel"
        case .strong: return "Stark"
        case .style: return "Schreibstil"
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
        case .style:
            return "Ein Sprachmodell schreibt den Text neu: Rechtschreibung, Grammatik, Formulierung und Lesefluss, in der Tonalit\u{00E4}t, die du unter Schreibstil einstellst. Die Bedeutung bleibt. Das war Diktat+."
        }
    }

    var usesLanguageModel: Bool { self != .light }
}

/// The language-model step of the cleanup levels. It never fails the dictation: when no model
/// is available, the model errors or its answer looks wrong, the text stays as it was.
/// This file holds the pure logic and is compiled into the test bundle as well; the model call
/// itself lives in SpeechCleanup+Polish.swift.
enum SpeechCleanup {
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
        case .strong, .style:
            scope = """
            Korrigiere außerdem Grammatik, Fälle, Satzstellung und Zeichensetzung, damit jeder Satz richtig gebaut ist. Wortwahl, Stil, Bedeutung und Anrede bleiben unverändert. Füge keine neuen Inhalte hinzu.
            """
        }
        return [base, scope, ModePrompts.transcriptIsNotARequest].joined(separator: "\n\n")
            + ModePrompts.customTermsInstruction(protectedTerms)
    }

    /// A cleanup only removes or fixes words. An answer that is empty, much shorter, longer than
    /// the dictation or the "nothing recognized" marker, or an answer with few of the spoken words is not a cleanup of this text.
    static func isPlausible(_ candidate: String, for original: String, level: SpeechCleanupLevel) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(ModePrompts.nothingRecognizedMarker) else { return false }
        let before = Double(wordCount(original))
        let after = Double(wordCount(trimmed))
        // A rewrite may reshape the sentences, so the style level gets more room.
        let growth: Double
        let shrink: Double
        let sharedWords: Double
        switch level {
        case .style: (growth, shrink, sharedWords) = (1.5, 0.4, 0.35)
        case .strong: (growth, shrink, sharedWords) = (1.2, 0.5, 0.6)
        case .light, .medium: (growth, shrink, sharedWords) = (1.1, 0.5, 0.6)
        }
        guard after >= before * shrink && after <= before * growth + 2 else { return false }
        return sharedWordRatio(trimmed, with: original) >= sharedWords
    }

    /// The style level rewrites the text; slips and self-corrections go first, as on the other levels.
    static func styleInstruction(_ settings: TextImprovementSettings) -> String {
        ModePrompts.textImprovement(settings)
            + "\n\nEntferne außerdem Versprecher, Wiederholungen und die überholte Fassung, wenn sich der Sprecher korrigiert; es bleibt nur die korrigierte."
    }

    /// The dictation as the model gets it. Handed over bare, a question in the text ("Hattest du
    /// heute einen lustigen Tag") is answered instead of tidied up; in this frame it stays text.
    static func framedTranscript(_ text: String) -> String {
        "Bereinige dieses Transkript. Gib nur den bereinigten Text zurück, ohne die Markierungen.\n<transkript>\n\(text)\n</transkript>"
    }

    /// Takes the frame off again when the model repeats it.
    static func unframed(_ answer: String) -> String {
        answer
            .replacingOccurrences(of: "<transkript>", with: "")
            .replacingOccurrences(of: "</transkript>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The share of the answer's words that were in the dictation. A tidy-up keeps most of them;
    /// an answer to a question in the text shares almost none.
    static func sharedWordRatio(_ candidate: String, with original: String) -> Double {
        let answerWords = words(candidate)
        guard !answerWords.isEmpty else { return 0 }
        let known = Set(words(original))
        return Double(answerWords.filter { known.contains($0) }.count) / Double(answerWords.count)
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}
