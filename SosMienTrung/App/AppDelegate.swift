import UIKit
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureFirebaseIfPossible()
        // Đăng ký nhận remote notifications (bắt buộc cho Firebase Phone Auth)
        application.registerForRemoteNotifications()
        print("✅ App did finish launching")
        print("✅ Remote notifications registered: \(application.isRegisteredForRemoteNotifications)")
        
        // Log Firebase config
        if let app = FirebaseApp.app() {
            print("✅ Firebase configured: \(app.options.googleAppID)")
            print("✅ Firebase API key: \(app.options.apiKey?.prefix(10) ?? "nil")...")
        }
        return true
    }

    private func configureFirebaseIfPossible() {
        guard FirebaseApp.app() == nil else { return }

        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: plistPath) else {
            assertionFailure("Missing or invalid GoogleService-Info.plist in app bundle")
            print("🔴 Firebase not configured: missing/invalid GoogleService-Info.plist")
            return
        }

        FirebaseApp.configure(options: options)
    }

    // MARK: - APNs cho Firebase Phone Auth
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("✅ APNs token received: \(tokenString.prefix(20))...")
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔴 APNs registration FAILED: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        completionHandler(.noData)
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if Auth.auth().canHandle(url) {
            return true
        }
        return false
    }
}
