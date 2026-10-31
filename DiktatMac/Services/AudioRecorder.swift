import AVFoundation
import Observation

@Observable
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    var isRecording = false
    var recordingURL: URL?
    var errorMessage: String?
    var audioLevel: Float = 0
    var lastRecordingDuration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    /// Set while a microphone other than the Mac's default input records.
    private var capture: EngineCapture?
    private var levelTimer: Timer?
    private var maxPowerDB: Float = -160
    private var adaptiveLevel = AdaptiveLevel()
    private var silentSince: Date?
    /// Digital silence for more than a second while recording: the microphone delivers nothing.
    private(set) var noSignal = false
    /// The recording was digital silence from start to end: a muted microphone, or the built-in one
    /// of a MacBook with the lid closed.
    private(set) var heardOnlySilence = false

    /// One file per recording: deleting one after its transcription never hits the next.
    private var fileURL = AudioRecorder.newFileURL()

    private static func newFileURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("recording-\(UUID().uuidString).m4a")
    }

    /// Deletes this recorder's audio, for recordings that are not transcribed.
    func discardRecording() {
        try? FileManager.default.removeItem(at: fileURL)
        recordingURL = nil
    }

    /// Recordings a crash or quit left behind, with their padded copies (`AudioPadding`), the
    /// stretches of live notes and the converted and streamed copies of meeting and audio file
    /// sound; nothing records or transcribes while the app starts.
    static func removeLeftoverRecordings() {
        let temp = FileManager.default.temporaryDirectory
        let files = (try? FileManager.default.contentsOfDirectory(at: temp, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            let name = file.lastPathComponent
            let leftover = (name.hasPrefix("recording") && file.pathExtension == "m4a")
                || (["diktat-padded-", "diktat-live-", "diktat-import-"].contains { name.hasPrefix($0) } && file.pathExtension == "wav")
                || (name.hasPrefix("fluidaudio-streaming-") && file.pathExtension == "raw")
            if leftover { try? FileManager.default.removeItem(at: file) }
        }
    }

    func startRecording() {
        errorMessage = nil
        lastRecordingDuration = 0
        maxPowerDB = -160
        adaptiveLevel.reset()
        heardOnlySilence = false
        silentSince = nil
        noSignal = false
        fileURL = Self.newFileURL()

        // Without access macOS records silence; say why instead of "Keine Aufnahme erkannt".
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .denied, .restricted:
            errorMessage = MicrophonePermission.deniedMessage
            return
        default:
            break
        }

        if startPickedMicrophone() { return }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            guard audioRecorder?.record() == true else {
                audioRecorder = nil
                errorMessage = String(localized: "Die Aufnahme lie\u{00DF} sich nicht starten. Darf Diktat das Mikrofon nutzen?")
                return
            }
            isRecording = true
            recordingURL = nil
            startMetering()
        } catch {
            errorMessage = String(localized: "Aufnahme konnte nicht gestartet werden: \(error.localizedDescription)")
        }
    }

    /// Records the microphone picked in the settings. False when none is picked, it is not
    /// connected or it does not open: then the Mac's default input records, as without a choice.
    private func startPickedMicrophone() -> Bool {
        guard let device = AudioInputDevices.preferredDeviceID() else { return false }
        let capture = EngineCapture()
        do {
            try capture.start(device: device, writingTo: fileURL)
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            return false
        }
        self.capture = capture
        isRecording = true
        recordingURL = nil
        startMetering()
        return true
    }

    func stopRecording() {
        stopMetering()
        if let capture {
            lastRecordingDuration = capture.duration
            capture.stop()
            self.capture = nil
        } else {
            lastRecordingDuration = audioRecorder?.currentTime ?? 0
            audioRecorder?.stop()
        }
        isRecording = false
        // Digital silence reads about -120 dB; the quietest real room is far above -110.
        heardOnlySilence = lastRecordingDuration > 0.6 && maxPowerDB < -110
        recordingURL = fileURL
        audioLevel = 0
    }

    private func startMetering() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            if let capture = self.capture {
                self.audioLevel = self.adaptiveLevel.normalize(capture.currentLevel)
                self.maxPowerDB = max(self.maxPowerDB, capture.peakPowerDB)
                self.trackSignal(powerDB: capture.currentPowerDB)
                return
            }
            self.audioRecorder?.updateMeters()
            let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            self.maxPowerDB = max(self.maxPowerDB, power)
            self.trackSignal(powerDB: power)
            let raw = max(0, min(1, (power + 50) / 50))
            self.audioLevel = self.adaptiveLevel.normalize(raw)
        }
    }

    /// Digital silence reads about -120 dB; the quietest real room is far above -110.
    private func trackSignal(powerDB: Float) {
        if powerDB < -110 {
            let since = silentSince ?? Date()
            silentSince = since
            noSignal = Date().timeIntervalSince(since) > 1
        } else {
            silentSince = nil
            noSignal = false
        }
    }

    private func stopMetering() {
        levelTimer?.invalidate()
        levelTimer = nil
        silentSince = nil
        noSignal = false
    }

    // MARK: - AVAudioRecorderDelegate

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task { @MainActor in
                self.errorMessage = String(localized: "Aufnahme fehlgeschlagen")
            }
        }
    }
}
