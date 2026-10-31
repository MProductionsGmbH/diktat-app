import CoreGraphics
import Foundation

/// Where the recording pill sits along the bottom edge of the screen. The middle is often where the
/// text field of a chat or a command line is, so the default is the right side at two thirds of the width.
enum PillPosition: String, CaseIterable, Identifiable, Codable {
    case left
    case center
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: return String(localized: "Links")
        case .center: return String(localized: "Mitte")
        case .right: return String(localized: "Rechts")
        }
    }

    /// The share of the screen width, from the left edge, where the middle of the pill sits.
    var share: CGFloat {
        switch self {
        case .left: return 1.0 / 3.0
        case .center: return 0.5
        case .right: return 2.0 / 3.0
        }
    }

    /// The left edge of a panel of this width on a screen area, kept inside the area.
    func originX(in area: CGRect, panelWidth: CGFloat) -> CGFloat {
        let wanted = area.minX + area.width * share - panelWidth / 2
        let upper = max(area.minX, area.maxX - panelWidth)
        return min(max(wanted, area.minX), upper)
    }
}
