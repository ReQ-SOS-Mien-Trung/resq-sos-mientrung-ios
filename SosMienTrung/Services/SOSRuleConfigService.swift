import Foundation
import Combine

private func trimmedNonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          trimmed.isEmpty == false else {
        return nil
    }
    return trimmed
}

enum SOSRuleConfigServiceError: Error, LocalizedError {
    case missingAccessToken
    case invalidURL
    case invalidResponse(Int, String?)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return L10n.SOSRuleConfig.missingAccessToken
        case .invalidURL:
            return L10n.SOSRuleConfig.invalidURL
        case .invalidResponse(let statusCode, let message):
            return message ?? L10n.SOSRuleConfig.invalidResponse(String(statusCode))
        case .decodingFailed(let error):
            return L10n.SOSRuleConfig.decodingFailed(error.localizedDescription)
        }
    }
}

final class SOSRuleConfigService {
    static let shared = SOSRuleConfigService()

    private let session: URLSession

    private init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: configuration)
        }
    }

    func fetchActiveConfig() async throws -> SOSRuleConfig {
        guard AuthSessionStore.shared.hasAuthenticatedSession else {
            throw SOSRuleConfigServiceError.missingAccessToken
        }

        guard let url = URL(string: "\(AppConfig.baseURLString)/emergency/sos-form-config") else {
            throw SOSRuleConfigServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await AuthenticatedRequestExecutor.shared.perform(
            request,
            using: session
        )
        let statusCode = response.statusCode

        guard (200...299).contains(statusCode) else {
            let rawBody = String(data: data, encoding: .utf8)
            throw SOSRuleConfigServiceError.invalidResponse(statusCode, rawBody)
        }

        do {
            return try JSONDecoder().decode(SOSRuleConfig.self, from: data)
        } catch {
            throw SOSRuleConfigServiceError.decodingFailed(error)
        }
    }
}

@MainActor
final class SOSRuleConfigStore: ObservableObject {
    static let shared = SOSRuleConfigStore()

    @Published private(set) var activeConfig: SOSRuleConfig
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshError: String?

    var currentConfig: SOSRuleConfig {
        activeConfig
    }

    private let storageKey = "sosRuleConfig.active"
    private let service: SOSRuleConfigService
    private let userDefaults: UserDefaults
    private var sessionObserver: AnyCancellable?
    private var refreshTask: Task<Void, Never>?

    init(
        service: SOSRuleConfigService? = nil,
        userDefaults: UserDefaults = .standard,
        sessionPublisher: AnyPublisher<AuthSession?, Never>? = nil
    ) {
        self.service = service ?? .shared
        self.userDefaults = userDefaults
        self.activeConfig = Self.loadCachedConfig(from: userDefaults) ?? .fallback

        let publisher = sessionPublisher ?? AuthSessionStore.shared.$session.eraseToAnyPublisher()
        sessionObserver = publisher.sink { [weak self] session in
            guard let self else { return }
            refreshTask?.cancel()

            guard trimmedNonEmpty(session?.accessToken) != nil,
                  AuthSessionStore.shared.hasAuthenticatedSession else {
                return
            }

            refreshTask = Task { [weak self] in
                await self?.refreshIfPossible(force: true)
            }
        }
    }

    func refreshIfPossible(force: Bool = false) async {
        guard AuthSessionStore.shared.hasAuthenticatedSession else { return }
        if isRefreshing { return }
        if force == false, activeConfig.id != nil, lastRefreshError == nil {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let fetched = try await service.fetchActiveConfig()
            lastRefreshError = nil
            guard fetched != activeConfig else { return }
            activeConfig = fetched
            persist(fetched)
        } catch {
            lastRefreshError = error.localizedDescription
            print("[SOSRuleConfigStore] Failed to refresh config: \(error.localizedDescription)")
        }
    }

    func prepareForSOSFormEntry(isNetworkAvailable: Bool) async {
        loadCachedFallbackIfNeeded()

        guard isNetworkAvailable else {
            return
        }

        await refreshIfPossible(force: true)
    }

    func loadCachedFallbackIfNeeded() {
        if let cached = Self.loadCachedConfig(from: userDefaults) {
            activeConfig = cached
        }
    }

    private func persist(_ config: SOSRuleConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            print("[SOSRuleConfigStore] Failed to persist config: \(error.localizedDescription)")
        }
    }

    private static func loadCachedConfig(from userDefaults: UserDefaults) -> SOSRuleConfig? {
        guard let data = userDefaults.data(forKey: "sosRuleConfig.active") else {
            return nil
        }

        do {
            return try JSONDecoder().decode(SOSRuleConfig.self, from: data)
        } catch {
            print("[SOSRuleConfigStore] Failed to load cached config: \(error.localizedDescription)")
            return nil
        }
    }
}
