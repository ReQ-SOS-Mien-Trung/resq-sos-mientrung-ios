import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Bridgefy sẽ được khởi động bởi BridgefyNetworkManager.shared
        print("✅ App did finish launching")
        return true
    }
}
