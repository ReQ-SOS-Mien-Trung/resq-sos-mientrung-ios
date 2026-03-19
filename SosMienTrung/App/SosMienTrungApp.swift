import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAuth

@main
struct SosMienTrungApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if GoogleSignInManager.shared.handleOpenURL(url) {
                        return
                    }

                    _ = Auth.auth().canHandle(url)
                }
        }
    }
}
