//
//  ChatRoomsView.swift
//  SosMienTrung
//
//  ResQ Chat Rooms — Editorial Layout
//

import SwiftUI

struct ChatRoomsView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @State private var searchText = ""
    @State private var selectedChatRoom: ChatRoom?
    @State private var showDirectChat = false
    @FocusState private var isSearchFocused: Bool

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

    var chatRooms: [ChatRoom] {
        var rooms: [ChatRoom] = []

        let generalMessages = bridgefyManager.messages.filter { $0.recipientId == nil }
        let generalUnread = generalMessages.filter { !$0.isFromMe }.count
        let lastGeneralMessage = generalMessages.sorted { $0.timestamp > $1.timestamp }.first
        rooms.append(ChatRoom(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(),
            type: .general,
            name: "Trò chuyện tổng",
            avatar: "bubble.left.fill",
            user: nil,
            unreadCount: generalUnread,
            lastMessage: lastGeneralMessage?.text,
            lastMessageTime: lastGeneralMessage?.timestamp
        ))

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

        directRooms.sort { room1, room2 in
            let time1 = room1.lastMessageTime ?? Date(timeIntervalSince1970: 0)
            let time2 = room2.lastMessageTime ?? Date(timeIntervalSince1970: 0)
            return time1 > time2
        }

        rooms.append(contentsOf: directRooms)
        return rooms
    }

    var filteredRooms: [ChatRoom] {
        if searchText.isEmpty { return chatRooms }
        return chatRooms.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                EyebrowLabel(text: "TIN NHẮN")
                Text("Trò chuyện")
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text)

                HStack(spacing: 6) {
                    Circle()
                        .fill(bridgefyManager.connectedUsersList.isEmpty ? DS.Colors.textTertiary : DS.Colors.success)
                        .frame(width: 8, height: 8)
                    Text("\(bridgefyManager.connectedUsersList.count) người trong mạng")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }

                EditorialDivider(height: DS.Border.thick)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)

            // Search bar
            ResQTextField(
                placeholder: "Tìm kiếm phòng trò chuyện...",
                text: $searchText,
                icon: "magnifyingglass"
            )
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)

            // Chat Rooms List
            if chatRooms.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "bubble.left.slash")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(DS.Colors.textTertiary)
                    Text("Chưa có phòng trò chuyện nào")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.textSecondary)
                    Text("Đợi người khác mở ứng dụng và ở gần bạn")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .frame(maxHeight: .infinity)
            } else if filteredRooms.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(DS.Colors.textTertiary)
                    Text("Không tìm thấy kết quả")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.xs) {
                        ForEach(filteredRooms) { room in
                            ChatRoomRow(room: room) {
                                selectedChatRoom = room
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.xs)
                }
            }
        }
        .background(DS.Colors.background)
        .sheet(item: $selectedChatRoom) { room in
            if room.type == .general {
                ChatView(bridgefyManager: bridgefyManager)
            } else if let user = room.user {
                DirectChatView(bridgefyManager: bridgefyManager, recipient: user)
            }
        }
        .onTapGesture { isSearchFocused = false }
    }
}

struct ChatRoomRow: View {
    let room: ChatRoomsView.ChatRoom
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.sm) {
                // Avatar — sharp square
                ZStack {
                    Rectangle()
                        .fill(room.type == .general ? DS.Colors.info.opacity(0.15) : DS.Colors.accent.opacity(0.15))
                        .frame(width: 44, height: 44)

                    if room.type == .general {
                        Image(systemName: room.avatar)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DS.Colors.info)
                    } else {
                        Text(room.avatar)
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(DS.Colors.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(room.name)
                            .font(DS.Typography.headline)
                            .foregroundColor(DS.Colors.text)
                        Spacer()
                        if let lastTime = room.lastMessageTime {
                            Text(lastTime, style: .time)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textTertiary)
                        }
                    }

                    if let lastMessage = room.lastMessage {
                        Text(lastMessage)
                            .font(DS.Typography.subheadline)
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text("Chưa có tin nhắn")
                            .font(DS.Typography.subheadline)
                            .foregroundColor(DS.Colors.textTertiary)
                            .italic()
                    }
                }

                if room.unreadCount > 0 {
                    ResQBadge(text: "\(room.unreadCount)", color: DS.Colors.danger)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surface)
            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
        }
    }
}

#Preview {
    ChatRoomsView(bridgefyManager: BridgefyNetworkManager.shared)
}
