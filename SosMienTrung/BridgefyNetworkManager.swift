import Foundation
import Combine
import BridgefySDK
import CoreLocation

final class BridgefyNetworkManager: NSObject, ObservableObject, BridgefyDelegate {
    static let shared = BridgefyNetworkManager()

    private var bridgefy: Bridgefy?
    @Published var messages: [Message] = []
    @Published var connectedUsers: Set<UUID> = []
    
    let locationManager = LocationManager()

    func start() {
        guard bridgefy == nil else { return }
        do {
            let bridgefy = try Bridgefy(withApiKey: "5a369f96-13d3-40df-8d41-805bf150cac0", delegate: self, verboseLogging: true)
            self.bridgefy = bridgefy
            bridgefy.start()
            
            // Start location updates
            locationManager.requestPermission()
            locationManager.startUpdating()
        } catch {
            print("❌ Bridgefy init/start failed: \(error.localizedDescription)")
        }
    }

    func sendBroadcastMessage(_ text: String) {
        guard let bridgefy, let sender = bridgefy.currentUserId else {
            print("Bridgefy not started or missing userId")
            return
        }
        
        let messageId = UUID()
        let payload = MessagePayload(text: text, messageId: messageId, timestamp: Date())
        
        do {
            let data = try JSONEncoder().encode(payload)
            _ = try bridgefy.send(data, using: .broadcast(senderId: sender))
            
            // Add to local messages
            let message = Message(id: messageId, text: text, senderId: sender, isFromMe: true)
            DispatchQueue.main.async {
                self.messages.append(message)
            }
        } catch {
            print("Bridgefy send failed: \(error.localizedDescription)")
        }
    }
    
    /// Gửi tin nhắn SOS kèm tọa độ vị trí hiện tại
    func sendSOSWithLocation(_ text: String = "🆘 Cần giúp đỡ gấp!") {
        guard let bridgefy, let sender = bridgefy.currentUserId else {
            print("Bridgefy not started or missing userId")
            return
        }
        
        guard let coords = locationManager.coordinates else {
            print("Location not available")
            // Fallback: gửi tin nhắn không có vị trí
            sendBroadcastMessage(text)
            return
        }
        
        let messageId = UUID()
        let payload = MessagePayload(
            type: .sosLocation,
            text: text,
            messageId: messageId,
            timestamp: Date(),
            latitude: coords.latitude,
            longitude: coords.longitude
        )
        
        do {
            let data = try JSONEncoder().encode(payload)
            _ = try bridgefy.send(data, using: .broadcast(senderId: sender))
            
            // Add to local messages
            let message = Message(
                id: messageId,
                type: .sosLocation,
                text: text,
                senderId: sender,
                isFromMe: true,
                latitude: coords.latitude,
                longitude: coords.longitude
            )
            DispatchQueue.main.async {
                self.messages.append(message)
            }
            
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
        }
    }

    func bridgefyDidDisconnect(from userId: UUID) {
        print("🔌 Disconnected from: \(userId)")
        DispatchQueue.main.async {
            self.connectedUsers.remove(userId)
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
        do {
            let payload = try JSONDecoder().decode(MessagePayload.self, from: data)
            print("📨 Received message \(messageId) via \(transmissionMode): \(payload.text)")
            
            // Extract sender ID from transmission mode
            let senderId: UUID
            switch transmissionMode {
            case .broadcast(let id), .mesh(let id), .p2p(let id):
                senderId = id
            }
            
            let message = Message(
                id: payload.messageId,
                type: payload.type,
                text: payload.text,
                senderId: senderId,
                isFromMe: false,
                latitude: payload.latitude,
                longitude: payload.longitude
            )
            
            DispatchQueue.main.async {
                // Avoid duplicates
                if !self.messages.contains(where: { $0.id == message.id }) {
                    self.messages.append(message)
                    
                    // Log nếu là tin nhắn SOS có vị trí
                    if message.type == .sosLocation, let lat = message.latitude, let long = message.longitude {
                        print("⚠️ SOS Location received: \(lat), \(long)")
                    }
                }
            }
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
}
