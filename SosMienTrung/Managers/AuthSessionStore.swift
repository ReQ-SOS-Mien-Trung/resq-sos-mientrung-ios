import Foundation
import Combine

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresAt: Date
    let userId: String
    let username: String?
    let fullName: String?
    let roleId: Int?
}

final class AuthSessionStore: ObservableObject {
    static let shared = AuthSessionStore()

    @Published private(set) var session: AuthSession?
    private let sessionKey = "authSession"

    private init() {
        load()
    }

    var isValid: Bool {
        guard let session = session else { return false }
        return session.expiresAt > Date()
    }

    func save(from response: LoginResponse) {
        let expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        let session = AuthSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: expiresAt,
            userId: response.userId,
            username: response.username,
            fullName: response.fullName,
            roleId: response.roleId
        )
        self.session = session

        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
        
        // Đồng bộ serverUserId ↔ Bridgefy deviceId
        BridgefyNetworkManager.shared.registerServerIdentity(response.userId)

        // Load dữ liệu SOS local của user mới đăng nhập
        SOSStorageManager.shared.reloadForUser(response.userId)
    }

    /// Lưu session từ Firebase Phone Login response
    func save(from response: FirebasePhoneLoginResponse) {
        let expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        let session = AuthSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: expiresAt,
            userId: response.userId,
            username: response.phone,
            fullName: response.displayName,
            roleId: response.roleId
        )
        self.session = session

        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }

        // Lưu token vào Keychain
        KeychainHelper.save(key: "accessToken", value: response.accessToken)
        KeychainHelper.save(key: "refreshToken", value: response.refreshToken)

        // Đồng bộ serverUserId ↔ Bridgefy deviceId
        BridgefyNetworkManager.shared.registerServerIdentity(response.userId)

        // Load dữ liệu SOS local của user mới đăng nhập
        SOSStorageManager.shared.reloadForUser(response.userId)
    }

    func clear() {
        session = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let decoded = try? JSONDecoder().decode(AuthSession.self, from: data) {
            session = decoded
        }
    }
}
