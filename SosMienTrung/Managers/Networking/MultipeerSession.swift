//
//  MultipeerSession.swift
//  SosMienTrung
//
//  Manages MultipeerConnectivity advertising/browsing and coordinates the Nearby
//  Interaction token handshake.
//
//  Architecture:
//    Rescuer → BROWSE only (tìm victim)
//    Victim  → ADVERTISE only (chờ rescuer tìm)
//  Không bao giờ cả browse lẫn advertise cùng lúc — tránh dual-invitation conflict.
//

import Foundation
import Combine
import MultipeerConnectivity
import NearbyInteraction
import os
import UIKit

final class MultipeerSession: NSObject, ObservableObject {
    @Published var connectedPeers: [MCPeerID] = []

    private let serviceType = "rescuefinder"
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private weak var nearbyManager: NearbyInteractionManager?
    private let logger = Logger(subsystem: "RescueFinder", category: "Multipeer")

    /// Retry timer khi bị disconnect
    private var retryTimer: Timer?
    private var isCurrentlyBrowsing = false
    private var isCurrentlyAdvertising = false

    init(nearbyManager: NearbyInteractionManager) {
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        self.advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
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

    // MARK: - Role-based Public Methods

    /// Rescuer: CHỈ browse — tìm victim đang advertise
    func startAsRescuer() {
        stopAll()
        // Tạm dừng WiFiDirectManager — 2 MCSession cùng kết nối 1 device gây conflict Bluetooth
        WiFiDirectManager.shared.stop()
        browser.startBrowsingForPeers()
        isCurrentlyBrowsing = true
        logger.info("🔍 Rescuer: started BROWSING for victims (WiFiDirect paused)")
    }

    /// Victim: CHỈ advertise — chờ rescuer browser tìm thấy
    func startAsVictim() {
        stopAll()
        // Tạm dừng WiFiDirectManager — 2 MCSession cùng kết nối 1 device gây conflict Bluetooth
        WiFiDirectManager.shared.stop()
        advertiser.startAdvertisingPeer()
        isCurrentlyAdvertising = true
        logger.info("📡 Victim: started ADVERTISING, waiting for rescuer (WiFiDirect paused)")
    }

    /// Dừng tất cả
    func stopAll() {
        retryTimer?.invalidate()
        retryTimer = nil

        if isCurrentlyBrowsing {
            browser.stopBrowsingForPeers()
            isCurrentlyBrowsing = false
        }
        if isCurrentlyAdvertising {
            advertiser.stopAdvertisingPeer()
            isCurrentlyAdvertising = false
        }
        // Khôi phục WiFiDirectManager khi không còn dùng NI
        WiFiDirectManager.shared.start()
        logger.info("⏹ Stopped all browsing/advertising (WiFiDirect resumed)")
    }

    // Legacy methods — delegate sang role-based
    func startAdvertising() { startAsVictim() }
    func stopAdvertising() { stopAll() }
    func startBrowsing() { startAsRescuer() }
    func stopBrowsing() { stopAll() }

    func broadcastDiscoveryTokenToConnectedPeers() {
        guard !connectedPeers.isEmpty else { return }
        logger.info("📤 Broadcasting NI token to \(self.connectedPeers.count) peers")
        connectedPeers.forEach { sendDiscoveryToken(to: $0) }
    }

    private func sendDiscoveryToken(to peer: MCPeerID) {
        guard let tokenData = nearbyManager?.discoveryTokenData else {
            logger.error("❌ No discovery token available to send.")
            return
        }

        do {
            try session.send(tokenData, toPeers: [peer], with: .reliable)
            logger.info("✅ Sent NI discovery token to \(peer.displayName, privacy: .public)")
        } catch {
            logger.error("❌ Failed to send discovery token: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Retry Logic

    private func scheduleRetry() {
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
}

// MARK: - Advertiser Delegate
extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        logger.info("📨 Received invitation from \(peerID.displayName, privacy: .public) — accepting")
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.error("❌ Advertiser failed: \(error.localizedDescription, privacy: .public)")
    }
}

// MARK: - Browser Delegate
extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Chỉ invite nếu chưa connected
        guard !session.connectedPeers.contains(peerID) else {
            logger.info("⏩ Already connected to \(peerID.displayName, privacy: .public), skip invite")
            return
        }
        logger.info("👀 Found peer \(peerID.displayName, privacy: .public) — sending invitation (timeout 30s)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
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

        switch state {
        case .connected:
            logger.info("✅ CONNECTED to \(peerID.displayName, privacy: .public)")
            retryTimer?.invalidate()
            // Gửi NI discovery token ngay khi connected
            sendDiscoveryToken(to: peerID)
        case .notConnected:
            logger.info("❌ DISCONNECTED from \(peerID.displayName, privacy: .public)")
            // Auto-retry nếu vẫn đang hoạt động
            if isCurrentlyBrowsing || isCurrentlyAdvertising {
                scheduleRetry()
            }
        case .connecting:
            logger.info("🔄 CONNECTING to \(peerID.displayName, privacy: .public)")
        @unknown default:
            logger.error("Unknown session state")
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
