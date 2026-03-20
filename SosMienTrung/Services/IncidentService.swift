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

    // MARK: - POST /operations/team-incidents
    func reportIncident(_ request: ReportIncidentRequest) async throws -> IncidentResponse {
        guard let url = URL(string: "\(baseURL)/operations/team-incidents") else {
            throw URLError(.badURL)
        }
        var req = authorizedRequest(url: url, method: "POST")
        req.httpBody = try JSONEncoder().encode(request)
        print("[IncidentService] → POST \(url.absoluteString)")
        let (data, response) = try await session.data(for: req)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            print("[IncidentService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return (try? JSONDecoder().decode(IncidentResponse.self, from: data)) ?? IncidentResponse(id: nil, message: "OK")
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
        return try JSONDecoder().decode([Incident].self, from: data)
    }

    // MARK: - PATCH /operations/team-incidents/{incidentId}/status
    /// Valid status values: Reported, Acknowledged, InProgress, Resolved, Closed
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
