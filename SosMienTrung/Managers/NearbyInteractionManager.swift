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

final class NearbyInteractionManager: NSObject, ObservableObject, ARSessionDelegate {
    @Published var statusMessage: String = "Initializing UWB..."
    @Published var latestDistance: Float?
    @Published var latestDirection: simd_float3?
    @Published var latestHorizontalAngle: Float?   // iOS 17+
    @Published var trackedPeer: MCPeerID?
    @Published var latestQuality: MeasurementQualityEstimator.MeasurementQuality = .unknown
    @Published var currentWorldTransform: simd_float4x4?
    @Published var showCoachingOverlay: Bool = true
    @Published var showUpDownText: String?

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
    /// Chờ ARSession có frame đầu tiên rồi mới attach vào NISession
    private var pendingARSessionAttachment = false
    /// Số lần restart liên tiếp — chặn infinite loop
    private var restartCount = 0
    private let maxRestarts = 2
    private var pendingDeactivateWorkItem: DispatchWorkItem?
    /// Tránh restart khi invalidate do chính app chủ động gọi.
    private var suppressNextInvalidationRestart = false
    /// Chỉ auto-restart khi user đang ở mode rescue/victim active.
    private var isModeActive = false

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
        guard !cameraAssistanceFailed else {
            pendingARSessionAttachment = false
            isARSessionAttachedToNI = false
            print("🎥 Skipping ARSession attach because camera assistance is already disabled")
            return
        }

        arSession.delegate = self
        if attachARSessionIfReady(arSession, reason: "initial-attach") == false {
            print("⏳ Waiting for first AR frame before enabling camera assistance")
        }
    }

    /// Detach ARSession khi view bị dismantled
    func detachARSession() {
        print("🔌 Detaching ARSession from NISession")
        let hadARLink = isARSessionAttachedToNI || pendingARSessionAttachment || arSession != nil
        arSession?.delegate = nil
        arSession = nil
        pendingARSessionAttachment = false

        guard hadARLink else {
            isARSessionAttachedToNI = false
            print("🔄 NISession already running without AR")
            return
        }

        // NISession vẫn giữ reference đến ARSession cũ; recreate để tránh stale ARSession.
        recreateSession(allowARReattach: false, reason: "ar-detach")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            guard self.isModeActive else { return }
            if let peer = self.trackedPeer,
               let token = self.tokensByPeer[peer] {
                self.configureSession(for: peer, token: token)
            }
            self.multipeerSession?.broadcastDiscoveryTokenToConnectedPeers()
        }

        print("🔄 NISession switched to non-AR mode after detach")
    }

    private func attachARSessionIfReady(_ arSession: ARSession, reason: String) -> Bool {
        guard !cameraAssistanceFailed else {
            pendingARSessionAttachment = false
            isARSessionAttachedToNI = false
            return false
        }
        guard NISession.deviceCapabilities.supportsCameraAssistance else {
            pendingARSessionAttachment = false
            isARSessionAttachedToNI = false
            print("🎥 Camera assistance not supported on this device")
            return false
        }
        guard arSession.currentFrame != nil else {
            pendingARSessionAttachment = true
            isARSessionAttachedToNI = false
            print("⏳ ARSession frame not ready (\(reason)); keeping NI in range-only mode")
            return false
        }

        session.setARSession(arSession)
        pendingARSessionAttachment = false
        isARSessionAttachedToNI = true
        print("🔗 Attached ARSession to NISession for Camera Assistance (\(reason))")
        return true
    }

    private func recreateSession(allowARReattach: Bool, reason: String) {
        suppressNextInvalidationRestart = true
        session.invalidate()
        session = NISession()
        session.delegate = self

        if allowARReattach, let arSession {
            _ = attachARSessionIfReady(arSession, reason: reason)
        } else {
            pendingARSessionAttachment = false
            isARSessionAttachedToNI = false
            print("⚠️ Running without ARSession (range-only mode)")
        }

        if hapticsAvailable { feedbackGenerator.prepare() }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let arSession, session === arSession else { return }
        guard pendingARSessionAttachment else { return }
        guard attachARSessionIfReady(arSession, reason: "live-frame") else { return }
        guard isModeActive,
              let peer = trackedPeer,
              let token = tokensByPeer[peer],
              multipeerSession?.isConnected(to: peer) == true else { return }

        print("🔄 Re-running NI session after ARSession became ready")
        configureSession(for: peer, token: token)
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("❌ ARSession failed: \(error.localizedDescription)")
        cameraAssistanceFailed = true
        pendingARSessionAttachment = false
        isARSessionAttachedToNI = false

        guard isModeActive else { return }
        guard let peer = trackedPeer, let token = tokensByPeer[peer] else { return }

        statusMessage = "AR sensor unavailable. Using range-only tracking."
        configureSession(for: peer, token: token)
    }

    func register(multipeerSession: MultipeerSession) {
        self.multipeerSession = multipeerSession
    }

    // MARK: - Session Configuration

    /// Nearby Interaction mode theo kiến trúc đối xứng: thiết bị nào cũng có thể tìm nhau.
    func configureForPeerFinding() {
        guard isNearbyInteractionSupported else {
            statusMessage = "Nearby Interaction not supported on this device."
            return
        }
        pendingDeactivateWorkItem?.cancel()
        pendingDeactivateWorkItem = nil
        isModeActive = true
        statusMessage = "Searching for nearby devices..."
        print("🔎 Nearby mode active (symmetric peer finding)")
        prepareDiscoveryTokenIfNeeded()
    }

    /// Backward-compat wrapper.
    func configureAsRescuer() {
        configureForPeerFinding()
    }

    /// Backward-compat wrapper.
    func configureAsVictim() {
        configureForPeerFinding()
    }

    /// Dừng Nearby Interaction sạch sẽ khi rời flow tìm kiếm.
    func deactivateNearbyMode() {
        pendingDeactivateWorkItem?.cancel()
        pendingDeactivateWorkItem = nil
        isModeActive = false
        trackedPeer = nil
        statusMessage = "Nearby Interaction is idle."
        latestDistance = nil
        latestDirection = nil
        latestHorizontalAngle = nil
        latestQuality = .unknown
        currentWorldTransform = nil
        showCoachingOverlay = true
        showUpDownText = nil
        convergenceByPeer.removeAll()
        tokensByPeer.removeAll()
        peerByTokenData.removeAll()
        restartCount = 0
        cameraAssistanceFailed = false
        pendingARSessionAttachment = false
    }

    func scheduleDeactivateNearbyMode(after delay: TimeInterval = 0.75) {
        pendingDeactivateWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.deactivateNearbyMode()
        }

        pendingDeactivateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
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

        statusMessage = "Tracking \(peer.displayName)..."

        guard let token = tokensByPeer[peer] else {
            // Token chưa sẵn sàng — lưu peer lại, sẽ configure khi nhận được token
            print("⏳ Token not yet available for \(peer.displayName), will configure when token arrives")
            return
        }
        configureSession(for: peer, token: token)
    }

    func handleTransportDisconnect(from peer: MCPeerID) {
        if let token = tokensByPeer.removeValue(forKey: peer),
           let data = tokenData(token) {
            peerByTokenData.removeValue(forKey: data)
        }
        convergenceByPeer.removeValue(forKey: peer)

        guard trackedPeer == peer else { return }

        trackedPeer = nil
        pendingARSessionAttachment = false
        resetTrackingVisualState()
        statusMessage = "Peer disconnected. Waiting to reconnect..."
        recreateSession(allowARReattach: false, reason: "transport-disconnect")
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

        print("📡 Configure NI session with \(peer.displayName)")

        if trackedPeer == nil {
            trackedPeer = peer
            configureSession(for: peer, token: token)
        } else if let active = trackedPeer, active == peer {
            configureSession(for: peer, token: token)
        }
    }

    private func configureSession(for peer: MCPeerID, token: NIDiscoveryToken) {
        guard isNearbyInteractionSupported else {
            statusMessage = "Nearby Interaction not supported on this device."
            return
        }
        guard multipeerSession?.isConnected(to: peer) ?? false else {
            print("⏭ Skipping NI configure because transport is no longer connected to \(peer.displayName)")
            return
        }

        #if !targetEnvironment(simulator)
        if !cameraAssistanceFailed, !isARSessionAttachedToNI, let arSession {
            _ = attachARSessionIfReady(arSession, reason: "configure")
        }
        #endif

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

        // Extended Distance Measurement (EDM)
        // Keep EDM disabled for broad device compatibility (including iPhone 11).
        if #available(iOS 17.0, *) {
            let localEDM = NISession.deviceCapabilities.supportsExtendedDistanceMeasurement
            let peerEDM = token.deviceCapabilities.supportsExtendedDistanceMeasurement
            print("🧪 EDM support → local=\(localEDM), peer=\(peerEDM)")
            configuration.isExtendedDistanceMeasurementEnabled = false
            print("ℹ️ EDM disabled by app policy for compatibility")
        } else {
            print("ℹ️ EDM not available on this OS; using classic ranging")
        }

        session.run(configuration)
        statusMessage = "Tracking \(peer.displayName)"
        lastDistanceForHaptics = nil
        print("▶️ NISession.run() for peer \(peer.displayName) [cameraAssist=\(configuration.isCameraAssistanceEnabled)]")
    }

    private func restartSession() {
        restartCount += 1
        print("🔄 NISession restarting... (attempt \(restartCount)/\(maxRestarts))")

        // Chặn infinite restart loop
        guard restartCount <= maxRestarts else {
            print("⛔️ Max restarts reached. Switching to range-only mode (no camera assistance).")
            cameraAssistanceFailed = true
            pendingARSessionAttachment = false
            restartCount = 0
            // Tạo session mới KHÔNG có ARSession (range-only)
            recreateSession(allowARReattach: false, reason: "restart-range-only")
            statusMessage = "Range-only mode (no AR)"

            // Đợi discoveryToken sẵn sàng trước khi configure + broadcast
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                if let peer = self.trackedPeer,
                   let token = self.tokensByPeer[peer] {
                    self.configureSession(for: peer, token: token)
                }
                self.multipeerSession?.broadcastDiscoveryTokenToConnectedPeers()
            }
            return
        }

        recreateSession(allowARReattach: !cameraAssistanceFailed, reason: "restart")
        statusMessage = "Reconnecting..."

        // Đợi discoveryToken sẵn sàng (NISession cần vài ms sau init)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }

            if let peer = self.trackedPeer,
               let token = self.tokensByPeer[peer] {
                self.configureSession(for: peer, token: token)
            }

            // Broadcast token mới cho peers
            self.multipeerSession?.broadcastDiscoveryTokenToConnectedPeers()
        }
    }

    private func resetTrackingVisualState() {
        DispatchQueue.main.async {
            self.latestDistance = nil
            self.latestDirection = nil
            self.latestHorizontalAngle = nil
            self.latestQuality = .unknown
            self.currentWorldTransform = nil
            self.showCoachingOverlay = true
            self.showUpDownText = nil
        }
    }

    private func shouldAutoRestart(after error: Error) -> Bool {
        if #available(iOS 17.0, *) {
            switch error {
            case NIError.userDidNotAllow,
                 NIError.incompatiblePeerDevice,
                 NIError.activeSessionsLimitExceeded,
                 NIError.activeExtendedDistanceSessionsLimitExceeded:
                return false
            case NIError.invalidARConfiguration:
                // Attempt range-only fallback instead of hard-failing.
                return true
            default:
                return true
            }
        } else {
            switch error {
            case NIError.userDidNotAllow,
                 NIError.activeSessionsLimitExceeded:
                return false
            case NIError.invalidARConfiguration:
                return true
            default:
                return true
            }
        }
    }

    private func handleInvalidARConfiguration() {
        cameraAssistanceFailed = true
        pendingARSessionAttachment = false
        isARSessionAttachedToNI = false
        restartCount = 0
        statusMessage = "Camera assistance unavailable. Falling back to range-only mode."
        print("⚠️ Invalid AR configuration. Falling back to range-only NI.")

        guard isModeActive else { return }
        restartSession()
    }

    private func handleRemovedPeers(_ nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        let removedPeers = nearbyObjects.compactMap { object -> MCPeerID? in
            guard let data = tokenData(object.discoveryToken) else { return nil }
            return peerByTokenData[data]
        }

        removedPeers.forEach { peer in
            tokensByPeer.removeValue(forKey: peer)
            convergenceByPeer.removeValue(forKey: peer)
        }

        nearbyObjects.forEach { object in
            guard let data = tokenData(object.discoveryToken) else { return }
            peerByTokenData.removeValue(forKey: data)
        }

        guard let activePeer = trackedPeer, removedPeers.contains(activePeer) else {
            return
        }

        resetTrackingVisualState()

        switch reason {
        case .peerEnded:
            statusMessage = "Peer ended nearby session. Waiting to reconnect..."
        case .timeout:
            statusMessage = "Signal lost. Reconnecting..."
        default:
            statusMessage = "Peer removed. Re-establishing session..."
        }

        guard isModeActive else {
            print("ℹ️ Skip recovery after didRemove because mode is inactive")
            return
        }

        restartSession()
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

    func prepareDiscoveryTokenIfNeeded() {
        guard isModeActive else { return }
        if session.discoveryToken != nil {
            return
        }

        print("🔁 Preparing NI session for discovery token...")

        recreateSession(allowARReattach: !cameraAssistanceFailed, reason: "prepare-token")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            if self.session.discoveryToken != nil {
                self.multipeerSession?.broadcastDiscoveryTokenToConnectedPeers()
            } else {
                print("⚠️ Discovery token still unavailable after NI session refresh")
            }
        }
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

    func session(_ session: NISession,
                 didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence,
                 for object: NINearbyObject?) {
        guard let object else { return }
        guard let data = tokenData(object.discoveryToken),
              let peer = peerByTokenData[data] else {
            return
        }

        convergenceByPeer[peer] = convergence

        guard peer == trackedPeer else { return }

        if #available(iOS 17.0, *) {
            computeViewState(with: convergence, nearbyObject: object)
        }
    }

    func session(_ session: NISession,
                 didRemove nearbyObjects: [NINearbyObject],
                 reason: NINearbyObject.RemovalReason) {
        guard !nearbyObjects.isEmpty else { return }
        print("⚠️ didRemove nearby object(s), reason=\(reason.rawValue)")
        handleRemovedPeers(nearbyObjects, reason: reason)
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
        if suppressNextInvalidationRestart {
            suppressNextInvalidationRestart = false
            print("ℹ️ NISession invalidated intentionally, skip auto-restart")
            return
        }

        DispatchQueue.main.async {
            self.statusMessage = "Session invalidated: \(error.localizedDescription)"
            self.currentWorldTransform = nil
            self.showCoachingOverlay = true
            self.showUpDownText = nil
        }
        print("❌ NISession invalidated: \(error.localizedDescription)")

        if #available(iOS 17.0, *) {
            if case NIError.invalidARConfiguration = error {
                handleInvalidARConfiguration()
                return
            }
        } else {
            if case NIError.invalidARConfiguration = error {
                handleInvalidARConfiguration()
                return
            }
        }

        guard shouldAutoRestart(after: error) else {
            print("ℹ️ Non-recoverable NI error, auto-restart disabled")
            return
        }

        guard isModeActive else {
            print("ℹ️ Ignore NI restart because mode is inactive")
            return
        }
        restartSession()
    }
}
