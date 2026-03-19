//
//  MultipeerSession.swift
//  SosMienTrung
//
//  Manages MultipeerConnectivity advertising/browsing and coordinates the Nearby
//  Interaction token handshake.
//
//  Architecture:
//    A single MCSession handles both background local discovery and local SOS relay.
//    Nearby Interaction token exchange is enabled only while the rescue feature UI is open.
//

import Foundation
import Combine
import MultipeerConnectivity
import NearbyInteraction
import os
import UIKit

final class MultipeerSession: NSObject, ObservableObject {
    @Published var connectedPeers: [MCPeerID] = []
    var onReceiveApplicationData: ((Data, MCPeerID) -> Void)?
    var onPeersChanged: (([MCPeerID]) -> Void)?

    enum CoordinationPolicy {
        case coexistWithBridgefy
        case suspendBridgefy
    }

    enum DiscoveryRole {
        case rescuer
        case victim

        var shouldBrowse: Bool {
            self == .rescuer
        }

        var shouldAdvertise: Bool {
            self == .victim
        }

        var displayName: String {
            switch self {
            case .rescuer:
                return "rescuer"
            case .victim:
                return "victim"
            }
        }

        var transportDescription: String {
            switch self {
            case .rescuer:
                return "browse-only"
            case .victim:
                return "advertise-only"
            }
        }
    }

    private struct DiscoveryConstants {
        static let identityKey = "identity"
        static let nodeIdKey = "nodeId"
        static let serviceIdentity = "com.sosmientrung.nearbyinteraction"
    }

    private let serviceType = "rescuefinder"
    private let maxNumPeers = 1
    private let localNodeId: String
    private let coordinationPolicy: CoordinationPolicy
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    private weak var nearbyManager: NearbyInteractionManager?
    private let logger = Logger(subsystem: "RescueFinder", category: "Multipeer")
    private let sessionQueue = DispatchQueue(label: "SosMienTrung.multipeer.session", qos: .default)
    private var currentConnectedPeers: [MCPeerID] = []
    private var pendingPeerConnections: Set<MCPeerID> = []
    private var tokenRetryCountByPeer: [MCPeerID: Int] = [:]

    private var retryTimer: Timer?
    private var pendingStopWorkItem: DispatchWorkItem?
    private var pendingDeactivateNearbyInteractionWorkItem: DispatchWorkItem?
    private var isCurrentlyBrowsing = false
    private var isCurrentlyAdvertising = false
    private var isPeerDiscoveryActive = false
    private var activeDiscoveryRole: DiscoveryRole?
    private var isNearbyInteractionActive = false
    private var hasPausedCompetingStacks = false
    private var pendingResumeWorkItem: DispatchWorkItem?
    private let niBridgefyPauseReason = "nearby-interaction-mode"

    init(
        nearbyManager: NearbyInteractionManager,
        coordinationPolicy: CoordinationPolicy = .coexistWithBridgefy
    ) {
        self.localNodeId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.coordinationPolicy = coordinationPolicy
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

    func startBackgroundDiscovery(for role: DiscoveryRole) {
        pendingStopWorkItem?.cancel()
        pendingStopWorkItem = nil
        pendingDeactivateNearbyInteractionWorkItem?.cancel()
        pendingDeactivateNearbyInteractionWorkItem = nil
        pendingResumeWorkItem?.cancel()
        pendingResumeWorkItem = nil

        let wasDiscoveryActive = isPeerDiscoveryActive
        let roleChanged = activeDiscoveryRole != role
        let shouldPreserveNearbyInteraction = isNearbyInteractionActive && !roleChanged
        activeDiscoveryRole = role
        isNearbyInteractionActive = shouldPreserveNearbyInteraction
        isPeerDiscoveryActive = true
        retryTimer?.invalidate()
        retryTimer = nil

        pauseCompetingStacksIfNeeded()
        syncDiscoveryTransport(for: role)
        if shouldPreserveNearbyInteraction {
            logger.info("⏩ Background MCSession already warm for \(role.displayName, privacy: .public); NI token exchange stays enabled")
        } else if roleChanged || !wasDiscoveryActive {
            logger.info("🌐 Warmed background MCSession for \(role.displayName, privacy: .public) (\(role.transportDescription, privacy: .public))")
        } else {
            logger.info("⏩ Background MCSession already warm for \(role.displayName, privacy: .public)")
        }
    }

    func activateNearbyInteractionDiscovery(for role: DiscoveryRole) {
        pendingStopWorkItem?.cancel()
        pendingStopWorkItem = nil
        pendingDeactivateNearbyInteractionWorkItem?.cancel()
        pendingDeactivateNearbyInteractionWorkItem = nil
        pendingResumeWorkItem?.cancel()
        pendingResumeWorkItem = nil

        let wasDiscoveryActive = isPeerDiscoveryActive
        let roleChanged = activeDiscoveryRole != role
        let niWasInactive = !isNearbyInteractionActive

        activeDiscoveryRole = role
        isNearbyInteractionActive = true
        isPeerDiscoveryActive = true
        retryTimer?.invalidate()
        retryTimer = nil

        pauseCompetingStacksIfNeeded()
        syncDiscoveryTransport(for: role)
        nearbyManager?.prepareDiscoveryTokenIfNeeded()

        if !wasDiscoveryActive || roleChanged || niWasInactive {
            logger.info("🔄 Nearby Interaction discovery active for \(role.displayName, privacy: .public) (\(role.transportDescription, privacy: .public))")
        }

        broadcastDiscoveryTokenToConnectedPeers()
    }

    func deactivateNearbyInteraction() {
        pendingDeactivateNearbyInteractionWorkItem?.cancel()
        pendingDeactivateNearbyInteractionWorkItem = nil
        guard isNearbyInteractionActive else { return }

        isNearbyInteractionActive = false
        tokenRetryCountByPeer.removeAll()
        logger.info("⏸ NI token exchange disabled; background MCSession stays warm")
    }

    func scheduleDeactivateNearbyInteraction(after delay: TimeInterval = 0.75) {
        pendingDeactivateNearbyInteractionWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.deactivateNearbyInteraction()
        }

        pendingDeactivateNearbyInteractionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func startPeerDiscovery() {
        activateNearbyInteractionDiscovery(for: activeDiscoveryRole ?? .rescuer)
    }

    func stopAll(resumeBridgefy: Bool = true) {
        pendingStopWorkItem?.cancel()
        pendingStopWorkItem = nil
        pendingDeactivateNearbyInteractionWorkItem?.cancel()
        pendingDeactivateNearbyInteractionWorkItem = nil
        isPeerDiscoveryActive = false
        isNearbyInteractionActive = false
        activeDiscoveryRole = nil
        retryTimer?.invalidate()
        retryTimer = nil
        currentConnectedPeers.removeAll()
        pendingPeerConnections.removeAll()
        tokenRetryCountByPeer.removeAll()
        rebuildDiscoveryTransport(restartDiscovery: false)
        resumeCompetingStacksIfNeeded(resumeBridgefy: resumeBridgefy)
    }

    func scheduleStopAll(after delay: TimeInterval = 0.75, resumeBridgefy: Bool = true) {
        pendingStopWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.stopAll(resumeBridgefy: resumeBridgefy)
        }

        pendingStopWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func broadcastDiscoveryTokenToConnectedPeers() {
        guard isNearbyInteractionActive else { return }
        guard !connectedPeers.isEmpty else { return }
        logger.info("📤 Broadcasting NI token to \(self.connectedPeers.count) peers")
        connectedPeers.forEach { sendDiscoveryToken(to: $0) }
    }

    func sendApplicationData(_ data: Data, to peers: [MCPeerID]? = nil) {
        let targets = peers ?? session.connectedPeers
        guard !targets.isEmpty else { return }

        do {
            try session.send(data, toPeers: targets, with: .reliable)
            logger.info("✅ Sent application payload to \(targets.count) peer(s)")
        } catch {
            logger.error("❌ Failed to send application payload: \(error.localizedDescription, privacy: .public)")
        }
    }

    func isConnected(to peer: MCPeerID) -> Bool {
        sessionQueue.sync {
            currentConnectedPeers.contains(peer) || session.connectedPeers.contains(peer)
        }
    }

    func startAdvertising() { startBackgroundDiscovery(for: .victim) }
    func stopAdvertising() { stopAll() }
    func startBrowsing() { startBackgroundDiscovery(for: .rescuer) }
    func stopBrowsing() { stopAll() }
    func startAsRescuer() { activateNearbyInteractionDiscovery(for: .rescuer) }
    func startAsVictim() { activateNearbyInteractionDiscovery(for: .victim) }

    // MARK: - Internal Helpers

    private func scheduleResumeCompetingStacks() {
        guard hasPausedCompetingStacks else { return }

        pendingResumeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isPeerDiscoveryActive else { return }
            guard self.hasPausedCompetingStacks else { return }

            switch self.coordinationPolicy {
            case .coexistWithBridgefy:
                break
            case .suspendBridgefy:
                BridgefyNetworkManager.shared.resume(reason: self.niBridgefyPauseReason)
            }
            self.hasPausedCompetingStacks = false
            self.logger.info("▶️ Resumed Bridgefy after NI cooldown")
        }

        pendingResumeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func syncDiscoveryTransport(for role: DiscoveryRole) {
        if role.shouldAdvertise {
            if !isCurrentlyAdvertising {
                advertiser.startAdvertisingPeer()
                isCurrentlyAdvertising = true
            }
        } else if isCurrentlyAdvertising {
            advertiser.stopAdvertisingPeer()
            isCurrentlyAdvertising = false
        }

        if role.shouldBrowse {
            if !isCurrentlyBrowsing {
                browser.startBrowsingForPeers()
                isCurrentlyBrowsing = true
            }
        } else if isCurrentlyBrowsing {
            browser.stopBrowsingForPeers()
            isCurrentlyBrowsing = false
        }
    }

    private func rebuildDiscoveryTransport(restartDiscovery: Bool) {
        if isCurrentlyBrowsing {
            browser.stopBrowsingForPeers()
            isCurrentlyBrowsing = false
        }
        if isCurrentlyAdvertising {
            advertiser.stopAdvertisingPeer()
            isCurrentlyAdvertising = false
        }

        session.disconnect()
        session.delegate = nil
        advertiser.delegate = nil
        browser.delegate = nil

        let newSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        let newAdvertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: [
                DiscoveryConstants.identityKey: DiscoveryConstants.serviceIdentity,
                DiscoveryConstants.nodeIdKey: localNodeId
            ],
            serviceType: serviceType
        )
        let newBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)

        newSession.delegate = self
        newAdvertiser.delegate = self
        newBrowser.delegate = self

        session = newSession
        advertiser = newAdvertiser
        browser = newBrowser
        currentConnectedPeers.removeAll()
        pendingPeerConnections.removeAll()
        tokenRetryCountByPeer.removeAll()

        DispatchQueue.main.async {
            self.connectedPeers = []
            self.onPeersChanged?([])
        }

        guard restartDiscovery, isPeerDiscoveryActive, let role = activeDiscoveryRole else { return }

        syncDiscoveryTransport(for: role)
        logger.info("🔄 Reset multipeer transport after disconnect (\(role.transportDescription, privacy: .public))")
    }

    private func pauseCompetingStacksIfNeeded() {
        switch coordinationPolicy {
        case .coexistWithBridgefy:
            logger.info("🔀 Multipeer discovery running alongside Bridgefy")
        case .suspendBridgefy:
            guard !hasPausedCompetingStacks else { return }
            BridgefyNetworkManager.shared.pause(reason: niBridgefyPauseReason)
            hasPausedCompetingStacks = true
        }
    }

    private func resumeCompetingStacksIfNeeded(resumeBridgefy: Bool) {
        switch coordinationPolicy {
        case .coexistWithBridgefy:
            logger.info("⏹ Stopped local multipeer discovery (Bridgefy kept active)")
        case .suspendBridgefy:
            if resumeBridgefy {
                scheduleResumeCompetingStacks()
                logger.info("⏹ Stopped local multipeer discovery (Bridgefy resumed)")
            } else {
                logger.info("⏹ Stopped local multipeer discovery (Bridgefy remains paused)")
            }
        }
    }

    private func sendDiscoveryToken(to peer: MCPeerID) {
        guard isNearbyInteractionActive else { return }
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

    private func peerConnected(peerID: MCPeerID) {
        pendingPeerConnections.remove(peerID)
        guard !currentConnectedPeers.contains(peerID) else { return }
        currentConnectedPeers.append(peerID)
        if currentConnectedPeers.count >= maxNumPeers {
            logger.info("🔒 Max peers reached; discovery stays alive for recovery")
        }
    }

    private func peerDisconnected(peerID: MCPeerID) -> Bool {
        pendingPeerConnections.remove(peerID)
        currentConnectedPeers.removeAll { $0 == peerID }
        tokenRetryCountByPeer.removeValue(forKey: peerID)
        return isPeerDiscoveryActive
    }
}

// MARK: - Advertiser Delegate
extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        sessionQueue.sync {
            let canAdvertise = self.activeDiscoveryRole?.shouldAdvertise == true
            let canAccept =
                canAdvertise &&
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
        guard activeDiscoveryRole?.shouldBrowse == true else {
            return
        }
        guard let identity = info?[DiscoveryConstants.identityKey],
              identity == DiscoveryConstants.serviceIdentity else {
            return
        }
        guard info?[DiscoveryConstants.nodeIdKey] != nil else {
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
        var shouldRefreshDiscovery = false

        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
            self.onPeersChanged?(session.connectedPeers)
        }

        sessionQueue.sync {
            switch state {
            case .connected:
                self.logger.info("✅ CONNECTED to \(peerID.displayName, privacy: .public)")
                self.retryTimer?.invalidate()
                self.peerConnected(peerID: peerID)
                if self.isNearbyInteractionActive {
                    self.sendDiscoveryToken(to: peerID)
                } else {
                    self.logger.info("🤝 MCSession warm with \(peerID.displayName, privacy: .public); NI token exchange deferred")
                }
            case .notConnected:
                self.logger.info("❌ DISCONNECTED from \(peerID.displayName, privacy: .public)")
                DispatchQueue.main.async {
                    self.nearbyManager?.handleTransportDisconnect(from: peerID)
                }
                shouldRefreshDiscovery = self.peerDisconnected(peerID: peerID)
            case .connecting:
                self.pendingPeerConnections.insert(peerID)
                self.logger.info("🔄 CONNECTING to \(peerID.displayName, privacy: .public)")
            @unknown default:
                self.logger.error("Unknown session state")
            }
        }

        guard shouldRefreshDiscovery else { return }

        DispatchQueue.main.async {
            self.rebuildDiscoveryTransport(restartDiscovery: true)
            self.logger.info("▶️ Discovery refreshed after disconnect")
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
            logger.info("📡 Received NI discovery token from \(peerID.displayName, privacy: .public)")
            DispatchQueue.main.async {
                self.nearbyManager?.receivedPeerDiscoveryToken(token, from: peerID)
            }
        } else {
            logger.info("📨 Received application payload from \(peerID.displayName, privacy: .public)")
            DispatchQueue.main.async {
                self.onReceiveApplicationData?(data, peerID)
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) { }
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)
    }
}
