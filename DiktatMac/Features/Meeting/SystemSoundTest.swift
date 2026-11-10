import Foundation
import Observation

/// "Ton testen" on the meeting page: listens to what the Mac plays, writes nothing down, and
/// shows a level, so you see before the meeting that the sound of the call arrives.
@Observable
@MainActor
final class SystemSoundTest {
    /// A test ends by itself, so a forgotten one does not keep listening.
    static let duration: TimeInterval = 30

    private(set) var isRunning = false
    /// 0...1 on a decibel scale, like the microphone's level.
    private(set) var level: Float = 0
    /// The Mac played something in the last moments.
    private(set) var isHearingSound = false
    private(set) var problem: String?

    @ObservationIgnored private var capture: Any?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var startedAt = Date()
    @ObservationIgnored private var lastSound = Date.distantPast

    static let hearingThreshold: Float = 0.05

    func start() {
        guard !isRunning, #available(macOS 14.2, *) else { return }
        problem = nil
        let capture = SystemAudioCapture()
        do {
            try capture.start(writingTo: nil)
        } catch {
            capture.stop()
            problem = error.localizedDescription
            return
        }
        self.capture = capture
        isRunning = true
        startedAt = Date()
        lastSound = .distantPast
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if #available(macOS 14.2, *) { (capture as? SystemAudioCapture)?.stop() }
        capture = nil
        isRunning = false
        level = 0
        isHearingSound = false
    }

    private func tick() {
        guard #available(macOS 14.2, *), let capture = capture as? SystemAudioCapture else { return }
        level = capture.currentLevel
        if level > Self.hearingThreshold { lastSound = Date() }
        isHearingSound = Date().timeIntervalSince(lastSound) < 1.5
        if Date().timeIntervalSince(startedAt) > Self.duration { stop() }
    }
}
