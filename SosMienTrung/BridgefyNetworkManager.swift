import Foundation
import Combine
import BridgefySDK
import CoreLocation

final class BridgefyNetworkManager: NSObject, ObservableObject, BridgefyDelegate {
    static let shared = BridgefyNetworkManager()

    private var bridgefy: Bridgefy?
    @Published var messages: [Message] = []
    @Published var connectedUsers: Set<UUID> = []
    @Published var connectedUsersList: [User] = []  // List of known users with profiles
    
    let locationManager = LocationManager()
    private var userProfiles: [UUID: User] = [:]  // Cache user profiles

    func start() {
        #if targetEnvironment(simulator)
        print("ℹ️ Bridgefy is not supported on the Simulator. Skipping start().")
        return
        #endif
        
        guard bridgefy == nil else { 
            print("⚠️ Bridgefy already started, skipping")
            return 
        }
        print("🚀 Starting Bridgefy...")
        do {
            let bridgefy = try Bridgefy(withApiKey: "5a369f96-13d3-40df-8d41-805bf150cac0", delegate: self, verboseLogging: true)
            self.bridgefy = bridgefy
            bridgefy.start()
            
            // Start location updates
            locationManager.requestPermission()
            locationManager.startUpdating()
            
            // Broadcast own profile after start
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.broadcastUserProfile()
            }
        } catch {
            print("❌ Bridgefy init/start failed: \(error.localizedDescription)")
        }
    }
    
    // Broadcast own user profile to network
    func broadcastUserProfile() {
        guard let bridgefy, 
              let sender = bridgefy.currentUserId,
              let currentUser = UserProfile.shared.currentUser else {
            return
        }
        
        let messageId = UUID()
        let payload = MessagePayload(
            type: .userInfo,
            text: "User profile update",
            messageId: messageId,
            timestamp: Date(),
            senderId: sender,
            senderName: currentUser.name,
            senderPhone: currentUser.phoneNumber
        )
        
        do {
            let data = try JSONEncoder().encode(payload)
            _ = try bridgefy.send(data, using: .broadcast(senderId: sender))
            print("📤 Broadcasted user profile: \(currentUser.name)")
        } catch {
            print("❌ Failed to broadcast profile: \(error.localizedDescription)")
        }
    }

    func sendBroadcastMessage(_ text: String) {
        guard let bridgefy, let sender = bridgefy.currentUserId else {
            print("Bridgefy not started or missing userId")
            return
        }
        
        guard let currentUser = UserProfile.shared.currentUser else {
            print("User profile not set")
            return
        }
        
        let messageId = UUID()
        let timestamp = Date()
        let payload = MessagePayload(
            text: text, 
            messageId: messageId, 
            timestamp: timestamp,
            senderId: sender,
            senderName: currentUser.name,
            senderPhone: currentUser.phoneNumber
        )
        
        do {
            let data = try JSONEncoder().encode(payload)
            try bridgefy.send(data, using: .broadcast(senderId: sender))
            
            // Add to local messages immediately
            let message = Message(
                id: messageId, 
                text: text, 
                senderId: sender, 
                isFromMe: true,
                timestamp: timestamp,
                senderName: currentUser.name,
                senderPhone: currentUser.phoneNumber
            )
            self.messages.append(message)
            self.objectWillChange.send()
            print("📤 Broadcast message sent: \(text)")
        } catch {
            print("❌ Bridgefy send failed: \(error.localizedDescription)")
        }
    }
    
    // Send direct message to specific user
    func sendDirectMessage(_ text: String, to recipient: User) {
        guard let bridgefy, let sender = bridgefy.currentUserId else {
            print("Bridgefy not started or missing userId")
            return
        }
        
        guard let currentUser = UserProfile.shared.currentUser else {
            print("User profile not set")
            return
        }
        
        let messageId = UUID()
        let timestamp = Date()
        let payload = MessagePayload(
            text: text,
            messageId: messageId,
            timestamp: timestamp,
            senderId: sender,
            senderName: currentUser.name,
            senderPhone: currentUser.phoneNumber,
            recipientId: recipient.id
        )
        
        do {
            let data = try JSONEncoder().encode(payload)
            // Use P2P for direct messages
            try bridgefy.send(data, using: .p2p(userId: recipient.id))
            
            // Add to local messages immediately
            let message = Message(
                id: messageId,
                text: text,
                senderId: sender,
                isFromMe: true,
                timestamp: timestamp,
                senderName: currentUser.name,
                senderPhone: currentUser.phoneNumber,
                recipientId: recipient.id
            )
            self.messages.append(message)
            self.objectWillChange.send()
            print("📤 Direct message sent to \(recipient.name): \(text)")
        } catch {
            print("❌ Failed to send direct message: \(error.localizedDescription)")
        }
    }
    
    /// Gửi tin nhắn SOS kèm tọa độ vị trí hiện tại
    func sendSOSWithLocation(_ text: String = "🆘 Cần giúp đỡ gấp!") {
        guard let bridgefy, let sender = bridgefy.currentUserId else {
            print("Bridgefy not started or missing userId")
            return
        }
        
        guard let currentUser = UserProfile.shared.currentUser else {
            print("User profile not set")
            return
        }
        
        let messageId = UUID()
        let timestamp = Date()
        let coords = locationManager.coordinates
        let message = Message(
            id: messageId,
            type: .sosLocation,
            text: text,
            senderId: sender,
            isFromMe: true,
            timestamp: timestamp,
            senderName: currentUser.name,
            senderPhone: currentUser.phoneNumber,
            latitude: coords?.latitude,
            longitude: coords?.longitude
        )
        self.messages.append(message)
        self.objectWillChange.send()

        let locString: String
        if let coords = coords {
            locString = "\(coords.latitude),\(coords.longitude)"
            print("📤 SOS prepared with location: \(coords.latitude), \(coords.longitude)")
        } else {
            locString = ""
            print("📤 SOS prepared without location")
        }

        let packet = SOSPacket(
            packetId: messageId.uuidString,
            originId: sender.uuidString,
            msg: text,
            loc: locString,
            hopCount: 0,
            path: [],
            timestamp: timestamp.timeIntervalSince1970
        )
        MeshRouter.shared.sendOrRelaySOS(packet)
    }

    // MARK: - BridgefyDelegate

    func bridgefyDidStart(with userId: UUID) {
        print("✅ Bridgefy STARTED with userId: \(userId)")
        MeshManager.shared.updateMyDeviceId(userId.uuidString)
        MeshManager.shared.start()
    }

    func bridgefyDidFailToStart(with error: BridgefyError) {
        print("❌ Bridgefy FAILED TO START: \(error)")
    }

    func bridgefyDidStop() {
        print("⚠️ Bridgefy did stop")
    }

    func bridgefyDidFailToStop(with error: BridgefyError) {
        print("❌ Bridgefy failed to stop: \(error)")
    }

    func bridgefyDidDestroySession() {
        print("💥 Bridgefy destroyed session")
    }

    func bridgefyDidFailToDestroySession(with error: BridgefyError) {
        print("❌ Bridgefy failed to destroy session: \(error)")
    }

    func bridgefyDidConnect(with userId: UUID) {
        print("🔗 Connected with: \(userId)")
        DispatchQueue.main.async {
            self.connectedUsers.insert(userId)
            print("📊 Total connected users: \(self.connectedUsers.count)")
            
            // Broadcast profile when new connection established
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.broadcastUserProfile()
            }
        }
    }

    func bridgefyDidDisconnect(from userId: UUID) {
        print("🔌 Disconnected from: \(userId)")
        DispatchQueue.main.async {
            self.connectedUsers.remove(userId)
            self.userProfiles.removeValue(forKey: userId)
            self.updateConnectedUsersList()
            print("📊 Total connected users: \(self.connectedUsers.count)")
        }
    }

    func bridgefyDidEstablishSecureConnection(with userId: UUID) {
        print("🔒 Secure connection established with: \(userId)")
    }

    func bridgefyDidFailToEstablishSecureConnection(with userId: UUID, error: BridgefyError) {
        print("❌ Failed to establish secure connection with \(userId): \(error)")
    }

    func bridgefyDidSendMessage(with messageId: UUID) {
        print("✅ Message sent successfully: \(messageId)")
    }

    func bridgefyDidFailSendingMessage(with messageId: UUID, withError error: BridgefyError) {
        print("❌ Failed to send message \(messageId): \(error)")
    }

    func bridgefyDidReceiveData(_ data: Data, with messageId: UUID, using transmissionMode: TransmissionMode) {
        if let envelope = try? JSONDecoder().decode(MeshEnvelope.self, from: data) {
            handleMeshEnvelope(envelope)
            return
        }

        do {
            let payload = try JSONDecoder().decode(MessagePayload.self, from: data)
            print("📨 Received message \(messageId) via \(transmissionMode): \(payload.text)")

            // Extract real sender from payload (not the relay)
            let senderId = payload.senderId

            // Handle user info messages
            if payload.type == .userInfo {
                let user = User(
                    id: senderId,
                    name: payload.senderName,
                    phoneNumber: payload.senderPhone,
                    isOnline: true
                )
                DispatchQueue.main.async {
                    self.userProfiles[senderId] = user
                    self.updateConnectedUsersList()
                    print("👤 Received user profile: \(user.name)")
                }
                return
            }

            // Check if this is a direct message for us
            let currentUserId = bridgefy?.currentUserId
            if let recipientId = payload.recipientId, recipientId != currentUserId {
                print("📪 Message not for us, ignoring")
                return
            }

            let message = Message(
                id: payload.messageId,
                type: payload.type,
                text: payload.text,
                senderId: senderId,
                isFromMe: false,
                timestamp: payload.timestamp,
                senderName: payload.senderName,
                senderPhone: payload.senderPhone,
                channelId: payload.channelId,
                recipientId: payload.recipientId,
                latitude: payload.latitude,
                longitude: payload.longitude
            )

            DispatchQueue.main.async {
                // Avoid duplicates
                if !self.messages.contains(where: { $0.id == message.id }) {
                    self.messages.append(message)
                    self.objectWillChange.send()
                    print("📨 Message received from \(payload.senderName): \(message.text)")

                    // Log nếu là tin nhắn SOS có vị trí
                    if message.type == .sosLocation, let lat = message.latitude, let long = message.longitude {
                        print("⚠️ SOS Location received: \(lat), \(long)")
                    }

                    // Update user profile if not cached
                    if self.userProfiles[senderId] == nil {
                        let user = User(
                            id: senderId,
                            name: payload.senderName,
                            phoneNumber: payload.senderPhone,
                            isOnline: true
                        )
                        self.userProfiles[senderId] = user
                        self.updateConnectedUsersList()
                    }
                }
            }
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
    
    private func updateConnectedUsersList() {
        connectedUsersList = Array(userProfiles.values).sorted { $0.name < $1.name }
    }

    func sendMeshData(_ data: Data, to peerId: String?) {
        guard let bridgefy, let sender = bridgefy.currentUserId else {
            print("[Mesh] Bridgefy not started or missing userId.")
            return
        }

        do {
            if let peerId = peerId, let peerUUID = UUID(uuidString: peerId) {
                try bridgefy.send(data, using: .p2p(userId: peerUUID))
                print("[Mesh] Sent mesh packet to \(peerId).")
            } else {
                try bridgefy.send(data, using: .broadcast(senderId: sender))
                print("[Mesh] Broadcast mesh packet.")
            }
        } catch {
            print("[Mesh] Failed to send mesh packet: \(error.localizedDescription)")
        }
    }

    private func handleMeshEnvelope(_ envelope: MeshEnvelope) {
        switch envelope.type {
        case .heartbeat:
            guard let payload = envelope.heartbeat else {
                print("[Mesh] Heartbeat envelope missing payload.")
                return
            }
            MeshRouter.shared.processHeartbeat(payload, rssi: 0)
        case .sos:
            guard let packet = envelope.sos else {
                print("[Mesh] SOS envelope missing packet.")
                return
            }
            MeshRouter.shared.handleSOSPacket(packet)
            addSOSMessageIfNeeded(from: packet)
        }
    }

    private func addSOSMessageIfNeeded(from packet: SOSPacket) {
        guard let message = messageFromSOSPacket(packet) else { return }
        DispatchQueue.main.async {
            if !self.messages.contains(where: { $0.id == message.id }) {
                self.messages.append(message)
                self.objectWillChange.send()
                print("📨 Mesh SOS received from \(message.senderName.isEmpty ? message.senderId.uuidString : message.senderName): \(message.text)")
            }
        }
    }

    private func messageFromSOSPacket(_ packet: SOSPacket) -> Message? {
        let messageId = UUID(uuidString: packet.packetId) ?? UUID()
        let senderId = UUID(uuidString: packet.originId) ?? UUID()
        let coords = parseCoordinates(packet.loc)
        let isFromMe = senderId == bridgefy?.currentUserId
        let profile = userProfiles[senderId]
        return Message(
            id: messageId,
            type: .sosLocation,
            text: packet.msg,
            senderId: senderId,
            isFromMe: isFromMe,
            timestamp: Date(timeIntervalSince1970: packet.timestamp),
            senderName: profile?.name ?? "",
            senderPhone: profile?.phoneNumber ?? "",
            latitude: coords?.latitude,
            longitude: coords?.longitude
        )
    }

    private func parseCoordinates(_ loc: String) -> (latitude: Double, longitude: Double)? {
        let parts = loc.split(separator: ",")
        guard parts.count == 2 else { return nil }
        let latString = parts[0].trimmingCharacters(in: .whitespaces)
        let longString = parts[1].trimmingCharacters(in: .whitespaces)
        guard let lat = Double(latString), let long = Double(longString) else { return nil }
        return (lat, long)
    }
}
