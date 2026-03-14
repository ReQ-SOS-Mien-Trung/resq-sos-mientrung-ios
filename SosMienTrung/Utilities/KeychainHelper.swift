import Foundation
import Security

struct KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum AppConfig {
    private static let fallbackBaseURL = "http://localhost:8080"

    static var baseURLString: String {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String else {
            assertionFailure("Missing BASE_URL in Info.plist")
            return fallbackBaseURL
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            assertionFailure("BASE_URL in Info.plist is empty")
            return fallbackBaseURL
        }

        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    static var baseURL: URL {
        guard let url = URL(string: baseURLString) else {
            assertionFailure("BASE_URL is not a valid URL: \(baseURLString)")
            return URL(string: fallbackBaseURL)!
        }
        return url
    }
}
