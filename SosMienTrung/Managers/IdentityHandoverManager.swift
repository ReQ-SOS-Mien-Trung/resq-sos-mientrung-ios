//
//  IdentityHandoverManager.swift
//  SosMienTrung
//
//  Manages the offline P2P account handover process using
//  Multipeer Connectivity for secure identity transfer.
//

import Foundation
import MultipeerConnectivity
import Combine
import UIKit
import os

// MARK: - Handover State
enum HandoverState: Equatable {
    case idle
    case advertising  // Old device waiting for new device
    case browsing  // New device looking for old device
    case connecting
    case waitingForConfirmation  // Old device: waiting for user to confirm
    case requestingTakeover  // New device: sent request, waiting for response
    case creatingToken  // Old device: creating delegation token
    case transferringToken  // Old device: sending token
    case receivingToken  // New device: receiving token
    case verifyingToken  // New device: verifying token
    case activatingIdentity  // New device: activating identity
    case revokingIdentity  // Old device: revoking identity
    case completed
    case failed(HandoverError)
    
    static func == (lhs: HandoverState, rhs: HandoverState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.advertising, .advertising),
             (.browsing, .browsing),
             (.connecting, .connecting),
             (.waitingForConfirmation, .waitingForConfirmation),
             (.requestingTakeover, .requestingTakeover),
             (.creatingToken, .creatingToken),
             (.transferringToken, .transferringToken),
             (.receivingToken, .receivingToken),
             (.verifyingToken, .verifyingToken),
             (.activatingIdentity, .activatingIdentity),
             (.revokingIdentity, .revokingIdentity),
             (.completed, .completed):
            return true
        case (.failed(let e1), .failed(let e2)):
            return e1.localizedDescription == e2.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Handover Role
enum HandoverRole {
    case none
    case oldDevice  // Device transferring identity out
    case newDevice  // Device receiving identity
}

// MARK: - Identity Handover Manager
final class IdentityHandoverManager: NSObject, ObservableObject {
    static let shared = IdentityHandoverManager()
    
    // MARK: - Published Properties
    @Published private(set) var state: HandoverState = .idle
    @Published private(set) var role: HandoverRole = .none
    @Published private(set) var discoveredPeers: [MCPeerID] = []
    @Published private(set) var connectedPeer: MCPeerID?
    @Published private(set) var pendingRequest: HandoverRequest?
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var statusMessage: String = ""
    @Published private(set) var batteryLevel: Float = 1.0
    @Published private(set) var isLowBattery: Bool = false
    
    // MARK: - Callbacks
    var onHandoverComplete: ((UserIdentity) -> Void)?
    var onHandoverFailed: ((HandoverError) -> Void)?
    var onRequestReceived: ((HandoverRequest, MCPeerID) -> Void)?
    
    // MARK: - Private Properties
    private let serviceType = "sos-handover"
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    private let keyManager = IdentityKeyManager.shared
    private let logger = Logger(subsystem: "SosMienTrung", category: "IdentityHandover")
    
    private var usedTokenIds: Set<String> = []
    private var auditLogs: [HandoverAuditLog] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Token storage
    private let usedTokensKey = "handover_used_tokens"
    private let auditLogsKey = "handover_audit_logs"
    
    // Track if token was successfully sent (for old device)
    private var tokenSentSuccessfully: Bool = false
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupPeerID()
        loadPersistedData()
        monitorBattery()
    }
    
    private func setupPeerID() {
        let deviceName = UIDevice.current.name
        peerID = MCPeerID(displayName: deviceName)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }
    
    private func loadPersistedData() {
        // Load used token IDs
        if let data = UserDefaults.standard.data(forKey: usedTokensKey),
           let tokens = try? JSONDecoder().decode(Set<String>.self, from: data) {
            usedTokenIds = tokens
        }
        
        // Load audit logs
        if let data = UserDefaults.standard.data(forKey: auditLogsKey),
           let logs = try? JSONDecoder().decode([HandoverAuditLog].self, from: data) {
            auditLogs = logs
        }
    }
    
    private func persistUsedTokens() {
        if let data = try? JSONEncoder().encode(usedTokenIds) {
            UserDefaults.standard.set(data, forKey: usedTokensKey)
        }
    }
    
    private func persistAuditLogs() {
        // Keep only last 100 logs
        let recentLogs = Array(auditLogs.suffix(100))
        if let data = try? JSONEncoder().encode(recentLogs) {
            UserDefaults.standard.set(data, forKey: auditLogsKey)
        }
    }
    
    private func monitorBattery() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateBatteryStatus()
            }
            .store(in: &cancellables)
        
        updateBatteryStatus()
    }
    
    private func updateBatteryStatus() {
        batteryLevel = UIDevice.current.batteryLevel
        isLowBattery = batteryLevel < 0.1 && batteryLevel >= 0
    }
    
    // MARK: - Old Device: Start Advertising
    
    /// Start as old device (the one transferring identity)
    func startAsOldDevice() {
        guard keyManager.identityStatus == .active else {
            setState(.failed(.noIdentityToTransfer))
            return
        }
        
        role = .oldDevice
        setState(.advertising)
        setStatus("Đang chờ thiết bị mới kết nối...")
        
        // Discovery info includes public key fingerprint for verification
        let publicKeyFingerprint = (try? keyManager.getPublicKeyBase64().prefix(8)) ?? ""
        let discoveryInfo: [String: String] = [
            "role": "old_device",
            "fingerprint": String(publicKeyFingerprint),
            "battery": String(Int(batteryLevel * 100))
        ]
        
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        logger.info("Started advertising as old device")
        addAuditLog(.handoverInitiated, details: "Started advertising for handover")
    }
    
    // MARK: - New Device: Start Browsing
    
    /// Start as new device (the one receiving identity)
    func startAsNewDevice() {
        // Reset any existing identity on new device to ensure clean state
        logger.info("Resetting identity on new device before handover...")
        keyManager.fullReset()
        IdentityStore.shared.clearIdentity()
        
        // Generate fresh key pair for the handover process
        do {
            try keyManager.generateIdentityKeyPair()
            logger.info("Generated fresh key pair for handover")
        } catch {
            logger.error("Failed to generate key pair: \(error.localizedDescription)")
            setState(.failed(.networkError(error.localizedDescription)))
            return
        }
        
        role = .newDevice
        setState(.browsing)
        setStatus("Đang tìm thiết bị cũ...")
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        logger.info("Started browsing for old device")
    }
    
    // MARK: - Connect to Peer
    
    /// New device: connect to discovered old device
    func connectToPeer(_ peer: MCPeerID) {
        guard role == .newDevice else { return }
        
        setState(.connecting)
        setStatus("Đang kết nối với \(peer.displayName)...")
        
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 30)
        
        logger.info("Inviting peer: \(peer.displayName)")
    }
    
    // MARK: - Send Takeover Request
    
    /// New device: send takeover request after connection
    private func sendTakeoverRequest() {
        guard role == .newDevice,
              let publicKey = try? keyManager.getPublicKeyData() else {
            return
        }
        
        setState(.requestingTakeover)
        setStatus("Đang gửi yêu cầu chuyển tài khoản...")
        setProgress(0.2)
        
        let request = HandoverRequest(
            newDevicePublicKey: publicKey,
            newDeviceName: UIDevice.current.name
        )
        
        do {
            let data = try JSONEncoder().encode(HandoverMessage.request(request))
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            logger.info("Sent takeover request")
        } catch {
            logger.error("Failed to send request: \(error.localizedDescription)")
            setState(.failed(.networkError(error.localizedDescription)))
        }
    }
    
    // MARK: - Old Device: Handle Request
    
    /// Old device: received takeover request from new device
    private func handleTakeoverRequest(_ request: HandoverRequest, from peer: MCPeerID) {
        guard role == .oldDevice else { return }
        
        pendingRequest = request
        connectedPeer = peer
        setState(.waitingForConfirmation)
        setStatus("Yêu cầu từ \(request.newDeviceName)")
        
        // Notify UI to show confirmation dialog
        DispatchQueue.main.async {
            self.onRequestReceived?(request, peer)
        }
        
        logger.info("Received takeover request from: \(request.newDeviceName)")
        addAuditLog(.handoverInitiated, details: "Request from \(request.newDeviceName)")
    }
    
    // MARK: - Old Device: Approve Request
    
    /// Old device: user approved the takeover request
    func approveTakeoverRequest() {
        logger.info("approveTakeoverRequest called - role: \(String(describing: self.role)), pendingRequest: \(self.pendingRequest != nil), identity: \(IdentityStore.shared.currentIdentity != nil)")
        
        guard role == .oldDevice else {
            logger.error("approveTakeoverRequest failed: role is not oldDevice")
            return
        }
        guard let request = pendingRequest else {
            logger.error("approveTakeoverRequest failed: pendingRequest is nil")
            return
        }
        
        // Get or create identity
        var identity = IdentityStore.shared.currentIdentity
        
        if identity == nil {
            logger.info("No identity found, creating from profile...")
            do {
                let publicKey = try keyManager.getPublicKeyData()
                identity = IdentityStore.shared.createIdentityFromProfile(publicKey)
            } catch {
                logger.error("Failed to get public key: \(error.localizedDescription)")
            }
        }
        
        guard let finalIdentity = identity else {
            logger.error("approveTakeoverRequest failed: could not get or create identity")
            setState(.failed(.networkError("Không thể tạo danh tính")))
            return
        }
        
        approveWithIdentity(request: request, identity: finalIdentity)
    }
    
    private func approveWithIdentity(request: HandoverRequest, identity: UserIdentity) {
        setState(.creatingToken)
        setStatus("Đang tạo mã chuyển tài khoản...")
        setProgress(0.4)
        
        do {
            // Create delegation token
            let oldPublicKey = try keyManager.getPublicKeyData()
            
            logger.info("Creating token with oldPublicKey length: \(oldPublicKey.count) bytes")
            
            var token = DelegationToken(
                userIdentity: identity,
                newDevicePublicKey: request.newDevicePublicKey,
                oldDevicePublicKey: oldPublicKey,
                ttlSeconds: isLowBattery ? 5 * 60 : 10 * 60  // Shorter TTL if low battery
            )
            
            // Debug: Log signing payload
            let signingPayload = try JSONEncoder().encode(token.signingPayload)
            logger.info("Signing payload length: \(signingPayload.count) bytes")
            logger.info("Signing payload hash: \(signingPayload.hashValue)")
            
            // Sign the token
            let signature = try keyManager.signDelegationToken(token)
            token.signatureByOldDevice = signature
            
            logger.info("Token signed, signature length: \(signature.count) bytes")
            
            addAuditLog(.tokenCreated, details: "Token created for \(request.newDeviceName)")
            
            // Send token
            sendDelegationToken(token)
            
        } catch {
            logger.error("Failed to create token: \(error.localizedDescription)")
            setState(.failed(.networkError(error.localizedDescription)))
            addAuditLog(.handoverFailed, details: error.localizedDescription, success: false)
        }
    }
    
    /// Old device: user rejected the takeover request
    func rejectTakeoverRequest() {
        guard role == .oldDevice, let request = pendingRequest else { return }
        
        let response = HandoverResponse(
            requestId: request.requestId,
            status: .rejected,
            errorMessage: "Yêu cầu đã bị từ chối"
        )
        
        do {
            let data = try JSONEncoder().encode(HandoverMessage.response(response))
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            logger.error("Failed to send rejection: \(error.localizedDescription)")
        }
        
        addAuditLog(.handoverFailed, details: "Request rejected by user", success: false)
        stopHandover()
    }
    
    // MARK: - Send Delegation Token
    
    private func sendDelegationToken(_ token: DelegationToken) {
        setState(.transferringToken)
        setStatus("Đang chuyển mã xác nhận...")
        setProgress(0.6)
        
        let response = HandoverResponse(
            requestId: pendingRequest?.requestId ?? "",
            status: .approved,
            delegationToken: token
        )
        
        do {
            let data = try JSONEncoder().encode(HandoverMessage.response(response))
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            
            addAuditLog(.tokenTransferred, details: "Token sent to new device")
            logger.info("Delegation token sent")
            
            // Mark as token sent so we know to proceed even if peer disconnects
            tokenSentSuccessfully = true
            
            // Revoke identity after short delay to ensure data is received
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                // Only revoke if we haven't already (due to disconnect handler)
                if case .transferringToken = self.state {
                    self.revokeIdentity()
                }
            }
            
        } catch {
            logger.error("Failed to send token: \(error.localizedDescription)")
            setState(.failed(.networkError(error.localizedDescription)))
        }
    }
    
    // MARK: - New Device: Handle Response
    
    private func handleTakeoverResponse(_ response: HandoverResponse) {
        guard role == .newDevice else { return }
        
        switch response.status {
        case .approved:
            guard let token = response.delegationToken else {
                setState(.failed(.tokenInvalid))
                return
            }
            verifyAndActivateToken(token)
            
        case .rejected:
            setState(.failed(.userRejected))
            onHandoverFailed?(.userRejected)
            
        case .expired:
            setState(.failed(.tokenExpired))
            onHandoverFailed?(.tokenExpired)
            
        case .alreadyTransferred:
            setState(.failed(.identityAlreadyTransferred))
            onHandoverFailed?(.identityAlreadyTransferred)
            
        case .pending:
            setStatus("Đang chờ xác nhận từ thiết bị cũ...")
        }
    }
    
    // MARK: - Verify and Activate Token
    
    private func verifyAndActivateToken(_ token: DelegationToken) {
        setState(.verifyingToken)
        setStatus("Đang xác minh mã...")
        setProgress(0.7)
        
        do {
            // Check if token already used (replay attack)
            if usedTokenIds.contains(token.tokenId) {
                addAuditLog(.replayAttempt, details: "Token already used", success: false)
                throw HandoverError.replayAttack
            }
            
            // Check expiration
            if !token.isValid {
                addAuditLog(.expiredTokenRejected, details: "Token expired", success: false)
                throw HandoverError.tokenExpired
            }
            
            // Debug: Log token info
            logger.info("Verifying token - tokenId: \(token.tokenId)")
            logger.info("Token oldDevicePublicKey length: \(token.oldDevicePublicKey.count) bytes")
            logger.info("Token signature length: \(token.signatureByOldDevice?.count ?? 0) bytes")
            
            // Verify signature using the old device's public key from the token
            let isValid = try keyManager.verifyDelegationToken(token, oldDevicePublicKey: token.oldDevicePublicKey)
            if !isValid {
                logger.error("Token signature verification failed")
                throw HandoverError.signatureInvalid
            }
            
            logger.info("✅ Token signature verified successfully")
            addAuditLog(.tokenVerified, details: "Token verified successfully")
            
            // Mark token as used
            usedTokenIds.insert(token.tokenId)
            persistUsedTokens()
            
            // Activate identity
            activateIdentity(from: token)
            
        } catch let error as HandoverError {
            setState(.failed(error))
            onHandoverFailed?(error)
        } catch {
            let handoverError = HandoverError.networkError(error.localizedDescription)
            setState(.failed(handoverError))
            onHandoverFailed?(handoverError)
        }
    }
    
    // MARK: - Activate Identity
    
    private func activateIdentity(from token: DelegationToken) {
        setState(.activatingIdentity)
        setStatus("Đang kích hoạt tài khoản...")
        setProgress(0.9)
        
        do {
            // Get our public key
            let ourPublicKey = try keyManager.getPublicKeyData()
            
            // Create new identity with our public key
            let newIdentity = token.userIdentity.withNewPublicKey(ourPublicKey)
            
            // Save identity
            IdentityStore.shared.setIdentity(newIdentity)
            
            // Migrate user profile
            UserProfile.shared.saveUser(
                name: newIdentity.displayName,
                phoneNumber: newIdentity.phoneNumber
            )
            
            addAuditLog(.identityActivated, details: "Identity activated: \(newIdentity.displayName)")
            
            setState(.completed)
            setStatus("Chuyển tài khoản thành công!")
            setProgress(1.0)
            
            onHandoverComplete?(newIdentity)
            
            // Broadcast identity takeover to mesh network
            broadcastIdentityTakeover(newIdentity)
            
            logger.info("Identity activated successfully")
            
        } catch {
            let handoverError = HandoverError.networkError(error.localizedDescription)
            setState(.failed(handoverError))
            onHandoverFailed?(handoverError)
        }
    }
    
    // MARK: - Revoke Identity (Old Device)
    
    private func revokeIdentity() {
        guard role == .oldDevice else { return }
        
        setState(.revokingIdentity)
        setStatus("Đang hủy kích hoạt tài khoản...")
        setProgress(0.8)
        
        do {
            // Revoke key (destroys private key)
            try keyManager.revokeIdentity()
            
            // Mark identity as transferred
            IdentityStore.shared.markAsTransferred()
            
            // Clear identity store
            IdentityStore.shared.clearIdentity()
            
            // Clear user profile - this will trigger return to setup screen
            UserProfile.shared.clearUser()
            
            // Disable Bridgefy
            BridgefyNetworkManager.shared.stop()
            
            addAuditLog(.identityRevoked, details: "Identity revoked after transfer")
            
            setState(.completed)
            setStatus("Tài khoản đã được chuyển!\nVui lòng đăng ký tài khoản mới.")
            setProgress(1.0)
            
            logger.info("Identity revoked on old device - user profile cleared")
            
        } catch {
            // Still clear profile since token was sent
            IdentityStore.shared.clearIdentity()
            UserProfile.shared.clearUser()
            
            setState(.completed)
            setStatus("Tài khoản đã được chuyển.\nVui lòng đăng ký tài khoản mới.")
            logger.error("Failed to fully revoke: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Broadcast Identity Takeover
    
    private func broadcastIdentityTakeover(_ identity: UserIdentity) {
        guard let bridgefyUserId = BridgefyNetworkManager.shared.currentUserId else {
            logger.warning("Cannot broadcast - Bridgefy not active")
            return
        }
        
        do {
            // Sign the takeover announcement
            let payload = "\(identity.id):\(bridgefyUserId.uuidString):\(Int(Date().timeIntervalSince1970))"
            let signature = try keyManager.sign(data: payload.data(using: .utf8)!)
            
            let broadcast = IdentityTakeoverBroadcast(
                userId: identity.id,
                oldPeerId: nil,  // We don't know the old peer ID
                newPeerId: bridgefyUserId.uuidString,
                signatureByNewDevice: signature
            )
            
            // Send via Bridgefy
            BridgefyNetworkManager.shared.broadcastIdentityTakeover(broadcast)
            
            logger.info("Broadcasted identity takeover to mesh")
            
        } catch {
            logger.error("Failed to broadcast takeover: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Emergency QR Mode
    
    /// Old device: Generate QR code for emergency transfer (low battery)
    func generateEmergencyQR() throws -> String {
        guard role == .oldDevice || role == .none,
              keyManager.identityStatus == .active,
              let identity = IdentityStore.shared.currentIdentity else {
            throw HandoverError.noIdentityToTransfer
        }
        
        // For QR, we need the new device's public key
        // In emergency mode, we generate a pre-signed token that any device can claim
        // This is less secure but necessary for emergency
        
        let dummyNewKey = Data(repeating: 0, count: 32)  // Placeholder
        let oldPublicKey = try keyManager.getPublicKeyData()
        
        var token = DelegationToken(
            userIdentity: identity,
            newDevicePublicKey: dummyNewKey,
            oldDevicePublicKey: oldPublicKey,
            ttlSeconds: 5 * 60  // Short TTL for emergency
        )
        
        // Sign token
        let signature = try keyManager.signDelegationToken(token)
        token.signatureByOldDevice = signature
        
        let qrPayload = try EmergencyQRPayload(token: token)
        let qrString = try qrPayload.toQRString()
        
        addAuditLog(.tokenCreated, details: "Emergency QR generated")
        
        // Auto-revoke after generating QR
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.revokeIdentity()
        }
        
        return qrString
    }
    
    /// New device: Process scanned QR code
    func processEmergencyQR(_ qrString: String) throws {
        let payload = try EmergencyQRPayload.fromQRString(qrString)
        
        // Verify checksum
        guard try payload.verifyChecksum() else {
            throw HandoverError.invalidQRCode
        }
        
        let token = payload.token
        
        // Verify and activate
        verifyAndActivateToken(token)
    }
    
    // MARK: - Stop Handover
    
    func stopHandover() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
        
        advertiser = nil
        browser = nil
        
        discoveredPeers.removeAll()
        connectedPeer = nil
        pendingRequest = nil
        tokenSentSuccessfully = false
        
        setState(.idle)
        role = .none
        setProgress(0)
        setStatus("")
        
        logger.info("Handover stopped")
    }
    
    // MARK: - Helpers
    
    private func setState(_ newState: HandoverState) {
        DispatchQueue.main.async {
            self.state = newState
        }
    }
    
    private func setStatus(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessage = message
        }
    }
    
    private func setProgress(_ value: Double) {
        DispatchQueue.main.async {
            self.progress = value
        }
    }
    
    private func addAuditLog(_ eventType: HandoverAuditLog.EventType, details: String, success: Bool = true) {
        let log = HandoverAuditLog(
            eventType: eventType,
            userId: IdentityStore.shared.currentIdentity?.id ?? "unknown",
            details: details,
            sourceDeviceName: role == .oldDevice ? UIDevice.current.name : connectedPeer?.displayName,
            targetDeviceName: role == .newDevice ? UIDevice.current.name : connectedPeer?.displayName,
            success: success
        )
        auditLogs.append(log)
        persistAuditLogs()
    }
    
    func getAuditLogs() -> [HandoverAuditLog] {
        return auditLogs
    }
}

// MARK: - Handover Message Types
private enum HandoverMessage: Codable {
    case request(HandoverRequest)
    case response(HandoverResponse)
}

// MARK: - MCSessionDelegate
extension IdentityHandoverManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.logger.info("Connected to: \(peerID.displayName)")
                self.connectedPeer = peerID
                
                if self.role == .newDevice {
                    // New device sends takeover request after connecting
                    self.sendTakeoverRequest()
                }
                
            case .notConnected:
                self.logger.info("Disconnected from: \(peerID.displayName)")
                if self.connectedPeer == peerID {
                    self.connectedPeer = nil
                    
                    // OLD DEVICE: If we already sent the token, proceed to revoke
                    // Don't mark as failed - the transfer was successful
                    if self.role == .oldDevice && self.tokenSentSuccessfully {
                        self.logger.info("New device disconnected after token sent - proceeding to revoke")
                        // Only revoke if not already revoking or completed
                        if case .transferringToken = self.state {
                            self.revokeIdentity()
                        }
                        return
                    }
                    
                    // NEW DEVICE: If we were receiving, mark as failed
                    if self.role == .newDevice {
                        if case .receivingToken = self.state {
                            self.setState(.failed(.oldDeviceOffline))
                        }
                    }
                }
                
            case .connecting:
                self.logger.info("Connecting to: \(peerID.displayName)")
                
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(HandoverMessage.self, from: data)
            
            DispatchQueue.main.async {
                switch message {
                case .request(let request):
                    self.handleTakeoverRequest(request, from: peerID)
                    
                case .response(let response):
                    self.handleTakeoverResponse(response)
                }
            }
        } catch {
            logger.error("Failed to decode message: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension IdentityHandoverManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        logger.info("Received invitation from: \(peerID.displayName)")
        
        // Auto-accept invitations when advertising
        invitationHandler(true, session)
        
        DispatchQueue.main.async {
            self.setState(.connecting)
            self.setStatus("Đang kết nối với \(peerID.displayName)...")
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.error("Failed to start advertising: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.setState(.failed(.networkError(error.localizedDescription)))
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension IdentityHandoverManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Only show old devices
        guard info?["role"] == "old_device" else { return }
        
        logger.info("Found peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        logger.info("Lost peer: \(peerID.displayName)")
        
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.error("Failed to start browsing: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.setState(.failed(.networkError(error.localizedDescription)))
        }
    }
}

// MARK: - Identity Store
/// Persists the user's identity locally
final class IdentityStore: ObservableObject {
    static let shared = IdentityStore()
    
    @Published private(set) var currentIdentity: UserIdentity?
    @Published private(set) var isTransferred: Bool = false
    
    private let identityKey = "user_identity"
    private let transferredKey = "identity_transferred"
    
    private init() {
        loadIdentity()
    }
    
    func loadIdentity() {
        if let data = UserDefaults.standard.data(forKey: identityKey),
           let identity = try? JSONDecoder().decode(UserIdentity.self, from: data) {
            currentIdentity = identity
        }
        
        isTransferred = UserDefaults.standard.bool(forKey: transferredKey)
    }
    
    func setIdentity(_ identity: UserIdentity) {
        currentIdentity = identity
        isTransferred = false
        
        if let data = try? JSONEncoder().encode(identity) {
            UserDefaults.standard.set(data, forKey: identityKey)
        }
        UserDefaults.standard.set(false, forKey: transferredKey)
    }
    
    func markAsTransferred() {
        isTransferred = true
        UserDefaults.standard.set(true, forKey: transferredKey)
    }
    
    func clearIdentity() {
        currentIdentity = nil
        isTransferred = false
        UserDefaults.standard.removeObject(forKey: identityKey)
        UserDefaults.standard.removeObject(forKey: transferredKey)
    }
    
    /// Create identity from existing user profile
    func createIdentityFromProfile(_ publicKey: Data) -> UserIdentity? {
        guard let user = UserProfile.shared.currentUser else { return nil }
        
        let identity = UserIdentity(
            id: user.id.uuidString,
            displayName: user.name,
            phoneNumber: user.phoneNumber,
            role: .civilian,
            activeMissions: [],
            publicKeyData: publicKey
        )
        
        setIdentity(identity)
        return identity
    }
}
