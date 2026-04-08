import Foundation

final class IncidentService {
    static let shared = IncidentService()

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

    private func postIncident<Request: Encodable>(url: URL, payload: Request) async throws -> IncidentResponse {
        var req = authorizedRequest(url: url, method: "POST")
        req.httpBody = try JSONEncoder().encode(payload)
        print("[IncidentService] → POST \(url.absoluteString)")
        let (data, response) = try await session.data(for: req)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            print("[IncidentService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(IncidentResponse.self, from: data)
    }

    // MARK: - POST /operations/missions/{missionId}/teams/{missionTeamId}/incident
    func reportMissionTeamIncident(
        missionId: Int,
        missionTeamId: Int,
        request: ReportMissionTeamIncidentRequest
    ) async throws -> IncidentResponse {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/teams/\(missionTeamId)/incident") else {
            throw URLError(.badURL)
        }

        return try await postIncident(url: url, payload: request)
    }

    // MARK: - POST /operations/missions/{missionId}/activities/{activityId}/incident
    func reportMissionActivityIncident(
        missionId: Int,
        activityId: Int,
        request: ReportMissionActivityIncidentRequest
    ) async throws -> IncidentResponse {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/activities/\(activityId)/incident") else {
            throw URLError(.badURL)
        }

        return try await postIncident(url: url, payload: request)
    }

    // MARK: - GET /operations/team-incidents/by-mission/{missionId}
    func getIncidents(missionId: Int) async throws -> [Incident] {
        guard let url = URL(string: "\(baseURL)/operations/team-incidents/by-mission/\(missionId)") else {
            throw URLError(.badURL)
        }
        print("[IncidentService] → GET \(url.absoluteString)")
        let (data, response) = try await session.data(for: authorizedRequest(url: url))
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(MissionIncidentsResponse.self, from: data).incidents
    }

    // MARK: - PATCH /operations/team-incidents/{incidentId}/status
    /// Valid status values: InProgress, Resolved
    func updateIncidentStatus(incidentId: Int, request: UpdateIncidentStatusRequest) async throws {
        guard let url = URL(string: "\(baseURL)/operations/team-incidents/\(incidentId)/status") else {
            throw URLError(.badURL)
        }
        var req = authorizedRequest(url: url, method: "PATCH")
        req.httpBody = try JSONEncoder().encode(request)
        print("[IncidentService] → PATCH \(url.absoluteString)")
        let (data, response) = try await session.data(for: req)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            print("[IncidentService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
    }
}
