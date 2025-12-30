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

final class NearbyInteractionManager: NSObject, ObservableObject {
    @Published var statusMessage: String = "Initializing UWB..."
    @Published var latestDistance: Float?
    @Published var latestDirection: simd_float3?
    @Published var latestHorizontalAngle: Float?   // iOS 17+
    @Published var trackedPeer: MCPeerID?
    @Published var latestQuality: MeasurementQualityEstimator.MeasurementQuality = .unknown

    var discoveryTokenData: Data? {
        guard let token = session.discoveryToken else { return nil }
        return try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private var session: NISession = NISession()
    private var tokensByPeer: [MCPeerID: NIDiscoveryToken] = [:]
    private var peerByTokenData: [Data: MCPeerID] = [:]
    private weak var multipeerSession: MultipeerSession?
    private var lastDistanceForHaptics: Float?
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let qualityEstimator = MeasurementQualityEstimator()

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

                var updated = false
                
                if let distance = object.distance {
                    self.latestDistance = distance
                    self.handleHaptics(newDistance: distance)
                    updated = true
                }

                if let direction = object.direction {
                    self.latestDirection = direction
                    updated = true
                }
                
                if #available(iOS 17.0, *), let angle = object.horizontalAngle {
                    self.latestHorizontalAngle = angle
                    updated = true
                }

                // Cập nhật quality estimator (EDM)
                self.latestQuality = self.qualityEstimator.estimateQuality(update: object)

                if updated {
                    self.statusMessage = "Tracking \(peer.displayName)"
                }
            }
        }
    }

    @available(iOS 17.0, *)
    func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?) {
        // Bạn có thể dùng convergence để hiển thị coaching UI
        print("🧭 Convergence updated: \(convergence)")
    }

    func sessionWasSuspended(_ session: NISession) {
        DispatchQueue.main.async {
            self.statusMessage = "Session suspended. Moving will resume tracking."
        }
    }

    func sessionSuspensionEnded(_ session: NISession) {
        DispatchQueue.main.async {
            self.statusMessage = "Session resumed."
        }
        restartSession()
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        DispatchQueue.main.async {
            self.statusMessage = "Session invalidated: \(error.localizedDescription)"
        }
        print("❌ NISession invalidated: \(error.localizedDescription)")
        restartSession()
    }
}
