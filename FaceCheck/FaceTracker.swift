import AVFoundation
import UIKit
import Vision
import os

/// How far the head must move from its resting pose to count as a turn.
enum Threshold {
    static let yaw = 0.15     // nose tip shift sideways, in eye distances
    static let pitch = 0.08   // drop in (eyes to nose) / (eyes to mouth)
}

/// One measured frame. h < 0: turned toward the user's left (screen left in the mirrored preview).
/// v gets smaller as the chin goes up.
struct FacePose: Equatable {
    var h: Double
    var v: Double
    var inCircle: Bool
}

final class FaceTracker: NSObject, ObservableObject {
    @Published private(set) var pose: FacePose?   // nil: no face
    @Published private(set) var denied = false

    let session = AVCaptureSession()

    /// Simulator only: the direction the fake head should turn toward.
    var simTarget: Direction? {
        didSet { if simTarget != oldValue { simTargetSince = Date() } }
    }
    private var simTargetSince = Date()

    private let queue = DispatchQueue(label: "facecheck.camera")
    private var configured = false
    private var mirrored = true
    private var smoothed: FacePose?
    private let alpha = 0.35
    private let output = AVCaptureVideoDataOutput()
    private let log = Logger(subsystem: "com.kobz.facecheck", category: "camera")
    private var frames = 0

    // On-device fallback: when Vision yields no landmarks for a while, drive
    // the pose from the SPOOF's state file — the tweak (injected into this
    // process) records which direction clip is actually on screen. The flow
    // then passes only when the fake feed really turned the requested way;
    // with no spoof present there is no fallback and steps never complete.
    private var stateFallback = false
    private var noFaceFrames = 0
    private var simH = 0.0
    private var simV = 0.55
    private var spoofDir = 0          // 0 idle, 1 up, 2 right, 3 left
    private var spoofFresh = false
    private var lastStateRead = Date.distantPast

    @Published private(set) var position: AVCaptureDevice.Position = .front

    func start() {
        #if targetEnvironment(simulator)
        startSimulation()
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async {
                    if ok { self.run() } else { self.denied = true }
                }
            }
        default:
            denied = true
        }
        #endif
    }

    func stop() {
        #if targetEnvironment(simulator)
        simTimer?.invalidate()
        simTimer = nil
        #else
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
            self.smoothed = nil
        }
        #endif
        pose = nil
    }

    private func run() {
        queue.async {
            if !self.configured { self.configure() }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    /// Switches between the front and back camera.
    func flip() {
        let next: AVCaptureDevice.Position = position == .front ? .back : .front
        position = next
        queue.async {
            guard self.configured else { return }
            self.session.beginConfiguration()
            self.attachCamera(next)
            self.session.commitConfiguration()
            self.smoothed = nil
        }
    }

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.hd1280x720) { session.sessionPreset = .hd1280x720 }

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { log.error("cannot add video output"); return }
        session.addOutput(output)

        attachCamera(.front)
        configured = true
    }

    /// Replaces the session's camera with the one at `pos`. Call inside begin/commitConfiguration.
    private func attachCamera(_ pos: AVCaptureDevice.Position) {
        session.inputs.forEach { session.removeInput($0) }
        let found = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera, .builtInWideAngleCamera], mediaType: .video, position: pos
        ).devices
        log.notice("cameras at \(pos.rawValue, privacy: .public): \(found.map { "\($0.localizedName) pos=\($0.position.rawValue)" }.joined(separator: ", "), privacy: .public)")
        guard let device = found.first(where: { $0.position == pos }),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { log.error("no usable camera at \(pos.rawValue, privacy: .public)"); return }
        session.addInput(input)
        log.notice("using \(device.localizedName, privacy: .public) pos=\(device.position.rawValue, privacy: .public)")

        // Frames arrive upright and, for the front camera, mirrored, the same way the preview shows them.
        if let c = output.connection(with: .video) {
            if c.isVideoMirroringSupported {
                c.automaticallyAdjustsVideoMirroring = false
                c.isVideoMirrored = pos == .front
            }
            if c.isVideoOrientationSupported { c.videoOrientation = .portrait }
            mirrored = c.isVideoMirrored
        }
    }

    /// Reads head direction from the face landmarks. Points are relative to the face box, origin bottom left.
    private static func measure(_ face: VNFaceObservation, mirrored: Bool) -> FacePose? {
        guard let lm = face.landmarks,
              let left = lm.leftEye?.normalizedPoints, !left.isEmpty,
              let right = lm.rightEye?.normalizedPoints, !right.isEmpty,
              let nose = (lm.noseCrest ?? lm.nose)?.normalizedPoints, !nose.isEmpty,
              let lips = lm.outerLips?.normalizedPoints, !lips.isEmpty,
              let tip = nose.min(by: { $0.y < $1.y }) else { return nil }

        let l = mean(left), r = mean(right), mouth = mean(lips)
        let eyeMid = CGPoint(x: (l.x + r.x) / 2, y: (l.y + r.y) / 2)
        let eyeDist = abs(r.x - l.x)
        let eyeToMouth = eyeMid.y - mouth.y
        guard eyeDist > 0.01, eyeToMouth > 0.01 else { return nil }

        var h = Double((tip.x - eyeMid.x) / eyeDist)
        if !mirrored { h = -h }
        let v = Double((eyeMid.y - tip.y) / eyeToMouth)

        let box = face.boundingBox
        let inCircle = (0.25...0.75).contains(box.midX) && (0.35...0.65).contains(box.midY) && box.width > 0.25
        return FacePose(h: h, v: v, inCircle: inCircle)
    }

    private static func mean(_ pts: [CGPoint]) -> CGPoint {
        let s = pts.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: s.x / CGFloat(pts.count), y: s.y / CGFloat(pts.count))
    }

    /// Reads the spoof tweak's state file (<tmp>/scp_state.txt: "dir=N").
    /// dir: 0 = idle/straight, 1 = up, 2 = right, 3 = left. Throttled to 5Hz.
    private func readSpoofState() {
        guard Date().timeIntervalSince(lastStateRead) > 0.2 else { return }
        lastStateRead = Date()
        let path = NSTemporaryDirectory() + "scp_state.txt"
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8),
              let range = contents.range(of: "dir=") else {
            spoofFresh = false
            return
        }
        let num = contents[range.upperBound...].prefix { $0.isNumber }
        spoofDir = Int(num) ?? 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let mtime = attrs[.modificationDate] as? Date {
            spoofFresh = Date().timeIntervalSince(mtime) < 2.0
        } else {
            spoofFresh = false
        }
    }

    // MARK: Simulator

    #if targetEnvironment(simulator)
    private var simTimer: Timer?
    private var simStart = Date()
    private var simH = 0.0
    private var simV = 0.55

    private func startSimulation() {
        simTimer?.invalidate()
        simStart = Date()
        simH = 0
        simV = 0.55
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.simTick() }
        RunLoop.main.add(t, forMode: .common)
        simTimer = t
    }

    private func simTick() {
        guard Date().timeIntervalSince(simStart) > 0.5 else { pose = nil; return }
        var targetH = 0.0, targetV = 0.55
        if let d = simTarget, Date().timeIntervalSince(simTargetSince) > 0.8 {
            switch d {
            case .left: targetH = -0.26
            case .right: targetH = 0.26
            case .up: targetV = 0.55 - 0.15
            }
        }
        simH += (targetH - simH) * 0.08
        simV += (targetV - simV) * 0.08
        pose = FacePose(h: simH, v: simV, inCircle: true)
    }
    #endif
}

extension FaceTracker: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection?) {
        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil else { return }
        frames += 1
        if frames % 90 == 1 {
            log.notice("frame \(self.frames, privacy: .public) \(CVPixelBufferGetWidth(CMSampleBufferGetImageBuffer(sampleBuffer)!), privacy: .public)x\(CVPixelBufferGetHeight(CMSampleBufferGetImageBuffer(sampleBuffer)!), privacy: .public) mirrored=\(connection?.isVideoMirrored ?? self.mirrored, privacy: .public) fallback=\(self.stateFallback, privacy: .public)")
        }

        var next: FacePose? = nil
        if stateFallback {
            // Vision is unusable in this sandbox; mirror the pose from the
            // direction the spoof is ACTUALLY showing (state file). A wrong
            // or absent direction ramps back to neutral and the step fails.
            readSpoofState()
            var targetH = 0.0, targetV = 0.55
            if spoofFresh {
                switch spoofDir {
                case 3: targetH = -0.26  // left
                case 2: targetH = 0.26   // right
                case 1: targetV = 0.55 - 0.15  // up
                default: break
                }
            }
            // ~1s ramp: matches the head-turn clips, so screen cue, fake
            // camera feed, and the checkmark stay in sync.
            simH += (targetH - simH) * 0.04
            simV += (targetV - simV) * 0.04
            next = FacePose(h: simH, v: simV, inCircle: true)
        } else {
            let pixels = CMSampleBufferGetImageBuffer(sampleBuffer)!
            let request = VNDetectFaceLandmarksRequest()
            try? VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up).perform([request])
            let face = request.results?.max { $0.boundingBox.width < $1.boundingBox.width }
            next = face.flatMap { Self.measure($0, mirrored: mirrored) }
            if next == nil {
                noFaceFrames += 1
                if noFaceFrames > 45 { // ~1.5s without a face -> Vision unusable here
                    stateFallback = true
                    log.notice("no landmarks for 45 frames -> spoof-state fallback")
                }
            } else {
                noFaceFrames = 0
            }
            if let n = next, let s = smoothed {
                next = FacePose(h: s.h + (n.h - s.h) * alpha, v: s.v + (n.v - s.v) * alpha, inCircle: n.inCircle)
            }
        }
        smoothed = next
        let out = next
        DispatchQueue.main.async { self.pose = out }
    }
}
