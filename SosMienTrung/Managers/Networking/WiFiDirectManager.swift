import Foundation
import MultipeerConnectivity
import UIKit

final class WiFiDirectManager: NSObject {
    static let shared = WiFiDirectManager()

    private let serviceType = "sos-wifi-direct"
    private let peerId: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    var onReceiveData: ((Data, MCPeerID) -> Void)?
    var onPeersChanged: (([MCPeerID]) -> Void)?

    private override init() {
        let deviceName = UIDevice.current.name
        peerId = MCPeerID(displayName: deviceName)
        session = MCSession(peer: peerId, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    func start() {
        if advertiser == nil {
            advertiser = MCNearbyServiceAdvertiser(peer: peerId, discoveryInfo: nil, serviceType: serviceType)
            advertiser?.delegate = self
        }
        if browser == nil {
            browser = MCNearbyServiceBrowser(peer: peerId, serviceType: serviceType)
            browser?.delegate = self
        }
        advertiser?.startAdvertisingPeer()
        browser?.startBrowsingForPeers()
        notifyPeersChanged()
        print("[WiFiDirect] Started advertising/browsing")
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        print("[WiFiDirect] Stopped advertising/browsing")
    }

    func send(_ data: Data) {
        let peers = session.connectedPeers
        send(data, to: peers)
    }

    func send(_ data: Data, to peers: [MCPeerID]) {
        guard !peers.isEmpty else {
            return
        }
        do {
            try session.send(data, toPeers: peers, with: .reliable)
            print("[WiFiDirect] Sent data to \(peers.count) peer(s)")
        } catch {
            print("[WiFiDirect] Failed to send data: \(error.localizedDescription)")
        }
    }

    private func notifyPeersChanged() {
        onPeersChanged?(session.connectedPeers)
    }
}

extension WiFiDirectManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("[WiFiDirect] Connected to \(peerID.displayName)")
        case .connecting:
            print("[WiFiDirect] Connecting to \(peerID.displayName)")
        case .notConnected:
            print("[WiFiDirect] Disconnected from \(peerID.displayName)")
        @unknown default:
            print("[WiFiDirect] Unknown state for \(peerID.displayName)")
        }
        notifyPeersChanged()
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        onReceiveData?(data, peerID)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension WiFiDirectManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension WiFiDirectManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
