import SwiftUI
import MultipeerConnectivity
import simd
import AVFoundation
import ARKit
import RealityKit

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
    let findingMode: FindingMode

    var body: some View {
        let showBlur = nearbyManager.currentWorldTransform == nil || nearbyManager.showCoachingOverlay

        VStack(spacing: 12) {
            Text("Tracking \(peer.displayName)")
                .foregroundStyle(.white)
                .font(.headline)
                .shadow(radius: 2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
            
            // NICoachingOverlay sẽ hiển thị arrow + distance + guidance ở center
            
            Spacer()

            // Quality badge ở dưới (không trùng với overlay)
            qualityBadge(nearbyManager.latestQuality)

            Text("Di chuyển chậm và giữ thiết bị hướng về nhau để tín hiệu UWB mạnh nhất.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .shadow(radius: 1)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                #if targetEnvironment(simulator)
                // Simulator: không dùng camera
                Color.black
                #else
                // Device: dùng RealityKit AR với NI camera assistance + animated spheres/text
                NICameraAssistanceView(findingMode: findingMode, nearbyManager: nearbyManager)
                #endif
                // Slight overlay để tạo depth
                Color.black.opacity(0.15)
                if showBlur {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .blur(radius: 10)
                }
            }
        )
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .center) {
            NICoachingOverlay(
                findingMode: findingMode,
                isConverged: false, // TODO: track convergence status
                measurementQuality: nearbyManager.latestQuality,
                distance: nearbyManager.latestDistance,
                horizontalAngle: nearbyManager.latestHorizontalAngle,
                showCoachingOverlay: nearbyManager.showCoachingOverlay,
                showUpdownText: nearbyManager.showUpDownText != nil
            )
        }
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
