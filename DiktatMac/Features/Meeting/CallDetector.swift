import Foundation

/// Polls the audio apps while no meeting is recorded and reports when a call starts.
@MainActor
final class CallDetector {
    /// The app name, once per call and never twice within `quietTime`.
    var onCall: ((String) -> Void)?

    static let interval: TimeInterval = 3
    /// A call must last this many checks, so a short blip of the microphone is not one.
    static let checksBeforeReport = 2
    static let quietTime: TimeInterval = 15 * 60

    private var timer: Timer?
    private var streak: [String: Int] = [:]
    private var lastReport: [String: Date] = [:]

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        streak = [:]
    }

    private func check() {
        guard #available(macOS 14.2, *) else { return }
        let candidates = AudioProcesses.all().map {
            CallDetection.Candidate(bundleID: $0.bundleID, isRunningInput: $0.isRunningInput, isRunningOutput: $0.isRunningOutput)
        }
        evaluate(CallDetection.calls(in: candidates))
    }

    /// Steps the counters with the apps in a call right now.
    func evaluate(_ calls: [String], now: Date = Date()) {
        streak = streak.filter { calls.contains($0.key) }
        for name in calls {
            let count = (streak[name] ?? 0) + 1
            streak[name] = count
            guard count == Self.checksBeforeReport else { continue }
            if let last = lastReport[name], now.timeIntervalSince(last) < Self.quietTime { continue }
            lastReport[name] = now
            onCall?(name)
        }
    }
}
