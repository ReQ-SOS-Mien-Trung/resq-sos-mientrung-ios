import Foundation

enum MessageType: String, Codable {
    case text
    case sosLocation
    case userInfo  // Share user profile
}

struct Message: Identifiable, Codable {
    let id: UUID
    let type: MessageType
    let text: String
    let senderId: UUID
    let timestamp: Date
    let isFromMe: Bool
    
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
         timestamp: Date = Date(),
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
        self.timestamp = timestamp
        self.isFromMe = isFromMe
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
         longitude: Double? = nil) {
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
    }
}
