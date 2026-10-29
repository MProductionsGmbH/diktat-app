import Foundation

struct TranscriptionSettings: Codable {
    /// "auto": the speech models detect the language and the later steps follow what was spoken.
    /// Settings saved before English support hold "de", which never was a choice (there is no
    /// picker), so it counts as automatic.
    var language: String = "auto"

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try container.decodeIfPresent(String.self, forKey: .language) ?? "auto"
        language = stored == "de" ? "auto" : stored
    }

    private enum CodingKeys: String, CodingKey {
        case language
    }
}
