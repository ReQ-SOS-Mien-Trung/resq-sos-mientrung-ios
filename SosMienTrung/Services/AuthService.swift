import Foundation

// MARK: - Auth DTOs
struct RegisterRequest: Codable {
    let phone: String?
    let password: String?
    let firebaseIdToken: String?
}

struct RegisterResponse: Codable {
    let userId: String
    let phone: String?
    let roleId: Int
    let createdAt: Date
}

/// Request cho đăng nhập bằng Firebase Phone OTP
struct FirebasePhoneLoginRequest: Codable {
    let idToken: String
}

/// Response cho đăng nhập bằng Firebase Phone OTP
struct FirebasePhoneLoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let userId: String
    let phone: String?
    let firstName: String?
    let lastName: String?
    let roleId: Int?
    let isNewUser: Bool
    let isOnboarded: Bool

    var displayName: String? {
        let parts = [lastName, firstName].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return phone
    }

    var isRescuer: Bool { roleId == 3 }
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

struct RescuerLoginRequest: Codable {
    let email: String
    let password: String
}

struct GoogleLoginRequest: Codable {
    let idToken: String
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let userId: String
    let username: String?
    let email: String?
    let fullName: String?
    let firstName: String?
    let lastName: String?
    let roleId: Int?
    let permissions: [String]?

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

struct GoogleLoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let userId: String
    let username: String?
    let firstName: String?
    let lastName: String?
    let roleId: Int?
    let isNewUser: Bool
    let isOnboarded: Bool

    var displayName: String? {
        let parts = [lastName, firstName].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return username
    }

    var isRescuer: Bool { roleId == 3 }
}

struct CurrentUserResponse: Codable {
    let id: String
    let roleId: Int?
    let firstName: String?
    let lastName: String?
    let username: String?
    let phone: String?
    let rescuerType: String?
    let email: String?
    let isEmailVerified: Bool
    let isOnboarded: Bool
    let isEligibleRescuer: Bool
    let avatarUrl: String?

    var displayName: String? {
        let parts = [lastName, firstName].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return username ?? email
    }
}

// MARK: - Auth Service
final class AuthService {
    static let shared = AuthService()

    // NOTE: Use your Mac's LAN IP for Simulator/device testing
    private let baseURL: URL
    private let session: URLSession

    private init(session: URLSession? = nil) {
        self.baseURL = AppConfig.baseURL
        print("[AuthService] baseURL = \(AppConfig.baseURLString)")
        
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

    func register(phone: String?, password: String?, firebaseIdToken: String? = nil, completion: @escaping (Result<RegisterResponse, Error>) -> Void) {
        let payload = RegisterRequest(phone: phone, password: password, firebaseIdToken: firebaseIdToken)
        request(path: "/identity/auth/register", body: payload, completion: completion)
    }

    /// Đăng nhập bằng Firebase Phone OTP
    func firebasePhoneLogin(idToken: String, completion: @escaping (Result<FirebasePhoneLoginResponse, Error>) -> Void) {
        let payload = FirebasePhoneLoginRequest(idToken: idToken)
        request(path: "/identity/auth/firebase-phone-login", body: payload, completion: completion)
    }

    func login(username: String? = nil, phone: String? = nil, password: String?, completion: @escaping (Result<LoginResponse, Error>) -> Void) {
        let payload = LoginRequest(username: username, phone: phone, password: password)
        request(path: "/identity/auth/login", body: payload, completion: completion)
    }

    /// Đăng nhập với tư cách Rescuer bằng email + password
    func loginRescuer(email: String, password: String, completion: @escaping (Result<LoginResponse, Error>) -> Void) {
        let payload = RescuerLoginRequest(email: email, password: password)
        request(path: "/identity/auth/login-rescuer", body: payload, completion: completion)
    }

    /// Đăng nhập Rescuer bằng Google ID token
    func googleLogin(idToken: String) async throws -> GoogleLoginResponse {
        let payload = GoogleLoginRequest(idToken: idToken)
        return try await request(path: "/identity/auth/google-login", body: payload)
    }

    /// Lấy hồ sơ người dùng hiện tại để đọc các cờ quyền như isEligibleRescuer
    func fetchCurrentUser() async throws -> CurrentUserResponse {
        try await authorizedRequest(path: "/identity/user/me")
    }
    
    /// Đăng xuất và xóa session
    func logout(completion: ((Result<Void, Error>) -> Void)? = nil) {
        Task {
            do {
                await NotificationHubService.shared.prepareForLogout()
                try await NotificationAPIService.shared.logout()
            } catch {
                print("[AuthService] Logout API failed: \(error.localizedDescription)")
            }

            await MainActor.run {
                GoogleSignInManager.shared.signOut()
                AuthSessionStore.shared.clear()
                UserProfile.shared.clearUser()
                SOSStorageManager.shared.clearSession()
                completion?(.success(()))
            }
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

    private func request<T: Codable, R: Codable>(
        path: String,
        body: T
    ) async throws -> R {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw AuthServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw error
        }

        return try await perform(request)
    }

    private func authorizedRequest<R: Codable>(
        path: String,
        method: String = "GET"
    ) async throws -> R {
        guard let token = AuthSessionStore.shared.session?.accessToken, !token.isEmpty else {
            throw AuthServiceError.missingData
        }

        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw AuthServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    private func perform<R: Codable>(_ request: URLRequest) async throws -> R {
        do {
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                var errorMessage: String? = nil
                if !data.isEmpty {
                    errorMessage = APIErrorResponse.decode(from: data)?.message
                        ?? String(data: data, encoding: .utf8)
                }
                throw AuthServiceError.httpStatus(statusCode, errorMessage)
            }

            guard !data.isEmpty else {
                throw AuthServiceError.missingData
            }

            do {
                return try makeDecoder().decode(R.self, from: data)
            } catch {
                throw AuthServiceError.decodingFailed(error)
            }
        } catch let authError as AuthServiceError {
            throw authError
        } catch {
            let nsErr = error as NSError
            if nsErr.code == NSURLErrorTimedOut || nsErr.code == NSURLErrorCannotConnectToHost || nsErr.code == NSURLErrorNetworkConnectionLost {
                throw AuthServiceError.timeout
            }
            throw AuthServiceError.requestFailed(error)
        }
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
