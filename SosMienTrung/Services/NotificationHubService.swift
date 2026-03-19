import Foundation
import Combine
import UIKit
import SignalRClient

enum RemoteNotificationHandling {
    case ignored
    case syncOnly
    case display
}

@MainActor
final class NotificationHubService: ObservableObject {
    static let shared = NotificationHubService()

    @Published private(set) var notifications: [RealtimeNotification] = []
    @Published private(set) var unreadCount = 0
    @Published private(set) var isConnected = false
    @Published private(set) var isSyncing = false
    @Published var presentedNotification: RealtimeNotification?
    @Published var errorMessage: String?

    private var connection: HubConnection?
    private let baseURL: String
    private let apiService: NotificationAPIService
    private var activeAccessToken: String?
    private var connectionDelegate: ConnectionDelegateProxy?

    private var backendUnreadCount = 0
    private var devicePushToken: String?
    private var registeredPushTokenKey: String?

    private let devicePushTokenDefaultsKey = "notificationHub.devicePushToken"
    private let registeredPushTokenDefaultsKey = "notificationHub.registeredPushTokenKey"

    private init() {
        self.baseURL = AppConfig.baseURLString
        self.apiService = NotificationAPIService.shared
        self.devicePushToken = UserDefaults.standard.string(forKey: devicePushTokenDefaultsKey)
        self.registeredPushTokenKey = UserDefaults.standard.string(forKey: registeredPushTokenDefaultsKey)
    }

    func connectIfNeeded() {
        guard let session = AuthSessionStore.shared.session, session.expiresAt > Date() else {
            log("Skip connect: auth session missing or expired")
            disconnect()
            return
        }

        let token = session.accessToken
        if connection != nil, activeAccessToken == token {
            if isConnected == false {
                log("Restart existing hub connection")
                connection?.start()
            }

            Task {
                await registerDevicePushTokenIfNeeded()
            }
            return
        }

        disconnect(clearNotifications: false)

        guard let url = makeHubURL(accessToken: token) else {
            errorMessage = "URL NotificationHub khong hop le"
            log("Invalid NotificationHub URL")
            return
        }

        activeAccessToken = token
        log("Connect NotificationHub -> \(url.absoluteString)")

        let connection = HubConnectionBuilder(url: url)
            .withLogging(minLogLevel: .debug)
            .withHubConnectionDelegate(delegate: makeConnectionDelegate())
            .withAutoReconnect()
            .build()

        self.connection = connection
        registerHandlers(for: connection)
        connection.start()

        Task {
            await registerDevicePushTokenIfNeeded()
        }
    }

    func disconnect(clearNotifications: Bool = true) {
        log("Disconnect NotificationHub")
        connection?.stop()
        connection = nil
        connectionDelegate = nil
        activeAccessToken = nil
        isConnected = false
        errorMessage = nil
        presentedNotification = nil

        if clearNotifications {
            notifications.removeAll()
            backendUnreadCount = 0
            updateUnreadCount()
        }
    }

    func dismissPresentedNotification() {
        presentedNotification = nil
    }

    func applicationDidBecomeActive() async {
        connectIfNeeded()
        await syncNotifications()
        await registerDevicePushTokenIfNeeded()
    }

    func syncNotifications(page: Int = 1, pageSize: Int = 20) async {
        guard AuthSessionStore.shared.isValid else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let response = try await apiService.fetchNotifications(page: page, pageSize: pageSize)
            let broadcastNotifications = notifications.filter(\.isBroadcastOnly)
            let merged = mergeBackendNotifications(response.items, with: broadcastNotifications)

            notifications = merged
            backendUnreadCount = response.unreadCount
            errorMessage = nil
            updateUnreadCount()
            log("Synced notifications: \(response.items.count) items, unread=\(response.unreadCount)")
        } catch {
            errorMessage = error.localizedDescription
            log("Sync notifications failed: \(error.localizedDescription)")
        }
    }

    func markAsRead(_ notification: RealtimeNotification) async {
        guard notification.isRead == false else { return }

        if let userNotificationId = notification.userNotificationId {
            do {
                try await apiService.markAsRead(userNotificationId: userNotificationId)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                log("Mark notification \(userNotificationId) as read failed: \(error.localizedDescription)")
                return
            }

            backendUnreadCount = max(0, backendUnreadCount - 1)
        }

        updateNotification(notification.id) { item in
            item.isRead = true
        }
        updateUnreadCount()
    }

    func markAllAsRead() async {
        do {
            if notifications.contains(where: { $0.isPersisted && $0.isRead == false }) {
                try await apiService.markAllAsRead()
            }

            for index in notifications.indices {
                notifications[index].isRead = true
            }

            backendUnreadCount = 0
            errorMessage = nil
            updateUnreadCount()
        } catch {
            errorMessage = error.localizedDescription
            log("Mark all notifications as read failed: \(error.localizedDescription)")
        }
    }

    func handlePresentedNotificationDismissal() async {
        guard let notification = presentedNotification else { return }
        await markAsRead(notification)
        dismissPresentedNotification()
    }

    func updateDevicePushToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        devicePushToken = trimmed
        UserDefaults.standard.set(trimmed, forKey: devicePushTokenDefaultsKey)
        log("Received FCM token")

        Task {
            await registerDevicePushTokenIfNeeded(force: true)
        }
    }

    func prepareForLogout() async {
        if let token = devicePushToken, !token.isEmpty {
            do {
                try await apiService.unregisterFCMToken(token)
                clearRegisteredPushTokenKey()
                log("FCM token unregistered")
            } catch {
                log("Failed to unregister FCM token: \(error.localizedDescription)")
            }
        }

        disconnect()
    }

    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async -> RemoteNotificationHandling {
        guard AuthSessionStore.shared.isValid else {
            return .ignored
        }

        if let type = extractString(for: "type", in: userInfo),
           !type.isEmpty {
            let broadcastNotification = RealtimeNotification.makeBroadcastPush(
                title: extractNotificationTitle(from: userInfo),
                body: extractNotificationBody(from: userInfo),
                type: type,
                messageId: extractString(for: "gcm.message_id", in: userInfo)
                    ?? extractString(for: "google.c.a.c_id", in: userInfo)
                    ?? extractString(for: "message_id", in: userInfo)
            )

            handle(notification: broadcastNotification, shouldPresent: true, adjustsBackendUnread: false)
            return .display
        }

        await syncNotifications()
        return .syncOnly
    }

    private func registerHandlers(for connection: HubConnection) {
        connection.on(method: "ReceiveNotification") { [weak self] argumentExtractor in
            Task { @MainActor [weak self] in
                guard let self else { return }

                do {
                    let notification = try argumentExtractor.getArgument(type: RealtimeNotification.self)
                    self.log("Received notification: \(notification.displayTitle)")
                    self.handle(notification: notification)
                } catch {
                    self.errorMessage = "Khong the decode ReceiveNotification: \(error.localizedDescription)"
                    self.log("ReceiveNotification decode failed: \(error.localizedDescription)")
                }
            }
        }

        connection.on(method: "Error") { [weak self] (message: String) in
            Task { @MainActor [weak self] in
                self?.errorMessage = message
                self?.log("Hub error event: \(message)")
            }
        }
    }

    private func handle(
        notification: RealtimeNotification,
        shouldPresent: Bool = true,
        adjustsBackendUnread: Bool = true
    ) {
        isConnected = true
        errorMessage = nil

        let existing = notifications.first(where: { $0.id == notification.id })
        let wasUnread = existing?.isRead == false

        upsert(notification)

        if adjustsBackendUnread, notification.isRead == false, wasUnread == false {
            backendUnreadCount += 1
        }

        updateUnreadCount()

        if shouldPresent {
            presentedNotification = notification
        }
    }

    private func upsert(_ notification: RealtimeNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index] = notification
        } else {
            notifications.insert(notification, at: 0)
        }

        notifications.sort { lhs, rhs in
            let leftDate = lhs.createdAt ?? .distantPast
            let rightDate = rhs.createdAt ?? .distantPast
            return leftDate > rightDate
        }
    }

    private func updateNotification(_ id: String, transform: (inout RealtimeNotification) -> Void) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        transform(&notifications[index])
    }

    private func mergeBackendNotifications(
        _ backendNotifications: [RealtimeNotification],
        with broadcastNotifications: [RealtimeNotification]
    ) -> [RealtimeNotification] {
        var mergedById: [String: RealtimeNotification] = [:]

        for notification in backendNotifications + broadcastNotifications {
            mergedById[notification.id] = notification
        }

        return mergedById.values.sorted {
            let leftDate = $0.createdAt ?? .distantPast
            let rightDate = $1.createdAt ?? .distantPast
            return leftDate > rightDate
        }
    }

    private func updateUnreadCount() {
        let broadcastUnreadCount = notifications.filter { $0.isBroadcastOnly && $0.isRead == false }.count
        unreadCount = backendUnreadCount + broadcastUnreadCount
        UIApplication.shared.applicationIconBadgeNumber = unreadCount
    }

    private func registerDevicePushTokenIfNeeded(force: Bool = false) async {
        guard let session = AuthSessionStore.shared.session, session.expiresAt > Date() else {
            return
        }

        guard let token = devicePushToken, !token.isEmpty else {
            return
        }

        let registrationKey = "\(session.userId)|\(token)"
        if force == false, registeredPushTokenKey == registrationKey {
            return
        }

        do {
            try await apiService.registerFCMToken(token)
            registeredPushTokenKey = registrationKey
            UserDefaults.standard.set(registrationKey, forKey: registeredPushTokenDefaultsKey)
            errorMessage = nil
            log("FCM token registered")
        } catch {
            errorMessage = error.localizedDescription
            log("Register FCM token failed: \(error.localizedDescription)")
        }
    }

    private func clearRegisteredPushTokenKey() {
        registeredPushTokenKey = nil
        UserDefaults.standard.removeObject(forKey: registeredPushTokenDefaultsKey)
    }

    private func makeHubURL(accessToken: String) -> URL? {
        guard var components = URLComponents(string: "\(baseURL)/hubs/notifications") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "access_token", value: accessToken)
        ]
        return components.url
    }

    private func extractNotificationTitle(from userInfo: [AnyHashable: Any]) -> String? {
        if let title = extractString(for: "title", in: userInfo) {
            return title
        }

        guard let aps = userInfo["aps"] as? [AnyHashable: Any] else {
            return nil
        }

        if let alert = aps["alert"] as? [AnyHashable: Any] {
            return alert["title"] as? String
        }

        return aps["alert"] as? String
    }

    private func extractNotificationBody(from userInfo: [AnyHashable: Any]) -> String? {
        if let body = extractString(for: "body", in: userInfo)
            ?? extractString(for: "content", in: userInfo) {
            return body
        }

        guard let aps = userInfo["aps"] as? [AnyHashable: Any] else {
            return nil
        }

        if let alert = aps["alert"] as? [AnyHashable: Any] {
            return alert["body"] as? String
        }

        return aps["alert"] as? String
    }

    private func extractString(for key: String, in dictionary: [AnyHashable: Any]) -> String? {
        if let value = dictionary[key] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let value = dictionary[key] as? NSNumber {
            return value.stringValue
        }

        return nil
    }

    private func makeConnectionDelegate() -> ConnectionDelegateProxy {
        let delegate = ConnectionDelegateProxy(owner: self)
        connectionDelegate = delegate
        return delegate
    }

    fileprivate func connectionDidOpen() {
        isConnected = true
        errorMessage = nil
        log("NotificationHub connected")
    }

    fileprivate func connectionDidFailToOpen(error: Error) {
        isConnected = false
        errorMessage = error.localizedDescription
        log("NotificationHub failed to open: \(error.localizedDescription)")
    }

    fileprivate func connectionDidClose(error: Error?) {
        isConnected = false
        if let error {
            errorMessage = error.localizedDescription
            log("NotificationHub closed with error: \(error.localizedDescription)")
        } else {
            log("NotificationHub closed")
        }
    }

    fileprivate func connectionWillReconnect(error: Error) {
        isConnected = false
        errorMessage = error.localizedDescription
        log("NotificationHub reconnecting: \(error.localizedDescription)")
    }

    fileprivate func connectionDidReconnect() {
        isConnected = true
        errorMessage = nil
        log("NotificationHub reconnected")

        Task {
            await syncNotifications()
        }
    }

    private func log(_ message: String) {
        print("[NotificationHub] \(message)")
    }
}

private final class ConnectionDelegateProxy: HubConnectionDelegate {
    weak var owner: NotificationHubService?

    init(owner: NotificationHubService) {
        self.owner = owner
    }

    func connectionDidOpen(hubConnection: HubConnection) {
        Task { @MainActor [weak owner] in
            owner?.connectionDidOpen()
        }
    }

    func connectionDidFailToOpen(error: Error) {
        Task { @MainActor [weak owner] in
            owner?.connectionDidFailToOpen(error: error)
        }
    }

    func connectionDidClose(error: Error?) {
        Task { @MainActor [weak owner] in
            owner?.connectionDidClose(error: error)
        }
    }

    func connectionWillReconnect(error: Error) {
        Task { @MainActor [weak owner] in
            owner?.connectionWillReconnect(error: error)
        }
    }

    func connectionDidReconnect() {
        Task { @MainActor [weak owner] in
            owner?.connectionDidReconnect()
        }
    }
}
