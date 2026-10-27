import SwiftUI

// Shapes of the Diktat look, shared by the iOS app, its extensions and the Mac app:
// the speech bubble of the record button, the message bubble of the last result, the
// typing loader and the Diktat mark.

/// A speech bubble: a circle filling the rect with a short curved tail at the bottom
/// leading edge. The tail reaches outside the rect, so give the shape some room below.
/// `tail` 0 is a plain circle and 1 the full bubble, so the shape can morph.
struct SpeechBubbleShape: Shape {
    var tail: CGFloat = 1

    var animatableData: CGFloat {
        get { tail }
        set { tail = newValue }
    }

    // Angles in degrees, clockwise from the right; distances in radii.
    private static let tailStart = 112.0, tailEnd = 150.0
    private static let tip = (angle: 132.0, distance: 1.38)
    private static let controlIn = (angle: 118.0, distance: 1.12)
    private static let controlOut = (angle: 138.0, distance: 1.02)

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        func point(_ degrees: Double, _ distance: Double) -> CGPoint {
            let stretched = 1 + (distance - 1) * Double(tail)
            let angle = degrees * .pi / 180
            return CGPoint(x: center.x + radius * stretched * cos(angle), y: center.y + radius * stretched * sin(angle))
        }

        var path = Path()
        let steps = 120
        for step in 0...steps {
            let degrees = Self.tailEnd + (Self.tailStart + 360 - Self.tailEnd) * Double(step) / Double(steps)
            let angle = degrees * .pi / 180
            let onCircle = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            step == 0 ? path.move(to: onCircle) : path.addLine(to: onCircle)
        }
        path.addQuadCurve(to: point(Self.tip.angle, Self.tip.distance), control: point(Self.controlIn.angle, Self.controlIn.distance))
        path.addQuadCurve(to: point(Self.tailEnd, 1), control: point(Self.controlOut.angle, Self.controlOut.distance))
        path.closeSubpath()
        return path
    }
}

/// A chat message: rounded rect with a small tail at the bottom trailing corner, like a
/// sent message. Used for the last result on the start screen.
struct MessageBubbleShape: Shape {
    var radius: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        let body = UnevenRoundedRectangle(
            topLeadingRadius: radius,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: 6,
            topTrailingRadius: radius,
            style: .continuous
        )
        .path(in: rect)

        var tail = Path()
        tail.move(to: CGPoint(x: rect.maxX - 16, y: rect.maxY))
        tail.addQuadCurve(to: CGPoint(x: rect.maxX + 6, y: rect.maxY + 4), control: CGPoint(x: rect.maxX - 2, y: rect.maxY + 2))
        tail.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - 14), control: CGPoint(x: rect.maxX - 1, y: rect.maxY - 2))
        tail.closeSubpath()
        return body.union(tail)
    }
}

/// Loading indicator: a speech bubble with three dots that rise one after another, the
/// way a chat shows that someone is writing.
struct TypingIndicator: View {
    var color: Color = DiktatColor.accent
    /// Ink of the dots on `color`.
    var dotColor: Color = .white
    var size: CGFloat = 48

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: size * 0.08) {
                ForEach(0..<3, id: \.self) { index in
                    let wave = max(0, sin(time * 5 - Double(index) * 0.8))
                    Circle()
                        .fill(dotColor)
                        .frame(width: size * 0.13, height: size * 0.13)
                        .offset(y: -size * 0.06 * wave)
                        .opacity(0.55 + 0.45 * wave)
                }
            }
            .frame(width: size, height: size)
            .background(SpeechBubbleShape().fill(color))
        }
        .accessibilityLabel("Lädt")
    }
}

/// The Diktat mark: five sound bars, drawn as a shape so it stays sharp and takes the
/// ink of the theme.
struct DiktatMark: Shape {
    /// Heights of the five bars relative to the square the mark is drawn in.
    private static let heights: [CGFloat] = [0.34, 0.62, 0.92, 0.62, 0.34]

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        let count = CGFloat(Self.heights.count)
        let barWidth = side * 0.13
        let gap = (side - count * barWidth) / (count - 1)
        var path = Path()
        for (index, height) in Self.heights.enumerated() {
            let barHeight = side * height
            let bar = CGRect(
                x: origin.x + CGFloat(index) * (barWidth + gap),
                y: origin.y + (side - barHeight) / 2,
                width: barWidth,
                height: barHeight
            )
            path.addRoundedRect(in: bar, cornerSize: CGSize(width: barWidth / 2, height: barWidth / 2))
        }
        return path
    }
}
