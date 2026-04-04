import Foundation

enum MissionServiceError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Phan hoi may chu khong hop le"
        case .httpStatus(let statusCode, let message):
            return message ?? "May chu tra ve loi (HTTP \(statusCode))"
        }
    }
}

final class MissionService {
    static let shared = MissionService()

    private let baseURL: String
    private let session: URLSession

    private init() {
        self.baseURL = AppConfig.baseURLString
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    private var authHeader: String? {
        guard let token = AuthSessionStore.shared.session?.accessToken else { return nil }
        return "Bearer \(token)"
    }

    private func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let auth = authHeader { req.setValue(auth, forHTTPHeaderField: "Authorization") }
        return req
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MissionServiceError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let message = APIErrorResponse.decode(from: data)?.message
                ?? String(data: data, encoding: .utf8)
            print("[MissionService] ✗ HTTP \(http.statusCode): \(message ?? "")")
            throw MissionServiceError.httpStatus(http.statusCode, message)
        }

        return data
    }

    // MARK: - GET /operations/missions/my-team
    func getMyTeamMissions() async throws -> [Mission] {
        guard let url = URL(string: "\(baseURL)/operations/missions/my-team") else {
            throw URLError(.badURL)
        }
        print("[MissionService] → GET \(url.absoluteString)")
        let (data, response) = try await session.data(for: authorizedRequest(url: url))
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            print("[MissionService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(MissionListResponse.self, from: data).missions
    }

    // MARK: - GET /operations/missions/{missionId}
    func getMission(missionId: Int) async throws -> Mission {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)") else {
            throw URLError(.badURL)
        }
        print("[MissionService] → GET \(url.absoluteString)")
        let (data, response) = try await session.data(for: authorizedRequest(url: url))
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Mission.self, from: data)
    }

    // MARK: - GET /operations/missions/{missionId}/activities/my-team
    func getMyTeamActivities(missionId: Int) async throws -> [Activity] {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/activities/my-team") else {
            throw URLError(.badURL)
        }
        print("[MissionService] → GET \(url.absoluteString)")
        let (data, response) = try await session.data(for: authorizedRequest(url: url))
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([Activity].self, from: data)
    }

    // MARK: - Backward-compatible wrapper
    func getActivities(missionId: Int) async throws -> [Activity] {
        try await getMyTeamActivities(missionId: missionId)
    }

    // MARK: - PATCH /operations/missions/{missionId}/activities/{activityId}/status
    /// Valid status values: Planned, OnGoing, Succeed, Failed, Cancelled
    func updateActivityStatus(missionId: Int, activityId: Int, status: String) async throws {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/activities/\(activityId)/status") else {
            throw URLError(.badURL)
        }
        var req = authorizedRequest(url: url, method: "PATCH")
        req.httpBody = try JSONEncoder().encode(ActivityStatusUpdate(status: status))
        print("[MissionService] → PATCH \(url.absoluteString) status=\(status)")
        let (data, response) = try await session.data(for: req)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            print("[MissionService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - GET /operations/missions/{missionId}/activities/{activityId}/route
    func getActivityRoute(missionId: Int, activityId: Int, originLat: Double, originLng: Double, vehicle: String = "car") async throws -> ActivityRoute {
        let urlStr = "\(baseURL)/operations/missions/\(missionId)/activities/\(activityId)/route?originLat=\(originLat)&originLng=\(originLng)&vehicle=\(vehicle)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        print("[MissionService] → GET \(url.absoluteString)")
        let (data, response) = try await session.data(for: authorizedRequest(url: url))
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(ActivityRoute.self, from: data)
    }

    // MARK: - GET /operations/missions/{missionId}/teams/{missionTeamId}/route
    func getMissionTeamRoute(
        missionId: Int,
        missionTeamId: Int,
        originLat: Double,
        originLng: Double,
        vehicle: String = "car"
    ) async throws -> MissionTeamRoute {
        var components = URLComponents(string: "\(baseURL)/operations/missions/\(missionId)/teams/\(missionTeamId)/route")
        components?.queryItems = [
            URLQueryItem(name: "originLat", value: String(originLat)),
            URLQueryItem(name: "originLng", value: String(originLng)),
            URLQueryItem(name: "vehicle", value: vehicle)
        ]

        guard let url = components?.url else { throw URLError(.badURL) }
        print("[MissionService] → GET \(url.absoluteString)")

        let data = try await send(authorizedRequest(url: url))

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
