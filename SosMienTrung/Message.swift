import Foundation

enum MessageType: String, Codable {
    case text
    case sosLocation
}

struct Message: Identifiable, Codable {
    let id: UUID
    let type: MessageType
    let text: String
    let senderId: UUID
    let timestamp: Date
    let isFromMe: Bool
    
    // Location data (optional)
    let latitude: Double?
    let longitude: Double?
    
    init(id: UUID = UUID(), type: MessageType = .text, text: String, senderId: UUID, isFromMe: Bool, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id
        self.type = type
        self.text = text
        self.senderId = senderId
        self.timestamp = Date()
        self.isFromMe = isFromMe
        self.latitude = latitude
        self.longitude = longitude
    }
    
    var hasLocation: Bool {
        return latitude != nil && longitude != nil
    }
}

struct MessagePayload: Codable {
    let type: MessageType
    let text: String
    let messageId: UUID
    let timestamp: Date
    let latitude: Double?
    let longitude: Double?
    
    init(type: MessageType = .text, text: String, messageId: UUID, timestamp: Date, latitude: Double? = nil, longitude: Double? = nil) {
        self.type = type
        self.text = text
        self.messageId = messageId
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
    }
}
