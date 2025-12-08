import Foundation

enum MessageType: String, Codable {
    case text
    case sosLocation
    case userInfo  // Share user profile
    case deliveryReceipt  // Message delivery confirmation
}

enum MessageStatus: String, Codable {
    case sending     // Đang gửi
    case sent        // Đã gửi
    case delivered   // Đã nhận
    case read        // Đã xem
    case failed      // Gửi thất bại
    
    var displayText: String {
        switch self {
        case .sending: return "Đang gửi"
        case .sent: return "Đã gửi"
        case .delivered: return "Đã nhận"
        case .read: return "Đã xem"
        case .failed: return "Thất bại"
        }
    }
}

struct Message: Identifiable, Codable {
    let id: UUID
    let type: MessageType
    let text: String
    let senderId: UUID
    let timestamp: Date
    let isFromMe: Bool
    var status: MessageStatus  // Make mutable
    
    // User info
    let senderName: String
    let senderPhone: String
    
    // Channel info
    let channelId: UUID?  // nil = general channel
    let recipientId: UUID?  // For direct messages
    
    // Location data (optional)
    let latitude: Double?
    let longitude: Double?
    
    init(id: UUID = UUID(), 
         type: MessageType = .text, 
         text: String, 
         senderId: UUID, 
         isFromMe: Bool,
         status: MessageStatus = .sending,
         senderName: String = "",
         senderPhone: String = "",
         channelId: UUID? = nil,
         recipientId: UUID? = nil,
         latitude: Double? = nil, 
         longitude: Double? = nil) {
        self.id = id
        self.type = type
        self.text = text
        self.senderId = senderId
        self.timestamp = Date()
        self.isFromMe = isFromMe
        self.status = isFromMe ? status : .delivered
        self.senderName = senderName
        self.senderPhone = senderPhone
        self.channelId = channelId
        self.recipientId = recipientId
        self.latitude = latitude
        self.longitude = longitude
    }
    
    var hasLocation: Bool {
        return latitude != nil && longitude != nil
    }
    
    var isDirectMessage: Bool {
        return recipientId != nil
    }
    
    var statusIcon: String {
        switch status {
        case .sending: return "clock"
        case .sent: return "checkmark"
        case .delivered: return "checkmark.circle"
        case .read: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        }
    }
}

struct MessagePayload: Codable {
    let type: MessageType
    let text: String
    let messageId: UUID
    let timestamp: Date
    let senderId: UUID
    let senderName: String
    let senderPhone: String
    let channelId: UUID?
    let recipientId: UUID?
    let latitude: Double?
    let longitude: Double?
    let status: MessageStatus?
    let originalMessageId: UUID? // For delivery receipts
    
    init(type: MessageType = .text, 
         text: String, 
         messageId: UUID, 
         timestamp: Date,
         senderId: UUID,
         senderName: String,
         senderPhone: String,
         channelId: UUID? = nil,
         recipientId: UUID? = nil,
         latitude: Double? = nil, 
         longitude: Double? = nil,
         status: MessageStatus? = nil,
         originalMessageId: UUID? = nil) {
        self.type = type
        self.text = text
        self.messageId = messageId
        self.timestamp = timestamp
        self.senderId = senderId
        self.senderName = senderName
        self.senderPhone = senderPhone
        self.channelId = channelId
        self.recipientId = recipientId
        self.latitude = latitude
        self.longitude = longitude
        self.status = status
        self.originalMessageId = originalMessageId
    }
}
