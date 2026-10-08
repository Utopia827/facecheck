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

                if let d = flow.active, flow.faceOK {
                    ArrowCue(direction: d)
                        .offset(x: d.unit.dx * (circle / 2 - 46), y: d.unit.dy * (circle / 2 - 46))
                        .id(d)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
            .frame(width: ring, height: ring)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: flow.active)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: flow.faceOK)
            .animation(.easeInOut(duration: 0.25), value: flow.phase)

            Spacer()

            StepDots(steps: flow.steps, done: flow.done, active: flow.active)
                .padding(.bottom, 56)
        }
    }
}

/// The blue arrow, nudging toward where the head should go.
private struct ArrowCue: View {
    let direction: Direction
    @State private var nudge = false

    var body: some View {
        Image(direction.arrowAsset)
            .resizable()
            .scaledToFit()
            .frame(width: 58, height: 58)
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
            .offset(x: direction.unit.dx * (nudge ? 10 : -2), y: direction.unit.dy * (nudge ? 10 : -2))
            .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: nudge)
            .onAppear { DispatchQueue.main.async { nudge = true } }
    }
}

private struct StepDots: View {
    let steps: [Direction]
    let done: Set<Direction>
    let active: Direction?

    var body: some View {
        HStack(spacing: 14) {
            ForEach(steps, id: \.self) { d in
                let isDone = done.contains(d)
                let isActive = d == active
                ZStack {
                    Circle()
                        .fill(isDone ? Color.doneGreen : Color.white)
                        .overlay(Circle().stroke(isDone ? Color.doneGreen : (isActive ? Color.igBlue : Color.tickGrey), lineWidth: 2))
                    Image(systemName: isDone ? "checkmark" : d.symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isDone ? Color.white : (isActive ? Color.igBlue : Color(white: 0.7)))
                }
                .frame(width: 36, height: 36)
                .scaleEffect(isActive ? 1.12 : 1)
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
