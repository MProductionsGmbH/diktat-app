import Foundation

// Voices Diktat knows across meetings (spec `docs/specs/stimmen-wiedererkennen.md`, STIM-01).
// A voiceprint is the row of numbers the speaker models compute for a voice: no sound, and
// nothing a recording could be rebuilt from, but it tells one person from another. Pure logic
// without disk or models, so it is tested on its own; `VoiceprintStore` keeps it on disk.

/// A person whose voice Diktat remembers because the user gave it a name.
struct KnownVoice: Codable, Identifiable, Equatable {
    /// The voiceprint of this person in one meeting.
    struct Sample: Codable, Equatable {
        let meetingID: UUID
        let speaker: Int
        let print: [Float]
    }

    let id: UUID
    var name: String
    /// Newest last, at most `VoiceMatching.maxSamples`.
    var samples: [Sample]
    /// Every meeting the voice was named or recognised in, also those whose sample has
    /// made room for newer ones.
    var meetingIDs: [UUID]
    var lastHeard: Date

    var meetingCount: Int { meetingIDs.count }

    init(id: UUID = UUID(), name: String, samples: [Sample] = [], meetingIDs: [UUID] = [], lastHeard: Date) {
        self.id = id
        self.name = name
        self.samples = samples
        self.meetingIDs = meetingIDs
        self.lastHeard = lastHeard
    }

    // Read leniently: a field a later version adds must not make the stored voices unreadable.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        samples = try container.decodeIfPresent([Sample].self, forKey: .samples) ?? []
        meetingIDs = try container.decodeIfPresent([UUID].self, forKey: .meetingIDs) ?? []
        lastHeard = try container.decodeIfPresent(Date.self, forKey: .lastHeard) ?? .distantPast
    }
}

/// What Diktat keeps about the voices of one meeting.
struct MeetingVoices: Codable, Equatable {
    /// One voiceprint per person, also for people without a name, so naming them later can
    /// still teach Diktat the voice. The recording itself is gone by then.
    var prints: [Int: [Float]] = [:]
    /// The known voice a person of this meeting belongs to.
    var assigned: [Int: UUID] = [:]
    /// People Diktat named by itself, shown as "erkannt" until the user names them.
    var recognised: Set<Int> = []
    /// People Diktat is unsure about and asks: "Ist das Anna?"
    var suggested: [Int: UUID] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        prints = try container.decodeIfPresent([Int: [Float]].self, forKey: .prints) ?? [:]
        assigned = try container.decodeIfPresent([Int: UUID].self, forKey: .assigned) ?? [:]
        recognised = try container.decodeIfPresent(Set<Int>.self, forKey: .recognised) ?? []
        suggested = try container.decodeIfPresent([Int: UUID].self, forKey: .suggested) ?? [:]
    }
}

enum VoiceMatching {
    /// Someone who said less than this is neither recognised nor learned: too little voice.
    static let minimumSpeech: TimeInterval = 10
    /// From this similarity on a person is named without asking, as long as no other known
    /// voice comes within `margin`. Strict on purpose, see the spec: rather ask than put a
    /// wrong name into the minutes. Not yet set from real meetings; `-DiktatVoiceCheck` prints
    /// the similarities of recordings to do so.
    static let sure: Float = 0.75
    /// From this similarity on Diktat asks whether it is that person.
    static let possible: Float = 0.45
    static let margin: Float = 0.15
    static let maxSamples = 20

    enum Match: Equatable {
        case recognised(UUID)
        case suggested(UUID)

        var voiceID: UUID {
            switch self {
            case .recognised(let id), .suggested(let id): return id
            }
        }
    }

    /// The cosine of the angle between two voiceprints: 1 for the same direction, around 0
    /// for unrelated voices. 0 for prints that cannot be compared.
    static func similarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, normA: Float = 0, normB: Float = 0
        for index in a.indices {
            dot += a[index] * b[index]
            normA += a[index] * a[index]
            normB += b[index] * b[index]
        }
        guard normA > 0, normB > 0, dot.isFinite else { return 0 }
        return dot / (normA.squareRoot() * normB.squareRoot())
    }

    static func isUsable(_ print: [Float]) -> Bool {
        !print.isEmpty && print.allSatisfy(\.isFinite) && print.contains { $0 != 0 }
    }

    /// How well a voiceprint fits a known voice: the best of its samples, because the same
    /// person sounds different through a headset and in a room.
    static func score(_ print: [Float], against voice: KnownVoice) -> Float {
        voice.samples.map { similarity(print, $0.print) }.max() ?? 0
    }

    /// Who of a meeting is a known voice. A known voice names one person at most (the best
    /// fitting), and two voices that fit alike are only asked about.
    static func matches(prints: [Int: [Float]], voices: [KnownVoice]) -> [Int: Match] {
        struct Candidate {
            let speaker: Int
            let voiceID: UUID
            let score: Float
            let isSure: Bool
        }
        var candidates: [Candidate] = []
        for (speaker, print) in prints {
            let scores = voices.map { (id: $0.id, score: score(print, against: $0)) }.sorted { $0.score > $1.score }
            guard let best = scores.first, best.score >= possible else { continue }
            let second = scores.dropFirst().first?.score ?? -1
            candidates.append(Candidate(
                speaker: speaker, voiceID: best.id, score: best.score,
                isSure: best.score >= sure && best.score - second >= margin
            ))
        }
        var taken = Set<UUID>()
        var result: [Int: Match] = [:]
        // The speaker number breaks ties, so the same meeting always gives the same answer.
        for candidate in candidates.sorted(by: { ($0.score, $1.speaker) > ($1.score, $0.speaker) }) {
            guard taken.insert(candidate.voiceID).inserted else { continue }
            result[candidate.speaker] = candidate.isSure ? .recognised(candidate.voiceID) : .suggested(candidate.voiceID)
        }
        return result
    }
}

/// The known voices and the voiceprints of the meetings. Nothing in here expires: prints stay
/// until the user removes them (a voice, a meeting, or all of them).
struct VoiceLibrary: Codable, Equatable {
    private(set) var voices: [KnownVoice] = []
    private(set) var meetings: [UUID: MeetingVoices] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        voices = try container.decodeIfPresent([KnownVoice].self, forKey: .voices) ?? []
        meetings = try container.decodeIfPresent([UUID: MeetingVoices].self, forKey: .meetings) ?? [:]
    }

    var hasPrints: Bool {
        !voices.isEmpty || meetings.values.contains { !$0.prints.isEmpty }
    }

    // MARK: - A new meeting

    /// The prints worth keeping: never the microphone of an online meeting ("Ich", speaker 0),
    /// and nobody who said too little.
    private static func usable(_ prints: [Int: [Float]], speech: [Int: TimeInterval]) -> [Int: [Float]] {
        prints.filter { speaker, print in
            speaker != 0 && (speech[speaker] ?? 0) >= VoiceMatching.minimumSpeech && VoiceMatching.isUsable(print)
        }
    }

    /// The names of the people Diktat is sure about, without storing anything: the summary
    /// needs them before it is clear that the evaluation succeeds.
    func recognisedNames(prints: [Int: [Float]], speech: [Int: TimeInterval], enabled: Bool) -> [Int: String] {
        guard enabled else { return [:] }
        var names: [Int: String] = [:]
        for (speaker, match) in VoiceMatching.matches(prints: Self.usable(prints, speech: speech), voices: voices) {
            if case .recognised(let id) = match, let voice = voices.first(where: { $0.id == id }) {
                names[speaker] = voice.name
            }
        }
        return names
    }

    /// Keeps the voiceprints of an evaluated meeting and notes who was recognised or is asked
    /// about. Returns the names of the recognised people. Switched off, nothing happens.
    @discardableResult
    mutating func register(
        meetingID: UUID, prints: [Int: [Float]], speech: [Int: TimeInterval], enabled: Bool, now: Date
    ) -> [Int: String] {
        guard enabled else { return [:] }
        // Evaluated again: what the first run taught is taken back first.
        if let earlier = meetings[meetingID] {
            for (speaker, voiceID) in earlier.assigned { detach(voiceID, meetingID: meetingID, speaker: speaker) }
        }
        var entry = MeetingVoices()
        entry.prints = Self.usable(prints, speech: speech)
        var names: [Int: String] = [:]
        for (speaker, match) in VoiceMatching.matches(prints: entry.prints, voices: voices) {
            switch match {
            case .recognised(let id):
                guard let print = entry.prints[speaker], let name = attach(id, meetingID: meetingID, speaker: speaker, print: print, now: now) else { continue }
                entry.assigned[speaker] = id
                entry.recognised.insert(speaker)
                names[speaker] = name
            case .suggested(let id):
                entry.suggested[speaker] = id
            }
        }
        meetings[meetingID] = entry
        return names
    }

    // MARK: - Naming

    /// Whether naming this person can teach Diktat the voice: the function is on and the
    /// meeting has a voiceprint of them (none for older meetings and for too little speech).
    func canRemember(speaker: Int, in meetingID: UUID, enabled: Bool) -> Bool {
        enabled && meetings[meetingID]?.prints[speaker] != nil
    }

    /// The user named a person. With `remember` the voice is learned under that name, joining
    /// a known voice of the same name. A voice the person belonged to before (a wrong
    /// recognition, a typo) loses what it learned from this meeting.
    mutating func name(speaker: Int, in meetingID: UUID, as name: String, remember: Bool, enabled: Bool, now: Date) {
        guard var entry = meetings[meetingID] else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let previous = entry.assigned[speaker]
        entry.recognised.remove(speaker)
        entry.suggested[speaker] = nil

        var target: UUID?
        if remember, !name.isEmpty, enabled, let print = entry.prints[speaker] {
            let known = voices.first { $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
            let id = known?.id ?? UUID()
            if previous != id {
                if known == nil { voices.append(KnownVoice(id: id, name: name, lastHeard: now)) }
                _ = attach(id, meetingID: meetingID, speaker: speaker, print: print, now: now)
            }
            target = id
        }
        if let previous, previous != target { detach(previous, meetingID: meetingID, speaker: speaker) }
        entry.assigned[speaker] = target
        meetings[meetingID] = entry
    }

    /// The answer to "Ist das Anna?". Yes returns the name to set and, with the function on,
    /// adds the voiceprint to that voice. Either way Diktat stops asking in this meeting.
    mutating func answer(speaker: Int, in meetingID: UUID, isSame: Bool, enabled: Bool, now: Date) -> String? {
        guard var entry = meetings[meetingID], let voiceID = entry.suggested[speaker] else { return nil }
        entry.suggested[speaker] = nil
        defer { meetings[meetingID] = entry }
        guard isSame, let voice = voices.first(where: { $0.id == voiceID }) else { return nil }
        if enabled, let print = entry.prints[speaker] {
            _ = attach(voiceID, meetingID: meetingID, speaker: speaker, print: print, now: now)
            entry.assigned[speaker] = voiceID
        }
        return voice.name
    }

    func isRecognised(speaker: Int, in meetingID: UUID) -> Bool {
        meetings[meetingID]?.recognised.contains(speaker) ?? false
    }

    func suggestion(for speaker: Int, in meetingID: UUID) -> KnownVoice? {
        guard let id = meetings[meetingID]?.suggested[speaker] else { return nil }
        return voices.first { $0.id == id }
    }

    // MARK: - Managing

    /// Forgetting a voice removes every voiceprint of that person: the samples of the voice
    /// and the prints the meetings kept of them. The names in earlier meetings stay; they are
    /// part of the meeting, not of the voice.
    mutating func forget(_ voiceID: UUID) {
        let samples = voices.first { $0.id == voiceID }?.samples ?? []
        voices.removeAll { $0.id == voiceID }
        for sample in samples {
            meetings[sample.meetingID]?.prints[sample.speaker] = nil
        }
        for (meetingID, var entry) in meetings {
            let speakers = entry.assigned.filter { $0.value == voiceID }.map(\.key)
            for speaker in speakers {
                entry.assigned[speaker] = nil
                entry.recognised.remove(speaker)
                entry.prints[speaker] = nil
            }
            entry.suggested = entry.suggested.filter { $0.value != voiceID }
            meetings[meetingID] = entry
        }
    }

    mutating func rename(_ voiceID: UUID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = voices.firstIndex(where: { $0.id == voiceID }) else { return }
        voices[index].name = name
    }

    /// A deleted meeting takes the voiceprints of its people along. What a known voice
    /// learned from it stays with that voice.
    mutating func removeMeeting(_ id: UUID) {
        meetings[id] = nil
    }

    mutating func removeAll() {
        voices = []
        meetings = [:]
    }

    // MARK: - Samples

    /// Adds the voiceprint of a person in a meeting to a voice. Returns the voice's name.
    private mutating func attach(_ voiceID: UUID, meetingID: UUID, speaker: Int, print: [Float], now: Date) -> String? {
        guard let index = voices.firstIndex(where: { $0.id == voiceID }) else { return nil }
        voices[index].samples.removeAll { $0.meetingID == meetingID && $0.speaker == speaker }
        voices[index].samples.append(KnownVoice.Sample(meetingID: meetingID, speaker: speaker, print: print))
        if voices[index].samples.count > VoiceMatching.maxSamples {
            voices[index].samples.removeFirst(voices[index].samples.count - VoiceMatching.maxSamples)
        }
        if !voices[index].meetingIDs.contains(meetingID) { voices[index].meetingIDs.append(meetingID) }
        voices[index].lastHeard = max(voices[index].lastHeard, now)
        return voices[index].name
    }

    /// Takes back what a voice learned from a person of a meeting. A voice with nothing left
    /// (it only ever was this person) goes with it.
    private mutating func detach(_ voiceID: UUID, meetingID: UUID, speaker: Int) {
        guard let index = voices.firstIndex(where: { $0.id == voiceID }) else { return }
        voices[index].samples.removeAll { $0.meetingID == meetingID && $0.speaker == speaker }
        if !voices[index].samples.contains(where: { $0.meetingID == meetingID }) {
            voices[index].meetingIDs.removeAll { $0 == meetingID }
        }
        if voices[index].samples.isEmpty { voices.remove(at: index) }
    }
}
