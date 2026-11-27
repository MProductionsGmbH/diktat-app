import FluidAudio
import Foundation

/// "Who spoke when" for meeting recordings, on device via FluidAudio's offline
/// pipeline (pyannote segmentation + WeSpeaker embeddings + VBx clustering).
/// The models download on first use.
actor SpeakerDiarizer {
    static let shared = SpeakerDiarizer()

    static var modelsDirectoryURL: URL {
        #if os(macOS)
        AppSupportPaths.localModelsDirectoryURL.appendingPathComponent("diarizer", isDirectory: true)
        #else
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Diktat/Models/diarizer", isDirectory: true)
        #endif
    }

    private var manager: OfflineDiarizerManager?

    /// Loads the models, downloading them the first time.
    func prepare() async throws {
        guard manager == nil else { return }
        try FileManager.default.createDirectory(at: Self.modelsDirectoryURL, withIntermediateDirectories: true)
        let manager = OfflineDiarizerManager()
        try await manager.prepareModels(directory: Self.modelsDirectoryURL)
        var url = Self.modelsDirectoryURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        self.manager = manager
    }

    /// Who spoke when, and what the models know about each voice.
    struct Analysis: Sendable {
        var turns: [SpeakerTurn] = []
        /// The voiceprint per person, numbered like the turns. Empty when the models give none.
        var prints: [Int: [Float]] = [:]
        /// How long each person spoke in total, in seconds.
        var speech: [Int: TimeInterval] = [:]
    }

    /// Speaker turns in time order. Consecutive segments of the same speaker are
    /// merged, and speakers are numbered by first appearance (1, 2, ...).
    func turns(in audioURL: URL) async throws -> [SpeakerTurn] {
        try await analysis(of: audioURL).turns
    }

    /// The turns of `turns(in:)` together with a voiceprint and the speaking time per person,
    /// for recognising voices across meetings (`VoiceLibrary`).
    func analysis(of audioURL: URL) async throws -> Analysis {
        try await prepare()
        guard let manager else { return Analysis() }
        let result = try await manager.process(audioURL)

        var numbers: [String: Int] = [:]
        var analysis = Analysis()
        for segment in result.segments.sorted(by: { $0.startTimeSeconds < $1.startTimeSeconds }) {
            let number = numbers[segment.speakerId] ?? {
                let next = numbers.count + 1
                numbers[segment.speakerId] = next
                return next
            }()
            let start = TimeInterval(segment.startTimeSeconds)
            let end = TimeInterval(segment.endTimeSeconds)
            analysis.speech[number, default: 0] += max(0, end - start)
            if let last = analysis.turns.last, last.speaker == number, start - last.end < 1.0 {
                analysis.turns[analysis.turns.count - 1] = SpeakerTurn(speaker: number, start: last.start, end: end)
            } else {
                analysis.turns.append(SpeakerTurn(speaker: number, start: start, end: end))
            }
        }
        analysis.turns = analysis.turns.filter { $0.end - $0.start >= 0.4 }
        for (speakerID, print) in result.speakerDatabase ?? [:] {
            if let number = numbers[speakerID] { analysis.prints[number] = print }
        }
        return analysis
    }
}
