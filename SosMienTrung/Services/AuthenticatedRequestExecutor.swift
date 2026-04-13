import Foundation

enum AuthenticatedRequestExecutorError: Error {
    case invalidResponse
}

final class AuthenticatedRequestExecutor {
    static let shared = AuthenticatedRequestExecutor()

    private init() { }

    func perform(
        _ request: URLRequest,
        using session: URLSession = .shared,
        accessTokenOverride: String? = nil,
        retryOnUnauthorized: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        let initialRequest = try await prepareRequest(
            from: request,
            accessTokenOverride: accessTokenOverride,
            forceRefresh: false
        )

        let (data, response) = try await session.data(for: initialRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthenticatedRequestExecutorError.invalidResponse
        }

        guard httpResponse.statusCode == 401, retryOnUnauthorized, accessTokenOverride == nil else {
            return (data, httpResponse)
        }

        let retryRequest = try await prepareRequest(
            from: request,
            accessTokenOverride: nil,
            forceRefresh: true
        )
        let (retryData, retryResponse) = try await session.data(for: retryRequest)
        guard let retryHTTPResponse = retryResponse as? HTTPURLResponse else {
            throw AuthenticatedRequestExecutorError.invalidResponse
        }

        return (retryData, retryHTTPResponse)
    }

    private func prepareRequest(
        from request: URLRequest,
        accessTokenOverride: String?,
        forceRefresh: Bool
    ) async throws -> URLRequest {
        var preparedRequest = request
        let accessToken: String

        if let accessTokenOverride, accessTokenOverride.isEmpty == false {
            accessToken = accessTokenOverride
        } else {
            accessToken = try await AuthSessionStore.shared.validAccessToken(forceRefresh: forceRefresh)
        }

        preparedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return preparedRequest
    }
}
