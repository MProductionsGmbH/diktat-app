import AVFoundation
import CoreAudio

/// Records one chosen microphone into a file, 16 kHz mono, in the format the system recorder
/// would write. Used when a microphone other than the Mac's default input is picked, since
/// AVAudioRecorder can only follow the default.
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

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var level: Float = 0
    private var peakDB: Float = -160
    private var paused = false
    private var framesWritten: AVAudioFramePosition = 0
    private var sampleRate: Double = 16_000
    private var configurationObserver: NSObjectProtocol?

    /// The microphone went away or the engine stopped on its own. Called on the main thread.
    var onInterruption: (() -> Void)?

    /// 0...1, scaled like the system recorder's meter.
    var currentLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return level
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
        paused = value
        if value { level = 0 }
        lock.unlock()
    }

    func start(device: AudioDeviceID, writingTo url: URL, settings: [String: Any] = EngineCapture.dictationSettings) throws {
        let input = engine.inputNode
        // The audio unit has to take the device first: only then does `inputFormat` report what this
        // device delivers. `outputFormat` keeps the format of the default input (1 channel, 48 kHz),
        // and a tap in that format gets no data from a device with another format (a webcam
        // microphone: 2 channels, 16 kHz).
        do { try input.auAudioUnit.setDeviceID(device) } catch { throw CaptureError.deviceUnavailable }
        let hardwareFormat = input.inputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 else { throw CaptureError.noInputFormat }

        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let target = file.processingFormat
        guard let converter = AVAudioConverter(from: hardwareFormat, to: target) else { throw CaptureError.noInputFormat }
        self.file = file
        sampleRate = target.sampleRate

        input.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
            self?.handle(buffer, converter: converter, target: target)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            self.file = nil
            throw error
        }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            // With the picked device gone the engine has stopped; a stopped one cannot record on.
            guard let self, !self.engine.isRunning else { return }
            self.onInterruption?()
        }
    }

    /// Stops and closes the file, so it is complete when this returns.
    func stop() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
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
        guard !paused else { return }
        if (try? file?.write(from: converted)) != nil { framesWritten += AVAudioFramePosition(converted.frameLength) }
    }
}
