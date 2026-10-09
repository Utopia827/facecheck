import SwiftUI
import UIKit

@MainActor
final class FlowModel: ObservableObject {
    enum Phase: Equatable { case calibrating, turning, checking, finished }

    @Published private(set) var phase: Phase = .calibrating
    @Published private(set) var steps: [Direction] = Direction.allCases.shuffled()
    @Published private(set) var current = 0
    @Published private(set) var done: Set<Direction> = []
    @Published private(set) var calibration = 0.0   // 0...1
    @Published private(set) var progress = 0.0      // active step, 0...1
    @Published private(set) var faceOK = false

    private let calibrationTime = 0.7
    private let holdTime = 0.25
    private var calibrationStart: Date?
    private var samples: [FacePose] = []
    private var baseline: FacePose?
    private var holdSince: Date?
    private var lastPoseAt: Date?
    private let poseGrace = 0.35   // seconds of landmark dropout tolerated mid-turn

    var active: Direction? { phase == .turning ? steps[current] : nil }

    var instruction: String {
        switch phase {
        case .calibrating: return faceOK ? "Hold still" : "Position your face in the circle"
        case .turning: return faceOK ? steps[current].instruction : "Move your face into the circle"
        case .checking: return "Checking your video selfie"
        case .finished: return "You're all set"
        }
    }

    func reset() {
        phase = .calibrating
        steps = Direction.allCases.shuffled()
        current = 0
        done = []
        calibration = 0
        progress = 0
        faceOK = false
        calibrationStart = nil
        samples = []
        baseline = nil
        holdSince = nil
        lastPoseAt = nil
    }

    func update(_ pose: FacePose?) {
        switch phase {
        case .calibrating:
            faceOK = pose?.inCircle ?? false
            calibrate(pose)
        case .turning:
            faceOK = pose != nil
            track(pose)
        case .checking, .finished:
            break
        }
    }

    private func calibrate(_ pose: FacePose?) {
        // The resting pose is the average over a short, steady stretch with the face in the circle.
        guard let p = pose, p.inCircle else { restartCalibration(); return }
        if let first = samples.first, abs(p.h - first.h) > 0.12 || abs(p.v - first.v) > 0.08 {
            restartCalibration()
        }
        if calibrationStart == nil { calibrationStart = Date() }
        samples.append(p)

        let elapsed = Date().timeIntervalSince(calibrationStart ?? Date())
        calibration = min(elapsed / calibrationTime, 1)
        guard elapsed >= calibrationTime, samples.count >= 5 else { return }

        let n = Double(samples.count)
        baseline = FacePose(h: samples.map(\.h).reduce(0, +) / n, v: samples.map(\.v).reduce(0, +) / n, inCircle: true)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        current = 0
        progress = 0
        phase = .turning
    }

    private func restartCalibration() {
        samples = []
        calibrationStart = nil
        calibration = 0
    }

    private func track(_ pose: FacePose?) {
        guard let b = baseline else { progress = 0; holdSince = nil; return }
        guard let p = pose else {
            // Vision drops landmarks on near-profile frames; brief dropouts
            // must not reset progress/hold (else a turn never completes).
            if let last = lastPoseAt, Date().timeIntervalSince(last) > poseGrace {
                progress = 0
                holdSince = nil
            }
            return
        }
        lastPoseAt = Date()
        let d = steps[current]
        let amount: Double
        switch d {
        case .left: amount = -(p.h - b.h) / Threshold.yaw
        case .right: amount = (p.h - b.h) / Threshold.yaw
        case .up: amount = -(p.v - b.v) / Threshold.pitch
        }
        progress = min(max(amount, 0), 1)

        guard amount >= 1 else { holdSince = nil; return }
        let since = holdSince ?? Date()
        holdSince = since
        if Date().timeIntervalSince(since) >= holdTime { complete(d) }
    }

    private func complete(_ d: Direction) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        done.insert(d)
        holdSince = nil
        progress = 0
        if current + 1 < steps.count {
            current += 1
            return
        }
        phase = .checking
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if phase == .checking { phase = .finished }
        }
    }

    /// Testing: jump straight to a given direction step (tap a step circle).
    func forceStep(_ d: Direction) {
        guard let idx = steps.firstIndex(of: d) else { return }
        current = idx
        progress = 0
        holdSince = nil
        if phase == .calibrating {
            baseline = baseline ?? FacePose(h: 0, v: 0.55, inCircle: true)
        }
        phase = .turning
    }

    /// Testing: tap the big arrow badge to skip the active step.
    func skipActive() {
        guard phase == .turning else { return }
        complete(steps[current])
    }
}
