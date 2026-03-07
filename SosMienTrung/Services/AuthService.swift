import Foundation

// MARK: - Auth DTOs
struct RegisterRequest: Codable {
    let phone: String?
    let password: String?
}

struct RegisterResponse: Codable {
    let userId: String
    let phone: String?
    let roleId: Int
    let createdAt: Date
}

/// Error response from server
struct APIErrorResponse: Codable, Sendable {
    let message: String
    
    /// Safe decoding that can be called from any context
    static func decode(from data: Data) -> APIErrorResponse? {
        try? JSONDecoder().decode(APIErrorResponse.self, from: data)
    }
}

struct LoginRequest: Codable {
    let username: String?
    let phone: String?
    let password: String?
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let userId: String
    let username: String?
    let fullName: String?
    let firstName: String?
    let lastName: String?
    let roleId: Int?

    /// Tên hiển thị: ưu tiên fullName → ghép lastName + firstName → username
    var displayName: String? {
        if let full = fullName, !full.isEmpty { return full }
        let parts = [lastName, firstName].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return username
    }

    /// roleId 3 = Rescuer, roleId 5 = Victim
    var isRescuer: Bool { roleId == 3 }
}

// MARK: - Auth Service
final class AuthService {
    static let shared = AuthService()

    // NOTE: Use your Mac's LAN IP for Simulator/device testing
    private let baseURL: URL
    private let session: URLSession

    private init(session: URLSession? = nil) {
        let configured = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "https://resq.somee.com"
        let urlString = configured
        self.baseURL = URL(string: urlString)!
        print("[AuthService] baseURL = \(urlString)")
        
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15   // 15s cho mỗi request
            config.timeoutIntervalForResource = 30  // 30s tổng
            self.session = URLSession(configuration: config)
        }
    }

    enum AuthServiceError: Error, LocalizedError {
        case invalidURL
        case requestFailed(Error)
        case timeout
        case httpStatus(Int, String?)
        case missingData
        case decodingFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "URL không hợp lệ"
            case .timeout:
                return "Hết thời gian chờ – kiểm tra lại IP máy chủ và kết nối mạng"
            case .requestFailed(let error):
                return error.localizedDescription
            case .httpStatus(let code, let message):
                return message ?? "Máy chủ trả về lỗi (HTTP \(code))"
            case .missingData:
                return "Không nhận được dữ liệu từ máy chủ"
            case .decodingFailed(let error):
                return "Không thể đọc dữ liệu: \(error.localizedDescription)"
            }
        }
    }

    func register(phone: String?, password: String?, completion: @escaping (Result<RegisterResponse, Error>) -> Void) {
        let payload = RegisterRequest(phone: phone, password: password)
        request(path: "/identity/auth/register", body: payload, completion: completion)
    }

    func login(username: String? = nil, phone: String? = nil, password: String?, completion: @escaping (Result<LoginResponse, Error>) -> Void) {
        let payload = LoginRequest(username: username, phone: phone, password: password)
        request(path: "/identity/auth/login", body: payload, completion: completion)
    }
    
    /// Đăng xuất và xóa session
    func logout(completion: ((Result<Void, Error>) -> Void)? = nil) {
        // Xóa token
        AuthSessionStore.shared.clear()
        // Xóa thông tin user → ContentView sẽ tự quay về SetupProfileView
        UserProfile.shared.clearUser()
        // Xóa danh sách SOS in-memory (dữ liệu local vẫn giữ theo userId)
        SOSStorageManager.shared.clearSession()
        
        DispatchQueue.main.async {
            completion?(.success(()))
        }
    }

    private func request<T: Codable, R: Codable>(
        path: String,
        body: T,
        completion: @escaping (Result<R, Error>) -> Void
    ) {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            DispatchQueue.main.async { completion(.failure(AuthServiceError.invalidURL)) }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("[AuthService] → \(request.httpMethod ?? "?") \(url.absoluteString)")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[AuthService] ✗ error: \(error.localizedDescription)")
                let nsErr = error as NSError
                if nsErr.code == NSURLErrorTimedOut || nsErr.code == NSURLErrorCannotConnectToHost || nsErr.code == NSURLErrorNetworkConnectionLost {
                    DispatchQueue.main.async { completion(.failure(AuthServiceError.timeout)) }
                } else {
                    DispatchQueue.main.async { completion(.failure(AuthServiceError.requestFailed(error))) }
                }
                return
            }
            print("[AuthService] ✓ status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(statusCode) else {
                // Try to parse error message from response
                var errorMessage: String? = nil
                if let data = data, !data.isEmpty {
                    let raw = String(data: data, encoding: .utf8) ?? "<binary>"
                    print("[AuthService] ✗ HTTP \(statusCode) body: \(raw)")
                    errorMessage = APIErrorResponse.decode(from: data)?.message ?? raw
                }
                DispatchQueue.main.async { completion(.failure(AuthServiceError.httpStatus(statusCode, errorMessage))) }
                return
            }

            guard let data = data, !data.isEmpty else {
                DispatchQueue.main.async { completion(.failure(AuthServiceError.missingData)) }
                return
            }

            do {
                let decoded = try self.makeDecoder().decode(R.self, from: data)
                DispatchQueue.main.async { completion(.success(decoded)) }
            } catch {
                let raw = String(data: data, encoding: .utf8) ?? "<binary>"
                print("[AuthService] ✗ decode error: \(error)")
                print("[AuthService] ✗ raw body: \(raw)")
                DispatchQueue.main.async { completion(.failure(AuthServiceError.decodingFailed(error))) }
            }
        }
        task.resume()
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let isoWithFraction = ISO8601DateFormatter()
            isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let isoNoFraction = ISO8601DateFormatter()
            isoNoFraction.formatOptions = [.withInternetDateTime]

            if let date = isoWithFraction.date(from: value) ?? isoNoFraction.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(value)")
        }
        return decoder
    }
}
