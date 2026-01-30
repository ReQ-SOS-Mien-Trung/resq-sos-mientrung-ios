//
//  Channel.swift
//  SosMienTrung
//
//  Channel model cho chat system
//

import Foundation

enum ChannelType: String, Codable {
    case general = "general"  // Chat tổng (broadcast)
    case direct = "direct"    // Chat 1-1
}

struct Channel: Identifiable, Codable, Hashable {
    let id: UUID
    let type: ChannelType
    let name: String
    var participants: [UUID]  // User IDs
    var lastMessage: String?
    var lastMessageTime: Date?
    var unreadCount: Int
    
    init(id: UUID = UUID(), type: ChannelType, name: String, participants: [UUID] = [], lastMessage: String? = nil, lastMessageTime: Date? = nil, unreadCount: Int = 0) {
        self.id = id
        self.type = type
        self.name = name
        self.participants = participants
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
    }
    
    // General channel (singleton)
    static let general = Channel(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        type: .general,
        name: "Kênh Tổng"
    )
    
    // Create direct channel between 2 users
    static func directChannel(with user: User, currentUserId: UUID) -> Channel {
        Channel(
            type: .direct,
            name: user.name,
            participants: [currentUserId, user.id]
        )
    }
}
