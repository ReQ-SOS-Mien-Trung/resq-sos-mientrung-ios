import UIKit
import UserNotifications
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        registerForPushNotifications(application)
        requestNotificationAuthorization()

        print("✅ App did finish launching")
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("✅ APNs token received: \(tokenString.prefix(20))...")

        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
        Messaging.messaging().apnsToken = deviceToken
        fetchFCMToken(reason: "APNs token available")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔴 APNs registration FAILED: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            _ = await NotificationHubService.shared.handleRemoteNotification(userInfo: userInfo)
            completionHandler(.newData)
        }
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if GoogleSignInManager.shared.handleOpenURL(url) {
            return true
        }

        if Auth.auth().canHandle(url) {
            return true
        }

        return false
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("🔴 Notification permission error: \(error.localizedDescription)")
            }

            print("✅ Notification permission granted: \(granted)")
        }
    }

    private func registerForPushNotifications(_ application: UIApplication) {
        DispatchQueue.main.async {
            application.registerForRemoteNotifications()
            print("📲 Requested APNs registration")
        }
    }

    private func fetchFCMToken(reason: String) {
        Messaging.messaging().token { token, error in
            if let error {
                print("🔴 FCM token fetch FAILED after \(reason): \(error.localizedDescription)")
                return
            }

            guard let token, !token.isEmpty else {
                print("⚠️ FCM token fetch returned empty token after \(reason)")
                return
            }

            print("✅ FCM token received after \(reason): \(token.prefix(16))...")
            Task { @MainActor in
                NotificationHubService.shared.updateDevicePushToken(token)
            }
        }
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }

        print("✅ FCM registration token updated: \(fcmToken.prefix(16))...")
        Task { @MainActor in
            NotificationHubService.shared.updateDevicePushToken(fcmToken)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler([])
            return
        }

        Task { @MainActor in
            let handling = await NotificationHubService.shared.handleRemoteNotification(userInfo: userInfo)
            switch handling {
            case .ignored, .silent:
                completionHandler([])
            case .syncOnly, .display:
                completionHandler([.banner, .sound, .badge])
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        Task { @MainActor in
            _ = await NotificationHubService.shared.handleRemoteNotification(userInfo: userInfo)
            completionHandler()
        }
    }
}
