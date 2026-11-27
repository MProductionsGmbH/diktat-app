import XCTest

/// Spec `docs/specs/stimmen-wiedererkennen.md` (STIM-01). Voiceprints here are short made-up
/// vectors; only the angle between them counts.
final class VoiceLibraryTests: XCTestCase {
    private let meeting1 = UUID()
    private let meeting2 = UUID()
    private let meeting3 = UUID()
    private let day1 = Date(timeIntervalSince1970: 1_800_000_000)
    private var day2: Date { day1.addingTimeInterval(86_400) }

    /// Anna's voice, and voices that resemble it to a chosen degree.
    private let anna: [Float] = [1, 0, 0, 0]
    private let bea: [Float] = [0, 0, 1, 0]
    private func like(_ base: [Float], _ similarity: Float) -> [Float] {
        let rest = (1 - similarity * similarity).squareRoot()
        return base == anna ? [similarity, rest, 0, 0] : [0, rest, similarity, 0]
    }
    private var sure: Float { VoiceMatching.sure + 0.2 }
    private var unsure: Float { (VoiceMatching.sure + VoiceMatching.possible) / 2 }
    private let long: TimeInterval = 120

    /// A library that knows Anna from `meeting1`, where she was "Person 2".
    private func libraryKnowingAnna() -> VoiceLibrary {
        var library = VoiceLibrary()
        library.register(meetingID: meeting1, prints: [1: bea, 2: anna], speech: [1: long, 2: long], enabled: true, now: day1)
        library.name(speaker: 2, in: meeting1, as: "Anna", remember: true, enabled: true, now: day1)
        return library
    }

    // MARK: - Kriterien

    func test_STIM01_AK02_switchedOffStoresNothingAndKeepsWhatIsThere() {
        var library = libraryKnowingAnna()
        let before = library
        let names = library.register(meetingID: meeting2, prints: [1: like(anna, sure)], speech: [1: long], enabled: false, now: day2)
        XCTAssertTrue(names.isEmpty)
        XCTAssertEqual(library, before)
        XCTAssertFalse(library.canRemember(speaker: 1, in: meeting2, enabled: false))
    }

    func test_STIM01_AK03_namingWithTheTickMakesAKnownVoice() {
        let library = libraryKnowingAnna()
        XCTAssertEqual(library.voices.map(\.name), ["Anna"])
        XCTAssertEqual(library.voices.first?.meetingCount, 1)
        XCTAssertEqual(library.voices.first?.lastHeard, day1)
    }

    func test_STIM01_AK04_namingWithoutTheTickRemembersNothing() {
        var library = VoiceLibrary()
        library.register(meetingID: meeting1, prints: [2: anna], speech: [2: long], enabled: true, now: day1)
        library.name(speaker: 2, in: meeting1, as: "Anna", remember: false, enabled: true, now: day1)
        XCTAssertTrue(library.voices.isEmpty)
    }

    func test_STIM01_AK05_aSureMatchIsNamedAndMarkedAsRecognised() {
        var library = libraryKnowingAnna()
        let names = library.register(meetingID: meeting2, prints: [1: like(anna, sure)], speech: [1: long], enabled: true, now: day2)
        XCTAssertEqual(names, [1: "Anna"])
        XCTAssertTrue(library.isRecognised(speaker: 1, in: meeting2))
        XCTAssertNil(library.suggestion(for: 1, in: meeting2))
        XCTAssertEqual(library.voices.first?.meetingCount, 2)
        XCTAssertEqual(library.voices.first?.lastHeard, day2)
    }

    func test_STIM01_AK06_anUnsureMatchAsksAndYesSetsTheName() {
        var library = libraryKnowingAnna()
        let names = library.register(meetingID: meeting2, prints: [1: like(anna, unsure)], speech: [1: long], enabled: true, now: day2)
        XCTAssertTrue(names.isEmpty)
        XCTAssertFalse(library.isRecognised(speaker: 1, in: meeting2))
        XCTAssertEqual(library.suggestion(for: 1, in: meeting2)?.name, "Anna")

        XCTAssertEqual(library.answer(speaker: 1, in: meeting2, isSame: true, enabled: true, now: day2), "Anna")
        XCTAssertNil(library.suggestion(for: 1, in: meeting2))
        XCTAssertEqual(library.voices.first?.meetingCount, 2)
    }

    func test_STIM01_AK06_noLeavesThePersonAndStopsAsking() {
        var library = libraryKnowingAnna()
        library.register(meetingID: meeting2, prints: [1: like(anna, unsure)], speech: [1: long], enabled: true, now: day2)
        XCTAssertNil(library.answer(speaker: 1, in: meeting2, isSame: false, enabled: true, now: day2))
        XCTAssertNil(library.suggestion(for: 1, in: meeting2))
        XCTAssertEqual(library.voices.first?.meetingCount, 1)
    }

    func test_STIM01_AK07_correctingAWrongNameTakesTheMeetingOutOfThatVoice() {
        var library = libraryKnowingAnna()
        library.register(meetingID: meeting2, prints: [1: like(anna, sure)], speech: [1: long], enabled: true, now: day2)
        library.name(speaker: 1, in: meeting2, as: "Bea", remember: true, enabled: true, now: day2)

        let annaVoice = library.voices.first { $0.name == "Anna" }
        XCTAssertEqual(annaVoice?.samples.map(\.meetingID), [meeting1])
        XCTAssertEqual(annaVoice?.meetingCount, 1)
        XCTAssertEqual(library.voices.first { $0.name == "Bea" }?.samples.map(\.meetingID), [meeting2])
        XCTAssertFalse(library.isRecognised(speaker: 1, in: meeting2))
    }

    func test_STIM01_AK08_aForgottenVoiceIsNoLongerRecognised() throws {
        var library = libraryKnowingAnna()
        library.forget(try XCTUnwrap(library.voices.first?.id))
        XCTAssertTrue(library.voices.isEmpty)
        let names = library.register(meetingID: meeting2, prints: [1: like(anna, sure)], speech: [1: long], enabled: true, now: day2)
        XCTAssertTrue(names.isEmpty)
        XCTAssertNil(library.suggestion(for: 1, in: meeting2))
    }

    func test_STIM01_AK08_forgettingAVoiceAlsoRemovesItsPrintsFromTheMeetings() throws {
        var library = libraryKnowingAnna()
        library.register(meetingID: meeting2, prints: [1: like(anna, sure), 2: bea], speech: [1: long, 2: long], enabled: true, now: day2)
        library.forget(try XCTUnwrap(library.voices.first?.id))

        XCTAssertNil(library.meetings[meeting1]?.prints[2], "the print Anna was named from")
        XCTAssertNil(library.meetings[meeting2]?.prints[1], "the print Anna was recognised by")
        XCTAssertNotNil(library.meetings[meeting1]?.prints[1], "other people keep theirs")
        XCTAssertNotNil(library.meetings[meeting2]?.prints[2])
        XCTAssertFalse(library.canRemember(speaker: 2, in: meeting1, enabled: true))
    }

    func test_STIM01_AK08_renamingAVoiceKeepsItsPrints() throws {
        var library = libraryKnowingAnna()
        library.rename(try XCTUnwrap(library.voices.first?.id), to: " Anna Meier ")
        XCTAssertEqual(library.voices.map(\.name), ["Anna Meier"])
        XCTAssertEqual(library.voices.first?.samples.count, 1)
    }

    func test_STIM01_AK09_switchingOffAndOnAgainKeepsAndUsesTheVoices() {
        var library = libraryKnowingAnna()
        library.register(meetingID: meeting2, prints: [1: like(anna, sure)], speech: [1: long], enabled: false, now: day2)
        XCTAssertEqual(library.voices.map(\.name), ["Anna"])
        let names = library.register(meetingID: meeting3, prints: [1: like(anna, sure)], speech: [1: long], enabled: true, now: day2)
        XCTAssertEqual(names, [1: "Anna"])
    }

    func test_STIM01_AK11_theOwnMicrophoneIsNeverComparedOrLearned() {
        var library = libraryKnowingAnna()
        let names = library.register(meetingID: meeting2, prints: [0: anna], speech: [0: long], enabled: true, now: day2)
        XCTAssertTrue(names.isEmpty)
        XCTAssertFalse(library.canRemember(speaker: 0, in: meeting2, enabled: true))
        XCTAssertNil(library.meetings[meeting2]?.prints[0])
    }

    func test_STIM01_AK14_nothingExpiresWithTime() throws {
        let library = libraryKnowingAnna()
        let stored = try JSONEncoder().encode(library)
        var later = try JSONDecoder().decode(VoiceLibrary.self, from: stored)
        XCTAssertEqual(later, library)

        let tenYears = day1.addingTimeInterval(10 * 365 * 86_400)
        let names = later.register(meetingID: meeting2, prints: [1: like(anna, sure)], speech: [1: long], enabled: true, now: tenYears)
        XCTAssertEqual(names, [1: "Anna"])
        XCTAssertNotNil(later.meetings[meeting1]?.prints[1], "the unnamed person of the first meeting is still there")
    }

    func test_STIM01_AK15_deletingAllLeavesNoPrint() {
        var library = libraryKnowingAnna()
        XCTAssertTrue(library.hasPrints)
        library.removeAll()
        XCTAssertFalse(library.hasPrints)
        XCTAssertTrue(library.voices.isEmpty)
        XCTAssertTrue(library.meetings.isEmpty)
    }

    func test_STIM01_AK17_deletingAMeetingTakesItsUnnamedPrintsAndKeepsKnownVoices() {
        var library = libraryKnowingAnna()
        library.removeMeeting(meeting1)
        XCTAssertNil(library.meetings[meeting1])
        XCTAssertEqual(library.voices.map(\.name), ["Anna"])
        XCTAssertEqual(library.voices.first?.samples.count, 1)
    }

    // MARK: - Randfälle

    func test_STIM01_RF01_twoVoicesThatFitAlikeAreOnlyAsked() {
        var library = libraryKnowingAnna()
        library.name(speaker: 1, in: meeting1, as: "Bea", remember: true, enabled: true, now: day1)
        // Between the two, a little closer to Anna.
        let between: [Float] = [0.72, 0, 0.69, 0]
        let names = library.register(meetingID: meeting2, prints: [1: between], speech: [1: long], enabled: true, now: day2)
        XCTAssertTrue(names.isEmpty)
        XCTAssertEqual(library.suggestion(for: 1, in: meeting2)?.name, "Anna")
    }

    func test_STIM01_RF02_oneVoiceNamesOnlyTheBetterOfTwoPeople() {
        var library = libraryKnowingAnna()
        let names = library.register(
            meetingID: meeting2,
            prints: [1: like(anna, sure), 2: like(anna, 0.99)],
            speech: [1: long, 2: long], enabled: true, now: day2
        )
        XCTAssertEqual(names, [2: "Anna"])
        XCTAssertFalse(library.isRecognised(speaker: 1, in: meeting2))
        XCTAssertNil(library.suggestion(for: 1, in: meeting2))
    }

    func test_STIM01_RF03_tooLittleSpeechIsNeitherRecognisedNorLearned() {
        var library = libraryKnowingAnna()
        let short = VoiceMatching.minimumSpeech - 1
        let names = library.register(meetingID: meeting2, prints: [1: like(anna, sure), 2: bea], speech: [1: short, 2: short], enabled: true, now: day2)
        XCTAssertTrue(names.isEmpty)
        XCTAssertNil(library.suggestion(for: 1, in: meeting2))
        XCTAssertFalse(library.canRemember(speaker: 2, in: meeting2, enabled: true))
        library.name(speaker: 2, in: meeting2, as: "Bea", remember: true, enabled: true, now: day2)
        XCTAssertEqual(library.voices.map(\.name), ["Anna"])
    }

    func test_STIM01_RF04_aNameThatIsAlreadyKnownJoinsThatVoice() {
        var library = libraryKnowingAnna()
        library.register(meetingID: meeting2, prints: [3: like(anna, 0.2)], speech: [3: long], enabled: true, now: day2)
        library.name(speaker: 3, in: meeting2, as: " anna ", remember: true, enabled: true, now: day2)
        XCTAssertEqual(library.voices.map(\.name), ["Anna"])
        XCTAssertEqual(library.voices.first?.samples.count, 2)
        XCTAssertEqual(library.voices.first?.meetingCount, 2)
    }

    func test_STIM01_RF05_aMeetingWithoutPrintsOffersNoTickAndLearnsNothing() {
        var library = libraryKnowingAnna()
        XCTAssertFalse(library.canRemember(speaker: 1, in: meeting3, enabled: true))
        library.name(speaker: 1, in: meeting3, as: "Carl", remember: true, enabled: true, now: day2)
        XCTAssertEqual(library.voices.map(\.name), ["Anna"])
    }

    func test_STIM01_RF07_lookingForMatchesAloneStoresNothing() {
        let library = libraryKnowingAnna()
        let before = library
        let names = library.recognisedNames(prints: [1: like(anna, sure)], speech: [1: long], enabled: true)
        XCTAssertEqual(names, [1: "Anna"])
        XCTAssertEqual(library, before)
    }

    // MARK: - Vergleich

    func testSimilarityIsTheCosineAndZeroForUnusablePrints() {
        XCTAssertEqual(VoiceMatching.similarity([1, 0], [1, 0]), 1, accuracy: 0.0001)
        XCTAssertEqual(VoiceMatching.similarity([1, 0], [0, 1]), 0, accuracy: 0.0001)
        XCTAssertEqual(VoiceMatching.similarity([2, 0], [0.5, 0]), 1, accuracy: 0.0001)
        XCTAssertEqual(VoiceMatching.similarity([1, 0], [1, 0, 0]), 0)
        XCTAssertEqual(VoiceMatching.similarity([0, 0], [1, 0]), 0)
        XCTAssertEqual(VoiceMatching.similarity([], []), 0)
    }

    func testAVoiceKeepsOnlyTheNewestSamplesButCountsEveryMeeting() {
        var library = libraryKnowingAnna()
        for index in 0..<(VoiceMatching.maxSamples + 5) {
            library.register(meetingID: UUID(), prints: [1: like(anna, sure)], speech: [1: long], enabled: true, now: day2.addingTimeInterval(Double(index)))
        }
        XCTAssertEqual(library.voices.first?.samples.count, VoiceMatching.maxSamples)
        XCTAssertEqual(library.voices.first?.meetingCount, VoiceMatching.maxSamples + 6)
    }
}
