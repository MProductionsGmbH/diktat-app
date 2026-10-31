import AppKit
import OSLog
import SwiftUI

private let indicatorLogger = Logger(subsystem: "app.diktat.mac", category: "RecordingIndicator")

/// A small black pill at the bottom of the screen while Diktat records or writes, so the recording
/// is visible wherever you type, not only in the menu bar. While recording it holds a row of thin
/// bars that follow the voice like a seismograph: tiny dots when it is quiet, bars of changing
/// height when someone speaks. When a recording starts, a label above the pill names the microphone
/// for a few seconds. A click on the pill stops a recording; during a meeting it shows the running
/// time and a click opens the meeting page. The panel never takes the focus, so the text still
/// lands in the app you are typing in.
@MainActor
final class RecordingIndicatorController {
    private let appState: AppState
    private let model = RecordingIndicatorModel()
    private var panel: NSPanel?
    private var lastStatus: MenuBarStatus = .idle
    /// Counts show and hide transitions; a fade that finishes late only hides the
    /// panel if no newer transition happened meanwhile.
    private var transition = 0
    private var meterTimer: Timer?
    private var hintTask: Task<Void, Never>?
    /// The microphone the label above the pill was last shown for: it appears again only when a recording
    /// starts with another one, not at every press.
    private var lastAnnouncedMicrophone: String?

    init(appState: AppState) {
        self.appState = appState
    }

    func update(to status: MenuBarStatus) {
        lastStatus = status
        guard appState.appSettings.showsRecordingIndicator else {
            hide()
            return
        }
        switch status {
        case .recording:
            let startsNow = !model.status.isRecording
            model.status = status
            if startsNow {
                let device = AudioInputDevices.activeDevice()
                model.microphoneName = device?.name ?? ""
                model.resetLevels()
                if let device, device.uid != lastAnnouncedMicrophone {
                    lastAnnouncedMicrophone = device.uid
                    showHintBriefly()
                }
            }
            startMeter()
            // A new recording picks the screen you work on now.
            show(placing: panel?.isVisible != true || isHiding)
        case .processing:
            stopMeter()
            model.status = status
            show(placing: panel?.isVisible != true)
        case .success:
            stopMeter()
            guard panel?.isVisible == true, !isHiding else { return }
            model.status = status
            hide(after: .milliseconds(900))
        case .copied:
            // Longer than "Fertig": it says the text did not go where it was meant to.
            stopMeter()
            model.status = status
            show(placing: panel?.isVisible != true)
            hide(after: .milliseconds(2_600))
        case .meeting:
            // Back after a dictation in between, or a meeting just started.
            stopMeter()
            model.status = status
            show(placing: panel?.isVisible != true || isHiding)
        case .idle, .error:
            stopMeter()
            hide()
        }
    }

    /// The setting changed, possibly mid-recording: apply it right away.
    func settingChanged() {
        update(to: lastStatus)
    }

    private var isHiding = false

    /// The microphone label above the pill: gone after three seconds.
    private func showHintBriefly() {
        hintTask?.cancel()
        model.showsHint = true
        hintTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.model.showsHint = false
        }
    }

    /// Feeds the bars: the input level about fifteen times a second, newest on the right.
    private func startMeter() {
        guard meterTimer == nil else { return }
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let workflow = self.appState.activeWorkflow
                self.model.noSignal = workflow?.noSignal ?? false
                self.model.push(level: workflow?.audioLevel ?? 0)
            }
        }
    }

    private func stopMeter() {
        meterTimer?.invalidate()
        meterTimer = nil
        hintTask?.cancel()
        model.showsHint = false
        model.noSignal = false
    }

    private func show(placing: Bool) {
        transition += 1
        isHiding = false
        let panel = panel ?? makePanel()
        self.panel = panel
        if placing { place(panel) }
        panel.ignoresMouseEvents = !model.status.isRecording && model.status != .meeting
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            indicatorLogger.info("Pill shown: window \(panel.frame.width, privacy: .public) x \(panel.frame.height, privacy: .public)")
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }
    }

    private func hide(after delay: Duration? = nil) {
        guard let panel, panel.isVisible else { return }
        transition += 1
        let current = transition
        isHiding = true
        panel.ignoresMouseEvents = true
        Task { [weak self] in
            if let delay {
                try? await Task.sleep(for: delay)
            }
            guard let self, self.transition == current else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                panel.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                Task { @MainActor in
                    guard let self, self.transition == current else { return }
                    self.isHiding = false
                    panel.orderOut(nil)
                }
            }
        }
    }

    /// Bottom centre, above the Dock, of the screen with the pointer: on a Mac with
    /// several displays that is the one you are working on. The size is always the full
    /// panel, label included, so the window never depends on what is shown inside.
    private func place(_ panel: NSPanel) {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) })
            ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let size = RecordingPill.panelSize
        let frame = screen.visibleFrame
        panel.setFrame(
            NSRect(x: frame.midX - size.width / 2, y: frame.minY + 8, width: size.width, height: size.height),
            display: true
        )
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: RecordingPill.panelSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        let appState = appState
        let hosting = FirstClickHostingView(rootView: RecordingPill(
            model: model,
            appState: appState,
            onStop: { appState.stopCurrentWorkflow() },
            onOpenMeeting: { appState.openMeeting() }
        ))
        // The pill has a fixed size; the panel never resizes with its content.
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: RecordingPill.panelSize)
        panel.contentView = hosting
        return panel
    }
}

private extension MenuBarStatus {
    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
}

@Observable
@MainActor
final class RecordingIndicatorModel {
    var status: MenuBarStatus = .idle
    /// The microphone this recording uses, named in the label above the pill.
    var microphoneName = ""
    var showsHint = false
    /// The microphone has delivered only silence for a moment.
    var noSignal = false
    /// The latest input levels 0...1, oldest first, one per bar.
    private(set) var levels: [Float] = Array(repeating: 0, count: RecordingPill.barCount)

    func push(level: Float) {
        levels.removeFirst()
        levels.append(level)
    }

    func resetLevels() {
        levels = Array(repeating: 0, count: RecordingPill.barCount)
    }

    /// For the design previews.
    func preview(levels: [Float]) {
        self.levels = levels
    }
}

/// Takes the first click, so the pill reacts without activating Diktat.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The pill: small and black, the same in light and dark mode, so it reads on any window behind it.
struct RecordingPill: View {
    let model: RecordingIndicatorModel
    let appState: AppState
    let onStop: () -> Void
    var onOpenMeeting: () -> Void = {}

    static let barCount = 11
    /// The panel is as wide as the longest label and tall enough for pill, label and shadow.
    static let panelSize = CGSize(width: 380, height: 88)
    private static let pillHeight: CGFloat = 26

    var body: some View {
        VStack(spacing: 7) {
            Spacer(minLength: 0)
            hint
            pill
        }
        .frame(width: Self.panelSize.width, height: Self.panelSize.height, alignment: .bottom)
        .padding(.bottom, 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: Label above the pill

    @ViewBuilder
    private var hint: some View {
        let text = hintText
        Text(text ?? " ")
            .font(.ui(12, .semibold))
            .foregroundStyle(model.noSignal ? Color(nsColor: .systemRed) : .white)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(Capsule().fill(Color.black.opacity(0.92)))
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            .opacity(text == nil ? 0 : 1)
            .animation(.easeOut(duration: 0.25), value: text)
            .allowsHitTesting(false)
    }

    /// What the label says: the microphone while a recording starts, a warning while nothing comes in,
    /// and why a text is only on the clipboard.
    private var hintText: String? {
        switch model.status {
        case .recording:
            let name = model.microphoneName
            if model.noSignal {
                return name.isEmpty ? String(localized: "Kein Ton") : String(localized: "Kein Ton (\(name))")
            }
            guard model.showsHint, !name.isEmpty else { return nil }
            return String(localized: "Mikrofon: \(name)")
        case .copied:
            return String(localized: "Nicht eingef\u{00FC}gt, der Text liegt in der Zwischenablage")
        default:
            return nil
        }
    }

    // MARK: The pill

    @ViewBuilder
    private var pill: some View {
        switch model.status {
        case .recording:
            Button(action: onStop) { capsule(width: 78) { VoiceSeismograph(levels: model.levels, silent: model.noSignal) } }
                .buttonStyle(.plain)
                .help("Klicken stoppt die Aufnahme")
        case .meeting:
            // Opens the meeting page instead of stopping: ending a meeting by a stray click would hurt.
            Button(action: onOpenMeeting) { capsule(width: 118) { MeetingPillContent(meeting: appState.meeting) } }
                .buttonStyle(.plain)
                .help("Meeting l\u{00E4}uft. Klicken \u{00F6}ffnet die Meeting-Seite.")
        case .processing:
            capsule(width: 78) { ThinkingBars() }
        case .success:
            capsule(width: 52) {
                Image(systemName: "checkmark")
                    .font(.ui(11, .bold))
                    .foregroundStyle(.white)
            }
        case .copied:
            capsule(width: 52) {
                Image(systemName: "doc.on.clipboard")
                    .font(.ui(11, .semibold))
                    .foregroundStyle(.white)
            }
        case .idle, .error:
            Color.clear.frame(height: Self.pillHeight)
        }
    }

    private func capsule<Content: View>(width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: width, height: Self.pillHeight)
            .background(Capsule().fill(Color.black.opacity(0.94)))
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            .padding(.bottom, 8)
            .contentShape(Capsule())
    }

    private var accessibilityText: String {
        switch model.status {
        case .recording: return String(localized: "Aufnahme l\u{00E4}uft. Klicken stoppt sie.")
        case .processing: return String(localized: "Diktat schreibt")
        case .success: return String(localized: "Fertig")
        case .copied: return String(localized: "Nicht eingef\u{00FC}gt, der Text liegt in der Zwischenablage")
        case .meeting: return String(localized: "Meeting wird aufgenommen. Klicken \u{00F6}ffnet die Meeting-Seite.")
        case .idle, .error: return ""
        }
    }
}

/// A running meeting: a pulsing red dot and the recorded time, or a pause sign.
private struct MeetingPillContent: View {
    let meeting: MeetingController

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if case .recording(let startedAt) = meeting.phase {
            if meeting.pausedAt != nil {
                HStack(spacing: 6) {
                    Image(systemName: "pause.fill")
                        .font(.ui(9, .bold))
                    Text("Pausiert")
                        .font(.ui(11, .semibold))
                }
                .foregroundStyle(.white.opacity(0.9))
            } else {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    let pulse = reduceMotion ? 1 : 0.55 + 0.45 * abs(cos(context.date.timeIntervalSince(startedAt) * .pi / 2))
                    HStack(spacing: 7) {
                        Circle()
                            .fill(Color(nsColor: .systemRed))
                            .frame(width: 7, height: 7)
                            .opacity(pulse)
                            .animation(.easeInOut(duration: 0.9), value: pulse)
                        Text(MeetingView.clock(context.date.timeIntervalSince(startedAt)))
                            .font(.ui(11.5, .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    // "1:02:34" after an hour still fits the capsule.
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }
            }
        }
    }
}

/// The voice as thin bars, newest on the right, like a seismograph: dots while it is quiet, bars of
/// changing height while someone speaks. The bars follow the level also with "Reduce motion" on,
/// since they show what the microphone hears and are no decoration.
private struct VoiceSeismograph: View {
    let levels: [Float]
    let silent: Bool

    private static let barWidth: CGFloat = 2.4
    private static let maxHeight: CGFloat = 15

    var body: some View {
        HStack(spacing: 2.4) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(silent ? Color(nsColor: .systemRed) : Color.white)
                    .frame(width: Self.barWidth, height: height(for: level))
            }
        }
        .animation(.easeOut(duration: 0.08), value: levels)
    }

    private func height(for level: Float) -> CGFloat {
        if silent { return Self.barWidth }
        let voice = VoiceBarMotion.voice(level: level)
        return Self.barWidth + (Self.maxHeight - Self.barWidth) * voice
    }
}

/// While the text is written: a few bars running in a wave.
private struct ThinkingBars: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.4) {
                ForEach(0..<11, id: \.self) { index in
                    let wave = reduceMotion ? 0.3 : 0.5 + 0.5 * sin(time * 5 - Double(index) * 0.7)
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 2.4, height: 2.4 + 7 * wave)
                }
            }
        }
    }
}
