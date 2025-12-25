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

    // Smoothed values để giảm jitter
    @Published var smoothedDistance: Float?
    @Published var smoothedDirection: simd_float3?

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

    // Debouncing và smoothing
    private var lastUpdateTime: Date = Date()
    private let minimumUpdateInterval: TimeInterval = 0.05 // ~20 FPS max (giảm từ 30 để nhẹ hơn)
    private var distanceHistory: [Float] = []
    private var directionHistory: [simd_float3] = []
    private let historySize = 8 // Tăng lên 8 samples để mượt hơn

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

        print("🎯 Configuring NI session for peer: \(peer.displayName)")

        let configuration = NINearbyPeerConfiguration(peerToken: token)
        session.run(configuration)
        statusMessage = "Tracking \(peer.displayName)"

        // Clear all data khi bắt đầu session mới
        latestDistance = nil
        latestDirection = nil
        smoothedDistance = nil
        smoothedDirection = nil
        lastDistanceForHaptics = nil
        clearHistory()

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

    // MARK: - Smoothing Functions

    private func smoothDistance(_ newDistance: Float) -> Float {
        distanceHistory.append(newDistance)
        if distanceHistory.count > historySize {
            distanceHistory.removeFirst()
        }

        // Moving average
        let sum = distanceHistory.reduce(0, +)
        return sum / Float(distanceHistory.count)
    }

    private func smoothDirection(_ newDirection: simd_float3) -> simd_float3 {
        directionHistory.append(newDirection)
        if directionHistory.count > historySize {
            directionHistory.removeFirst()
        }

        // Normalize và average các vectors
        var sumX: Float = 0
        var sumY: Float = 0
        var sumZ: Float = 0

        for dir in directionHistory {
            sumX += dir.x
            sumY += dir.y
            sumZ += dir.z
        }

        let count = Float(directionHistory.count)
        let avgDirection = simd_float3(sumX / count, sumY / count, sumZ / count)

        // Normalize để giữ unit vector
        let length = simd_length(avgDirection)
        if length > 0.001 {
            return avgDirection / length
        }
        return avgDirection
    }

    func clearHistory() {
        distanceHistory.removeAll()
        directionHistory.removeAll()
        smoothedDistance = nil
        smoothedDirection = nil
    }
}

extension NearbyInteractionManager: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard !nearbyObjects.isEmpty else { return }

        // Debouncing: skip update nếu quá nhanh
        let now = Date()
        guard now.timeIntervalSince(lastUpdateTime) >= minimumUpdateInterval else { return }

        for object in nearbyObjects {
            guard let tokenData = tokenData(object.discoveryToken),
                  let peer = peerByTokenData[tokenData] else {
                print("⚠️ NI: Could not find peer for token")
                continue
            }

            // Only update if this is the actively tracked peer
            guard peer == self.trackedPeer else {
                print("📍 NI: Ignoring update from non-tracked peer: \(peer.displayName)")
                continue
            }

            // Cập nhật lastUpdateTime sau khi tìm được tracked peer
            lastUpdateTime = now

            // Log raw data
            print("📏 NI Raw - distance: \(object.distance ?? -1), direction: \(object.direction?.debugDescription ?? "nil")")

            DispatchQueue.main.async {
                var updated = false

                if let distance = object.distance {
                    self.latestDistance = distance
                    self.smoothedDistance = self.smoothDistance(distance)
                    self.handleHaptics(newDistance: distance)
                    updated = true
                }

                if let direction = object.direction {
                    self.latestDirection = direction
                    self.smoothedDirection = self.smoothDirection(direction)
                    updated = true
                }

                if updated {
                    self.statusMessage = "Tracking \(peer.displayName)"
                    print("✅ NI Updated - smoothedDistance: \(self.smoothedDistance ?? -1)")
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
