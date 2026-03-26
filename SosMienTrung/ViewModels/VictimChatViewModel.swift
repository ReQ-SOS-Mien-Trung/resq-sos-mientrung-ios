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
    private let cloudinaryUploader = CloudinaryUploader(
        cloudName: "dezgwdrfs",
        uploadPreset: "ResQ_SOS",
        folder: "resq/chat"
    )
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

    init() {
        self.token = AuthSessionStore.shared.session?.accessToken ?? ""
        self.api = ConversationAPIService(token: self.token)

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

    func sendImage(_ image: UIImage) async {
        guard let convId = conversationId else { return }

        isUploadingImage = true
        defer { isUploadingImage = false }

        do {
            let imageURL = try await cloudinaryUploader.upload(image: image)
            let markdownImage = "![Anh chat](\(imageURL))"
            sendMessageContent(markdownImage, conversationId: convId)
        } catch {
            errorMessage = "Upload ảnh thất bại: \(error.localizedDescription)"
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

private struct CloudinaryUploadResponse: Decodable {
    let secure_url: String
}

private enum CloudinaryUploaderError: LocalizedError {
    case invalidImageData
    case invalidResponse
    case uploadFailed(statusCode: Int, message: String?)
    case missingURL

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Không thể xử lý dữ liệu ảnh"
        case .invalidResponse:
            return "Phản hồi upload không hợp lệ"
        case .uploadFailed(let statusCode, let message):
            return message ?? "Upload ảnh lỗi (HTTP \(statusCode))"
        case .missingURL:
            return "Cloudinary không trả về URL ảnh"
        }
    }
}

private final class CloudinaryUploader {
    private let cloudName: String
    private let uploadPreset: String
    private let folder: String
    private let session: URLSession

    init(cloudName: String, uploadPreset: String, folder: String, session: URLSession = .shared) {
        self.cloudName = cloudName
        self.uploadPreset = uploadPreset
        self.folder = folder
        self.session = session
    }

    func upload(image: UIImage) async throws -> String {
        guard let imageData = normalizedJPEGData(from: image) else {
            throw CloudinaryUploaderError.invalidImageData
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload") else {
            throw CloudinaryUploaderError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        request.httpBody = makeBody(
            boundary: boundary,
            uploadPreset: uploadPreset,
            folder: folder,
            fileData: imageData,
            fileName: "chat_\(Int(Date().timeIntervalSince1970)).jpg"
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudinaryUploaderError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw CloudinaryUploaderError.uploadFailed(statusCode: http.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(CloudinaryUploadResponse.self, from: data)
        guard !decoded.secure_url.isEmpty else {
            throw CloudinaryUploaderError.missingURL
        }
        return decoded.secure_url
    }

    private func normalizedJPEGData(from image: UIImage) -> Data? {
        let maxDimension: CGFloat = 2048
        let largest = max(image.size.width, image.size.height)

        guard largest > maxDimension else {
            return image.jpegData(compressionQuality: 0.82)
        }

        let scale = maxDimension / largest
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }

    private func makeBody(boundary: String, uploadPreset: String, folder: String, fileData: Data, fileName: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        func append(_ string: String) {
            if let data = string.data(using: .utf8) {
                body.append(data)
            }
        }

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"upload_preset\"\(lineBreak)\(lineBreak)")
        append("\(uploadPreset)\(lineBreak)")

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"folder\"\(lineBreak)\(lineBreak)")
        append("\(folder)\(lineBreak)")

        append("--\(boundary)\(lineBreak)")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(lineBreak)")
        append("Content-Type: image/jpeg\(lineBreak)\(lineBreak)")
        body.append(fileData)
        append(lineBreak)

        append("--\(boundary)--\(lineBreak)")
        return body
    }
}
