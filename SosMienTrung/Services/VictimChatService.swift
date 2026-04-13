import Foundation
import Combine
import SignalRClient

@MainActor
final class VictimChatService: ObservableObject {

    @Published var messages: [CoordinatorChatMessage] = []
    @Published var conversationStatus: ConversationStatus = .aiAssist
    @Published var coordinatorName: String?
    @Published var isConnected = false
    @Published var errorMessage: String?

    private var connection: HubConnection?
    private let baseURL: String
    private var joinRetryCount = 0
    private let maxJoinRetries = 8
    private var hasJoinedConversation = false
    private var isJoiningConversation = false
    private var pendingOutgoingMessages: [(conversationId: Int, content: String)] = []

    init() {
        self.baseURL = AppConfig.baseURLString
    }

    // MARK: - Connect

    func connect(token: String, conversationId: Int) {
        // Nếu đã kết nối thì không tạo mới
        guard connection == nil else { return }

        hasJoinedConversation = false
        isJoiningConversation = false

        guard let url = URL(string: "\(baseURL)/hubs/chat?access_token=\(token)") else {
            errorMessage = L10n.Common.invalidChatHubURL
            return
        }

        connection = HubConnectionBuilder(url: url)
            .withLogging(minLogLevel: .warning)
            .withAutoReconnect()
            .build()

        registerHandlers(conversationId: conversationId)
        connection?.start()
        scheduleJoinRetry(conversationId: conversationId)
    }

    func disconnect(conversationId: Int) {
        connection?.invoke(method: "LeaveConversation", conversationId) { _ in }
        connection?.stop()
        connection = nil
        isConnected = false
        joinRetryCount = 0
        hasJoinedConversation = false
        isJoiningConversation = false
        pendingOutgoingMessages.removeAll()
    }

    // MARK: - Server → Client handlers

    private func registerHandlers(conversationId: Int) {
        guard let conn = connection else { return }

        // Sau khi join thành công
        conn.on(method: "JoinedConversation") { [weak self] in
            Task { @MainActor [weak self] in
                self?.isConnected = true
                self?.joinRetryCount = 0
                self?.isJoiningConversation = false
                self?.hasJoinedConversation = true
                self?.flushPendingMessages()
            }
        }

        // Nhận tin nhắn mới
        conn.on(method: "ReceiveMessage") { [weak self] (msg: CoordinatorChatMessage) in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Xoá optimistic message (ID âm) trùng nội dung + sender
                self.messages.removeAll { $0.id < 0 && $0.senderId == msg.senderId && $0.content == msg.content }

                // Dedup an toàn: ưu tiên theo ID dương, fallback theo payload đầy đủ.
                let isDuplicate = self.messages.contains { existing in
                    if msg.id > 0, existing.id == msg.id {
                        return true
                    }
                    return existing.senderId == msg.senderId
                        && existing.content == msg.content
                        && existing.createdAt == msg.createdAt
                        && existing.messageType == msg.messageType
                }
                guard !isDuplicate else { return }

                self.messages.append(msg)
            }
        }

        // Coordinator tham gia
        conn.on(method: "CoordinatorJoined") { [weak self] (payload: CoordinatorJoinedPayload) in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.conversationStatus = .coordinatorActive
                self.coordinatorName = payload.coordinatorId

                guard !self.messages.contains(where: {
                    $0.messageType == CoordinatorMessageType.systemMessage.rawValue
                    && $0.content == payload.systemMessage
                }) else {
                    return
                }

                let systemMsg = CoordinatorChatMessage(
                    id: Int.random(in: 100_000...999_999),
                    conversationId: payload.conversationId,
                    senderId: nil,
                    senderName: "Hệ thống",
                    content: payload.systemMessage,
                    messageType: CoordinatorMessageType.systemMessage.rawValue,
                    createdAt: ISO8601DateFormatter().string(from: Date())
                )
                self.messages.append(systemMsg)
            }
        }

        // Lỗi từ server
        conn.on(method: "Error") { [weak self] (message: String) in
            Task { @MainActor [weak self] in
                self?.errorMessage = message
            }
        }

        // Khi kết nối xong → join group
        conn.on(method: "Connected") { [weak self] in
            Task { @MainActor [weak self] in
                self?.joinConversation(conversationId: conversationId)
            }
        }

        // Fallback: join sau delay nhỏ nếu Connected không được gọi
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, !self.isConnected else { return }
            self.joinConversation(conversationId: conversationId)
        }
    }

    // MARK: - Client → Server

    func joinConversation(conversationId: Int) {
        guard !hasJoinedConversation, !isJoiningConversation else { return }
        isJoiningConversation = true

        connection?.invoke(method: "JoinConversation", conversationId) { [weak self] error in
            if let error {
                Task { @MainActor [weak self] in
                    self?.errorMessage = L10n.VictimChatService.cannotJoinRoom(error.localizedDescription)
                    self?.isJoiningConversation = false
                }
                return
            }

            Task { @MainActor [weak self] in
                self?.isConnected = true
                self?.joinRetryCount = 0
                self?.isJoiningConversation = false
                self?.hasJoinedConversation = true
                self?.flushPendingMessages()
            }
        }
    }

    func sendMessage(conversationId: Int, content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Queue until connect() creates a hub connection.
        guard connection != nil else {
            pendingOutgoingMessages.append((conversationId: conversationId, content: trimmed))
            return
        }

        guard hasJoinedConversation || isConnected else {
            pendingOutgoingMessages.append((conversationId: conversationId, content: trimmed))
            joinConversation(conversationId: conversationId)
            return
        }

        invokeSendMessage(conversationId: conversationId, content: trimmed)
    }

    private func invokeSendMessage(conversationId: Int, content: String) {
        connection?.invoke(method: "SendMessage", conversationId, content) { [weak self] error in
            if let error {
                Task { @MainActor [weak self] in
                    self?.errorMessage = L10n.VictimChatService.sendFailed(error.localizedDescription)
                }
            }
        }
    }

    private func flushPendingMessages() {
        guard !pendingOutgoingMessages.isEmpty else { return }

        let queued = pendingOutgoingMessages
        pendingOutgoingMessages.removeAll()
        for message in queued {
            invokeSendMessage(conversationId: message.conversationId, content: message.content)
        }
    }

    private func scheduleJoinRetry(conversationId: Int) {
        joinRetryCount = 0
        retryJoinConversation(conversationId: conversationId)
    }

    private func retryJoinConversation(conversationId: Int) {
        guard !isConnected else { return }
        guard joinRetryCount < maxJoinRetries else { return }

        joinRetryCount += 1
        joinConversation(conversationId: conversationId)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.retryJoinConversation(conversationId: conversationId)
        }
    }
}
