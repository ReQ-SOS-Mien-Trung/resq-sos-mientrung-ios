//
//  MultipeerSession.swift
//  SosMienTrung
//
//  Manages MultipeerConnectivity advertising/browsing and coordinates the Nearby
//  Interaction token handshake.
//
//  Architecture:
//    Symmetric NI discovery like Apple's sample:
//    each device both ADVERTISES and BROWSES, then exchanges NI tokens.
//

import Foundation
import Combine
import MultipeerConnectivity
import NearbyInteraction
import os
import UIKit

final class MultipeerSession: NSObject, ObservableObject {
    @Published var connectedPeers: [MCPeerID] = []

    private struct DiscoveryConstants {
        static let identityKey = "identity"
        static let nodeIdKey = "nodeId"
        static let serviceIdentity = "com.sosmientrung.nearbyinteraction"
    }

    private let serviceType = "rescuefinder"
    private let maxNumPeers = 1
    private let localNodeId: String
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private weak var nearbyManager: NearbyInteractionManager?
    private let logger = Logger(subsystem: "RescueFinder", category: "Multipeer")
    private let sessionQueue = DispatchQueue(label: "SosMienTrung.multipeer.session", qos: .default)
    private var currentConnectedPeers: [MCPeerID] = []
    private var pendingPeerConnections: Set<MCPeerID> = []
    private var tokenRetryCountByPeer: [MCPeerID: Int] = [:]

    /// Retry timer khi bị disconnect
    private var retryTimer: Timer?
    private var isCurrentlyBrowsing = false
    private var isCurrentlyAdvertising = false
    private var isPeerDiscoveryActive = false
    private var hasPausedCompetingStacks = false
    private var pendingResumeWorkItem: DispatchWorkItem?
    private let niWiFiPauseReason = "nearby-interaction-mode"
    private let niBridgefyPauseReason = "nearby-interaction-mode"

    init(nearbyManager: NearbyInteractionManager) {
        self.localNodeId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        self.advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: [
                DiscoveryConstants.identityKey: DiscoveryConstants.serviceIdentity,
                DiscoveryConstants.nodeIdKey: self.localNodeId
            ],
            serviceType: serviceType
        )
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        self.nearbyManager = nearbyManager
        super.init()

        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        nearbyManager.register(multipeerSession: self)
    }

    deinit {
        stopAll()
    }

    // MARK: - Public Methods

    /// Bắt đầu peer discovery theo mô hình đối xứng (browse + advertise cùng lúc).
    func startPeerDiscovery() {
        pendingResumeWorkItem?.cancel()
        pendingResumeWorkItem = nil

        if isPeerDiscoveryActive {
            logger.info("⏩ Peer discovery already active, skip re-start")
            return
        }

        isPeerDiscoveryActive = true
        retryTimer?.invalidate()
        retryTimer = nil

        if !hasPausedCompetingStacks {
            WiFiDirectManager.shared.pause(reason: niWiFiPauseReason)
            BridgefyNetworkManager.shared.pause(reason: niBridgefyPauseReason)
            hasPausedCompetingStacks = true
        }

        advertiser.startAdvertisingPeer()
        isCurrentlyAdvertising = true

        browser.startBrowsingForPeers()
        isCurrentlyBrowsing = true
        logger.info("🔄 Started symmetric NI peer discovery (browse + advertise)")
    }

    /// Dừng tất cả
    func stopAll(resumeWiFiDirect: Bool = true) {
        isPeerDiscoveryActive = false
        retryTimer?.invalidate()
        retryTimer = nil
        currentConnectedPeers.removeAll()
        pendingPeerConnections.removeAll()

        if isCurrentlyBrowsing {
            browser.stopBrowsingForPeers()
            isCurrentlyBrowsing = false
        }
        if isCurrentlyAdvertising {
            advertiser.stopAdvertisingPeer()
            isCurrentlyAdvertising = false
        }
        if resumeWiFiDirect {
            scheduleResumeCompetingStacks()
            logger.info("⏹ Stopped all browsing/advertising (WiFiDirect resumed)")
        } else {
            logger.info("⏹ Stopped all browsing/advertising (WiFiDirect remains paused)")
        }
    }

    private func scheduleResumeCompetingStacks() {
        guard hasPausedCompetingStacks else { return }

        pendingResumeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isPeerDiscoveryActive else { return }
            guard self.hasPausedCompetingStacks else { return }

            WiFiDirectManager.shared.resume(reason: self.niWiFiPauseReason)
            BridgefyNetworkManager.shared.resume(reason: self.niBridgefyPauseReason)
            self.hasPausedCompetingStacks = false
            self.logger.info("▶️ Resumed WiFiDirect/Bridgefy after NI cooldown")
        }

        pendingResumeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    // Legacy methods — delegate sang mode đối xứng
    func startAdvertising() { startPeerDiscovery() }
    func stopAdvertising() { stopAll() }
    func startBrowsing() { startPeerDiscovery() }
    func stopBrowsing() { stopAll() }
    func startAsRescuer() { startPeerDiscovery() }
    func startAsVictim() { startPeerDiscovery() }

    func broadcastDiscoveryTokenToConnectedPeers() {
        guard !connectedPeers.isEmpty else { return }
        logger.info("📤 Broadcasting NI token to \(self.connectedPeers.count) peers")
        connectedPeers.forEach { sendDiscoveryToken(to: $0) }
    }

    func isConnected(to peer: MCPeerID) -> Bool {
        sessionQueue.sync {
            currentConnectedPeers.contains(peer) || session.connectedPeers.contains(peer)
        }
    }

    private func sendDiscoveryToken(to peer: MCPeerID) {
        guard let tokenData = nearbyManager?.discoveryTokenData else {
            let retryCount = (tokenRetryCountByPeer[peer] ?? 0) + 1
            tokenRetryCountByPeer[peer] = retryCount
            guard retryCount <= 8 else {
                logger.error("❌ No discovery token available after retries for \(peer.displayName, privacy: .public)")
                tokenRetryCountByPeer[peer] = 0
                return
            }
            if retryCount == 4 {
                nearbyManager?.prepareDiscoveryTokenIfNeeded()
            }
            logger.info("⏳ Discovery token not ready, retry \(retryCount) for \(peer.displayName, privacy: .public)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self else { return }
                guard self.session.connectedPeers.contains(peer) else { return }
                self.sendDiscoveryToken(to: peer)
            }
            return
        }

        do {
            try session.send(tokenData, toPeers: [peer], with: .reliable)
            tokenRetryCountByPeer[peer] = 0
            logger.info("✅ Sent NI discovery token to \(peer.displayName, privacy: .public)")
        } catch {
            logger.error("❌ Failed to send discovery token: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Retry Logic

    private func scheduleRetry() {
        guard isPeerDiscoveryActive else { return }
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.connectedPeers.isEmpty {
                self.logger.info("🔄 Retrying connection...")
                if self.isCurrentlyBrowsing {
                    self.browser.stopBrowsingForPeers()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.browser.startBrowsingForPeers()
                        self.logger.info("🔍 Re-started browsing after retry")
                    }
                }
                if self.isCurrentlyAdvertising {
                    self.advertiser.stopAdvertisingPeer()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.advertiser.startAdvertisingPeer()
                        self.logger.info("📡 Re-started advertising after retry")
                    }
                }
            }
        }
    }

    private func peerConnected(peerID: MCPeerID) {
        pendingPeerConnections.remove(peerID)
        guard !currentConnectedPeers.contains(peerID) else { return }
        currentConnectedPeers.append(peerID)
        if currentConnectedPeers.count >= maxNumPeers {
            if isCurrentlyBrowsing {
                browser.stopBrowsingForPeers()
                isCurrentlyBrowsing = false
            }
            if isCurrentlyAdvertising {
                advertiser.stopAdvertisingPeer()
                isCurrentlyAdvertising = false
            }
            logger.info("⏸ Discovery suspended (max peers reached)")
        }
    }

    private func peerDisconnected(peerID: MCPeerID) {
        pendingPeerConnections.remove(peerID)
        guard currentConnectedPeers.contains(peerID) else { return }
        currentConnectedPeers.removeAll { $0 == peerID }
        tokenRetryCountByPeer.removeValue(forKey: peerID)
        guard isPeerDiscoveryActive else { return }
        guard (isCurrentlyBrowsing || isCurrentlyAdvertising) == false else { return }
        advertiser.startAdvertisingPeer()
        isCurrentlyAdvertising = true
        browser.startBrowsingForPeers()
        isCurrentlyBrowsing = true
        logger.info("▶️ Discovery resumed after disconnect")
    }
}

// MARK: - Advertiser Delegate
extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        sessionQueue.sync {
            let canAccept =
                !self.pendingPeerConnections.contains(peerID) &&
                self.session.connectedPeers.count < self.maxNumPeers &&
                self.currentConnectedPeers.count < self.maxNumPeers
            if canAccept {
                self.pendingPeerConnections.insert(peerID)
            }
            invitationHandler(canAccept, canAccept ? self.session : nil)
        }
        logger.info("📨 Invitation from \(peerID.displayName, privacy: .public)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.error("❌ Advertiser failed: \(error.localizedDescription, privacy: .public)")
    }
}

// MARK: - Browser Delegate
extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        guard let identity = info?[DiscoveryConstants.identityKey],
              identity == DiscoveryConstants.serviceIdentity else {
            return
        }
        guard let remoteNodeId = info?[DiscoveryConstants.nodeIdKey] else {
            return
        }

        // Deterministic inviter election prevents both sides sending invitations at once.
        // Only the lexicographically smaller nodeId sends invite.
        let shouldInvite: Bool
        if localNodeId == remoteNodeId {
            shouldInvite = self.peerID.displayName < peerID.displayName
        } else {
            shouldInvite = localNodeId < remoteNodeId
        }

        guard shouldInvite else {
            logger.info("⏳ Found peer \(peerID.displayName, privacy: .public) — waiting for remote invite")
            return
        }

        sessionQueue.sync {
            guard !self.session.connectedPeers.contains(peerID) else {
                return
            }
            guard !self.pendingPeerConnections.contains(peerID) else {
                return
            }
            guard self.session.connectedPeers.count < self.maxNumPeers else {
                return
            }
            self.pendingPeerConnections.insert(peerID)
            logger.info("👀 Found peer \(peerID.displayName, privacy: .public) — sending invitation")
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 15)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("👋 Lost peer \(peerID.displayName, privacy: .public)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.error("❌ Browser failed: \(error.localizedDescription, privacy: .public)")
    }
}

// MARK: - Session Delegate
extension MultipeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
        }

        sessionQueue.sync {
            switch state {
            case .connected:
                self.logger.info("✅ CONNECTED to \(peerID.displayName, privacy: .public)")
                self.retryTimer?.invalidate()
                self.peerConnected(peerID: peerID)
                self.sendDiscoveryToken(to: peerID)
            case .notConnected:
                self.logger.info("❌ DISCONNECTED from \(peerID.displayName, privacy: .public)")
                DispatchQueue.main.async {
                    self.nearbyManager?.handleTransportDisconnect(from: peerID)
                }
                self.peerDisconnected(peerID: peerID)
                if self.isCurrentlyBrowsing || self.isCurrentlyAdvertising {
                    self.scheduleRetry()
                }
            case .connecting:
                self.pendingPeerConnections.insert(peerID)
                self.logger.info("🔄 CONNECTING to \(peerID.displayName, privacy: .public)")
            @unknown default:
                self.logger.error("Unknown session state")
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
            logger.info("📡 Received NI discovery token from \(peerID.displayName, privacy: .public)")
            DispatchQueue.main.async {
                self.nearbyManager?.receivedPeerDiscoveryToken(token, from: peerID)
            }
        } else {
            logger.error("Received unknown data from \(peerID.displayName, privacy: .public)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)
    }
}
