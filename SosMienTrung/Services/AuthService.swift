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
    let permissions: [String]?
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
    let code: String?
    let innerError: String?
    let errors: [String: [String]]?
    
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
    let firebaseIdToken: String?
}

struct RefreshTokenRequest: Codable {
    let accessToken: String
    let refreshToken: String
}

struct RefreshTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let permissions: [String]?
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

struct UserProfileUpdateRequest: Encodable {
    let firstName: String
    let lastName: String
    let phone: String
    let address: String
    let ward: String
    let province: String
    let latitude: Double
    let longitude: Double
    let avatarUrl: String
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
    let permissions: [String]?
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
    let address: String?
    let ward: String?
    let province: String?
    let latitude: Double?
    let longitude: Double?
    let rescuerType: String?
    let email: String?
    let isEmailVerified: Bool
    let isOnboarded: Bool
    let isEligibleRescuer: Bool
    let avatarUrl: String?
    let permissions: [String]?

    var displayName: String? {
        let parts = [lastName, firstName].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return username ?? email ?? phone
    }

    var isVictim: Bool { roleId == 5 }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)

        // Some environments wrap user payload under data/user/result.
        if !container.contains(DynamicCodingKey(rawValue: "id")) {
            if let nested = Self.decodeNestedUser(from: container, key: "data")
                ?? Self.decodeNestedUser(from: container, key: "user")
                ?? Self.decodeNestedUser(from: container, key: "result")
                ?? Self.decodeNestedUser(from: container, key: "payload") {
                self = nested
                return
            }
        }

        id = Self.decodeString(from: container, keys: ["id", "userId", "uid"]) ?? ""
        roleId = Self.decodeInt(from: container, keys: ["roleId", "role_id"])
        firstName = Self.decodeString(from: container, keys: ["firstName", "first_name"])
        lastName = Self.decodeString(from: container, keys: ["lastName", "last_name"])
        username = Self.decodeString(from: container, keys: ["username", "userName"])
        phone = Self.decodeString(from: container, keys: ["phone", "phoneNumber"])
        address = Self.decodeString(from: container, keys: ["address", "streetAddress", "street_address"])
        ward = Self.decodeString(from: container, keys: ["ward", "commune", "district"])
        province = Self.decodeString(from: container, keys: ["province", "city"])
        latitude = Self.decodeDouble(from: container, keys: ["latitude", "lat"])
        longitude = Self.decodeDouble(from: container, keys: ["longitude", "lng", "lon"])
        rescuerType = Self.decodeString(from: container, keys: ["rescuerType", "rescuer_type"])
        email = Self.decodeString(from: container, keys: ["email"])
        isEmailVerified = Self.decodeBool(from: container, keys: ["isEmailVerified", "emailVerified", "is_email_verified"]) ?? false
        isOnboarded = Self.decodeBool(from: container, keys: ["isOnboarded", "onboarded", "is_onboarded"]) ?? false
        isEligibleRescuer = Self.decodeBool(from: container, keys: ["isEligibleRescuer", "eligibleRescuer", "is_eligible_rescuer"]) ?? false
        avatarUrl = Self.decodeString(
            from: container,
            keys: [
                "avatarUrl",
                "avatarURL",
                "avatar_url",
                "avatar",
                "photoUrl",
                "photoURL",
                "photo_url",
                "imageUrl",
                "imageURL",
                "image_url",
                "profileImageUrl",
                "profile_image_url"
            ]
        )
        permissions = Self.decodeStringArray(from: container, keys: ["permissions"])
    }

    private static func decodeNestedUser(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        key rawKey: String
    ) -> CurrentUserResponse? {
        let key = DynamicCodingKey(rawValue: rawKey)
        return try? container.decode(CurrentUserResponse.self, forKey: key)
    }

    private static func decodeString(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        keys: [String]
    ) -> String? {
        for rawKey in keys {
            let key = DynamicCodingKey(rawValue: rawKey)

            if let value = try? container.decode(String.self, forKey: key) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                return trimmed
            }

            if let value = try? container.decode(Int.self, forKey: key) {
                return String(value)
            }
        }

        return nil
    }

    private static func decodeInt(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        keys: [String]
    ) -> Int? {
        for rawKey in keys {
            let key = DynamicCodingKey(rawValue: rawKey)

            if let value = try? container.decode(Int.self, forKey: key) {
                return value
            }

            if let rawValue = try? container.decode(String.self, forKey: key),
               let parsed = Int(rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return parsed
            }
        }

        return nil
    }

    private static func decodeBool(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        keys: [String]
    ) -> Bool? {
        for rawKey in keys {
            let key = DynamicCodingKey(rawValue: rawKey)

            if let value = try? container.decode(Bool.self, forKey: key) {
                return value
            }

            if let rawValue = try? container.decode(String.self, forKey: key) {
                switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "1":
                    return true
                case "false", "0":
                    return false
                default:
                    continue
                }
            }

            if let rawValue = try? container.decode(Int.self, forKey: key) {
                return rawValue != 0
            }
        }

        return nil
    }

    private static func decodeDouble(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        keys: [String]
    ) -> Double? {
        for rawKey in keys {
            let key = DynamicCodingKey(rawValue: rawKey)

            if let value = try? container.decode(Double.self, forKey: key) {
                return value
            }

            if let value = try? container.decode(Int.self, forKey: key) {
                return Double(value)
            }

            if let rawValue = try? container.decode(String.self, forKey: key) {
                let normalized = rawValue
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ",", with: ".")
                if let parsed = Double(normalized) {
                    return parsed
                }
            }
        }

        return nil
    }

    private static func decodeStringArray(
        from container: KeyedDecodingContainer<DynamicCodingKey>,
        keys: [String]
    ) -> [String]? {
        for rawKey in keys {
            let key = DynamicCodingKey(rawValue: rawKey)

            if let values = try? container.decode([String].self, forKey: key) {
                return values.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }.filter { !$0.isEmpty }
            }
        }

        return nil
    }

    private struct DynamicCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int?

        init(rawValue: String) {
            self.stringValue = rawValue
            self.intValue = nil
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
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
                return L10n.Common.invalidURL
            case .timeout:
                return L10n.Common.timeoutCheckConnection()
            case .requestFailed(let error):
                return error.localizedDescription
            case .httpStatus(let code, let message):
                return message ?? L10n.Auth.httpStatus(String(code))
            case .missingData:
                return L10n.Common.noServerData
            case .decodingFailed(let error):
                return L10n.Common.cannotDecodeData(error.localizedDescription)
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
    func googleLogin(idToken: String, firebaseIdToken: String? = nil) async throws -> GoogleLoginResponse {
        let payload = GoogleLoginRequest(idToken: idToken, firebaseIdToken: firebaseIdToken)
        return try await request(path: "/identity/auth/google-login", body: payload)
    }

    func refreshToken(accessToken: String, refreshToken: String) async throws -> RefreshTokenResponse {
        let payload = RefreshTokenRequest(accessToken: accessToken, refreshToken: refreshToken)
        return try await request(path: "/identity/auth/refresh-token", body: payload)
    }

    /// Lấy hồ sơ người dùng hiện tại để đọc các cờ quyền như isEligibleRescuer
    func fetchCurrentUser() async throws -> CurrentUserResponse {
        try await authorizedRequest(path: "/identity/user/me")
    }

    func updateUserProfile(_ payload: UserProfileUpdateRequest) async throws -> CurrentUserResponse? {
        let data = try await authorizedRequestData(
            path: "/identity/user/profile",
            method: "PUT",
            body: try JSONEncoder().encode(payload)
        )

        guard !data.isEmpty else {
            return nil
        }

        do {
            return try makeDecoder().decode(CurrentUserResponse.self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[AuthService] updateUserProfile decode skipped: \(raw)")
            return nil
        }
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
        let data = try await authorizedRequestData(path: path, method: method)

        do {
            return try makeDecoder().decode(R.self, from: data)
        } catch {
            throw AuthServiceError.decodingFailed(error)
        }
    }

    private func authorizedRequestData(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> Data {
        let token = try await AuthSessionStore.shared.validAccessToken()
        guard !token.isEmpty else {
            throw AuthServiceError.missingData
        }

        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw AuthServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return try await performData(request, allowEmptyBody: true)
    }

    private func perform<R: Codable>(_ request: URLRequest) async throws -> R {
        let data = try await performData(request)

        do {
            return try makeDecoder().decode(R.self, from: data)
        } catch {
            throw AuthServiceError.decodingFailed(error)
        }
    }

    private func performData(
        _ request: URLRequest,
        allowEmptyBody: Bool = false
    ) async throws -> Data {
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

            guard allowEmptyBody || !data.isEmpty else {
                throw AuthServiceError.missingData
            }

            return data
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
