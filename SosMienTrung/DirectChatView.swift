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
            // Messages sent to this user or received from this user
            (message.recipientId == recipient.id && message.isFromMe) ||
            (message.senderId == recipient.id && !message.isFromMe)
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 40, height: 40)
                        
                        Text(recipient.name.prefix(1).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recipient.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(recipient.isOnline ? .green : .gray)
                                .frame(width: 8, height: 8)
                            
                            Text(recipient.isOnline ? "Online" : "Offline")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.white.opacity(0.05))
                
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if directMessages.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white.opacity(0.3))
                                    
                                    Text("Chưa có tin nhắn")
                                        .foregroundStyle(.white.opacity(0.5))
                                    
                                    Text("Gửi tin nhắn đầu tiên cho \(recipient.name)")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.4))
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
                        .padding()
                    }
                    .onChange(of: directMessages.count) {
                        if let lastMessage = directMessages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input
                HStack(spacing: 12) {
                    TextField("Nhắn tin...", text: $messageText)
                        .focused($isTextFieldFocused)
                        .padding(12)
                        .background(Color.white.opacity(0.15))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageText.isEmpty ? .gray : .blue)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding()
                .background(Color.black)
            }
        }
    }
    
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        bridgefyManager.sendDirectMessage(trimmed, to: recipient)
        messageText = ""
    }
}
