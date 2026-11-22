import AVFoundation
import CoreAudio

/// Records one chosen microphone into a file, 16 kHz mono, in the format the system recorder
/// would write. Used when a microphone other than the Mac's default input is picked, since
/// AVAudioRecorder can only follow the default.
///
/// A meeting also uses it for the default input, with `survivingDeviceChanges`: when macOS
/// changes the audio setup under a running recording (a monitor is connected for the
/// presentation, headphones go, the microphone is unplugged), the engine stops. The capture
/// then starts again on the picked microphone or, when that is gone, on the Mac's default input,
/// and keeps writing the same file. The gap becomes silence, so the file stays in step with the
/// clock and with the system sound of an online meeting.
final class EngineCapture: @unchecked Sendable {
    enum CaptureError: LocalizedError {
        case deviceUnavailable
        case noInputFormat

        var errorDescription: String? {
            switch self {
            case .deviceUnavailable: return String(localized: "Das gew\u{00E4}hlte Mikrofon l\u{00E4}sst sich nicht \u{00F6}ffnen.")
            case .noInputFormat: return String(localized: "Das gew\u{00E4}hlte Mikrofon liefert kein Signal.")
            }
        }
    }

    /// Dictation: compact AAC.
    static let dictationSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]

    /// Meetings: 16 kHz mono 16-bit PCM, what the speech models read and a crash can leave behind.
    static let meetingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
    ]

    private var engine = AVAudioEngine()
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var target: AVAudioFormat?
    private var survivesDeviceChanges = false
    private var watchdog: Timer?
    private var restartFailed = false
    /// How often the capture had to start again.
    private(set) var restarts = 0

    // Under `lock`.
    private var startedAt = Date()
    private var pausedSince: Date?
    private var pausedTotal: TimeInterval = 0
    private var lastDelivery = Date()
    private var fillsGap = false

    /// No buffer for this long means the engine no longer records, whatever it says.
    static let silenceBeforeRestart: TimeInterval = 2
    private var level: Float = 0
    private var peakDB: Float = -160
    private var currentDB: Float = -160
    private var paused = false
    private var framesWritten: AVAudioFramePosition = 0
    private var sampleRate: Double = 16_000
    private var configurationObserver: NSObjectProtocol?

    /// The microphone went away or the engine stopped on its own. Called on the main thread.
    /// Not called with `survivingDeviceChanges`; that reports through `onDeviceChange`.
    var onInterruption: (() -> Void)?

    /// With `survivingDeviceChanges`: the audio setup changed. Nil when the capture records
    /// again, otherwise why not (it keeps trying). Called on the main thread.
    var onDeviceChange: ((Error?) -> Void)?

    /// 0...1, scaled like the system recorder's meter.
    var currentLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return level
    }

    /// The level of the latest buffer in dB.
    var currentPowerDB: Float {
        lock.lock()
        defer { lock.unlock() }
        return currentDB
    }

    /// The loudest moment so far in dB; about -120 means digital silence (a muted or closed-lid microphone).
    var peakPowerDB: Float {
        lock.lock()
        defer { lock.unlock() }
        return peakDB
    }

    /// Recorded time, without pauses.
    var duration: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return Double(framesWritten) / sampleRate
    }

    var isRunning: Bool { engine.isRunning }

    /// While paused the microphone stays open, but nothing is written.
    func setPaused(_ value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard value != paused else { return }
        if value {
            pausedSince = Date()
            level = 0
        } else if let pausedSince {
            pausedTotal += Date().timeIntervalSince(pausedSince)
            self.pausedSince = nil
        }
        paused = value
    }

    /// - Parameters:
    ///   - device: The microphone, or nil for the Mac's default input.
    ///   - survivingDeviceChanges: Start again by itself when the audio setup changes. Call
    ///     `start` and `stop` on the main thread then.
    func start(
        device: AudioDeviceID?,
        writingTo url: URL,
        settings: [String: Any] = EngineCapture.dictationSettings,
        survivingDeviceChanges: Bool = false
    ) throws {
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        target = file.processingFormat
        sampleRate = file.processingFormat.sampleRate
        survivesDeviceChanges = survivingDeviceChanges
        lock.lock()
        self.file = file
        startedAt = Date()
        lastDelivery = Date()
        lock.unlock()
        do {
            try attach(device: device)
        } catch {
            lock.lock()
            self.file = nil
            lock.unlock()
            throw error
        }
        guard survivingDeviceChanges else { return }
        let watchdog = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.checkDelivery() }
        RunLoop.main.add(watchdog, forMode: .common)
        self.watchdog = watchdog
    }

    /// Opens the microphone on the current engine and starts it.
    private func attach(device: AudioDeviceID?) throws {
        guard let target else { throw CaptureError.noInputFormat }
        let input = engine.inputNode
        // The audio unit has to take the device first: only then does `inputFormat` report what this
        // device delivers. `outputFormat` keeps the format of the default input (1 channel, 48 kHz),
        // and a tap in that format gets no data from a device with another format (a webcam
        // microphone: 2 channels, 16 kHz).
        if let device {
            do { try input.auAudioUnit.setDeviceID(device) } catch { throw CaptureError.deviceUnavailable }
        }
        let hardwareFormat = input.inputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else { throw CaptureError.noInputFormat }
        guard let converter = AVAudioConverter(from: hardwareFormat, to: target) else { throw CaptureError.noInputFormat }

        input.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
            self?.handle(buffer, converter: converter, target: target)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            // With the device gone or its format changed the engine has stopped; a stopped one
            // cannot record on.
            guard let self, !self.engine.isRunning else { return }
            if self.survivesDeviceChanges {
                self.restart()
            } else {
                self.onInterruption?()
            }
        }
    }

    private func detach() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Opens the microphone again after the audio setup changed: the picked one while it is
    /// connected, else the Mac's default input. A fresh engine reads the new setup; the old one
    /// keeps the format it started with.
    private func restart() {
        detach()
        engine = AVAudioEngine()
        lock.lock()
        fillsGap = true
        level = 0
        // Until the microphone delivers again, the level is "nothing" and not the last one heard.
        currentDB = -160
        lock.unlock()
        do {
            try attach(device: AudioInputDevices.preferredDeviceID())
            restarts += 1
            restartFailed = false
            onDeviceChange?(nil)
        } catch {
            detach()
            // Once per loss; the next tries are quiet.
            if !restartFailed { onDeviceChange?(error) }
            restartFailed = true
        }
        lock.lock()
        lastDelivery = Date()
        lock.unlock()
    }

    /// The change notice does not come for every way a microphone can go; no buffers, or a
    /// stopped engine, say the same.
    private func checkDelivery() {
        lock.lock()
        let silentFor = Date().timeIntervalSince(lastDelivery)
        lock.unlock()
        guard !engine.isRunning || silentFor > Self.silenceBeforeRestart else { return }
        restart()
    }

    #if DEBUG
    /// Stops the engine without telling anyone, as when the audio setup changes under it.
    func simulateDeviceLoss() {
        engine.stop()
    }
    #endif

    /// Stops and closes the file, so it is complete when this returns.
    func stop() {
        watchdog?.invalidate()
        watchdog = nil
        detach()
        lock.lock()
        file = nil
        level = 0
        lock.unlock()
    }

    private func handle(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, target: AVAudioFormat) {
        if let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
            var sum: Float = 0
            for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
            let rms = (sum / Float(buffer.frameLength)).squareRoot()
            let power = 20 * log10(max(rms, 0.000_001))
            lock.lock()
            level = max(0, min(1, (power + 50) / 50))
            peakDB = max(peakDB, power)
            currentDB = power
            lock.unlock()
        }

        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate) + 32
        guard let converted = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var delivered = false
        var error: NSError?
        converter.convert(to: converted, error: &error) { _, status in
            if delivered {
                status.pointee = .noDataNow
                return nil
            }
            delivered = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, converted.frameLength > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        lastDelivery = Date()
        guard !paused, let file else { return }
        if fillsGap {
            fillsGap = false
            writeSilence(before: converted.frameLength, to: file)
        }
        if (try? file.write(from: converted)) != nil { framesWritten += AVAudioFramePosition(converted.frameLength) }
    }

    /// Silence for the time the microphone was away, measured on the clock and without pauses,
    /// up to the buffer that arrives now. Called under `lock`.
    private func writeSilence(before frames: AVAudioFrameCount, to file: AVAudioFile) {
        let format = file.processingFormat
        let recorded = Date().timeIntervalSince(startedAt) - pausedTotal
        var missing = AVAudioFramePosition(recorded * format.sampleRate) - AVAudioFramePosition(frames) - framesWritten
        guard missing > AVAudioFramePosition(format.sampleRate / 10),
              let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate)) else { return }
        silence.frameLength = silence.frameCapacity
        for channel in UnsafeMutableAudioBufferListPointer(silence.mutableAudioBufferList) {
            if let data = channel.mData { memset(data, 0, Int(channel.mDataByteSize)) }
        }
        while missing > 0 {
            silence.frameLength = AVAudioFrameCount(min(AVAudioFramePosition(silence.frameCapacity), missing))
            guard (try? file.write(from: silence)) != nil else { return }
            framesWritten += AVAudioFramePosition(silence.frameLength)
            missing -= AVAudioFramePosition(silence.frameLength)
        }
    }
}
