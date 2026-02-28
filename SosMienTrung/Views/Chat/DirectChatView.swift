//
//  DirectChatView.swift
//  SosMienTrung
//
//  Chat 1-1 với user cụ thể
//

import SwiftUI

struct DirectChatView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    let recipient: User
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.dismiss) var dismiss
    
    var directMessages: [Message] {
        bridgefyManager.messages.filter { message in
            // Only include messages with recipientId (exclude broadcast messages)
            // Messages sent to this user or received from this user
            (message.recipientId == recipient.id && message.isFromMe) ||
            (message.senderId == recipient.id && message.recipientId != nil && !message.isFromMe)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DS.Colors.accent)
                }

                // Sharp square avatar
                ZStack {
                    Rectangle()
                        .fill(DS.Colors.accent.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Text(recipient.name.prefix(1).uppercased())
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(DS.Colors.accent)
                }
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))

                VStack(alignment: .leading, spacing: 2) {
                    Text(recipient.name)
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(recipient.isOnline ? DS.Colors.success : DS.Colors.textTertiary)
                            .frame(width: 6, height: 6)
                        Text(recipient.isOnline ? "Online" : "Offline")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.surface)
            .overlay(Rectangle().frame(height: DS.Border.thin).foregroundColor(DS.Colors.border), alignment: .bottom)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        if directMessages.isEmpty {
                            VStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(DS.Colors.textTertiary)
                                Text("Chưa có tin nhắn")
                                    .font(DS.Typography.headline)
                                    .foregroundColor(DS.Colors.textSecondary)
                                Text("Gửi tin nhắn đầu tiên cho \(recipient.name)")
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.textTertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                        } else {
                            ForEach(directMessages) { message in
                                MessageBubble(message: message)
                                    .environmentObject(bridgefyManager)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(DS.Spacing.md)
                }
                .onChange(of: directMessages.count) {
                    if let lastMessage = directMessages.last {
                        withAnimation { proxy.scrollTo(lastMessage.id, anchor: .bottom) }
                    }
                }
            }

            // Input bar
            HStack(spacing: DS.Spacing.sm) {
                ResQTextField(placeholder: "Nhắn tin...", text: $messageText)
                    .focused($isTextFieldFocused)

                Button { sendMessage() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(messageText.isEmpty ? DS.Colors.textTertiary : .white)
                        .frame(width: 36, height: 36)
                        .background(messageText.isEmpty ? DS.Colors.surface : DS.Colors.accent)
                        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                }
                .disabled(messageText.isEmpty)
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surface)
            .overlay(Rectangle().frame(height: DS.Border.thin).foregroundColor(DS.Colors.border), alignment: .top)
        }
        .background(DS.Colors.background)
        .onTapGesture { isTextFieldFocused = false }
    }
    
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        bridgefyManager.sendDirectMessage(trimmed, to: recipient)
        messageText = ""
    }
}
