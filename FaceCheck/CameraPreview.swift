import AVFoundation
import SwiftUI

struct CameraPreview: View {
    @ObservedObject var tracker: FaceTracker

    var body: some View {
        #if targetEnvironment(simulator)
        SimulatedFace(pose: tracker.pose)
        #else
        PreviewLayerView(session: tracker.session)
        #endif
    }
}

private struct PreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The connection only exists once the session has its camera, so check on every layout.
        if let c = previewLayer.connection, c.isVideoOrientationSupported, c.videoOrientation != .portrait {
            c.videoOrientation = .portrait
        }
    }
}

/// Stand-in for the camera in the simulator, a silhouette that turns with the simulated pose.
private struct SimulatedFace: View {
    let pose: FacePose?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.32), Color(white: 0.12)], startPoint: .top, endPoint: .bottom)
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 190)
                .foregroundStyle(Color(white: 0.78))
                .offset(y: 50)
                .rotation3DEffect(.degrees((pose?.h ?? 0) * 140), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .rotation3DEffect(.degrees((0.55 - (pose?.v ?? 0.55)) * 220), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .opacity(pose == nil ? 0 : 1)
                .animation(.easeOut(duration: 0.3), value: pose == nil)
        }
    }
}
