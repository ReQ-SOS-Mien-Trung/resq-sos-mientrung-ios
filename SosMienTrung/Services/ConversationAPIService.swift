import Foundation

enum ConversationAPIError: Error, LocalizedError {
    case invalidURL
    case notAuthenticated
    case httpError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:        return "URL không hợp lệ"
        case .notAuthenticated:  return "Chưa đăng nhập"
        case .httpError(let code, let msg): return "Lỗi server \(code): \(msg)"
        case .decodingError:     return "Không đọc được dữ liệu từ server"
        }
    }
}

final class ConversationAPIService {
    private let baseURL: String
    private let token: String

    init(token: String) {
        self.token = token
        self.baseURL = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String
            ?? "https://resq.somee.com"
    }

    // MARK: - Bước 1: Lấy/tạo conversation
    func getOrCreateConversation() async throws -> ConversationResponse {
        let data = try await request("/operations/conversations/my-conversation")
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
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
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
