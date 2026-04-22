import Foundation

enum MissionServiceError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return L10n.MissionService.invalidResponse
        case .httpStatus(let statusCode, let message):
            return message ?? L10n.MissionService.httpStatus(String(statusCode))
        }
    }
}

final class MissionService {
    static let shared = MissionService()

    private struct RouteCacheEntry {
        let data: Data
        let expiresAt: Date
    }

    private actor RouteResponseCache {
        private var entries: [String: RouteCacheEntry] = [:]
        private var cooldowns: [String: Date] = [:]

        func cachedData(for key: String, now: Date = Date()) -> Data? {
            cleanup(now: now)
            guard let entry = entries[key], entry.expiresAt > now else {
                entries[key] = nil
                return nil
            }

            return entry.data
        }

        func store(_ data: Data, for key: String, ttl: TimeInterval, now: Date = Date()) {
            guard ttl > 0 else { return }
            entries[key] = RouteCacheEntry(data: data, expiresAt: now.addingTimeInterval(ttl))
        }

        func setCooldown(for key: String, duration: TimeInterval, now: Date = Date()) {
            guard duration > 0 else { return }
            cooldowns[key] = now.addingTimeInterval(duration)
        }

        func clearCooldown(for key: String) {
            cooldowns[key] = nil
        }

        func cooldownRemaining(for key: String, now: Date = Date()) -> TimeInterval? {
            cleanup(now: now)
            guard let cooldownUntil = cooldowns[key], cooldownUntil > now else {
                cooldowns[key] = nil
                return nil
            }

            return cooldownUntil.timeIntervalSince(now)
        }

        private func cleanup(now: Date) {
            entries = entries.filter { $0.value.expiresAt > now }
            cooldowns = cooldowns.filter { $0.value > now }
        }
    }

    private static let routeCacheTTL: TimeInterval = 30
    private static let routeRateLimitCooldown: TimeInterval = 20

    private let baseURL: String
    private let session: URLSession
    private let authExecutor = AuthenticatedRequestExecutor.shared
    private let routeResponseCache = RouteResponseCache()

    private init() {
        self.baseURL = AppConfig.baseURLString
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    private func missionDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private static func isRouteRateLimitError(_ error: Error) -> Bool {
        guard let serviceError = error as? MissionServiceError else {
            return false
        }

        if case .httpStatus(let statusCode, let message) = serviceError {
            if statusCode == 429 {
                return true
            }

            let normalizedMessage = (message ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return normalizedMessage.contains("over_rate_limit")
                || normalizedMessage.contains("rate limit")
        }

        return false
    }

    private static func routeRateLimitMessage(seconds: Int) -> String {
        "Đang giới hạn tần suất tải lộ trình để tránh vượt hạn mức Goong. Vui lòng thử lại sau khoảng \(seconds) giây."
    }

    private func normalizedRouteCoordinate(_ value: Double) -> String {
        let rounded = (value * 10_000).rounded() / 10_000
        return String(format: "%.4f", rounded)
    }

    private func activityRouteCacheKey(
        missionId: Int,
        activityId: Int,
        originLat: Double,
        originLng: Double,
        vehicle: String
    ) -> String {
        [
            "activity",
            String(missionId),
            String(activityId),
            vehicle.lowercased(),
            normalizedRouteCoordinate(originLat),
            normalizedRouteCoordinate(originLng)
        ].joined(separator: "|")
    }

    private func missionTeamRouteCacheKey(
        missionId: Int,
        missionTeamId: Int,
        originLat: Double,
        originLng: Double,
        vehicle: String
    ) -> String {
        [
            "team",
            String(missionId),
            String(missionTeamId),
            vehicle.lowercased(),
            normalizedRouteCoordinate(originLat),
            normalizedRouteCoordinate(originLng)
        ].joined(separator: "|")
    }

    private func decodeMissionTeamRoute(
        data: Data,
        missionId: Int,
        missionTeamId: Int,
        originLat: Double,
        originLng: Double,
        vehicle: String
    ) throws -> MissionTeamRoute {
        if let decoded = try? JSONDecoder().decode(MissionTeamRoute.self, from: data) {
            return decoded
        }

        if let decodedRoutes = try? JSONDecoder().decode([ActivityRoute].self, from: data) {
            return MissionTeamRoute(
                missionId: missionId,
                missionTeamId: missionTeamId,
                originLatitude: originLat,
                originLongitude: originLng,
                vehicle: vehicle,
                route: nil,
                activityRoutes: decodedRoutes
            )
        }

        if let decodedSingleRoute = try? JSONDecoder().decode(ActivityRoute.self, from: data) {
            return MissionTeamRoute(
                missionId: missionId,
                missionTeamId: missionTeamId,
                originLatitude: originLat,
                originLongitude: originLng,
                vehicle: vehicle,
                route: nil,
                activityRoutes: [decodedSingleRoute]
            )
        }

        if let decodedSummary = try? JSONDecoder().decode(ActivityRouteSummary.self, from: data) {
            return MissionTeamRoute(
                missionId: missionId,
                missionTeamId: missionTeamId,
                originLatitude: originLat,
                originLongitude: originLng,
                vehicle: vehicle,
                route: decodedSummary,
                activityRoutes: []
            )
        }

        throw MissionServiceError.invalidResponse
    }

    private func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, http) = try await authExecutor.perform(request, using: session)

        guard (200...299).contains(http.statusCode) else {
            let decodedError = APIErrorResponse.decode(from: data)
            let rawBody = String(data: data, encoding: .utf8)
            let message = decodedError?.message ?? rawBody

            print("[MissionService] ✗ HTTP \(http.statusCode): \(message ?? "")")

            if let code = decodedError?.code, code.isEmpty == false {
                print("[MissionService] ✗ errorCode: \(code)")
            }

            if let innerError = decodedError?.innerError, innerError.isEmpty == false {
                print("[MissionService] ✗ innerError: \(innerError)")
            }

            if let errors = decodedError?.errors, errors.isEmpty == false {
                print("[MissionService] ✗ validationErrors: \(errors)")
            }

            if let rawBody, rawBody.isEmpty == false, rawBody != message {
                print("[MissionService] ✗ rawBody: \(rawBody)")
            }

            throw MissionServiceError.httpStatus(http.statusCode, message)
        }

        return data
    }

    private func debugJSONString(from data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        return String(data: data, encoding: .utf8)
    }

    // MARK: - GET /operations/missions/my-team
    func getMyTeamMissions() async throws -> [Mission] {
        guard let url = URL(string: "\(baseURL)/operations/missions/my-team") else {
            throw URLError(.badURL)
        }
        print("[MissionService] → GET \(url.absoluteString)")
        let data = try await send(authorizedRequest(url: url))
        return try missionDecoder().decode(MissionListResponse.self, from: data).missions
    }

    // MARK: - GET /operations/missions/{missionId}
    func getMission(missionId: Int) async throws -> Mission {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)") else {
            throw URLError(.badURL)
        }
        print("[MissionService] → GET \(url.absoluteString)")
        let data = try await send(authorizedRequest(url: url))
        return try missionDecoder().decode(Mission.self, from: data)
    }

    // MARK: - GET /operations/missions/{missionId}/activities
    func getMissionActivities(missionId: Int) async throws -> [Activity] {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/activities") else {
            throw URLError(.badURL)
        }
        print("[MissionService] → GET \(url.absoluteString)")
        let data = try await send(authorizedRequest(url: url))
        return try missionDecoder().decode([Activity].self, from: data)
    }

    // MARK: - GET /operations/missions/{missionId}/activities/my-team
    func getMyTeamActivities(missionId: Int) async throws -> [Activity] {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/activities/my-team") else {
            throw URLError(.badURL)
        }
        print("[MissionService] → GET \(url.absoluteString)")
        let data = try await send(authorizedRequest(url: url))
        return try missionDecoder().decode([Activity].self, from: data)
    }

    // MARK: - Backward-compatible wrapper
    func getActivities(missionId: Int) async throws -> [Activity] {
        try await getMissionActivities(missionId: missionId)
    }

    // MARK: - PATCH /operations/missions/{missionId}/activities/{activityId}/status
    /// Contract aligned with the web client: Planned, OnGoing, Succeed, PendingConfirmation, Failed, Cancelled.
    func updateActivityStatus(
        missionId: Int,
        activityId: Int,
        status: String,
        imageUrl: String? = nil
    ) async throws {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/activities/\(activityId)/status") else {
            throw URLError(.badURL)
        }

        let normalizedStatus = ActivityStatus(apiValue: status)?.apiUpdateCandidates.first ?? status
        var req = authorizedRequest(url: url, method: "PATCH")
        req.httpBody = try JSONEncoder().encode(
            ActivityStatusUpdate(
                status: normalizedStatus,
                imageUrl: imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
        )
        let imageAttachmentLabel = imageUrl == nil ? "none" : "attached"
        print("[MissionService] → PATCH \(url.absoluteString) status=\(normalizedStatus) imageUrl=\(imageAttachmentLabel)")
        _ = try await send(req)
    }

    // MARK: - POST /operations/missions/{missionId}/activities/{activityId}/confirm-pickup
    func confirmActivityPickup(
        missionId: Int,
        activityId: Int,
        bufferUsages: [MissionPickupBufferUsageRequest]
    ) async throws -> MissionConfirmPickupResponse {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/activities/\(activityId)/confirm-pickup") else {
            throw URLError(.badURL)
        }

        var req = authorizedRequest(url: url, method: "POST")
        let payload = MissionConfirmPickupRequest(
            bufferUsages: bufferUsages.isEmpty ? nil : bufferUsages
        )
        req.httpBody = try JSONEncoder().encode(payload)
        print("[MissionService] → POST \(url.absoluteString) bufferUsages=\(bufferUsages.count)")

        let data = try await send(req)
        return try missionDecoder().decode(MissionConfirmPickupResponse.self, from: data)
    }

    // MARK: - POST /operations/missions/{missionId}/activities/{activityId}/confirm-delivery
    func confirmActivityDelivery(
        missionId: Int,
        activityId: Int,
        actualDeliveredItems: [MissionActualDeliveredItemRequest],
        deliveryNote: String?
    ) async throws -> MissionConfirmDeliveryResponse {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/activities/\(activityId)/confirm-delivery") else {
            throw URLError(.badURL)
        }

        var req = authorizedRequest(url: url, method: "POST")
        let payload = MissionConfirmDeliveryRequest(
            actualDeliveredItems: actualDeliveredItems,
            deliveryNote: deliveryNote?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
        let encodedPayload = try JSONEncoder().encode(payload)
        req.httpBody = encodedPayload
        print("[MissionService] → POST \(url.absoluteString) deliveredItems=\(actualDeliveredItems.count)")
        if let payloadString = debugJSONString(from: encodedPayload) {
            print("[MissionService] payload=\n\(payloadString)")
        }

        let data = try await send(req)
        return try missionDecoder().decode(MissionConfirmDeliveryResponse.self, from: data)
    }

    // MARK: - PATCH /operations/missions/{missionId}/status
    /// Common values used by backend deployments: Planned, OnGoing, Completed, Cancelled
    func updateMissionStatus(missionId: Int, status: String) async throws {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/status") else {
            throw URLError(.badURL)
        }

        var req = authorizedRequest(url: url, method: "PATCH")
        req.httpBody = try JSONEncoder().encode(MissionStatusUpdate(status: status))
        print("[MissionService] → PATCH \(url.absoluteString) status=\(status)")

        _ = try await send(req)
    }

    // MARK: - GET /operations/missions/{missionId}/activities/{activityId}/route
    func getActivityRoute(
        missionId: Int,
        activityId: Int,
        originLat: Double,
        originLng: Double,
        vehicle: String = "car",
        bypassCache: Bool = false
    ) async throws -> ActivityRoute {
        let cacheKey = activityRouteCacheKey(
            missionId: missionId,
            activityId: activityId,
            originLat: originLat,
            originLng: originLng,
            vehicle: vehicle
        )

        if let cooldownRemaining = await routeResponseCache.cooldownRemaining(for: cacheKey) {
            let waitSeconds = max(1, Int(cooldownRemaining.rounded(.up)))
            throw MissionServiceError.httpStatus(429, Self.routeRateLimitMessage(seconds: waitSeconds))
        }

        if bypassCache == false,
           let cachedData = await routeResponseCache.cachedData(for: cacheKey) {
            return try JSONDecoder().decode(ActivityRoute.self, from: cachedData)
        }

        let urlStr = "\(baseURL)/operations/missions/\(missionId)/activities/\(activityId)/route?originLat=\(originLat)&originLng=\(originLng)&vehicle=\(vehicle)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        print("[MissionService] → GET \(url.absoluteString)")

        do {
            let data = try await send(authorizedRequest(url: url))
            await routeResponseCache.store(data, for: cacheKey, ttl: Self.routeCacheTTL)
            await routeResponseCache.clearCooldown(for: cacheKey)
            return try JSONDecoder().decode(ActivityRoute.self, from: data)
        } catch {
            if Self.isRouteRateLimitError(error) {
                await routeResponseCache.setCooldown(for: cacheKey, duration: Self.routeRateLimitCooldown)
            }
            throw error
        }
    }

    // MARK: - GET /operations/missions/{missionId}/teams/{missionTeamId}/route
    func getMissionTeamRoute(
        missionId: Int,
        missionTeamId: Int,
        originLat: Double,
        originLng: Double,
        vehicle: String = "car",
        bypassCache: Bool = false
    ) async throws -> MissionTeamRoute {
        let cacheKey = missionTeamRouteCacheKey(
            missionId: missionId,
            missionTeamId: missionTeamId,
            originLat: originLat,
            originLng: originLng,
            vehicle: vehicle
        )

        if let cooldownRemaining = await routeResponseCache.cooldownRemaining(for: cacheKey) {
            let waitSeconds = max(1, Int(cooldownRemaining.rounded(.up)))
            throw MissionServiceError.httpStatus(429, Self.routeRateLimitMessage(seconds: waitSeconds))
        }

        if bypassCache == false,
           let cachedData = await routeResponseCache.cachedData(for: cacheKey) {
            return try decodeMissionTeamRoute(
                data: cachedData,
                missionId: missionId,
                missionTeamId: missionTeamId,
                originLat: originLat,
                originLng: originLng,
                vehicle: vehicle
            )
        }

        var components = URLComponents(string: "\(baseURL)/operations/missions/\(missionId)/teams/\(missionTeamId)/route")
        components?.queryItems = [
            URLQueryItem(name: "originLat", value: String(originLat)),
            URLQueryItem(name: "originLng", value: String(originLng)),
            URLQueryItem(name: "vehicle", value: vehicle)
        ]

        guard let url = components?.url else { throw URLError(.badURL) }
        print("[MissionService] → GET \(url.absoluteString)")

        do {
            let data = try await send(authorizedRequest(url: url))
            await routeResponseCache.store(data, for: cacheKey, ttl: Self.routeCacheTTL)
            await routeResponseCache.clearCooldown(for: cacheKey)

            return try decodeMissionTeamRoute(
                data: data,
                missionId: missionId,
                missionTeamId: missionTeamId,
                originLat: originLat,
                originLng: originLng,
                vehicle: vehicle
            )
        } catch {
            if Self.isRouteRateLimitError(error) {
                await routeResponseCache.setCooldown(for: cacheKey, duration: Self.routeRateLimitCooldown)
            }
            throw error
        }
    }

    // MARK: - POST /operations/missions/{missionId}/teams/{missionTeamId}/complete-execution
    func completeMissionTeamExecution(missionId: Int, missionTeamId: Int, note: String?) async throws -> CompleteMissionTeamExecutionResponse {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/teams/\(missionTeamId)/complete-execution") else {
            throw URLError(.badURL)
        }

        var req = authorizedRequest(url: url, method: "POST")
        req.httpBody = try JSONEncoder().encode(CompleteMissionTeamExecutionRequest(note: note))
        print("[MissionService] → POST \(url.absoluteString)")
        let data = try await send(req)
        return try JSONDecoder().decode(CompleteMissionTeamExecutionResponse.self, from: data)
    }

    // MARK: - GET /operations/missions/{missionId}/teams/{missionTeamId}/report
    func getMissionTeamReport(missionId: Int, missionTeamId: Int) async throws -> MissionTeamReportResponse {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/teams/\(missionTeamId)/report") else {
            throw URLError(.badURL)
        }

        print("[MissionService] → GET \(url.absoluteString)")
        let data = try await send(authorizedRequest(url: url))
        return try JSONDecoder().decode(MissionTeamReportResponse.self, from: data)
    }

    // MARK: - PUT /operations/missions/{missionId}/teams/{missionTeamId}/report-draft
    func saveMissionTeamReportDraft(missionId: Int, missionTeamId: Int, request: SaveMissionTeamReportDraftRequest) async throws -> MissionTeamReportResponse {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/teams/\(missionTeamId)/report-draft") else {
            throw URLError(.badURL)
        }

        var req = authorizedRequest(url: url, method: "PUT")
        req.httpBody = try JSONEncoder().encode(request)
        print("[MissionService] → PUT \(url.absoluteString)")
        let data = try await send(req)
        return try JSONDecoder().decode(MissionTeamReportResponse.self, from: data)
    }

    // MARK: - POST /operations/missions/{missionId}/teams/{missionTeamId}/report-submit
    func submitMissionTeamReport(missionId: Int, missionTeamId: Int, request: SubmitMissionTeamReportRequest) async throws -> MissionTeamReportResponse {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/teams/\(missionTeamId)/report-submit") else {
            throw URLError(.badURL)
        }

        var req = authorizedRequest(url: url, method: "POST")
        req.httpBody = try JSONEncoder().encode(request)
        print("[MissionService] → POST \(url.absoluteString)")
        let data = try await send(req)
        return try JSONDecoder().decode(MissionTeamReportResponse.self, from: data)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
