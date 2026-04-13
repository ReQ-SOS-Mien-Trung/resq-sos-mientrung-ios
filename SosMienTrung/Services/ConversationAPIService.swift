import Foundation

enum ConversationAPIError: Error, LocalizedError {
    case invalidURL
    case notAuthenticated
    case httpError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:        return L10n.Common.invalidURL
        case .notAuthenticated:  return L10n.NotificationAPI.notAuthenticated
        case .httpError(let code, let msg): return L10n.ConversationAPI.httpError(String(code), msg)
        case .decodingError:     return L10n.ConversationAPI.decodingError
        }
    }
}

final class ConversationAPIService {
    private let baseURL: String
    private let token: String

    init(token: String) {
        self.token = token
        self.baseURL = AppConfig.baseURLString
    }

    // MARK: - Bước 1: Lấy/tạo conversation
    func getOrCreateConversation() async throws -> ConversationResponse {
        let data = try await request("/operations/conversations/my-conversation")
        return try decode(data)
    }

    // MARK: - Lấy danh sách conversation của victim
    func getMyConversations() async throws -> [VictimConversationSummary] {
        let data = try await request("/operations/conversations/my-conversations")
        return try decode(data)
    }

    // MARK: - Bước 2: Chọn chủ đề
    func selectTopic(conversationId: Int, topicKey: String) async throws -> SelectTopicResponse {
        let body = try JSONEncoder().encode(SelectTopicRequest(topicKey: topicKey))
        let data = try await request(
            "/operations/conversations/\(conversationId)/select-topic",
            method: "POST", body: body
        )
        return try decode(data)
    }

    // MARK: - Bước 3: Gắn SOS request
    func linkSosRequest(conversationId: Int, sosRequestId: Int) async throws -> LinkSosResponse {
        let body = try JSONEncoder().encode(LinkSosRequest(sosRequestId: sosRequestId))
        let data = try await request(
            "/operations/conversations/\(conversationId)/link-sos-request",
            method: "POST", body: body
        )
        return try decode(data)
    }

    // MARK: - Bước 5: Tải lịch sử tin nhắn
    func getMessages(conversationId: Int, page: Int = 1, pageSize: Int = 50) async throws -> MessagesResponse {
        let data = try await request(
            "/operations/conversations/\(conversationId)/messages?page=\(page)&pageSize=\(pageSize)"
        )
        return try decode(data)
    }

    // MARK: - Private helpers

    private func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw ConversationAPIError.invalidURL
        }
        guard AuthSessionStore.shared.hasAuthenticatedSession || token.isEmpty == false else {
            throw ConversationAPIError.notAuthenticated
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, http) = try await AuthenticatedRequestExecutor.shared.perform(
            req,
            using: URLSession.shared,
            accessTokenOverride: AuthSessionStore.shared.hasAuthenticatedSession ? nil : token,
            retryOnUnauthorized: AuthSessionStore.shared.hasAuthenticatedSession
        )
        if !(200..<300).contains(http.statusCode) {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw ConversationAPIError.httpError(http.statusCode, msg)
        }
        return data
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ConversationAPIError.decodingError(error)
        }
    }
}
