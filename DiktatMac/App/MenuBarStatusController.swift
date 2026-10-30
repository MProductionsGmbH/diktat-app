import AppKit

enum MenuBarStatus: Equatable {
    case idle
    case recording(WorkflowType)
    case processing(WorkflowType)
    case success(WorkflowType?)
    case error(WorkflowType?)
    /// Not pasted on purpose, e.g. because another field has the focus; the text is on the clipboard.
    case copied(WorkflowType?)
    /// A meeting is being recorded; shown while no dictation is active.
    case meeting
}

@MainActor
final class MenuBarStatusController {
    private weak var button: NSStatusBarButton?
    private var animationTimer: Timer?
    private var animationFrame = 0
    private var currentStatus: MenuBarStatus = .idle
    /// The input level while recording, so the symbol follows the voice.
    var levelProvider: (() -> Float)?
    /// Small dot on the idle icon while a release note is unread.
    var showsNewBadge = false {
        didSet {
            guard oldValue != showsNewBadge else { return }
            renderCurrentStatus()
        }
    }

    func attach(to button: NSStatusBarButton) {
        self.button = button
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        renderCurrentStatus()
    }

    func update(to status: MenuBarStatus) {
        currentStatus = status
        animationFrame = 0
        configureAnimationIfNeeded()
        renderCurrentStatus()
    }

    private func configureAnimationIfNeeded() {
        stopAnimation()

        switch currentStatus {
        case .recording:
            startAnimation(interval: 0.08)
        case .processing:
            startAnimation(interval: 0.18)
        default:
            break
        }
    }

    private func startAnimation(interval: TimeInterval) {
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func tick() {
        animationFrame = (animationFrame + 1) % 4
        renderCurrentStatus()
    }

    private func renderCurrentStatus() {
        guard let button else { return }
        var image = MenuBarStatusIconRenderer.makeImage(for: currentStatus, frame: animationFrame, level: levelProvider?() ?? 0)
        if showsNewBadge, case .idle = currentStatus {
            image = MenuBarStatusIconRenderer.withNewDot(image)
        }
        button.image = image
        button.image?.isTemplate = true
        // A running meeting turns the symbol red, so it stands out next to the microphone
        // indicator that other apps keep on as well.
        button.contentTintColor = currentStatus == .meeting ? .systemRed : nil
        button.toolTip = tooltip(for: currentStatus)
    }

    private func tooltip(for status: MenuBarStatus) -> String {
        switch status {
        case .idle:
            return String(localized: "Diktat ist bereit")
        case .recording(let type):
            return String(localized: "\(type.displayName): Aufnahme läuft")
        case .processing(let type):
            return String(localized: "\(type.displayName): Verarbeitung läuft")
        case .success(let type):
            if let type {
                return String(localized: "\(type.displayName): Fertig")
            }
            return String(localized: "Diktat: Fertig")
        case .copied:
            return String(localized: "Diktat: Text liegt in der Zwischenablage")
        case .error(let type):
            if let type {
                return String(localized: "\(type.displayName): Fehler")
            }
            return String(localized: "Diktat: Fehler")
        case .meeting:
            return String(localized: "Meeting: Aufnahme l\u{00E4}uft")
        }
    }

    deinit {
        animationTimer?.invalidate()
    }
}

private enum MenuBarStatusIconRenderer {
    static func withNewDot(_ base: NSImage) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        return NSImage(size: size, flipped: false) { bounds in
            base.draw(in: bounds)
            let diameter: CGFloat = 5.5
            let dot = NSRect(x: bounds.maxX - diameter, y: bounds.maxY - diameter, width: diameter, height: diameter)
            NSColor.black.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
    }

    static func makeImage(for status: MenuBarStatus, frame: Int, level: Float) -> NSImage {
        if case .idle = status, let baseImage = baseTemplateImage() {
            return baseImage
        }

        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { bounds in
            drawMarkBars(in: bounds, status: status, frame: frame, level: level)

            switch status {
            case .recording(let type):
                drawActivityBadge(
                    type: type,
                    systemName: badgeSymbol(for: type),
                    in: bounds,
                    frame: frame,
                    phase: .recording
                )
            case .processing(let type):
                drawActivityBadge(
                    type: type,
                    systemName: badgeSymbol(for: type),
                    in: bounds,
                    frame: frame,
                    phase: .processing
                )
            case .success:
                drawBadge(systemName: "checkmark", in: bounds, fillOpacity: 1.0)
            case .copied:
                drawBadge(systemName: "doc.on.clipboard", in: bounds, fillOpacity: 1.0)
            case .error:
                drawBadge(systemName: "exclamationmark", in: bounds, fillOpacity: 1.0)
            case .meeting:
                drawBadge(systemName: "record.circle", in: bounds, fillOpacity: 1.0)
            default:
                break
            }

            return true
        }
        image.isTemplate = true
        image.size = size
        return image
    }

    private enum ActivityPhase {
        case recording
        case processing
    }

    /// The Diktat mark, as in the idle icon. While recording the bars follow the voice, while
    /// writing they run in a wave; the frame counts up to four.
    private static func drawMarkBars(in bounds: CGRect, status: MenuBarStatus, frame: Int, level: Float) {
        let heights: [CGFloat] = [0.34, 0.62, 0.92, 0.62, 0.34]
        let side: CGFloat = 15
        let barWidth = side * 0.15
        let gap = (side - 5 * barWidth) / 4
        let originX = bounds.midX - side / 2
        let phase = CGFloat(frame) * .pi / 2
        for (index, height) in heights.enumerated() {
            let scale: CGFloat
            switch status {
            case .recording:
                scale = CGFloat(VoiceBarMotion.scale(index: index, level: level, phase: Double(phase)))
            case .processing:
                scale = 0.45 + 0.55 * (0.5 + 0.5 * sin(phase - CGFloat(index) * 0.9))
            default:
                scale = 1
            }
            let barHeight = max(2, side * height * scale)
            let rect = CGRect(x: originX + CGFloat(index) * (barWidth + gap), y: bounds.midY - barHeight / 2, width: barWidth, height: barHeight)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        }
    }

    private static func drawActivityBadge(
        type: WorkflowType,
        systemName: String,
        in bounds: CGRect,
        frame: Int,
        phase: ActivityPhase
    ) {
        let badgeSize: CGFloat = 7.5
        let badgeRect = CGRect(
            x: bounds.maxX - badgeSize - 0.8,
            y: bounds.minY + 0.8,
            width: badgeSize,
            height: badgeSize
        )

        let badgeOpacity: CGFloat
        let haloOpacity: CGFloat

        switch phase {
        case .recording:
            let values: [CGFloat]
            switch type {
            case .tapTalk, .localTapTalk:
                values = [0.74, 1.0, 0.82, 0.92]
            case .textImprover:
                values = [0.66, 0.84, 1.0, 0.8]
            case .dampfAblassen:
                values = [1.0, 0.76, 0.94, 0.68]
            case .emojiText:
                values = [0.8, 0.92, 0.7, 1.0]
            }
            badgeOpacity = values[frame % values.count]
            haloOpacity = 0.14 + (CGFloat(frame % 4) * 0.04)
        case .processing:
            let values: [CGFloat]
            switch type {
            case .tapTalk, .localTapTalk:
                values = [0.58, 0.72, 0.9, 0.72]
            case .textImprover:
                values = [0.48, 0.68, 0.92, 0.84]
            case .dampfAblassen:
                values = [0.84, 0.62, 0.9, 0.56]
            case .emojiText:
                values = [0.54, 0.76, 0.88, 0.68]
            }
            badgeOpacity = values[frame % values.count]
            haloOpacity = 0.12 + (CGFloat((frame + 2) % 4) * 0.03)
        }

        let haloInset = phase == .recording ? -0.8 : -0.45
        let haloRect = badgeRect.insetBy(dx: haloInset, dy: haloInset)
        let haloPath = NSBezierPath(ovalIn: haloRect)
        NSColor.black.withAlphaComponent(haloOpacity).setStroke()
        haloPath.lineWidth = phase == .recording ? 0.9 : 0.75
        haloPath.stroke()

        drawBadge(systemName: systemName, in: bounds, fillOpacity: badgeOpacity)

        if phase == .processing {
            drawProcessingDot(around: badgeRect, frame: frame)
        }
    }

    private static func drawBadge(systemName: String, in bounds: CGRect, fillOpacity: CGFloat) {
        let badgeSize: CGFloat = 7.5
        let badgeRect = CGRect(
            x: bounds.maxX - badgeSize - 0.8,
            y: bounds.minY + 0.8,
            width: badgeSize,
            height: badgeSize
        )

        let badgePath = NSBezierPath(ovalIn: badgeRect)
        NSColor.black.withAlphaComponent(fillOpacity).setFill()
        badgePath.fill()

        guard let symbol = NSImage(
            systemSymbolName: systemName,
            accessibilityDescription: nil
        ) else {
            return
        }

        let config = NSImage.SymbolConfiguration(pointSize: 5.5, weight: .bold)
        let configuredSymbol = symbol.withSymbolConfiguration(config) ?? symbol
        let symbolRect = badgeRect.insetBy(dx: 1.2, dy: 1.2)
        configuredSymbol.draw(
            in: symbolRect,
            from: .zero,
            operation: .destinationOut,
            fraction: 1.0
        )
    }

    private static func drawProcessingDot(around badgeRect: CGRect, frame: Int) {
        let orbitPoints: [CGPoint] = [
            CGPoint(x: badgeRect.midX, y: badgeRect.maxY + 0.35),
            CGPoint(x: badgeRect.maxX + 0.35, y: badgeRect.midY),
            CGPoint(x: badgeRect.midX, y: badgeRect.minY - 0.35),
            CGPoint(x: badgeRect.minX - 0.35, y: badgeRect.midY),
        ]
        let point = orbitPoints[frame % orbitPoints.count]
        let dotRect = CGRect(x: point.x - 0.85, y: point.y - 0.85, width: 1.7, height: 1.7)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        NSColor.black.withAlphaComponent(0.92).setFill()
        dotPath.fill()
    }

    private static func badgeSymbol(for type: WorkflowType) -> String {
        switch type {
        case .tapTalk:
            return "mic.fill"
        case .localTapTalk:
            return "lock.fill"
        case .textImprover:
            return "text.alignleft"
        case .dampfAblassen:
            return "flame.fill"
        case .emojiText:
            return "face.smiling"
        }
    }

    private static func baseTemplateImage() -> NSImage? {
        guard let image = NSImage(named: "menubar_icon") else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}
