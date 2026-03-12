import SwiftUI

struct CoordinatorChatRoomView: View {
    @ObservedObject var vm: VictimChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBanner

            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(vm.chatService.messages) { msg in
                            CoordinatorMessageBubble(
                                message: msg,
                                currentUserId: AuthSessionStore.shared.session?.userId
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(DS.Spacing.sm)
                }
                .onChange(of: vm.chatService.messages.count) { _ in
                    if let last = vm.chatService.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Input bar
            inputBar
        }
        .background(DS.Colors.background)
        .navigationTitle("Chat hỗ trợ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status banner

    @ViewBuilder
    private var statusBanner: some View {
        if vm.phase == .waitingCoordinator {
            HStack(spacing: DS.Spacing.xs) {
                ProgressView().scaleEffect(0.7)
                Text("Đang chờ nhân viên hỗ trợ tham gia...")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.warning)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.warning.opacity(0.12))
        } else if vm.chatService.conversationStatus == .coordinatorActive {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DS.Colors.success)
                    .font(.caption)
                Text("Đã kết nối với Coordinator")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.success)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.success.opacity(0.1))
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            ResQTextField(placeholder: "Nhập tin nhắn...", text: $vm.inputText)
                .onSubmit { vm.sendMessage() }

            Button(action: vm.sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(canSend ? .white : DS.Colors.textTertiary)
                    .frame(width: 40, height: 40)
                    .background(canSend ? DS.Colors.accent : DS.Colors.surface)
                    .overlay(
                        Rectangle()
                            .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
                    )
            }
            .disabled(!canSend)
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.background)
        .shadow(color: DS.Colors.border, radius: 1, y: -1)
    }

    private var canSend: Bool {
        !vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Message Bubble

struct CoordinatorMessageBubble: View {
    let message: CoordinatorChatMessage
    let currentUserId: String?

    private var isFromMe: Bool {
        message.messageType == CoordinatorMessageType.userMessage.rawValue
            && message.senderId == currentUserId
    }
    private var isAI: Bool     { message.messageType == CoordinatorMessageType.aiMessage.rawValue }
    private var isSystem: Bool { message.messageType == CoordinatorMessageType.systemMessage.rawValue }

    var body: some View {
        if isSystem {
            // System message: centered pill
            Text(message.content)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.surface)
                .clipShape(Capsule())
                .frame(maxWidth: .infinity)
        } else {
            HStack(alignment: .bottom, spacing: DS.Spacing.xs) {
                if isFromMe { Spacer(minLength: 60) }

                VStack(alignment: isFromMe ? .trailing : .leading, spacing: 2) {
                    if !isFromMe {
                        Text(message.senderName ?? (isAI ? "AI Hỗ trợ" : "Coordinator"))
                            .font(DS.Typography.caption)
                            .foregroundColor(isAI ? DS.Colors.info : DS.Colors.accent)
                    }
                    Text(message.content)
                        .font(DS.Typography.body)
                        .padding(DS.Spacing.sm)
                        .background(bubbleColor)
                        .foregroundColor(isFromMe ? .white : DS.Colors.text)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }

                if !isFromMe { Spacer(minLength: 60) }
            }
        }
    }

    private var bubbleColor: Color {
        if isFromMe { return DS.Colors.accent }
        if isAI     { return DS.Colors.info.opacity(0.15) }
        return DS.Colors.surface
    }
}
