import Foundation
import Combine

@MainActor
final class VictimChatViewModel: ObservableObject {

    // MARK: - Setup phase data
    @Published var conversationId: Int?
    @Published var topicSuggestions: [TopicSuggestion] = []
    @Published var aiGreetingMessage: String?
    @Published var sosRequests: [SosRequestDto] = []

    // MARK: - UI state
    @Published var phase: ChatPhase = .loading
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inputText = ""

    // MARK: - SignalR service (observable trong View)
    let chatService = VictimChatService()

    private let api: ConversationAPIService
    private let token: String
    private var statusCancellable: AnyCancellable?

    enum ChatPhase {
        case loading
        case selectingTopic       // Bước 2: chọn chủ đề
        case selectingSos         // Bước 3: chọn SOS
        case waitingCoordinator   // Đang chờ
        case chatting             // Đang chat với coordinator
    }

    init() {
        self.token = AuthSessionStore.shared.session?.accessToken ?? ""
        self.api = ConversationAPIService(token: self.token)
    }

    // MARK: - Bước 1: Mở màn hình

    func initialize() async {
        guard !token.isEmpty else {
            errorMessage = "Chưa đăng nhập, vui lòng đăng nhập lại"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let conv = try await api.getOrCreateConversation()
            conversationId = conv.conversationId
            aiGreetingMessage = conv.aiGreetingMessage
            topicSuggestions = conv.topicSuggestions

            switch conv.status {
            case .aiAssist:
                phase = .selectingTopic
            case .waitingCoordinator:
                phase = .waitingCoordinator
                connectSignalR()
            case .coordinatorActive:
                phase = .chatting
                connectSignalR()
                await loadHistory()
            case .closed:
                phase = .chatting
                await loadHistory()
            }
        } catch {
            errorMessage = "Không thể mở chat: \(error.localizedDescription)"
            phase = .selectingTopic
        }
    }

    // MARK: - Bước 2: Chọn chủ đề

    func selectTopic(_ topicKey: String) async {
        guard let convId = conversationId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await api.selectTopic(conversationId: convId, topicKey: topicKey)
            appendAiMessage(resp.aiResponseMessage, convId: convId)

            if topicKey == "SosRequestSupport", let list = resp.sosRequests, !list.isEmpty {
                sosRequests = list
                phase = .selectingSos
            } else {
                phase = .waitingCoordinator
                connectSignalR()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Bước 3: Gắn SOS

    func linkSosRequest(_ sosRequestId: Int) async {
        guard let convId = conversationId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await api.linkSosRequest(conversationId: convId, sosRequestId: sosRequestId)
            appendAiMessage(resp.aiConfirmationMessage, convId: convId)
            phase = .waitingCoordinator
            connectSignalR()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Gửi tin nhắn

    func sendMessage() {
        guard let convId = conversationId else { return }
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        // Optimistic local insert — dùng ID âm để phân biệt với server ID
        let tempId = -Int(Date().timeIntervalSince1970 * 1000) % Int.max
        let session = AuthSessionStore.shared.session
        let localMsg = CoordinatorChatMessage(
            id: tempId,
            conversationId: convId,
            senderId: session?.userId,
            senderName: session?.fullName ?? session?.username ?? "Tôi",
            content: text,
            messageType: CoordinatorMessageType.userMessage.rawValue,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        chatService.messages.append(localMsg)

        chatService.sendMessage(conversationId: convId, content: text)
        inputText = ""
    }

    // MARK: - SignalR connect

    private func connectSignalR() {
        guard let convId = conversationId else { return }
        chatService.connect(token: token, conversationId: convId)

        // Auto-transition sang chatting khi coordinator join
        statusCancellable = chatService.$conversationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .coordinatorActive {
                    self?.phase = .chatting
                    Task { await self?.loadHistory() }
                }
            }
    }

    // MARK: - Tải lịch sử

    func loadHistory() async {
        guard let convId = conversationId else { return }
        do {
            let resp = try await api.getMessages(conversationId: convId)
            let history: [CoordinatorChatMessage] = resp.messages.compactMap { dto in
                guard let content = dto.content else { return nil }
                return CoordinatorChatMessage(
                    id: dto.id,
                    conversationId: convId,
                    senderId: dto.senderId,
                    senderName: dto.senderName,
                    content: content,
                    messageType: dto.messageType.rawValue,
                    createdAt: dto.createdAt ?? ""
                )
            }
            let existingIds = Set(chatService.messages.map(\.id))
            chatService.messages = history + chatService.messages.filter { !existingIds.contains($0.id) }
        } catch {
            errorMessage = "Không thể tải lịch sử: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private func appendAiMessage(_ content: String, convId: Int) {
        let msg = CoordinatorChatMessage(
            id: Int.random(in: 1...99_999),
            conversationId: convId,
            senderId: nil,
            senderName: "AI Hỗ trợ",
            content: content,
            messageType: CoordinatorMessageType.aiMessage.rawValue,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        chatService.messages.append(msg)
    }
}
