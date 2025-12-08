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

final class NearbyInteractionManager: NSObject, ObservableObject {
    @Published var statusMessage: String = "Initializing UWB..."
    @Published var latestDistance: Float?
    @Published var latestDirection: simd_float3?
    @Published var trackedPeer: MCPeerID?

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

        statusMessage = "Searching for rescue teammates..."
        feedbackGenerator.prepare()
    }

    func register(multipeerSession: MultipeerSession) {
        self.multipeerSession = multipeerSession
    }

    func setActivePeer(_ peer: MCPeerID?) {
        guard isNearbyInteractionSupported else {
            statusMessage = "Nearby Interaction not supported on this device."
            return
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
        
        print("📡 Received discovery token from \(peer.displayName)")

        // Only auto-track if no peer is currently tracked
        if trackedPeer == nil {
            trackedPeer = peer
            configureSession(for: peer, token: token)
        } else if let active = trackedPeer, active == peer {
            // Re-configure if this is the actively tracked peer
            configureSession(for: peer, token: token)
        }
    }

    private func configureSession(for peer: MCPeerID, token: NIDiscoveryToken) {
        guard isNearbyInteractionSupported else {
            statusMessage = "Nearby Interaction not supported on this device."
            return
        }

        let configuration = NINearbyPeerConfiguration(peerToken: token)
        session.run(configuration)
        statusMessage = "Tracking \(peer.displayName)"
        latestDistance = nil
        latestDirection = nil
        lastDistanceForHaptics = nil

        // Ensure the peer has our latest token (important after a session restart).
        multipeerSession?.broadcastDiscoveryTokenToConnectedPeers()
    }

    private func restartSession() {
        session.invalidate()
        session = NISession()
        session.delegate = self
        feedbackGenerator.prepare()
        statusMessage = "Restarting Nearby Interaction..."

        if let peer = trackedPeer, let token = tokensByPeer[peer] {
            configureSession(for: peer, token: token)
        }
    }

    private func tokenData(_ token: NIDiscoveryToken) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private func handleHaptics(newDistance: Float) {
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
                // Only update if this is the actively tracked peer
                guard peer == self.trackedPeer else { 
                    print("📍 Ignoring update from non-tracked peer \(peer.displayName)")
                    return 
                }

                var updated = false
                
                if let distance = object.distance {
                    self.latestDistance = distance
                    self.handleHaptics(newDistance: distance)
                    updated = true
                    print("📏 Distance: \(String(format: "%.2f", distance))m")
                }

                if let direction = object.direction {
                    self.latestDirection = direction
                    updated = true
                    print("🧭 Direction: x=\(String(format: "%.2f", direction.x)), y=\(String(format: "%.2f", direction.y)), z=\(String(format: "%.2f", direction.z))")
                }
                
                if updated {
                    self.statusMessage = "Tracking \(peer.displayName)"
                }
            }
        }
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
        restartSession()
    }
}
