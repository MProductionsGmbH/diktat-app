import AppKit
import Foundation
import Observation

/// Transcribes an audio file on this Mac: Voice Memos from the iPhone (m4a), WhatsApp
/// voice messages (Opus in Ogg) and anything else macOS can decode. The result lands on
/// the clipboard and in the list of earlier files on the page "Audiodatei" (not in the history
/// of dictations); the AI modes can rewrite it afterwards.
@Observable
@MainActor
final class AudioFileController {
    enum Phase: Equatable {
        case idle
        case working(String)
        case done
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var fileName = ""
    private(set) var duration: TimeInterval = 0
    private(set) var transcript = ""
    private(set) var text = ""
    private(set) var mode: WorkflowType = .tapTalk
    private(set) var copied = false
    /// The entry in the list of earlier files that is shown, nil when nothing is kept.
    private(set) var entryID: UUID?

    private var task: Task<Void, Never>?

    var isWorking: Bool {
        if case .working = phase { return true }
        return false
    }

    func transcribe(_ url: URL, appState: AppState) {
        task?.cancel()
        fileName = url.lastPathComponent
        duration = 0
        transcript = ""
        text = ""
        mode = .tapTalk
        copied = false
        entryID = nil

        guard appState.selectedLocalModelIsInstalled else {
            phase = .failed(String(localized: "Zuerst in den Einstellungen ein lokales Sprachmodell laden."))
            return
        }

        phase = .working(String(localized: "Wird umgewandelt ..."))
        let language = appState.transcriptionSettings.language
        let modelName = appState.selectedLocalModelName
        let postProcessor = appState.postProcessor
        let paragraphs = appState.appSettings.automaticParagraphs

        task = Task {
            do {
                let wav = try await Task.detached(priority: .userInitiated) {
                    try AudioFileConverter.convertToWAV(url)
                }.value
                defer { try? FileManager.default.removeItem(at: wav.url) }
                duration = wav.duration
                if Task.isCancelled { return }

                phase = .working(String(localized: "Wird transkribiert ..."))
                let raw = try await LocalTranscriptionService.transcribe(
                    audioURL: wav.url,
                    language: language,
                    modelName: modelName
                ) { [weak self] in
                    self?.phase = .working(LocalTranscriptionService.slowPreparationMessage)
                }
                var processed = postProcessor.process(TranscriptionQualityService.cleanedTranscript(raw))
                if paragraphs {
                    processed = TranscriptParagraphService.format(processed, language: language)
                }
                guard !processed.isEmpty else {
                    phase = .failed(String(localized: "In der Datei wurde keine Sprache erkannt."))
                    return
                }
                if Task.isCancelled { return }

                transcript = SwissSpelling.ifEnabled(processed)
                finish(processed, mode: .tapTalk, appState: appState)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func rewrite(as newMode: WorkflowType, appState: AppState) {
        let promptLanguage = PromptLanguage.resolve(setting: appState.transcriptionSettings.language, text: transcript)
        guard !transcript.isEmpty, let instruction = Self.instruction(for: newMode, appState: appState, language: promptLanguage) else { return }
        task?.cancel()
        copied = false
        phase = .working(String(localized: "\(appState.displayName(for: newMode)) wird formuliert ..."))
        let engine = appState.appSettings.rewriteEngine
        let source = transcript

        task = Task {
            do {
                let rewritten = try await TextRewriter.rewrite(source, instruction: instruction, engine: engine, language: promptLanguage)
                let cleaned = TranscriptionQualityService.cleanedTranscript(rewritten)
                if Task.isCancelled { return }
                finish(cleaned, mode: newMode, appState: appState)
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func showTranscript(appState: AppState) {
        guard !transcript.isEmpty else { return }
        text = transcript
        mode = .tapTalk
        if let entryID { appState.audioFiles.update(entryID, text: transcript, mode: .tapTalk) }
        copy(appState: appState)
    }

    /// Shows an earlier file again. The clipboard stays as it is until "Kopieren".
    func open(_ entry: AudioFileEntry) {
        task?.cancel()
        task = nil
        entryID = entry.id
        fileName = entry.fileName
        duration = entry.duration
        transcript = entry.transcript
        text = entry.text
        mode = entry.workflow
        copied = false
        phase = .done
    }

    /// Deletes an earlier file's text; the page empties when it is the one shown.
    func delete(_ entry: AudioFileEntry, appState: AppState) {
        appState.audioFiles.remove(entry)
        guard entryID == entry.id else { return }
        reset()
    }

    /// Back to the empty page: no file, no text.
    func reset() {
        task?.cancel()
        task = nil
        entryID = nil
        fileName = ""
        duration = 0
        transcript = ""
        text = ""
        mode = .tapTalk
        copied = false
        phase = .idle
    }

    func copy(appState: AppState) {
        appState.copyToClipboard(text)
        copied = true
    }

    func close() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    private func finish(_ written: String, mode: WorkflowType, appState: AppState) {
        let result = SwissSpelling.ifEnabled(written)
        text = result
        self.mode = mode
        if let entryID {
            appState.audioFiles.update(entryID, text: result, mode: mode)
        } else {
            entryID = appState.audioFiles.add(fileName: fileName, duration: duration, transcript: transcript, text: result)
        }
        copy(appState: appState)
        phase = .done
    }

    private static func instruction(for mode: WorkflowType, appState: AppState, language: PromptLanguage) -> String? {
        switch mode {
        case .textImprover: return ModePrompts.textImprovement(appState.textImprovementSettings, language: language)
        case .dampfAblassen: return ModePrompts.dampfAblassen(appState.dampfAblassenSettings, language: language)
        case .emojiText: return ModePrompts.emoji(appState.emojiTextSettings, language: language)
        case .tapTalk, .localTapTalk: return nil
        }
    }
}
