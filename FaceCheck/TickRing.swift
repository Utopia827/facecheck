import SwiftUI

/// Ring of tick marks around the camera circle.
/// Calibration fills it blue clockwise from 12 o'clock; each direction then owns a sector that fills green.
struct TickRing: View {
    let phase: FlowModel.Phase
    let calibration: Double
    let active: Direction?
    let progress: Double
    let done: Set<Direction>
    let faceOK: Bool

    private let count = 72
    private let tickLength: CGFloat = 16
    private let halfSector = 44.0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(color(i))
                        .frame(width: 3.5, height: tickLength)
                        .offset(y: -(size / 2 - tickLength / 2))
                        .rotationEffect(.degrees(Double(i) / Double(count) * 360))
                }
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .animation(.easeOut(duration: 0.15), value: progress)
        .animation(.easeOut(duration: 0.15), value: calibration)
        .animation(.easeInOut(duration: 0.3), value: done)
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    private func color(_ i: Int) -> Color {
        let fraction = Double(i) / Double(count)
        switch phase {
        case .checking, .finished:
            return .doneGreen
        case .calibrating:
            return faceOK && fraction < calibration ? .igBlue : .tickGrey
        case .turning:
            // Screen angle of this tick: 0 = 3 o'clock, clockwise.
            let angle = (fraction * 360 - 90 + 360).truncatingRemainder(dividingBy: 360)
            for d in Direction.allCases {
                let dist = angularDistance(angle, d.sectorCenter)
                guard dist <= halfSector else { continue }
                if done.contains(d) { return .doneGreen }
                if d == active, faceOK, dist / halfSector <= progress, progress > 0 { return .doneGreen }
                return .tickGrey
            }
            return .tickGrey
        }
    }

    private func angularDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }
}
