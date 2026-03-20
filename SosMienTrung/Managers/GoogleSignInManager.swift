import Foundation
import UIKit
import GoogleSignIn

enum GoogleSignInManagerError: LocalizedError {
    case missingIOSClientID
    case missingServerClientID
    case missingURLScheme(String)
    case missingPresentingViewController
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .missingIOSClientID:
            return "Thieu iOS OAuth client ID. Hay them GIDClientID hoac CLIENT_ID tu GoogleService-Info.plist."
        case .missingServerClientID:
            return "Thieu GIDServerClientID de BE xac minh Google ID token."
        case .missingURLScheme(let scheme):
            return "Thieu URL scheme iOS cho Google Sign-In: \(scheme)"
        case .missingPresentingViewController:
            return "Khong tim thay man hinh de mo Google Sign-In."
        case .missingIDToken:
            return "Google khong tra ve ID token hop le."
        }
    }
}

@MainActor
final class GoogleSignInManager {
    static let shared = GoogleSignInManager()

    private init() {}

    func signIn() async throws -> String {
        let configuration = try makeConfiguration()

        guard let presentingViewController = UIApplication.shared.topMostViewController() else {
            throw GoogleSignInManagerError.missingPresentingViewController
        }

        GIDSignIn.sharedInstance.configuration = configuration

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInManagerError.missingIDToken
        }

        return idToken
    }

    func handleOpenURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    private func makeConfiguration() throws -> GIDConfiguration {
        let bundle = Bundle.main
        let googleServiceInfo = googleServiceInfoDictionary()

        let clientID = nonEmptyString(bundle.object(forInfoDictionaryKey: "GIDClientID"))
            ?? nonEmptyString(googleServiceInfo?["CLIENT_ID"])
        let serverClientID = nonEmptyString(bundle.object(forInfoDictionaryKey: "GIDServerClientID"))
        let reversedClientID = nonEmptyString(googleServiceInfo?["REVERSED_CLIENT_ID"])

        guard let clientID else {
            throw GoogleSignInManagerError.missingIOSClientID
        }

        guard let serverClientID else {
            throw GoogleSignInManagerError.missingServerClientID
        }

        if let reversedClientID, !isURLSchemeRegistered(reversedClientID) {
            throw GoogleSignInManagerError.missingURLScheme(reversedClientID)
        }

        return GIDConfiguration(
            clientID: clientID,
            serverClientID: serverClientID
        )
    }

    private func googleServiceInfoDictionary() -> [String: Any]? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dictionary = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }

        return dictionary
    }

    private func isURLSchemeRegistered(_ expectedScheme: String) -> Bool {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }

        for urlType in urlTypes {
            let schemes = urlType["CFBundleURLSchemes"] as? [String] ?? []
            if schemes.contains(expectedScheme) {
                return true
            }
        }

        return false
    }

    private func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension UIApplication {
    func topMostViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let navigationController = base as? UINavigationController {
            return topMostViewController(base: navigationController.visibleViewController)
        }

        if let tabBarController = base as? UITabBarController {
            return topMostViewController(base: tabBarController.selectedViewController)
        }

        if let presentedViewController = base?.presentedViewController {
            return topMostViewController(base: presentedViewController)
        }

        return base
    }
}
