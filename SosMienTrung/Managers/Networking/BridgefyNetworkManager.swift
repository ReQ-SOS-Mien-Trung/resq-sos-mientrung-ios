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
    @Published private(set) var isIdentityDisabled: Bool = false  // True if identity was transferred

    let locationManager = LocationManager()
    private var userProfiles: [UUID: User] = [:]  // Cache user profiles
    
    // Identity mapping: userId (application layer) -> peerId (Bridgefy transport layer)
    private var identityToPeerMapping: [String: UUID] = [:]
    private let identityMappingKey = "bridgefy_identity_mapping"

    private let networkMonitor = NetworkMonitor.shared
    private let sosRelayService = SOSRelayService.shared
    private var processedSOSPacketIds: Set<String> = []  // Avoid reprocessing
    
    /// Get current Bridgefy user ID
    var currentUserId: UUID? {
        bridgefy?.currentUserId
    }

    func start() {
        #if targetEnvironment(simulator)
        print("ℹ️ Bridgefy is not supported on the Simulator. Skipping start().")
        return
        #else
        
        // Check if identity was transferred - don't start if so
        if IdentityStore.shared.isTransferred {
            print("⚠️ Identity was transferred to another device. Bridgefy disabled.")
            isIdentityDisabled = true
            return
        }
        
        guard bridgefy == nil else { 
            print("⚠️ Bridgefy already started, skipping")
            return 
        }
        print("🚀 Starting Bridgefy...")
        do {
            let apiKey = KeyManager.bridgefy
            guard !apiKey.isEmpty else {
                print("❌ Bridgefy API key not found in Keys.plist")
                return
            }
            let bridgefy = try Bridgefy(withApiKey: apiKey, delegate: self, verboseLogging: true)
            self.bridgefy = bridgefy
            bridgefy.start()
            
            // Location will be requested on-demand (SOS / map)
            
            // Load identity mapping
            loadIdentityMapping()
            
            // Broadcast own profile after start
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.broadcastUserProfile()
            }
        } catch {
            print("❌ Bridgefy init/start failed: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Stop Bridgefy (used when identity is transferred)
    func stop() {
        bridgefy?.stop()
        bridgefy = nil
        isIdentityDisabled = true
        print("🛑 Bridgefy stopped")
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
            _ = try bridgefy.send(data, using: .broadcast(senderId: sender))
            
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
            _ = try bridgefy.send(data, using: .p2p(userId: recipient.id))
            
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
    
    /// Gửi tin nhắn SOS kèm tọa độ vị trí hiện tại (legacy - không upload)
    func sendSOSWithLocation(_ text: String = "🆘 Cần giúp đỡ gấp!") {
        guard let bridgefy, let sender = bridgefy.currentUserId else {
            print("Bridgefy not started or missing userId")
            return
        }

        guard let currentUser = UserProfile.shared.currentUser else {
            print("User profile not set")
            return
        }

        locationManager.requestLocation { location in
            guard let location else {
                print("Location not available")
                // Fallback: gửi tin nhắn không có vị trí
                self.sendBroadcastMessage(text)
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
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )

            do {
                let data = try JSONEncoder().encode(payload)
                _ = try bridgefy.send(data, using: .broadcast(senderId: sender))

                let message = Message(
                    id: messageId,
                    type: .sosLocation,
                    text: text,
                    senderId: sender,
                    isFromMe: true,
                    timestamp: timestamp,
                    senderName: currentUser.name,
                    senderPhone: currentUser.phoneNumber,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                self.messages.append(message)
                self.objectWillChange.send()

                print("📤 SOS sent with location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            } catch {
                print("❌ Bridgefy send failed: \(error.localizedDescription)")
            }

            let packet = SOSPacket(
                packetId: messageId.uuidString,
                originId: sender.uuidString,
                timestamp: timestamp,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                message: text,
                hopCount: 0,
                path: []
            )
            MeshRouter.shared.sendOrRelaySOS(packet)
        }
    }

    /// Gửi SOS với khả năng upload lên server (nếu có mạng) hoặc relay qua mesh
    func sendSOSWithUpload(_ text: String) async {
        guard let bridgefy, let sender = bridgefy.currentUserId else {
            print("Bridgefy not started or missing userId")
            return
        }

        guard UserProfile.shared.currentUser != nil else {
            print("User profile not set")
            return
        }

        guard let coords = locationManager.coordinates else {
            print("Location not available")
            await MainActor.run {
                sendBroadcastMessage(text)
            }
            return
        }

        let messageId = UUID()
        let timestamp = Date()

        // Tạo SOSPacket cho server
        let sosPacket = SOSPacket(
            packetId: messageId.uuidString,
            originId: sender.uuidString,
            timestamp: timestamp,
            latitude: coords.latitude,
            longitude: coords.longitude,
            message: text,
            hopCount: 0,
            path: [sender.uuidString]
        )

        // Gửi qua ServerRequestGateway (tự upload hoặc relay)
        ServerRequestGateway.shared.submitSOSBasic(sosPacket)

        // Luôn broadcast qua mesh network (để các device khác có thể relay)
        await MainActor.run {
            broadcastSOSPacket(sosPacket, originalMessage: text, timestamp: timestamp)
        }
    }
    
    /// Gửi SOS với structured data từ Wizard form
    func sendStructuredSOS(_ formData: SOSFormData) async {
        guard let bridgefy, let sender = bridgefy.currentUserId else {
            print("Bridgefy not started or missing userId")
            return
        }

        guard UserProfile.shared.currentUser != nil else {
            print("User profile not set")
            return
        }

        guard let coords = locationManager.coordinates else {
            print("Location not available")
            await MainActor.run {
                sendBroadcastMessage(formData.toSOSMessage())
            }
            return
        }

        let timestamp = Date()
        
        // Tạo Enhanced SOS Packet với structured data
        let enhancedPacket = SOSPacketEnhanced(
            from: formData,
            originId: sender.uuidString,
            latitude: coords.latitude,
            longitude: coords.longitude
        )
        
        // Convert to basic packet for mesh relay compatibility
        let sosPacket = enhancedPacket.toBasicPacket()
        
        // 📦 Lưu SOS vào storage để xem lại và chỉnh sửa
        await MainActor.run {
            SOSStorageManager.shared.saveSOS(
                formData,
                packetId: sosPacket.packetId,
                latitude: coords.latitude,
                longitude: coords.longitude
            )
        }

        // Gửi qua ServerRequestGateway (tự upload hoặc relay)
        ServerRequestGateway.shared.submitSOSEnhanced(enhancedPacket)

        // Broadcast qua mesh network (dùng basic packet để compatibility)
        await MainActor.run {
            broadcastSOSPacket(sosPacket, originalMessage: formData.toSOSMessage(), timestamp: timestamp)
        }
    }
    
    /// Upload enhanced SOS packet to server
    private func uploadEnhancedSOS(_ packet: SOSPacketEnhanced) async -> Bool {
        guard networkMonitor.isConnected else {
            print("📴 No network - cannot upload enhanced SOS directly")
            return false
        }

        guard let url = URL(string: "https://690cc857a6d92d83e84f5f9e.mockapi.io/api/ResQ/SOS") else {
            print("❌ Invalid server URL")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(packet)

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 Uploading Enhanced SOS to server:")
                print(jsonString)
            }

            request.httpBody = jsonData

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("✅ Enhanced SOS uploaded successfully to server")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📥 Server response: \(responseString)")
                    }
                    return true
                } else {
                    print("❌ Server returned status: \(httpResponse.statusCode)")
                    return false
                }
            }
        } catch {
            print("❌ Failed to upload enhanced SOS: \(error.localizedDescription)")
        }

        return false
    }

    /// Broadcast SOS packet qua mesh network
    private func broadcastSOSPacket(_ sosPacket: SOSPacket, originalMessage: String, timestamp: Date) {
        guard let bridgefy, let sender = bridgefy.currentUserId else { return }
        guard let currentUser = UserProfile.shared.currentUser else { return }

        let messageId = UUID(uuidString: sosPacket.packetId) ?? UUID()

        // Tạo MeshPayload chứa SOSPacket
        let meshPayload = MeshPayload(sosPacket: sosPacket)

        do {
            let data = try JSONEncoder().encode(meshPayload)
            _ = try bridgefy.send(data, using: .broadcast(senderId: sender))

            // Add to local messages
            let locParts = sosPacket.loc.split(separator: ",")
            let lat = Double(locParts.first ?? "0") ?? 0
            let long = Double(locParts.last ?? "0") ?? 0

            let message = Message(
                id: messageId,
                type: .sosLocation,
                text: originalMessage,
                senderId: sender,
                isFromMe: true,
                timestamp: timestamp,
                senderName: currentUser.name,
                senderPhone: currentUser.phoneNumber,
                latitude: lat,
                longitude: long
            )
            self.messages.append(message)

            print("📤 SOS broadcast via mesh: \(sosPacket.packetId)")
            print("📤 SOS sent with location: \(lat), \(long)")
        } catch {
            print("❌ Failed to broadcast SOS: \(error.localizedDescription)")
        }
    }

    /// Xử lý SOS packet nhận được từ mesh - relay lên server nếu có mạng
    private func handleReceivedSOSPacket(_ sosPacket: SOSPacket) {
        guard bridgefy?.currentUserId != nil else { return }

        // Tránh xử lý trùng lặp
        guard !processedSOSPacketIds.contains(sosPacket.packetId) else {
            print("⏭️ Already processed SOS packet: \(sosPacket.packetId)")
            return
        }
        processedSOSPacketIds.insert(sosPacket.packetId)

        print("📨 Received SOS packet: \(sosPacket.packetId) from \(sosPacket.originId)")
        print("   Hop count: \(sosPacket.hopCount), Path: \(sosPacket.path)")

        // Relay/upload qua ServerRequestGateway
        ServerRequestGateway.shared.handleIncomingRequest(ServerRequestEnvelope.basicSOS(sosPacket), transport: .bridgefyMesh)
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
        ServerRequestGateway.shared.triggerRetry(reason: .peerUpdate)
    }

    func bridgefyDidDisconnect(from userId: UUID) {
        print("🔌 Disconnected from: \(userId)")
        DispatchQueue.main.async {
            self.connectedUsers.remove(userId)
            self.userProfiles.removeValue(forKey: userId)
            self.updateConnectedUsersList()
            print("📊 Total connected users: \(self.connectedUsers.count)")
        }
        ServerRequestGateway.shared.triggerRetry(reason: .peerUpdate)
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
        // Try identity takeover broadcast first
        if let payload = try? JSONDecoder().decode(IdentityTakeoverPayload.self, from: data) {
            handleIdentityTakeoverBroadcast(payload.broadcast)
            return
        }
        
        if let envelope = try? JSONDecoder().decode(MeshEnvelope.self, from: data) {
            handleMeshEnvelope(envelope)
            return
        }

        if let meshPayload = try? JSONDecoder().decode(MeshPayload.self, from: data) {
            handleMeshPayload(meshPayload, messageId: messageId, transmissionMode: transmissionMode)
            return
        }

        do {
            let payload = try JSONDecoder().decode(MessagePayload.self, from: data)
            handleLegacyPayload(payload, messageId: messageId, transmissionMode: transmissionMode)
        } catch {
            print("Failed to decode message: \(error)")
        }
    }

    private func handleMeshPayload(_ meshPayload: MeshPayload, messageId: UUID, transmissionMode: TransmissionMode) {
        switch meshPayload.meshType {
        case .sosRelay:
            // Nhận SOS packet cần relay
            if let sosPacket = meshPayload.sosPacket {
                print("📨 Received SOS relay packet via \(transmissionMode)")
                handleReceivedSOSPacket(sosPacket)

                // Cũng hiển thị như message trong chat
                displaySOSPacketAsMessage(sosPacket)
            }

        case .serverRequest:
            if let request = meshPayload.serverRequest {
                ServerRequestGateway.shared.handleIncomingRequest(request, transport: .bridgefyMesh)
            }

        case .serverAck:
            if let ack = meshPayload.serverAck {
                ServerRequestGateway.shared.handleIncomingAck(ack, transport: .bridgefyMesh)
            }

        case .chat, .sosLocation, .userInfo:
            // Các loại message thường - dùng chatPayload
            if let payload = meshPayload.chatPayload {
                handleLegacyPayload(payload, messageId: messageId, transmissionMode: transmissionMode)
            }
        }
    }

    private func displaySOSPacketAsMessage(_ sosPacket: SOSPacket) {
        let locParts = sosPacket.loc.split(separator: ",")
        let lat = Double(locParts.first ?? "0") ?? 0
        let long = Double(locParts.last ?? "0") ?? 0

        let packetMessageId = UUID(uuidString: sosPacket.packetId) ?? UUID()
        let originId = UUID(uuidString: sosPacket.originId) ?? UUID()

        let message = Message(
            id: packetMessageId,
            type: .sosLocation,
            text: sosPacket.msg,
            senderId: originId,
            isFromMe: false,
            timestamp: Date(timeIntervalSince1970: TimeInterval(sosPacket.ts)),
            senderName: "SOS từ \(sosPacket.originId.prefix(8))...",
            senderPhone: "",
            latitude: lat,
            longitude: long
        )

        DispatchQueue.main.async {
            if !self.messages.contains(where: { $0.id == message.id }) {
                self.messages.append(message)
                self.objectWillChange.send()
                print("⚠️ SOS Location received: \(lat), \(long)")
            }
        }
    }

    private func handleLegacyPayload(_ payload: MessagePayload, messageId: UUID, transmissionMode: TransmissionMode) {
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
                _ = try bridgefy.send(data, using: .p2p(userId: peerUUID))
                print("[Mesh] Sent mesh packet to \(peerId).")
            } else {
                _ = try bridgefy.send(data, using: .broadcast(senderId: sender))
                print("[Mesh] Broadcast mesh packet.")
            }
        } catch {
            print("[Mesh] Failed to send mesh packet: \(error.localizedDescription)")
        }
    }

    func sendServerRequest(_ request: ServerRequestEnvelope) {
        guard let bridgefy, let sender = bridgefy.currentUserId else {
            print("[ServerRequest] Bridgefy not started or missing userId.")
            return
        }

        let payload = MeshPayload(serverRequest: request)
        do {
            let data = try JSONEncoder().encode(payload)
            _ = try bridgefy.send(data, using: .broadcast(senderId: sender))
            print("[ServerRequest] Broadcast request: \(request.requestId)")
        } catch {
            print("[ServerRequest] Failed to send request: \(error.localizedDescription)")
        }
    }

    func sendServerAck(_ ack: ServerRequestAck) {
        guard let bridgefy, let sender = bridgefy.currentUserId else {
            print("[ServerRequest] Bridgefy not started or missing userId.")
            return
        }

        let payload = MeshPayload(serverAck: ack)
        do {
            let data = try JSONEncoder().encode(payload)
            _ = try bridgefy.send(data, using: .broadcast(senderId: sender))
            print("[ServerRequest] Broadcast ack: \(ack.requestId)")
        } catch {
            print("[ServerRequest] Failed to send ack: \(error.localizedDescription)")
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
            timestamp: Date(timeIntervalSince1970: TimeInterval(packet.ts)),
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
    
    // MARK: - Identity Mapping
    
    /// Load persisted identity-to-peer mapping
    private func loadIdentityMapping() {
        if let data = UserDefaults.standard.data(forKey: identityMappingKey),
           let mapping = try? JSONDecoder().decode([String: String].self, from: data) {
            identityToPeerMapping = mapping.compactMapValues { UUID(uuidString: $0) }
            print("📋 Loaded \(identityToPeerMapping.count) identity mappings")
        }
    }
    
    /// Persist identity-to-peer mapping
    private func saveIdentityMapping() {
        let stringMapping = identityToPeerMapping.mapValues { $0.uuidString }
        if let data = try? JSONEncoder().encode(stringMapping) {
            UserDefaults.standard.set(data, forKey: identityMappingKey)
        }
    }
    
    /// Update mapping when identity is taken over
    func updateIdentityMapping(userId: String, newPeerId: UUID) {
        identityToPeerMapping[userId] = newPeerId
        saveIdentityMapping()
        print("🔄 Updated identity mapping: \(userId) → \(newPeerId)")
    }
    
    /// Get peer ID for a user identity
    func getPeerIdForIdentity(_ userId: String) -> UUID? {
        return identityToPeerMapping[userId]
    }
    
    // MARK: - Identity Takeover Broadcast
    
    /// Broadcast identity takeover announcement to mesh network
    func broadcastIdentityTakeover(_ broadcast: IdentityTakeoverBroadcast) {
        guard let bridgefy, let sender = bridgefy.currentUserId else {
            print("⚠️ Cannot broadcast identity takeover - Bridgefy not active")
            return
        }
        
        let payload = IdentityTakeoverPayload(broadcast: broadcast)
        
        do {
            let data = try JSONEncoder().encode(payload)
            _ = try bridgefy.send(data, using: .broadcast(senderId: sender))
            print("📢 Broadcasted identity takeover: \(broadcast.userId) → \(broadcast.newPeerId)")
            
            // Update local mapping
            if let newPeerUUID = UUID(uuidString: broadcast.newPeerId) {
                updateIdentityMapping(userId: broadcast.userId, newPeerId: newPeerUUID)
            }
        } catch {
            print("❌ Failed to broadcast identity takeover: \(error.localizedDescription)")
        }
    }
    
    /// Handle received identity takeover broadcast
    private func handleIdentityTakeoverBroadcast(_ broadcast: IdentityTakeoverBroadcast) {
        print("📨 Received identity takeover: \(broadcast.userId) → \(broadcast.newPeerId)")
        
        // Verify signature (optional - requires knowing the user's public key)
        // For now, we trust the broadcast and update mapping
        
        if let newPeerUUID = UUID(uuidString: broadcast.newPeerId) {
            // Update mapping
            updateIdentityMapping(userId: broadcast.userId, newPeerId: newPeerUUID)
            
            // If we had cached profile for old peer, update it
            if let oldPeerId = broadcast.oldPeerId,
               let oldPeerUUID = UUID(uuidString: oldPeerId),
               let profile = userProfiles[oldPeerUUID] {
                // Move profile to new peer ID
                userProfiles[newPeerUUID] = profile
                userProfiles.removeValue(forKey: oldPeerUUID)
                updateConnectedUsersList()
                print("👤 Migrated profile for \(profile.name) to new peer ID")
            }
        }
    }
}

// MARK: - Identity Takeover Payload
struct IdentityTakeoverPayload: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case broadcast
    }
    
    let broadcast: IdentityTakeoverBroadcast
    
    init(broadcast: IdentityTakeoverBroadcast) {
        self.broadcast = broadcast
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.broadcast = try container.decode(IdentityTakeoverBroadcast.self, forKey: .broadcast)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("identity_takeover", forKey: .type)
        try container.encode(broadcast, forKey: .broadcast)
    }
}

// MARK: - Extended Data Handling
extension BridgefyNetworkManager {
    /// Extended data receiver that handles identity takeover broadcasts
    func handleExtendedData(_ data: Data, messageId: UUID, transmissionMode: TransmissionMode) {
        // Try to decode as identity takeover
        if let payload = try? JSONDecoder().decode(IdentityTakeoverPayload.self, from: data) {
            handleIdentityTakeoverBroadcast(payload.broadcast)
            return
        }
    }
}
