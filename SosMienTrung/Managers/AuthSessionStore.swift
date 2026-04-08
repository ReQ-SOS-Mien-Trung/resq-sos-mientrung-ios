import Foundation
import Combine

struct AuthSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresAt: Date
    let userId: String
    let username: String?
    let email: String?
    let fullName: String?
    let roleId: Int?
    let permissions: [String]
    let permissionsLoaded: Bool
    let isOnboarded: Bool?
    let isEligibleRescuer: Bool?

    enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case tokenType
        case expiresAt
        case userId
        case username
        case email
        case fullName
        case roleId
        case permissions
        case permissionsLoaded
        case isOnboarded
        case isEligibleRescuer
    }

    init(
        accessToken: String,
        refreshToken: String,
        tokenType: String,
        expiresAt: Date,
        userId: String,
        username: String?,
        email: String?,
        fullName: String?,
        roleId: Int?,
        permissions: [String] = [],
        permissionsLoaded: Bool = false,
        isOnboarded: Bool?,
        isEligibleRescuer: Bool?
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresAt = expiresAt
        self.userId = userId
        self.username = username
        self.email = email
        self.fullName = fullName
        self.roleId = roleId
        self.permissions = permissions
        self.permissionsLoaded = permissionsLoaded
        self.isOnboarded = isOnboarded
        self.isEligibleRescuer = isEligibleRescuer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        tokenType = try container.decode(String.self, forKey: .tokenType)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        userId = try container.decode(String.self, forKey: .userId)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
        roleId = try container.decodeIfPresent(Int.self, forKey: .roleId)
        permissions = try container.decodeIfPresent([String].self, forKey: .permissions) ?? []
        permissionsLoaded = try container.decodeIfPresent(Bool.self, forKey: .permissionsLoaded) ?? false
        isOnboarded = try container.decodeIfPresent(Bool.self, forKey: .isOnboarded)
        isEligibleRescuer = try container.decodeIfPresent(Bool.self, forKey: .isEligibleRescuer)
    }
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
            permissions: response.permissions ?? [],
            permissionsLoaded: response.permissions != nil,
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
            permissions: response.permissions ?? [],
            permissionsLoaded: response.permissions != nil,
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
            permissions: response.permissions ?? [],
            permissionsLoaded: response.permissions != nil,
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
            permissions: currentUser.permissions ?? existing.permissions,
            permissionsLoaded: currentUser.permissions != nil || existing.permissionsLoaded,
            isOnboarded: currentUser.isOnboarded,
            isEligibleRescuer: currentUser.isEligibleRescuer
        )

        guard updated != existing else { return }
        persist(updated)
    }

    @MainActor
    func refreshCurrentUserIfNeeded(force: Bool = false) async {
        guard let session else { return }

        if isRefreshingCurrentUser {
            return
        }

        let needsPermissions = session.permissionsLoaded == false
        let needsRescuerEligibility = session.roleId == 3 && session.isEligibleRescuer == nil

        if force == false, !needsPermissions && !needsRescuerEligibility {
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

enum PermissionCode {
    static let sosRequestCreate = "sos.request.create"
    static let sosRequestView = "sos.request.view"
    static let personnelTeamView = "personnel.team.view"
    static let personnelStatusReport = "personnel.status.report"
    static let missionGlobalManage = "mission.global.manage"
    static let missionPointManage = "mission.point.manage"
    static let missionTeamUpdate = "mission.team.update"
    static let missionView = "mission.view"
    static let activityGlobalView = "activity.global.view"
    static let activityPointView = "activity.point.view"
    static let activityTeamManage = "activity.team.manage"
    static let activityOwnManage = "activity.own.manage"
}

enum PermissionGroup {
    static let sosRequestAccess = [
        PermissionCode.sosRequestCreate,
        PermissionCode.sosRequestView,
    ]

    static let missionAccess = [
        PermissionCode.missionGlobalManage,
        PermissionCode.missionPointManage,
        PermissionCode.missionTeamUpdate,
        PermissionCode.missionView,
    ]

    static let activityManage = [
        PermissionCode.missionGlobalManage,
        PermissionCode.missionPointManage,
        PermissionCode.activityTeamManage,
    ]

    static let activityAccess = [
        PermissionCode.activityGlobalView,
        PermissionCode.activityPointView,
        PermissionCode.missionGlobalManage,
        PermissionCode.missionPointManage,
        PermissionCode.activityTeamManage,
        PermissionCode.activityOwnManage,
    ]

    static let routeAccess = [
        PermissionCode.missionGlobalManage,
        PermissionCode.missionPointManage,
        PermissionCode.missionTeamUpdate,
        PermissionCode.activityTeamManage,
        PermissionCode.activityOwnManage,
    ]

    static let rescuerWorkspaceAccess = [
        PermissionCode.personnelTeamView,
        PermissionCode.personnelStatusReport,
        PermissionCode.missionGlobalManage,
        PermissionCode.missionPointManage,
        PermissionCode.missionTeamUpdate,
        PermissionCode.missionView,
        PermissionCode.activityGlobalView,
        PermissionCode.activityPointView,
        PermissionCode.activityTeamManage,
        PermissionCode.activityOwnManage,
    ]

    static let teamAvailabilityManage = [
        PermissionCode.missionTeamUpdate,
        PermissionCode.activityTeamManage,
    ]
}

extension AuthSession {
    private var permissionSet: Set<String> {
        Set(permissions)
    }

    func hasPermission(_ code: String) -> Bool {
        permissionSet.contains(code)
    }

    func hasAnyPermission(_ codes: [String]) -> Bool {
        !permissionSet.isDisjoint(with: codes)
    }

    var canCreateSosRequest: Bool {
        hasPermission(PermissionCode.sosRequestCreate)
    }

    var canAccessRescuerWorkspace: Bool {
        hasAnyPermission(PermissionGroup.rescuerWorkspaceAccess)
    }

    var canUseRescuerTracking: Bool {
        roleId == 3 && canAccessRescuerWorkspace
    }

    var canViewMissionWorkspace: Bool {
        hasAnyPermission(PermissionGroup.missionAccess)
            || hasAnyPermission(PermissionGroup.activityAccess)
    }

    var canManageMissionStatus: Bool {
        hasAnyPermission(PermissionGroup.activityManage)
    }

    var canUpdateActivityStatus: Bool {
        hasAnyPermission(PermissionGroup.activityAccess)
    }

    var canAccessMissionRoutes: Bool {
        hasAnyPermission(PermissionGroup.routeAccess)
    }

    var canManageTeamAvailability: Bool {
        hasAnyPermission(PermissionGroup.teamAvailabilityManage)
    }
}
