import SwiftUI
import MultipeerConnectivity
import simd
import AVFoundation
import ARKit

#if targetEnvironment(simulator)
// Trên Simulator: không dùng ARKit camera
struct ARKitCameraView: View {
    var body: some View { Color.black }
}
#else
struct ARKitCameraView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.automaticallyUpdatesLighting = true
        view.preferredFramesPerSecond = 60
        view.contentScaleFactor = UIScreen.main.scale
        view.backgroundColor = .black

        // Chạy ARKit để hỗ trợ Camera Assistance (trên thiết bị)
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        config.isLightEstimationEnabled = true
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.session.pause()
    }
}
#endif

struct CameraPreview: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        context.coordinator.setupSession(for: view)
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {}
    
    static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
        coordinator.stopSession()
    }
    
    class Coordinator: NSObject {
        var captureSession: AVCaptureSession?
        
        func setupSession(for view: PreviewView) {
            #if targetEnvironment(simulator)
            // Không chạy camera trên simulator
            return
            #else
            let session = AVCaptureSession()
            session.sessionPreset = .high
            self.captureSession = session
            
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
            do {
                let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
                if session.canAddInput(videoInput) {
                    session.addInput(videoInput)
                }
                DispatchQueue.main.async {
                    view.videoPreviewLayer.session = session
                    view.videoPreviewLayer.videoGravity = .resizeAspectFill
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                }
            } catch {
                print("Camera error: \(error)")
            }
            #endif
        }
        
        func stopSession() {
            guard let session = captureSession else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                if session.isRunning { session.stopRunning() }
            }
        }
    }
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

struct TrackingView: View {
    let peer: MCPeerID
    @ObservedObject var nearbyManager: NearbyInteractionManager

    var body: some View {
        let distance = nearbyManager.latestDistance
        let direction = nearbyManager.latestDirection
        let color = backgroundColor(for: distance)
        let arrowAngle = computedArrowAngle(direction: direction, horizontalAngle: nearbyManager.latestHorizontalAngle)

        VStack(spacing: 16) {
            Text("Tracking \(peer.displayName)")
                .foregroundStyle(.white)
                .font(.headline)
                .shadow(radius: 2)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 220, height: 220)
                
                Image(systemName: "location.north.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 160, height: 160)
                    .foregroundStyle(color)
                    .rotationEffect(.degrees(arrowAngle))
                    .shadow(color: .black.opacity(0.5), radius: 4)
            }

            if let distance {
                Text(String(format: "%.2fm", distance))
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            } else {
                Text("Locating...")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
            
            // Gợi ý khi chưa có hướng (Simulator thường không có hướng)
            if nearbyManager.latestHorizontalAngle == nil && direction == nil && distance != nil {
                Text("Point camera at rescuer for direction")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 4)
                    .shadow(radius: 1)
            }

            // Hiển thị chất lượng đo đạc (EDM)
            qualityBadge(nearbyManager.latestQuality)

            Text("Move slowly and keep devices facing each other for strongest UWB signal.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .shadow(radius: 1)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                #if targetEnvironment(simulator)
                // Simulator: không dùng ARKit camera
                Color.black
                #else
                // Device: dùng ARKit camera để hỗ trợ Camera Assistance
                ARKitCameraView()
                #endif
                color.opacity(0.3)
            }
        )
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func backgroundColor(for distance: Float?) -> Color {
        guard let distance else { return .orange }
        if distance < 3 { return .green }
        if distance < 10 { return .yellow }
        return .red
    }

    // Ưu tiên horizontalAngle (iOS 17+, EDM + Camera Assistance), fallback sang vector direction
    private func computedArrowAngle(direction: simd_float3?, horizontalAngle: Float?) -> Double {
        if #available(iOS 17.0, *), let angle = horizontalAngle {
            // horizontalAngle là radian → đổi sang độ
            return Double(angle) * 180.0 / .pi
        } else {
            return angleForArrow(from: direction)
        }
    }

    private func angleForArrow(from direction: simd_float3?) -> Double {
        guard let direction else { return 0 }
        let horizontal = simd_float2(direction.x, direction.z)
        let magnitude = simd_length(horizontal)
        guard magnitude > 0.01 else { return 0 }
        let radians = atan2(Double(horizontal.x), Double(horizontal.y))
        let degrees = radians * 180.0 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    @ViewBuilder
    private func qualityBadge(_ q: MeasurementQualityEstimator.MeasurementQuality) -> some View {
        switch q {
        case .close:
            Label("Close", systemImage: "figure.walk.circle.fill")
                .font(.caption.bold())
                .padding(6)
                .background(.green.opacity(0.2))
                .cornerRadius(8)
                .foregroundColor(.white)
        case .good:
            Label("Good signal", systemImage: "antenna.radiowaves.left.and.right")
                .font(.caption.bold())
                .padding(6)
                .background(.yellow.opacity(0.2))
                .cornerRadius(8)
                .foregroundColor(.white)
        case .unknown:
            EmptyView()
        }
    }
}
