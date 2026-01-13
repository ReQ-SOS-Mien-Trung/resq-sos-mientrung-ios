//
//  ChatRoomsView.swift
//  SosMienTrung
//
//  Gộp Users và Chat, hiển thị các phòng chat với Chat Tổng ở đầu
//

import SwiftUI

struct ChatRoomsView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @ObservedObject var appearanceManager = AppearanceManager.shared
    @State private var searchText = ""
    @State private var selectedChatRoom: ChatRoom?
    @State private var showDirectChat = false
    
    // Chat room model
    struct ChatRoom: Identifiable {
        let id: UUID
        let type: ChatRoomType
        let name: String
        let avatar: String
        let user: User?
        let unreadCount: Int
        let lastMessage: String?
        let lastMessageTime: Date?
    }
    
    enum ChatRoomType {
        case general
        case direct
    }
    
    // Tính toán danh sách chat rooms
    var chatRooms: [ChatRoom] {
        var rooms: [ChatRoom] = []
        
        // Chat tổng luôn ở đầu
        let generalMessages = bridgefyManager.messages.filter { $0.recipientId == nil }
        let generalUnread = generalMessages.filter { !$0.isFromMe }.count
        let lastGeneralMessage = generalMessages.sorted { $0.timestamp > $1.timestamp }.first
        rooms.append(ChatRoom(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(),
            type: .general,
            name: "Chat Tổng",
            avatar: "bubble.left.fill",
            user: nil,
            unreadCount: generalUnread,
            lastMessage: lastGeneralMessage?.text,
            lastMessageTime: lastGeneralMessage?.timestamp
        ))
        
        // Các phòng chat cá nhân từ users, sắp xếp theo tin nhắn mới nhất
        var directRooms: [ChatRoom] = []
        for user in bridgefyManager.connectedUsersList {
            let userMessages = bridgefyManager.messages.filter { message in
                (message.senderId == user.id && !message.isFromMe && message.recipientId == nil) ||
                (message.recipientId == user.id && message.isFromMe) ||
                (message.senderId == user.id && !message.isFromMe && message.recipientId != nil)
            }
            
            let userUnread = userMessages.filter { !$0.isFromMe }.count
            let lastMessage = userMessages.sorted { $0.timestamp > $1.timestamp }.first
            
            directRooms.append(ChatRoom(
                id: user.id,
                type: .direct,
                name: user.name,
                avatar: user.name.prefix(1).uppercased(),
                user: user,
                unreadCount: userUnread,
                lastMessage: lastMessage?.text,
                lastMessageTime: lastMessage?.timestamp
            ))
        }
        
        // Sắp xếp các direct rooms theo thời gian tin nhắn mới nhất
        directRooms.sort { room1, room2 in
            let time1 = room1.lastMessageTime ?? Date(timeIntervalSince1970: 0)
            let time2 = room2.lastMessageTime ?? Date(timeIntervalSince1970: 0)
            return time1 > time2
        }
        
        rooms.append(contentsOf: directRooms)
        return rooms
    }
    
    var filteredRooms: [ChatRoom] {
        if searchText.isEmpty {
            return chatRooms
        }
        return chatRooms.filter { room in
            room.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            TelegramBackground()
            
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tin Nhắn")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(appearanceManager.textColor)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(bridgefyManager.connectedUsersList.isEmpty ? .gray : .green)
                            .frame(width: 10, height: 10)
                        Text("\(bridgefyManager.connectedUsersList.count) người trong mạng")
                            .foregroundStyle(appearanceManager.secondaryTextColor)
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(appearanceManager.tertiaryTextColor)
                    
                    TextField("Tìm kiếm phòng chat...", text: $searchText)
                        .foregroundColor(appearanceManager.textColor)
                }
                .padding(12)
                .background(appearanceManager.textColor.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 12)
                
                // Chat Rooms List
                if chatRooms.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.slash")
                            .font(.system(size: 60))
                            .foregroundColor(appearanceManager.tertiaryTextColor)
                        
                        Text("Chưa có phòng chat nào")
                            .foregroundStyle(appearanceManager.secondaryTextColor)
                            .multilineTextAlignment(.center)
                        
                        Text("Đợi người khác mở app và ở gần bạn")
                            .font(.caption)
                            .foregroundStyle(appearanceManager.tertiaryTextColor)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                } else if filteredRooms.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(appearanceManager.tertiaryTextColor)
                        
                        Text("Không tìm thấy kết quả")
                            .foregroundStyle(appearanceManager.secondaryTextColor)
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredRooms) { room in
                                ChatRoomRow(room: room) {
                                    selectedChatRoom = room
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(item: $selectedChatRoom) { room in
            if room.type == .general {
                ChatView(bridgefyManager: bridgefyManager)
            } else if let user = room.user {
                DirectChatView(
                    bridgefyManager: bridgefyManager,
                    recipient: user
                )
            }
        }
    }
}

struct ChatRoomRow: View {
    let room: ChatRoomsView.ChatRoom
    let onTap: () -> Void
    @ObservedObject var appearanceManager = AppearanceManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    if room.type == .general {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: room.avatar)
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .fill(Color.purple.opacity(0.3))
                            .frame(width: 50, height: 50)
                        
                        Text(room.avatar)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Chat room info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(room.name)
                            .font(.headline)
                            .foregroundColor(appearanceManager.textColor)
                        
                        Spacer()
                        
                        if let lastTime = room.lastMessageTime {
                            Text(lastTime, style: .time)
                                .font(.caption)
                                .foregroundColor(appearanceManager.tertiaryTextColor)
                        }
                    }
                    
                    if let lastMessage = room.lastMessage {
                        Text(lastMessage)
                            .font(.subheadline)
                            .foregroundColor(appearanceManager.secondaryTextColor)
                            .lineLimit(1)
                    } else {
                        Text("Chưa có tin nhắn")
                            .font(.subheadline)
                            .foregroundColor(appearanceManager.tertiaryTextColor)
                            .italic()
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    if room.unreadCount > 0 {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 24, height: 24)
                            
                            Text("\(room.unreadCount)")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(appearanceManager.tertiaryTextColor)
                }
            }
            .padding()
            .background(appearanceManager.textColor.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

#Preview {
    ChatRoomsView(bridgefyManager: BridgefyNetworkManager.shared)
}
