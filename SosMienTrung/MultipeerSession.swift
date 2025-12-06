//
//  MultipeerSession.swift
//  SosMienTrung
//
//  Manages MultipeerConnectivity advertising/browsing and coordinates the Nearby
//  Interaction token handshake.
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

        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    deinit {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    func broadcastDiscoveryTokenToConnectedPeers() {
        connectedPeers.forEach { sendDiscoveryToken(to: $0) }
    }

    private func sendDiscoveryToken(to peer: MCPeerID) {
        guard let tokenData = nearbyManager?.discoveryTokenData else {
            logger.error("No discovery token available to send.")
            return
        }

        do {
            try session.send(tokenData, toPeers: [peer], with: .reliable)
            logger.debug("Sent discovery token to \(peer.displayName, privacy: .public)")
        } catch {
            logger.error("Failed to send discovery token: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.error("Advertiser failed: \(error.localizedDescription, privacy: .public)")
    }
}

extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 8)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("Lost peer \(peerID.displayName, privacy: .public)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.error("Browser failed: \(error.localizedDescription, privacy: .public)")
    }
}

extension MultipeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
        }

        switch state {
        case .connected:
            logger.info("Connected to \(peerID.displayName, privacy: .public)")
            sendDiscoveryToken(to: peerID)
        case .notConnected:
            logger.info("Disconnected from \(peerID.displayName, privacy: .public)")
        case .connecting:
            logger.info("Connecting to \(peerID.displayName, privacy: .public)")
        @unknown default:
            logger.error("Unknown session state")
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
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
