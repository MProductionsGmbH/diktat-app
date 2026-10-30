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

    /// The code the filler-word list and the sentence tokenizer know.
    var code: String {
        switch self {
        case .german: return "de"
        case .english: return "en"
        }
    }
}
