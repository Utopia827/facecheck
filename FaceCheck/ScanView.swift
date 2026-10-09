import SwiftUI

struct ScanView: View {
    @ObservedObject var tracker: FaceTracker
    @ObservedObject var flow: FlowModel
    var onClose: () -> Void

    private let circle: CGFloat = 270
    private let ring: CGFloat = 316

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Button(action: tracker.flip) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 8)

            if tracker.denied {
                CameraDeniedView()
            } else {
                scanner
            }
        }
        .background(Color.white.ignoresSafeArea())
        .onAppear { tracker.start() }
        .onDisappear { tracker.stop() }
        .onReceive(tracker.$pose) { flow.update($0) }
        .onChange(of: flow.active) { d in tracker.simTarget = d }
    }

    private var scanner: some View {
        VStack(spacing: 0) {
            Text(flow.instruction)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .animation(.easeInOut(duration: 0.2), value: flow.instruction)

            Spacer()

            ZStack {
                TickRing(phase: flow.phase, calibration: flow.calibration, active: flow.active,
                         progress: flow.progress, done: flow.done, faceOK: flow.faceOK)
                    .frame(width: ring, height: ring)

                CameraPreview(tracker: tracker)
                    .frame(width: circle, height: circle)
                    .clipShape(Circle())

                if flow.phase == .checking {
                    Circle().fill(Color.white.opacity(0.55)).frame(width: circle, height: circle)
                    ProgressView().controlSize(.large).tint(.black)
                }
            }
            .frame(width: ring, height: ring)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: flow.active)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: flow.faceOK)
            .animation(.easeInOut(duration: 0.25), value: flow.phase)

            Spacer()

            StepDots(steps: flow.steps, done: flow.done, active: flow.active, onTap: flow.forceStep)
                .padding(.bottom, 56)
        }
    }
}

/// (Removed: the floating ArrowCue badge — the TickRing's active blue wedge
///  with its white arrow glyph carries the direction cue now, and only one
///  white-on-blue shape may be on screen for the on-device screen analyzer.)

private struct StepDots: View {
    let steps: [Direction]
    let done: Set<Direction>
    let active: Direction?
    let onTap: (Direction) -> Void

    var body: some View {
        HStack(spacing: 18) {
            ForEach(steps, id: \.self) { d in
                let isDone = done.contains(d)
                let isActive = d == active
                Button { onTap(d) } label: {
                    ZStack {
                        Circle()
                            .fill(isDone ? Color.doneGreen
                                        : isActive ? Color.igBlue
                                        : Color.tickGrey)
                        Image(systemName: isDone ? "checkmark" : d.symbol)
                            .font(.system(size: 18, weight: .bold))
                            // active: DARK arrow — a white glyph in a blue circle would
                            // false-trigger the on-device arrow detector (that job
                            // belongs to the ArrowCue badge alone)
                            .foregroundStyle(isDone ? Color.white
                                             : isActive ? Color(red: 0.05, green: 0.12, blue: 0.3)
                                             : Color(white: 0.55))
                    }
                    .frame(width: 48, height: 48)
                    .scaleEffect(isActive ? 1.18 : 1)
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDone)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
            }
        }
    }
}

private struct CameraDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color(white: 0.6))
            Text("Allow camera access")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
            Text("Turn on the camera in Settings to take your video selfie.")
                .font(.system(size: 15))
                .foregroundStyle(Color(white: 0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.igBlue, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}
