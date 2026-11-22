import Foundation
import NaturalLanguage

/// The language the instructions to the language model are written in. It follows what was
/// spoken: a German dictation gets the German instructions, anything else the English ones,
/// which tell the model to answer in the language of the transcript.
enum PromptLanguage: Equatable {
    case german
    case english

    /// German, or too little text to tell: German is the language the prompts were written in.
    static func detect(from text: String) -> PromptLanguage {
        guard let language = NLLanguageRecognizer.dominantLanguage(for: text) else { return .german }
        return language == .german ? .german : .english
    }

    /// The dictation language setting ("de", "en", or "auto") decides when it names a language;
    /// "auto" follows the text.
    static func resolve(setting: String, text: String) -> PromptLanguage {
        switch setting.lowercased().prefix(2) {
        case "de": return .german
        case "en": return .english
        default: return detect(from: text)
        }
    }

    /// How sure the recognizer must be that a text is English before English hesitation
    /// sounds are removed from it.
    static let fillerConfidence = 0.6

    /// The language whose hesitation sounds may be removed from `text`: "en" only when the text
    /// clearly is English, otherwise "de" (the sounds every language shares). A short German
    /// sentence with an English word ("Zoom Call um 9") is often taken for Portuguese or
    /// Icelandic; treating that as English removed the preposition "um".
    static func fillerLanguageCode(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let english = recognizer.languageHypotheses(withMaximum: 3)[.english] ?? 0
        return recognizer.dominantLanguage == .english && english >= fillerConfidence ? "en" : "de"
    }

    /// The code the filler-word list and the sentence tokenizer know.
    var code: String {
        switch self {
        case .german: return "de"
        case .english: return "en"
        }
    }
}
