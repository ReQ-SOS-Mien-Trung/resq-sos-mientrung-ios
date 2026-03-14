//
//  NearbyInteractionManager.swift
//  SosMienTrung
//
//  Handles NISession lifecycle, token exchange, and distance/direction updates.
//

import Foundation
import Combine
import MultipeerConnectivity
import NearbyInteraction
import simd
import UIKit
import CoreHaptics
import ARKit

final class NearbyInteractionManager: NSObject, ObservableObject {
    @Published var statusMessage: String = "Initializing UWB..."
    @Published var latestDistance: Float?
    @Published var latestDirection: simd_float3?
    @Published var latestHorizontalAngle: Float?   // iOS 17+
    @Published var trackedPeer: MCPeerID?
    @Published var latestQuality: MeasurementQualityEstimator.MeasurementQuality = .unknown
    @Published var currentWorldTransform: simd_float4x4?
    @Published var showCoachingOverlay: Bool = true
    @Published var showUpDownText: String?

    /// Vai trò hiện tại của device trong phiên UWB
    /// - `.rescuer`: chủ động tìm victim (cần AR + NISession run)
    /// - `.victim`:  bị tìm (chỉ cần broadcast token, không cần AR)
    @Published var userRole: UserRole = .victim

    /// Discovery token dạng Data — sàng lọc nil an toàn
    var discoveryTokenData: Data? {
        guard let token = session.discoveryToken else { return nil }
        return try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private var session: NISession = NISession()
    private var tokensByPeer: [MCPeerID: NIDiscoveryToken] = [:]
    private var peerByTokenData: [Data: MCPeerID] = [:]
    private weak var arSession: ARSession?
    private weak var multipeerSession: MultipeerSession?
    private var lastDistanceForHaptics: Float?
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let qualityEstimator = MeasurementQualityEstimator()
    private var convergenceByPeer: [MCPeerID: Any] = [:]

    /// Camera assistance đã fail — khi true sẽ fallback về range-only mode
    private var cameraAssistanceFailed = false
    /// ARSession đã thực sự được attach vào NISession hiện tại chưa
    private var isARSessionAttachedToNI = false
    /// Số lần restart liên tiếp — chặn infinite loop
    private var restartCount = 0
    private let maxRestarts = 2

    #if targetEnvironment(simulator)
    private let hapticsAvailable = false
    #else
    private let hapticsAvailable = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    #endif

    private var isNearbyInteractionSupported: Bool {
        NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
    }

    override init() {
        super.init()
        session.delegate = self

        guard isNearbyInteractionSupported else {
            statusMessage = "Nearby Interaction not supported on this device."
            return
        }

        #if targetEnvironment(simulator)
        print("🏃 Running on SIMULATOR")
        #else
        print("🏃 Running on DEVICE")
        #endif

        let caps = NISession.deviceCapabilities
        print("🔎 NI caps → precise=\(caps.supportsPreciseDistanceMeasurement), direction=\(caps.supportsDirectionMeasurement), camera=\(caps.supportsCameraAssistance)")
        if #available(iOS 17.0, *) {
            print("🔎 NI EDM local support: \(caps.supportsExtendedDistanceMeasurement)")
        }

        statusMessage = "Searching for rescue teammates..."
        if hapticsAvailable {
            feedbackGenerator.prepare()
        }
    }

    // Attach ARKit session — chỉ dùng bởi rescuer (NICameraAssistanceView)
    func attachARSession(_ arSession: ARSession) {
        self.arSession = arSession
        session.setARSession(arSession)
        isARSessionAttachedToNI = true
        print("🔗 Attached ARSession to NISession for Camera Assistance")
    }

    /// Detach ARSession khi view bị dismantled
    func detachARSession() {
        print("🔌 Detaching ARSession from NISession")
        arSession = nil
        isARSessionAttachedToNI = false
        // Invalidate và tạo lại NISession — đảm bảo không còn link tới ARSession cũ
        session.invalidate()
        session = NISession()
        session.delegate = self
        if hapticsAvailable { feedbackGenerator.prepare() }
        // Đợi token sẵn sàng rồi mới broadcast
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.multipeerSession?.broadcastDiscoveryTokenToConnectedPeers()
        }
        print("🔄 NISession recreated after ARSession detach")
    }

    func register(multipeerSession: MultipeerSession) {
        self.multipeerSession = multipeerSession
    }

    // MARK: - Role Configuration

    /// Gọi bởi RescuersView khi bật chế độ cứu hộ — rescuer chủ động tìm victim
    func configureAsRescuer() {
        guard isNearbyInteractionSupported else {
            statusMessage = "Nearby Interaction not supported on this device."
            return
        }
        userRole = .rescuer
        statusMessage = "Searching for victims..."
        print("🚨 Role set to RESCUER — will actively track victims")
    }

    /// Gời khi victim bật chế độ chờ cứu — victim không cần AR, chỉ cần advertise token
    func configureAsVictim() {
        guard isNearbyInteractionSupported else {
            statusMessage = "Nearby Interaction not supported on this device."
            return
        }
        userRole = .victim
        // Victim không gọi configureSession — chỉ đợi rescuer kết nối rồi sẽ respond token
        statusMessage = "Waiting to be found by rescuers..."
        print("🟣 Role set to VICTIM — broadcasting NI token passively")
    }

    func setActivePeer(_ peer: MCPeerID?) {
        guard isNearbyInteractionSupported else {
            statusMessage = "Nearby Interaction not supported on this device."
            return
        }

        if trackedPeer != peer {
            latestDistance = nil
            latestDirection = nil
            latestHorizontalAngle = nil
            latestQuality = .unknown
            currentWorldTransform = nil
            showCoachingOverlay = true
            showUpDownText = nil
        }

        trackedPeer = peer
        guard let peer else {
            statusMessage = "Select a peer to start tracking."
            return
        }

        // Chỉ rescuer mới chủ động chạy NISession
        // Victim chỉ respond token và đợi, không tự configure session
        guard userRole == .rescuer else {
            statusMessage = "Victim mode: waiting for rescuer UWB ping..."
            return
        }

        guard let token = tokensByPeer[peer] else {
            // Token chưa sẵn sàng — lưu peer lại, sẽ configure khi nhận được token
            print("⏳ Token not yet available for \(peer.displayName), will configure when token arrives")
            return
        }
        configureSession(for: peer, token: token)
    }

    func receivedPeerDiscoveryToken(_ token: NIDiscoveryToken, from peer: MCPeerID) {
        tokensByPeer[peer] = token
        if let tokenData = tokenData(token) {
            peerByTokenData[tokenData] = peer
        }

        if #available(iOS 17.0, *) {
            print("📡 Received discovery token from \(peer.displayName), peer EDM support: \(token.deviceCapabilities.supportsExtendedDistanceMeasurement)")
        } else {
            print("📡 Received discovery token from \(peer.displayName)")
        }

        // Victim: không tự chạy NISession — chỉ giữ token để respond nếu rescuer init
        // (Phía rescuer sẽ giao tiếp trước, victim respond khi được ping)
        guard userRole == .rescuer else {
            print("🟣 Victim: stored token from \(peer.displayName), waiting for rescuer to start session")
            return
        }

        // Rescuer: configure session
        if trackedPeer == nil {
            trackedPeer = peer
            configureSession(for: peer, token: token)
        } else if let active = trackedPeer, active == peer {
            // Rescuer nhận lại token (có thể sau restart) — luôn configure lại
            configureSession(for: peer, token: token)
        }
    }

    private func configureSession(for peer: MCPeerID, token: NIDiscoveryToken) {
        guard isNearbyInteractionSupported else {
            statusMessage = "Nearby Interaction not supported on this device."
            return
        }

        let configuration = NINearbyPeerConfiguration(peerToken: token)

        // Camera Assistance — chỉ bật khi ARSession THỰC SỰ được attach vào NISession
        #if targetEnvironment(simulator)
        configuration.isCameraAssistanceEnabled = false
        print("🎥 Camera Assistance (Simulator): OFF")
        #else
        if cameraAssistanceFailed {
            configuration.isCameraAssistanceEnabled = false
            print("🎥 Camera Assistance: DISABLED (previous failure, using range-only)")
        } else if isARSessionAttachedToNI && NISession.deviceCapabilities.supportsCameraAssistance {
            configuration.isCameraAssistanceEnabled = true
            print("🎥 Camera Assistance (Device): ON [ARSession attached]")
        } else {
            configuration.isCameraAssistanceEnabled = false
            print("🎥 Camera Assistance: OFF (ARSession not attached or not supported)")
        }
        #endif

        // Extended Distance Measurement (EDM) – iOS 17+
        if #available(iOS 17.0, *) {
            let localEDM = NISession.deviceCapabilities.supportsExtendedDistanceMeasurement
            let peerEDM = token.deviceCapabilities.supportsExtendedDistanceMeasurement
            print("🧪 EDM support → local=\(localEDM), peer=\(peerEDM)")
            if localEDM && peerEDM {
                configuration.isExtendedDistanceMeasurementEnabled = true
                print("✅ EDM enabled in configuration")
            } else {
                print("ℹ️ EDM NOT enabled (fallback to classic ranging)")
            }
        } else {
            print("ℹ️ EDM not available on this OS; using classic ranging")
        }

        session.run(configuration)
        statusMessage = "Tracking \(peer.displayName)"
        lastDistanceForHaptics = nil
        print("▶️ NISession.run() for peer \(peer.displayName) [cameraAssist=\(!cameraAssistanceFailed)]")
    }

    private func restartSession() {
        restartCount += 1
        print("🔄 NISession restarting... (attempt \(restartCount)/\(maxRestarts))")

        // Chặn infinite restart loop
        guard restartCount <= maxRestarts else {
            print("⛔️ Max restarts reached. Switching to range-only mode (no camera assistance).")
            cameraAssistanceFailed = true
            restartCount = 0
            // Tạo session mới KHÔNG có ARSession (range-only)
            session.invalidate()
            session = NISession()
            session.delegate = self
            // Không gắn ARSession — chạy range-only
            if hapticsAvailable { feedbackGenerator.prepare() }
            statusMessage = "Range-only mode (no AR)"

            // Đợi discoveryToken sẵn sàng trước khi configure + broadcast
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                if self.userRole == .rescuer,
                   let peer = self.trackedPeer,
                   let token = self.tokensByPeer[peer] {
                    self.configureSession(for: peer, token: token)
                }
                self.multipeerSession?.broadcastDiscoveryTokenToConnectedPeers()
            }
            return
        }

        session.invalidate()
        session = NISession()
        session.delegate = self

        // Chỉ re-attach ARSession nếu chưa fail camera assistance
        if !cameraAssistanceFailed, let arSession, arSession.currentFrame != nil {
            session.setARSession(arSession)
            isARSessionAttachedToNI = true
            print("🔗 Re-attached live ARSession to new NISession")
        } else {
            isARSessionAttachedToNI = false
            print("⚠️ Running without ARSession (range-only mode)")
        }

        if hapticsAvailable { feedbackGenerator.prepare() }
        statusMessage = userRole == .rescuer ? "Restarting search..." : "Reconnecting..."

        // Đợi discoveryToken sẵn sàng (NISession cần vài ms sau init)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }

            if self.userRole == .rescuer,
               let peer = self.trackedPeer,
               let token = self.tokensByPeer[peer] {
                self.configureSession(for: peer, token: token)
            }

            // Broadcast token mới cho peers
            self.multipeerSession?.broadcastDiscoveryTokenToConnectedPeers()
        }
    }

    private func tokenData(_ token: NIDiscoveryToken) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private func handleHaptics(newDistance: Float) {
        guard hapticsAvailable else { return }
        if let previous = lastDistanceForHaptics, newDistance < previous - 0.1 {
            feedbackGenerator.impactOccurred()
        }
        lastDistanceForHaptics = newDistance
    }
    
    // Logic tính toán view state giống Apple's "Finding Devices with Precision"
    @available(iOS 17.0, *)
    private func computeViewState(with context: NIAlgorithmConvergence?, nearbyObject: NINearbyObject?) {
        let estimatedQuality = qualityEstimator.estimateQuality(update: nearbyObject)
        var showUpDownText = false
        var worldTransform: simd_float4x4? = nil
        
        if let object = nearbyObject,
           let distance = object.distance,
           let horizontalAngle = object.horizontalAngle {
            
            let minimumViewDistance: Float = 10.0
            // Công thức góc động của Apple: góc hẹp dần khi đến gần
            let minimumViewAngle = Double.pi / (4 + Double(1 - distance / minimumViewDistance))
            let angle = abs(Double(horizontalAngle))
            let angleDegrees = angle * 180.0 / .pi
            let limitDegrees = minimumViewAngle * 180.0 / .pi
            
            // Điều kiện: đủ gần + trong góc view
            if (distance <= minimumViewDistance) && (angle <= minimumViewAngle) {
                // Nếu converged → lấy worldTransform
                if (context?.status ?? .unknown) == .converged,
                   let transform = session.worldTransform(for: object) {
                    worldTransform = transform
                    print(String(format: "🎯 worldTransform OK (d=%.2fm, ang=%.1f°, limit=%.1f°)", distance, angleDegrees, limitDegrees))
                } else {
                    // Chưa converged nhưng đủ điều kiện → hiển thị coaching
                    showUpDownText = true
                    print(String(format: "⏳ Waiting convergence (d=%.2fm, ang=%.1f°, limit=%.1f°)", distance, angleDegrees, limitDegrees))
                }
            } else {
                print(String(format: "❌ Out of range (d=%.2fm, ang=%.1f°, limit=%.1f°)", distance, angleDegrees, limitDegrees))
            }
        }
        
        let showText = showUpDownText
        let transform = worldTransform
        
        // Update view state on MainActor (thread-safe)
        Task { @MainActor in
            self.updateViewState(with: context, quality: estimatedQuality, nearbyObject: nearbyObject,
                                worldTransform: transform, showUpDownText: showText)
        }
    }
    
    // Update all published properties on MainActor
    @MainActor
    private func updateViewState(with context: NIAlgorithmConvergence?,
                                 quality: MeasurementQualityEstimator.MeasurementQuality,
                                 nearbyObject: NINearbyObject?,
                                 worldTransform: simd_float4x4?,
                                 showUpDownText: Bool) {
        self.latestQuality = quality
        self.currentWorldTransform = worldTransform
        self.showCoachingOverlay = (worldTransform == nil)
        self.showUpDownText = showUpDownText ? "Move device up/down to refine alignment" : nil
        
        // Update distance/angle if available
        if let object = nearbyObject {
            if let distance = object.distance {
                self.latestDistance = distance
            }
            if let angle = object.horizontalAngle {
                self.latestHorizontalAngle = angle
            }
            if let direction = object.direction {
                self.latestDirection = direction
            }
        }
    }
}

extension NearbyInteractionManager: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard !nearbyObjects.isEmpty else { return }

        // Session đang hoạt động tốt — reset restart counter
        restartCount = 0

        for object in nearbyObjects {
            guard let tokenData = tokenData(object.discoveryToken),
                  let peer = peerByTokenData[tokenData] else { 
                print("⚠️ Could not find peer for discovery token")
                continue 
            }

            DispatchQueue.main.async {
                guard peer == self.trackedPeer else { 
                    return 
                }

                // Handle haptics for distance changes
                if let distance = object.distance {
                    self.handleHaptics(newDistance: distance)
                }

                // Compute view state với logic Apple (updates all published properties)
                if #available(iOS 17.0, *) {
                    self.computeViewState(with: self.convergenceByPeer[peer] as? NIAlgorithmConvergence, nearbyObject: object)
                } else {
                    // iOS < 17: không có Camera Assistance
                    if let distance = object.distance {
                        self.latestDistance = distance
                    }
                    if let direction = object.direction {
                        self.latestDirection = direction
                    }
                    self.latestQuality = self.qualityEstimator.estimateQuality(update: object)
                    self.currentWorldTransform = nil
                    self.showCoachingOverlay = true
                    self.showUpDownText = nil
                }
                
                self.statusMessage = "Tracking \(peer.displayName)"
            }
        }
    }

    func sessionWasSuspended(_ session: NISession) {
        DispatchQueue.main.async {
            self.statusMessage = "Session suspended. Moving will resume tracking."
            self.currentWorldTransform = nil
            self.showCoachingOverlay = true
            self.showUpDownText = nil
        }
    }

    func sessionSuspensionEnded(_ session: NISession) {
        DispatchQueue.main.async {
            self.statusMessage = "Session resumed."
            self.currentWorldTransform = nil
            self.showCoachingOverlay = true
            self.showUpDownText = nil
        }
        restartSession()
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        DispatchQueue.main.async {
            self.statusMessage = "Session invalidated: \(error.localizedDescription)"
            self.currentWorldTransform = nil
            self.showCoachingOverlay = true
            self.showUpDownText = nil
        }
        print("❌ NISession invalidated: \(error.localizedDescription)")
        restartSession()
    }
}
