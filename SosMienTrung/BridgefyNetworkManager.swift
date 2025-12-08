import Foundation
import Combine
import BridgefySDK
import CoreLocation

final class BridgefyNetworkManager: NSObject, ObservableObject, BridgefyDelegate {
    static let shared = BridgefyNetworkManager()

    private var bridgefy: Bridgefy?
    private var outgoingMessageMap: [UUID: UUID] = [:] // Bridgefy messageId -> app messageId
    @Published var messages: [Message] = []
    @Published var connectedUsers: Set<UUID> = []
    @Published var connectedUsersList: [User] = []  // List of known users with profiles
    
    let locationManager = LocationManager()
    private var userProfiles: [UUID: User] = [:]  // Cache user profiles

    // Mark message as read
    func markMessageAsRead(_ messageId: UUID) {
        DispatchQueue.main.async {
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                // Only mark delivered messages as read
                if self.messages[index].status == .delivered && !self.messages[index].isFromMe {
                    print("📖 Marking message \(messageId) as read")
                    self.messages[index].status = .read
                    self.objectWillChange.send()
                }
            }
        }
    }

    func start() {
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
            let bridgefyMessageId = try bridgefy.send(data, using: .broadcast(senderId: sender))
            outgoingMessageMap[bridgefyMessageId] = messageId
            
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
            print("📤 Broadcast message added locally: \(text) (\(messageId))")
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
            let bridgefyMessageId = try bridgefy.send(data, using: .p2p(userId: recipient.id))
            outgoingMessageMap[bridgefyMessageId] = messageId
            
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
            print("📤 Direct message added locally to \(recipient.name): \(text) (\(messageId))")
        } catch {
            print("❌ Failed to send direct message: \(error.localizedDescription)")
        }
    }
    
    // Send delivery receipt back to sender
    private func sendDeliveryReceipt(for messageId: UUID, to recipientId: UUID) {
        guard let bridgefy, let currentUserId = bridgefy.currentUserId else {
            return
        }
        
        guard let currentUser = UserProfile.shared.currentUser else {
            return
        }
        
        let receiptId = UUID()
        let payload = MessagePayload(
            type: .deliveryReceipt,
            text: "Receipt",
            messageId: receiptId,
            timestamp: Date(),
            senderId: currentUserId,
            senderName: currentUser.name,
            senderPhone: currentUser.phoneNumber,
            originalMessageId: messageId
        )
        
        do {
            let data = try JSONEncoder().encode(payload)
            _ = try bridgefy.send(data, using: .p2p(userId: recipientId))
            print("📬 Sent delivery receipt for message \(messageId)")
        } catch {
            print("❌ Failed to send delivery receipt: \(error.localizedDescription)")
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
        
        guard let coords = locationManager.coordinates else {
            print("Location not available")
            // Fallback: gửi tin nhắn không có vị trí
            sendBroadcastMessage(text)
            return
        }
        
        let messageId = UUID()
        let timestamp = Date()
        let payload = MessagePayload(
            type: .sosLocation,
            text: text,
            messageId: messageId,
            timestamp: timestamp,
            senderId: sender,
            senderName: currentUser.name,
            senderPhone: currentUser.phoneNumber,
            latitude: coords.latitude,
            longitude: coords.longitude
        )
        
        do {
            let data = try JSONEncoder().encode(payload)
            let bridgefyMessageId = try bridgefy.send(data, using: .broadcast(senderId: sender))
            outgoingMessageMap[bridgefyMessageId] = messageId
            
            // Add to local messages
            let message = Message(
                id: messageId,
                type: .sosLocation,
                text: text,
                senderId: sender,
                isFromMe: true,
                timestamp: timestamp,
                senderName: currentUser.name,
                senderPhone: currentUser.phoneNumber,
                latitude: coords.latitude,
                longitude: coords.longitude
            )
            self.messages.append(message)
            
            print("SOS sent with location: \(coords.latitude), \(coords.longitude)")
        } catch {
            print("Bridgefy send failed: \(error.localizedDescription)")
        }
    }

    // MARK: - BridgefyDelegate

    func bridgefyDidStart(with userId: UUID) {
        print("✅ Bridgefy STARTED with userId: \(userId)")
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
        
        // Update message status to .sent
        DispatchQueue.main.async {
            let originalId = self.outgoingMessageMap[messageId] ?? messageId
            self.outgoingMessageMap.removeValue(forKey: messageId)
            
            guard let index = self.messages.firstIndex(where: { $0.id == originalId }) else {
                print("⚠️ Could not find message \(originalId) to update status")
                return
            }
            print("🔄 Updating message status from \(self.messages[index].status) to .sent")
            self.messages[index].status = .sent
            self.objectWillChange.send()
        }
    }

    func bridgefyDidFailSendingMessage(with messageId: UUID, withError error: BridgefyError) {
        print("❌ Failed to send message \(messageId): \(error)")
        
        // Update message status to .failed
        DispatchQueue.main.async {
            let originalId = self.outgoingMessageMap[messageId] ?? messageId
            self.outgoingMessageMap.removeValue(forKey: messageId)
            
            if let index = self.messages.firstIndex(where: { $0.id == originalId }) {
                print("🔄 Updating message status to .failed")
                self.messages[index].status = .failed
                self.objectWillChange.send()
            }
        }
    }

    func bridgefyDidReceiveData(_ data: Data, with messageId: UUID, using transmissionMode: TransmissionMode) {
        do {
            let payload = try JSONDecoder().decode(MessagePayload.self, from: data)
            print("📨 Received message \(messageId) via \(transmissionMode): \(payload.text)")
            
            // Extract real sender from payload (not the relay)
            let senderId = payload.senderId
            
            // Handle delivery receipts
            if payload.type == .deliveryReceipt {
                DispatchQueue.main.async {
                    if let originalId = payload.originalMessageId,
                       let index = self.messages.firstIndex(where: { $0.id == originalId }) {
                        print("🔄 Updating message status from \(self.messages[index].status) to .delivered")
                        self.messages[index].status = .delivered
                        self.objectWillChange.send()
                        print("✅ Message \(originalId) marked as delivered")
                    } else {
                        print("⚠️ Could not find message with originalId to mark as delivered")
                    }
                }
                return
            }
            
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
                    print("📨 Message added from \(payload.senderName): \(message.text) (\(message.id))")
                    
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
                    
                    // Send delivery receipt immediately
                    self.sendDeliveryReceipt(for: payload.messageId, to: senderId)
                }
            }
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
    
    private func updateConnectedUsersList() {
        connectedUsersList = Array(userProfiles.values).sorted { $0.name < $1.name }
    }
}
