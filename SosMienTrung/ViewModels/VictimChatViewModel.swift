import Foundation
import Combine
import UIKit

@MainActor
final class VictimChatViewModel: ObservableObject {
    private static let skippedConversationIdKey = "chat.skippedConversationId"

    // MARK: - Setup phase data
    @Published var conversationId: Int?
    @Published var topicSuggestions: [TopicSuggestion] = []
    @Published var aiGreetingMessage: String?
    @Published var sosRequests: [SosRequestDto] = []
    @Published var linkedSosRequestId: Int?

    // MARK: - UI state
    @Published var phase: ChatPhase = .loading
    @Published var isLoading = false
    @Published var isUploadingImage = false
    @Published var errorMessage: String?
    @Published var inputText = ""

    // MARK: - SignalR service (observable trong View)
    let chatService = VictimChatService()

    private let api: ConversationAPIService
    private let token: String
    private let preferredConversationId: Int?
    private let cloudinaryUploader = CloudinaryImageUploader.resQ(folder: "resq/chat")
    private var statusCancellable: AnyCancellable?
    private var chatServiceChangesCancellable: AnyCancellable?
    private var historySyncTask: Task<Void, Never>?

    enum ChatPhase {
        case loading
        case selectingTopic       // Bước 2: chọn chủ đề
        case selectingSos         // Bước 3: chọn SOS
        case waitingCoordinator   // Đang chờ
        case chatting             // Đang chat với coordinator
    }

    init(preferredConversationId: Int? = nil) {
        self.token = AuthSessionStore.shared.session?.accessToken ?? ""
        self.api = ConversationAPIService(token: self.token)
        self.preferredConversationId = preferredConversationId

        // Bridge nested ObservableObject updates so SwiftUI redraws immediately.
        self.chatServiceChangesCancellable = chatService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    // MARK: - Bước 1: Mở màn hình

    func initialize(forceNewConversation: Bool = false) async {
        guard !token.isEmpty else {
            errorMessage = "Chưa đăng nhập, vui lòng đăng nhập lại"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            if !forceNewConversation {
                let summaries = try await api.getMyConversations()
                let skippedConversationId = UserDefaults.standard.object(forKey: Self.skippedConversationIdKey) as? Int

                if let preferredConversationId,
                   let preferredConversation = summaries.first(where: { $0.conversationId == preferredConversationId }) {
                    await resumeConversation(from: preferredConversation)
                    return
                }

                // Nếu đã có phòng đang hoạt động thì resume lại để không mất lịch sử sau khi refresh.
                if let latestActive = summaries.first(where: {
                    ($0.status == .waitingCoordinator || $0.status == .coordinatorActive)
                    && $0.conversationId != skippedConversationId
                }) {
                    await resumeConversation(from: latestActive)
                    return
                }
            }

            let conv = try await api.getOrCreateConversation()
            UserDefaults.standard.removeObject(forKey: Self.skippedConversationIdKey)
            conversationId = conv.conversationId
            aiGreetingMessage = conv.aiGreetingMessage
            topicSuggestions = conv.topicSuggestions
            linkedSosRequestId = conv.linkedSosRequestId

            if conv.linkedSosRequestId != nil {
                await loadQuickDispatchSosRequestsIfNeeded()
            }

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
            if topicKey != "SosRequestSupport" {
                appendAiMessage(resp.aiResponseMessage, convId: convId)
            }

            if topicKey == "SosRequestSupport", let list = resp.sosRequests, !list.isEmpty {
                sosRequests = list.sorted { $0.id > $1.id }
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
            linkedSosRequestId = resp.linkedSosRequestId
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

    func sendImage(_ image: UIImage) async {
        guard let convId = conversationId else { return }

        isUploadingImage = true
        defer { isUploadingImage = false }

        do {
            let imageURL = try await cloudinaryUploader.upload(image: image, fileNamePrefix: "chat")
            let markdownImage = "![Anh chat](\(imageURL))"
            sendMessageContent(markdownImage, conversationId: convId)
        } catch {
            errorMessage = "Upload ảnh thất bại: \(error.localizedDescription)"
        }
    }

    func sendSosQuickDispatchCard(_ sos: SosRequestDto) {
        guard let convId = conversationId else { return }

        let session = AuthSessionStore.shared.session
        let sharedByName = session?.fullName ?? session?.username
        let payload = SosQuickDispatchCardPayload.from(sos: sos, sharedByName: sharedByName)
        sendMessageContent(payload.encodedMessageContent(), conversationId: convId)
    }

    func loadQuickDispatchSosRequestsIfNeeded(forceReload: Bool = false) async {
        if forceReload == false, !sosRequests.isEmpty { return }

        guard let records = await APIService.shared.fetchMySOS() else { return }

        var seenIds = Set<Int>()
        let mapped = records
            .map(Self.mapServerSOSRecord)
            .filter { seenIds.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if let leftDate = Self.parseServerDate(lhs.createdAt),
                   let rightDate = Self.parseServerDate(rhs.createdAt) {
                    return leftDate > rightDate
                }
                return lhs.id > rhs.id
            }

        if !mapped.isEmpty {
            sosRequests = mapped
        }
    }

    func cleanup() {
        historySyncTask?.cancel()
        historySyncTask = nil
        statusCancellable = nil

        if let convId = conversationId {
            chatService.disconnect(conversationId: convId)
        }
    }

    func endCurrentConversation() async {
        guard let convId = conversationId else { return }

        historySyncTask?.cancel()
        historySyncTask = nil
        statusCancellable = nil

        chatService.disconnect(conversationId: convId)
        UserDefaults.standard.set(convId, forKey: Self.skippedConversationIdKey)

        chatService.messages = []
        chatService.conversationStatus = .aiAssist
        conversationId = nil
        topicSuggestions = []
        aiGreetingMessage = nil
        sosRequests = []
        linkedSosRequestId = nil
        inputText = ""
        phase = .loading

        await initialize(forceNewConversation: true)
    }

    // MARK: - SignalR connect

    private func connectSignalR() {
        guard let convId = conversationId else { return }
        chatService.connect(token: token, conversationId: convId)
        startHistorySyncLoop()

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

    func loadHistory(showError: Bool = true) async {
        guard let convId = conversationId else { return }
        do {
            let resp = try await api.getMessages(conversationId: convId)
            let historyRaw: [CoordinatorChatMessage] = resp.messages.compactMap { dto in
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

            var seenSystemContents = Set<String>()
            let history = historyRaw.filter { message in
                guard message.messageType == CoordinatorMessageType.systemMessage.rawValue else {
                    return true
                }

                if seenSystemContents.contains(message.content) {
                    return false
                }
                seenSystemContents.insert(message.content)
                return true
            }

            let pendingLocal = chatService.messages.filter { $0.id < 0 }
            let pendingStillNotEchoed = pendingLocal.filter { local in
                !history.contains(where: {
                    $0.senderId == local.senderId && $0.content == local.content
                })
            }
            chatService.messages = history + pendingStillNotEchoed
        } catch {
            if showError {
                errorMessage = "Không thể tải lịch sử: \(error.localizedDescription)"
            }
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

    private func sendMessageContent(_ content: String, conversationId: Int) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let tempId = -Int(Date().timeIntervalSince1970 * 1000) % Int.max
        let session = AuthSessionStore.shared.session
        let localMsg = CoordinatorChatMessage(
            id: tempId,
            conversationId: conversationId,
            senderId: session?.userId,
            senderName: session?.fullName ?? session?.username ?? "Tôi",
            content: trimmed,
            messageType: CoordinatorMessageType.userMessage.rawValue,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        chatService.messages.append(localMsg)
        chatService.sendMessage(conversationId: conversationId, content: trimmed)
    }

    private static func mapServerSOSRecord(_ record: SOSServerRecord) -> SosRequestDto {
        SosRequestDto(
            id: record.id,
            sosType: record.sosType,
            msg: record.rawMessage,
            status: record.status ?? "Pending",
            priorityLevel: record.priorityLevel,
            waitTimeMinutes: record.waitTimeMinutes,
            latitude: record.latitude,
            longitude: record.longitude,
            createdAt: record.createdAt
        )
    }

    private static func parseServerDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }

    private func startHistorySyncLoop() {
        historySyncTask?.cancel()
        historySyncTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                await self.loadHistory(showError: false)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func resumeConversation(from summary: VictimConversationSummary) async {
        conversationId = summary.conversationId
        linkedSosRequestId = summary.linkedSosRequestId

        if summary.linkedSosRequestId != nil {
            await loadQuickDispatchSosRequestsIfNeeded()
        }

        switch summary.status {
        case .aiAssist:
            let conv = try? await api.getOrCreateConversation()
            aiGreetingMessage = conv?.aiGreetingMessage
            topicSuggestions = conv?.topicSuggestions ?? []
            phase = .selectingTopic

        case .waitingCoordinator:
            phase = .waitingCoordinator
            connectSignalR()
            await loadHistory(showError: false)

        case .coordinatorActive:
            phase = .chatting
            chatService.conversationStatus = .coordinatorActive
            connectSignalR()
            await loadHistory(showError: false)

        case .closed:
            phase = .chatting
            await loadHistory(showError: false)
        }
    }
}
