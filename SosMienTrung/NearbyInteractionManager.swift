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

    override init() {
        super.init()
        session.delegate = self

        #if compiler(>=5.5)
        #warning("Using deprecated NISession.isSupported - replace when newer API is available")
        #endif
        guard NISession.isSupported else {
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
        guard NISession.isSupported else {
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

        if trackedPeer == nil {
            trackedPeer = peer
        }

        if let active = trackedPeer, active == peer {
            configureSession(for: peer, token: token)
        }
    }

    private func configureSession(for peer: MCPeerID, token: NIDiscoveryToken) {
        guard NISession.isSupported else {
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
        for object in nearbyObjects {
            guard let tokenData = tokenData(object.discoveryToken),
                  let peer = peerByTokenData[tokenData] else { continue }

            DispatchQueue.main.async {
                if self.trackedPeer == nil {
                    self.trackedPeer = peer
                }

                guard peer == self.trackedPeer else { return }

                if let distance = object.distance {
                    self.latestDistance = distance
                    self.handleHaptics(newDistance: distance)
                }

                if let direction = object.direction {
                    self.latestDirection = direction
                }

                self.statusMessage = "Tracking \(peer.displayName)"
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
