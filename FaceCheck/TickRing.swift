import SwiftUI

/// Ring around the camera circle.
/// Idle: grey ticks. Calibrating: ticks fill green clockwise. Turning: the
/// active direction owns a solid blue wedge with a white arrow glyph inside,
/// and a green wedge sweeps with progress; done directions keep green wedges.
///
/// Color contract with the on-device screen analyzer: blue only ever marks the
/// ACTIVE direction wedge (calibration uses green, the step dots use a dark
/// glyph on blue with no white), and exactly one white-glyph-on-blue shape is
/// on screen at a time.
struct TickRing: View {
    let phase: FlowModel.Phase
    let calibration: Double
    let active: Direction?
    let progress: Double
    let done: Set<Direction>
    let faceOK: Bool

    private let count = 72
    private let tickLength: CGFloat = 16
    private let halfSector = 40.0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    Capsule()
                        .fill(tickColor(i))
                        .frame(width: 3.5, height: tickLength)
                        .offset(y: -(size / 2 - tickLength / 2))
                        .rotationEffect(.degrees(Double(i) / Double(count) * 360))
                }

                if phase == .turning || phase == .checking || phase == .finished {
                    ForEach(Direction.allCases, id: \.self) { d in
                        if done.contains(d) {
                            wedgePath(size: size, centerAngle: d.sectorCenter)
                                .fill(Color.doneGreen.opacity(0.85))
                        } else if d == active && phase == .turning {
                            wedgePath(size: size, centerAngle: d.sectorCenter)
                                .fill(Color.igBlue)
                            // progress sweeps an INNER arc, leaving the blue
                            // wedge intact — covering it shrank the blue blob
                            // below the screen analyzer's gates and dropped
                            // detection mid-step (the one-detection flicker).
                            if progress > 0.01 {
                                let sweepHalf = halfSector * progress
                                wedgePath(size: size,
                                          centerAngle: d.sectorCenter - halfSector + sweepHalf,
                                          halfWidth: max(sweepHalf, 0.01),
                                          innerScale: 4.6, outerScale: 2.6)
                                    .fill(Color.doneGreen)
                            }
                        }
                    }
                }

                // White arrow glyph inside the active wedge — the single
                // white-on-blue shape the screen analyzer tracks.
                if phase == .turning, let d = active, faceOK {
                    Image(systemName: d.symbol)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 3)
                        .offset(x: d.unit.dx * (size / 2 - 26), y: d.unit.dy * (size / 2 - 26))
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

    private func tickColor(_ i: Int) -> Color {
        let fraction = Double(i) / Double(count)
        switch phase {
        case .checking, .finished:
            return .doneGreen
        case .calibrating:
            return faceOK && fraction < calibration ? .doneGreen : .tickGrey
        case .turning:
            return .tickGrey
        }
    }

    /// Annular sector centered on `centerAngle` (degrees, 0 = 3 o'clock,
    /// clockwise in screen coordinates). innerScale/outerScale position the
    /// band: larger = closer to the center.
    private func wedgePath(size: CGFloat, centerAngle: Double,
                           halfWidth: Double? = nil,
                           innerScale: CGFloat = 2.4, outerScale: CGFloat = 0) -> Path {
        let hw = halfWidth ?? halfSector
        let center = CGPoint(x: size / 2, y: size / 2)
        let tickLen = tickLength
        let outer = outerScale == 0 ? size / 2 - 4 : size / 2 - tickLen * outerScale
        let inner = size / 2 - tickLen * innerScale
        var p = Path()
        p.addArc(center: center, radius: outer,
                 startAngle: .degrees(centerAngle - hw),
                 endAngle: .degrees(centerAngle + hw), clockwise: false)
        p.addArc(center: center, radius: inner,
                 startAngle: .degrees(centerAngle + hw),
                 endAngle: .degrees(centerAngle - hw), clockwise: true)
        p.closeSubpath()
        return p
    }
}
