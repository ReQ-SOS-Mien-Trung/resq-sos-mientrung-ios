import Foundation

enum NotificationAPIError: Error, LocalizedError {
    case invalidURL
    case notAuthenticated
    case httpError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL thông báo không hợp lệ"
        case .notAuthenticated:
            return "Chưa đăng nhập"
        case .httpError(let code, let message):
            return message.isEmpty ? "Máy chủ trả về lỗi \(code)" : "Máy chủ trả về lỗi \(code): \(message)"
        case .decodingError:
            return "Không thể đọc dữ liệu thông báo từ máy chủ"
        }
    }
}

struct NotificationPageResponse: Decodable {
    let items: [RealtimeNotification]
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let unreadCount: Int
}

private struct FCMTokenRequest: Encodable {
    let token: String
}

final class NotificationAPIService {
    static let shared = NotificationAPIService()

    private let baseURL: String
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.baseURL = AppConfig.baseURLString
        self.session = session
    }

    func fetchNotifications(page: Int = 1, pageSize: Int = 20) async throws -> NotificationPageResponse {
        try await request("/notifications?page=\(page)&pageSize=\(pageSize)")
    }

    func markAsRead(userNotificationId: Int) async throws {
        _ = try await requestData("/notifications/\(userNotificationId)/read", method: "PATCH")
    }

    func markAllAsRead() async throws {
        _ = try await requestData("/notifications/read-all", method: "PATCH")
    }

    func registerFCMToken(_ token: String) async throws {
        let body = try JSONEncoder().encode(FCMTokenRequest(token: token))
        _ = try await requestData("/identity/user/me/fcm-token", method: "POST", body: body)
    }

    func broadcastAlert(_ payload: BroadcastAlertPayload) async throws {
        let body = try Self.encoder().encode(payload)
        _ = try await requestData("/notifications/broadcast", method: "POST", body: body)
    }

    func unregisterFCMToken(_ token: String) async throws {
        let body = try JSONEncoder().encode(FCMTokenRequest(token: token))
        _ = try await requestData("/identity/user/me/fcm-token", method: "DELETE", body: body)
    }

    func logout() async throws {
        _ = try await requestData("/identity/auth/logout", method: "POST")
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        let data = try await requestData(path, method: method, body: body)

        do {
            return try RealtimeNotification.decoder().decode(T.self, from: data)
        } catch {
            throw NotificationAPIError.decodingError(error)
        }
    }

    private func requestData(
        _ path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        guard let token = AuthSessionStore.shared.session?.accessToken, !token.isEmpty else {
            throw NotificationAPIError.notAuthenticated
        }

        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw NotificationAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotificationAPIError.httpError(-1, "Khong nhan duoc phan hoi hop le")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            throw NotificationAPIError.httpError(httpResponse.statusCode, message)
        }

        return data
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        encoder.dateEncodingStrategy = .custom { date, nestedEncoder in
            var container = nestedEncoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }
}
