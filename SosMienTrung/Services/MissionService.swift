import Foundation

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

    // MARK: - GET /operations/missions/{missionId}/activities
    func getActivities(missionId: Int) async throws -> [Activity] {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/activities") else {
            throw URLError(.badURL)
        }
        print("[MissionService] → GET \(url.absoluteString)")
        let (data, response) = try await session.data(for: authorizedRequest(url: url))
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([Activity].self, from: data)
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
}
