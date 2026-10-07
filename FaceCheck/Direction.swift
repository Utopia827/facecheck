import SwiftUI

enum Direction: CaseIterable, Hashable {
    case left, right, up

    var instruction: String {
        switch self {
        case .left: return "Turn your head left"
        case .right: return "Turn your head right"
        case .up: return "Look up"
        }
    }

    var arrowAsset: String {
        switch self {
        case .left: return "ArrowLeft"
        case .right: return "ArrowRight"
        case .up: return "ArrowUp"
        }
    }

    var symbol: String {
        switch self {
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .up: return "arrow.up"
        }
    }

    /// Centre of this direction's ring sector, in degrees, 0 = 3 o'clock, clockwise (screen coordinates).
    var sectorCenter: Double {
        switch self {
        case .left: return 180
        case .right: return 0
        case .up: return 270
        }
    }

    /// Unit vector pointing where the head should go, in screen coordinates.
    var unit: CGVector {
        switch self {
        case .left: return CGVector(dx: -1, dy: 0)
        case .right: return CGVector(dx: 1, dy: 0)
        case .up: return CGVector(dx: 0, dy: -1)
        }
    }
}

extension Color {
    static let igBlue = Color(red: 0, green: 0x95 / 255, blue: 0xF6 / 255)
    static let doneGreen = Color(red: 0x1F / 255, green: 0xC1 / 255, blue: 0x6B / 255)
    static let tickGrey = Color(white: 0.86)
}
