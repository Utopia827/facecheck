import SwiftUI

struct RootView: View {
    enum Screen { case intro, scan, success }

    /// Launch argument for CI: start on the scan screen and loop the flow without taps.
    private let autoplay = ProcessInfo.processInfo.arguments.contains("-autoplay")

    @State private var screen: Screen
    @StateObject private var tracker = FaceTracker()
    @StateObject private var flow = FlowModel()

    init() {
        _screen = State(initialValue: ProcessInfo.processInfo.arguments.contains("-autoplay") ? .scan : .intro)
    }

    var body: some View {
        ZStack {
            switch screen {
            case .intro:
                IntroView(onContinue: startScan)
                    .transition(.opacity)
            case .scan:
                ScanView(tracker: tracker, flow: flow, onClose: restart)
                    .transition(.move(edge: .trailing))
            case .success:
                SuccessView(onDone: restart)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
        .onChange(of: flow.phase) { phase in
            if phase == .finished { screen = .success }
        }
        .task(id: screen) {
            guard autoplay, screen == .success else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if screen == .success { restart() }
        }
    }

    private func startScan() {
        flow.reset()
        screen = .scan
    }

    private func restart() {
        flow.reset()
        screen = autoplay ? .scan : .intro
    }
}
