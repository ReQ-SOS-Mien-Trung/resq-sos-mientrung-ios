//
//  NICameraAssistanceView.swift
//  SosMienTrung
//
//  Renders AR anchors with animated spheres (exhibit) or text+sphere (visitor) driven by 
//  NearbyInteractionManager world transform state. Based on "Finding Devices with Precision" sample.
//

import SwiftUI
import RealityKit
import ARKit
import MultipeerConnectivity
import Combine

#if os(iOS)
struct NICameraAssistanceView: UIViewRepresentable {
    let findingMode: FindingMode
    @ObservedObject var nearbyManager: NearbyInteractionManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // QUAN TRỌNG: Gắn ARSession vào NISession TRƯỚC khi chạy configuration
        // Nếu gắn SAU thì NISession sẽ invalid
        nearbyManager.attachARSession(arView.session)
        
        // Configure ARWorldTracking AFTER attaching to NISession
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isCollaborationEnabled = false
        configuration.userFaceTrackingEnabled = false
        configuration.initialWorldMap = nil
        configuration.environmentTexturing = .automatic
        configuration.isLightEstimationEnabled = true
        
        arView.session.run(configuration)
        
        context.coordinator.findingMode = findingMode
        context.coordinator.arView = arView
        context.coordinator.nearbyManager = nearbyManager
        
        // Subscribe to worldTransform changes để update AR liên tục
        context.coordinator.startObserving()
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // SwiftUI sẽ gọi method này khi @Published properties thay đổi
        // Nhưng không cần làm gì vì coordinator đã subscribe trực tiếp
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        // Pause ARKit when SwiftUI tears down the view to avoid ARSession deallocation warnings
        uiView.session.pause()
        coordinator.stopObserving()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    @MainActor
    class Coordinator: NSObject {
        var findingMode: FindingMode = .visitor
        weak var arView: ARView?
        weak var nearbyManager: NearbyInteractionManager?
        
        var peerName: String = ""
        var meshText: MeshResource?
        var meshSphere: MeshResource?
        var meshSphereArray = [MeshResource]()
        var initialSize: Float = 0
        
        let sphereSeparation = Float(0.6)
        var animationUpdates: [Cancellable?] = []
        var lastWorldTransform: simd_float4x4?
        var lastDistance: Float = -1
        var lastUpdateTime: TimeInterval = 0  // Throttle updates: max 15 updates/sec
        var subscriptions: [AnyCancellable] = []
        
        // Subscribe to nearbyManager's published properties
        func startObserving() {
            guard let manager = nearbyManager, let arView = arView else { return }
            
            // Subscribe to worldTransform changes
            manager.$currentWorldTransform
                .combineLatest(manager.$latestDistance, manager.$trackedPeer)
                .sink { [weak self, weak arView] (transform, distance, peer) in
                    guard let self = self, let arView = arView else { return }
                    
                    if let distance = distance {
                        self.updatePeerAnchor(
                            arView: arView,
                            currentWorldTransform: transform,
                            peerName: peer?.displayName ?? "Peer",
                            distance: distance
                        )
                    }
                }
                .store(in: &subscriptions)
        }

            func stopObserving() {
                subscriptions.forEach { $0.cancel() }
                subscriptions.removeAll()
            }
        
        // Animate sphere nhảy lên và scale lặp lại
        func animate(entity: HasTransform,
                     reference: Entity?,
                     height: Float,
                     scale: Float,
                     duration: TimeInterval,
                     arView: ARView,
                     index: Int) {
            var transform = entity.transform
            transform.scale *= scale
            transform.translation.y += height
            
            entity.move(to: transform.matrix,
                        relativeTo: reference,
                        duration: duration,
                        timingFunction: .default)
            
            guard animationUpdates.count < (index + 1) else { return }
            
            animationUpdates.append(arView.scene.subscribe(to: AnimationEvents.PlaybackCompleted.self,
                                                     on: entity, { [weak self] _ in
                entity.position = [0, Float(index) * self!.sphereSeparation, 0]
                entity.scale = entity.scale(relativeTo: entity.parent) / scale
                
                self?.animate(entity: entity,
                             reference: reference,
                             height: height,
                             scale: scale,
                             duration: duration,
                             arView: arView,
                             index: index)
            }))
        }
        
        // Exhibit mode: 4 animated spheres
        func placeSpheresInView(_ arView: ARView, _ worldTransform: simd_float4x4) {
            if let peerAnchor = arView.scene.anchors.first {
                // Update anchor position liên tục khi di chuyển
                peerAnchor.transform.matrix = worldTransform
            } else {
                let peerAnchor = AnchorEntity(.world(transform: worldTransform))
                if meshSphereArray.isEmpty {
                    for index in 0...3 {
                        meshSphereArray.append(MeshResource.generateSphere(radius: 0.15 + Float(index) * 0.1))
                    }
                }
                
                for index in 0...3 {
                    let sphere = ModelEntity(mesh: meshSphereArray[index],
                                             materials: [SimpleMaterial(color: .systemPink, isMetallic: true)])
                    peerAnchor.addChild(sphere, preservingWorldTransform: false)
                    sphere.position = [0, Float(index) * sphereSeparation, 0]
                    
                    animate(entity: sphere,
                           reference: peerAnchor,
                           height: Float(index + 1) * sphereSeparation,
                           scale: 2.0,
                           duration: 2.0,
                           arView: arView,
                           index: index)
                }
                
                arView.scene.addAnchor(peerAnchor)
            }
        }
        
        // Visitor mode: text banner + sphere
        func placeTextInView(_ arView: ARView, _ worldTransform: simd_float4x4, name: String, distance: Float) {
            if let peerAnchor = arView.scene.anchors.first {
                // Update toàn bộ transform matrix, không chỉ position
                peerAnchor.transform.matrix = worldTransform
            } else {
                if meshText == nil || (peerName != name) {
                    initialSize = 0.3 + 0.01 * distance
                    meshText = MeshResource.generateText(name,
                                                         extrusionDepth: 0.03,
                                                         font: .systemFont(ofSize: CGFloat(initialSize)),
                                                         alignment: .center,
                                                         lineBreakMode: .byWordWrapping)
                    peerName = name
                }
                if meshSphere == nil {
                    meshSphere = MeshResource.generateSphere(radius: 0.3)
                }
                
                let peerAnchor = AnchorEntity(.world(transform: matrix_identity_float4x4))
                if let text = meshText, let sphere = meshSphere {
                    let textEntity = ModelEntity(mesh: text, materials: [SimpleMaterial(color: .systemPink, isMetallic: false)])
                    peerAnchor.addChild(textEntity)
                    
                    let sphereEntity = ModelEntity(mesh: sphere,
                                                   materials: [SimpleMaterial(color: .systemPink, isMetallic: true)])
                    peerAnchor.addChild(sphereEntity)
                    
                    let center = (text.bounds.max - text.bounds.min)
                    textEntity.position = -1 / 2 * [center.x, center.y, center.z]
                    sphereEntity.position = textEntity.position + [0, initialSize + 0.2, 0]
                    
                    // Text luôn quay về camera
                    arView.scene.subscribe(to: SceneEvents.Update.self) { _ in
                        textEntity.look(at: arView.cameraTransform.translation, from: textEntity.position(relativeTo: nil), relativeTo: nil)
                        textEntity.transform.rotation *= simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
                    }.store(in: &self.subscriptions)
                    
                    arView.scene.addAnchor(peerAnchor)
                    // Set initial transform
                    peerAnchor.transform.matrix = worldTransform
                }
            }
        }
        
        // Helper to check if two matrices are significantly different
        func matricesAreDifferent(_ a: simd_float4x4?, _ b: simd_float4x4?, threshold: Float = 0.01) -> Bool {
            guard let a = a, let b = b else { return true }
            // So sánh position vector (column 3)
            let posA = a.columns.3
            let posB = b.columns.3
            let distance = simd_distance(SIMD3<Float>(posA.x, posA.y, posA.z), 
                                        SIMD3<Float>(posB.x, posB.y, posB.z))
            return distance > threshold
        }
        
        // Update peer anchor dựa trên worldTransform + gọi placeSpheresInView/placeTextInView
        func updatePeerAnchor(arView: ARView, currentWorldTransform: simd_float4x4?, peerName: String, distance: Float) {
            let now = Date().timeIntervalSinceReferenceDate
            // Throttle nhẹ hơn: 30 FPS (33ms) để AR mượt hơn
            if now - lastUpdateTime < 0.033 {
                return
            }
            
            // Threshold nhỏ hơn: 1cm để update nhạy hơn
            if !matricesAreDifferent(currentWorldTransform, lastWorldTransform, threshold: 0.01) 
               && abs(distance - lastDistance) < 0.01 {
                return
            }
            
            lastUpdateTime = now
            
            if let worldTransform = currentWorldTransform {
                print("🔄 AR Update: d=\(String(format: "%.2f", distance))m, pos=[\(String(format: "%.2f", worldTransform.columns.3.x)), \(String(format: "%.2f", worldTransform.columns.3.y)), \(String(format: "%.2f", worldTransform.columns.3.z))]")
                
                switch findingMode {
                case .exhibit:
                    placeSpheresInView(arView, worldTransform)
                case .visitor:
                    placeTextInView(arView, worldTransform, name: peerName, distance: distance)
                }
                lastWorldTransform = worldTransform
                lastDistance = distance
            } else {
                // Xóa tất cả anchors và animations khi mất transform
                for peerAnchor in arView.scene.anchors {
                    for childEntity in peerAnchor.children {
                        childEntity.removeFromParent()
                    }
                    peerAnchor.removeFromParent()
                }
                arView.scene.anchors.removeAll()
                
                subscriptions.forEach { $0.cancel() }
                subscriptions.removeAll()
                
                animationUpdates.forEach { $0?.cancel() }
                animationUpdates.removeAll()
                
                lastWorldTransform = nil
                lastDistance = -1
            }
        }
    }
}

// Fallback
struct NICameraAssistanceView_Fallback: View {
    var body: some View {
        Color.black.ignoresSafeArea()
    }
}

#endif
