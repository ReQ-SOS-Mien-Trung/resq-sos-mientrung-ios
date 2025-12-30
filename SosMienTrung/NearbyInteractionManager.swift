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
    @available(iOS 17.0, *)
    private var convergenceByPeer: [MCPeerID: NIAlgorithmConvergence] = [:]

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

    // Attach ARKit session so NI can use Camera Assistance (required for worldTransform/horizontalAngle)
    func attachARSession(_ arSession: ARSession) {
        self.arSession = arSession
        session.setARSession(arSession)
        print("🔗 Attached ARSession to NISession for Camera Assistance")
    }

    func register(multipeerSession: MultipeerSession) {
        self.multipeerSession = multipeerSession
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
        guard let peer, let token = tokensByPeer[peer] else {
            statusMessage = "Select a peer to start tracking."
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

        let configuration = NINearbyPeerConfiguration(peerToken: token)

        // Camera Assistance
        #if targetEnvironment(simulator)
        configuration.isCameraAssistanceEnabled = false
        print("🎥 Camera Assistance (Simulator): OFF")
        #else
        if NISession.deviceCapabilities.supportsCameraAssistance {
            configuration.isCameraAssistanceEnabled = true
            print("🎥 Camera Assistance (Device): ON")
        } else {
            print("🎥 Camera Assistance (Device): NOT SUPPORTED")
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
        print("▶️ NISession.run() for peer \(peer.displayName)")
    }

    private func restartSession() {
        session.invalidate()
        session = NISession()
        session.delegate = self
        if let arSession {
            session.setARSession(arSession)
        }
        if hapticsAvailable {
            feedbackGenerator.prepare()
        }
        statusMessage = "Restarting Nearby Interaction..."

        if let peer = trackedPeer, let token = tokensByPeer[peer] {
            configureSession(for: peer, token: token)
        }
        
        // Broadcast the new token to peers so they can track us
        multipeerSession?.broadcastDiscoveryTokenToConnectedPeers()
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
                    self.computeViewState(with: self.convergenceByPeer[peer], nearbyObject: object)
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

    @available(iOS 17.0, *)
    func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?) {
        guard let object,
              let tokenData = tokenData(object.discoveryToken),
              let peer = peerByTokenData[tokenData] else {
            return
        }
        
        // Lưu convergence context
        convergenceByPeer[peer] = convergence
        print("🧭 Convergence updated: \(convergence)")
        
        // Recompute view state với convergence context mới (giống Apple)
        DispatchQueue.main.async {
            if peer == self.trackedPeer {
                self.computeViewState(with: convergence, nearbyObject: object)
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
