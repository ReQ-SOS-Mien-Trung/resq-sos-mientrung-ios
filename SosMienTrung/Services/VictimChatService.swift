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

    init() {
        self.baseURL = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String
            ?? "https://resq.somee.com"
    }

    // MARK: - Connect

    func connect(token: String, conversationId: Int) {
        // Nếu đã kết nối thì không tạo mới
        guard connection == nil else { return }

        guard let url = URL(string: "\(baseURL)/hubs/chat?access_token=\(token)") else {
            errorMessage = "URL hub không hợp lệ"
            return
        }

        connection = HubConnectionBuilder(url: url)
            .withLogging(minLogLevel: .warning)
            .withAutoReconnect()
            .build()

        registerHandlers(conversationId: conversationId)
        connection?.start()
    }

    func disconnect(conversationId: Int) {
        connection?.invoke(method: "LeaveConversation", conversationId) { _ in }
        connection?.stop()
        connection = nil
        isConnected = false
    }

    // MARK: - Server → Client handlers

    private func registerHandlers(conversationId: Int) {
        guard let conn = connection else { return }

        // Sau khi join thành công
        conn.on(method: "JoinedConversation") { [weak self] in
            Task { @MainActor [weak self] in
                self?.isConnected = true
            }
        }

        // Nhận tin nhắn mới
        conn.on(method: "ReceiveMessage") { [weak self] (msg: CoordinatorChatMessage) in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Xoá optimistic message (ID âm) trùng nội dung + sender
                self.messages.removeAll { $0.id < 0 && $0.senderId == msg.senderId && $0.content == msg.content }
                // Dedup theo server ID
                guard !self.messages.contains(where: { $0.id == msg.id }) else { return }
                self.messages.append(msg)
            }
        }

        // Coordinator tham gia
        conn.on(method: "CoordinatorJoined") { [weak self] (payload: CoordinatorJoinedPayload) in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.conversationStatus = .coordinatorActive
                self.coordinatorName = payload.coordinatorId
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
        connection?.invoke(method: "JoinConversation", conversationId) { [weak self] error in
            if let error {
                Task { @MainActor [weak self] in
                    self?.errorMessage = "Không thể join phòng chat: \(error.localizedDescription)"
                }
            }
        }
    }

    func sendMessage(conversationId: Int, content: String) {
        connection?.invoke(method: "SendMessage", conversationId, content) { [weak self] error in
            if let error {
                Task { @MainActor [weak self] in
                    self?.errorMessage = "Gửi thất bại: \(error.localizedDescription)"
                }
            }
        }
    }
}
