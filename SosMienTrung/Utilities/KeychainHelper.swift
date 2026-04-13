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
    private static let fallbackBaseURLDevice = "https://resq.somee.com/"
    private static let fallbackBaseURLSimulator = "https://resq.somee.com/"
    static let supportsRelayedVictimUpdate = false

    private static func normalizedURLString(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    private static func releaseSafeBundleURLString(_ raw: String?) -> String? {
        guard let normalized = normalizedURLString(raw) else { return nil }

        #if DEBUG
        return normalized
        #else
        guard
            let components = URLComponents(string: normalized),
            components.scheme?.lowercased() == "https",
            let host = components.host?.lowercased(),
            isLocalDevelopmentHost(host) == false
        else {
            return nil
        }

        return normalized
        #endif
    }

    private static func isLocalDevelopmentHost(_ host: String) -> Bool {
        if host == "localhost" || host.hasPrefix("127.") || host.hasPrefix("10.") || host.hasPrefix("192.168.") {
            return true
        }

        let octets = host.split(separator: ".")
        if octets.count == 4,
           octets[0] == "172",
           let secondOctet = Int(octets[1]),
           (16...31).contains(secondOctet) {
            return true
        }

        return false
    }

    static var baseURLString: String {
        if let env = normalizedURLString(ProcessInfo.processInfo.environment["BACKEND_BASE_URL"]) {
            return env
        }

        #if targetEnvironment(simulator)
        if let simulator = releaseSafeBundleURLString(Bundle.main.object(forInfoDictionaryKey: "BASE_URL_SIMULATOR") as? String) {
            return simulator
        }
        if let shared = releaseSafeBundleURLString(Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String) {
            return shared
        }
        return fallbackBaseURLSimulator
        #else
        if let device = releaseSafeBundleURLString(Bundle.main.object(forInfoDictionaryKey: "BASE_URL_DEVICE") as? String) {
            return device
        }
        if let shared = releaseSafeBundleURLString(Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String) {
            return shared
        }
        return fallbackBaseURLDevice
        #endif
    }

    static var baseURL: URL {
        guard let url = URL(string: baseURLString) else {
            assertionFailure("BASE_URL is not a valid URL: \(baseURLString)")
            #if targetEnvironment(simulator)
            return URL(string: fallbackBaseURLSimulator)!
            #else
            return URL(string: fallbackBaseURLDevice)!
            #endif
        }
        return url
    }
}
