import Foundation
import Combine

struct AuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresAt: Date
    let userId: String
    let username: String?
    let email: String?
    let fullName: String?
    let roleId: Int?
    let isOnboarded: Bool?
    let isEligibleRescuer: Bool?
}

final class AuthSessionStore: ObservableObject {
    static let shared = AuthSessionStore()

    @Published private(set) var session: AuthSession?
    @Published private(set) var isRefreshingCurrentUser = false
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
            email: response.email,
            fullName: response.fullName,
            roleId: response.roleId,
            isOnboarded: nil,
            isEligibleRescuer: nil
        )
        persist(session)
        
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
            email: nil,
            fullName: response.displayName,
            roleId: response.roleId,
            isOnboarded: response.isOnboarded,
            isEligibleRescuer: nil
        )
        persist(session)

        // Lưu token vào Keychain
        KeychainHelper.save(key: "accessToken", value: response.accessToken)
        KeychainHelper.save(key: "refreshToken", value: response.refreshToken)

        // Đồng bộ serverUserId ↔ Bridgefy deviceId
        BridgefyNetworkManager.shared.registerServerIdentity(response.userId)

        // Load dữ liệu SOS local của user mới đăng nhập
        SOSStorageManager.shared.reloadForUser(response.userId)
    }

    func save(from response: GoogleLoginResponse) {
        let expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        let session = AuthSession(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresAt: expiresAt,
            userId: response.userId,
            username: response.username,
            email: response.username,
            fullName: response.displayName,
            roleId: response.roleId,
            isOnboarded: response.isOnboarded,
            isEligibleRescuer: nil
        )
        persist(session)

        KeychainHelper.save(key: "accessToken", value: response.accessToken)
        KeychainHelper.save(key: "refreshToken", value: response.refreshToken)

        BridgefyNetworkManager.shared.registerServerIdentity(response.userId)
        SOSStorageManager.shared.reloadForUser(response.userId)
    }

    func apply(currentUser: CurrentUserResponse) {
        guard let existing = session else { return }

        let updated = AuthSession(
            accessToken: existing.accessToken,
            refreshToken: existing.refreshToken,
            tokenType: existing.tokenType,
            expiresAt: existing.expiresAt,
            userId: existing.userId,
            username: currentUser.username ?? existing.username,
            email: currentUser.email ?? existing.email,
            fullName: currentUser.displayName ?? existing.fullName,
            roleId: currentUser.roleId ?? existing.roleId,
            isOnboarded: currentUser.isOnboarded,
            isEligibleRescuer: currentUser.isEligibleRescuer
        )

        guard updated != existing else { return }
        persist(updated)
    }

    @MainActor
    func refreshCurrentUserIfNeeded(force: Bool = false) async {
        guard let session else { return }

        if force == false, session.roleId != 3 {
            return
        }

        if force == false, session.isEligibleRescuer != nil {
            return
        }

        if isRefreshingCurrentUser {
            return
        }

        isRefreshingCurrentUser = true
        defer { isRefreshingCurrentUser = false }

        do {
            let currentUser = try await AuthService.shared.fetchCurrentUser()
            apply(currentUser: currentUser)
        } catch {
            print("[AuthSessionStore] Failed to refresh current user: \(error.localizedDescription)")
        }
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

    private func persist(_ session: AuthSession) {
        self.session = session

        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }
}
