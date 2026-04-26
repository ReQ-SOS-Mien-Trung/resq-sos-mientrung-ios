import Foundation

final class IncidentService {
    static let shared = IncidentService()

    private let baseURL: String
    private let session: URLSession
    private let authExecutor = AuthenticatedRequestExecutor.shared

    private init() {
        self.baseURL = AppConfig.baseURLString
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    private func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    private func postIncident<Request: Encodable>(url: URL, payload: Request) async throws -> IncidentResponse {
        var req = authorizedRequest(url: url, method: "POST")
        req.httpBody = try JSONEncoder().encode(payload)
        print("[IncidentService] → POST \(url.absoluteString)")
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await authExecutor.perform(req, using: session)
        } catch {
            print("[IncidentService] ✗ Request failed: \(error.localizedDescription)")
            throw error
        }

        let statusCode = response.statusCode
        guard (200...299).contains(statusCode) else {
            print("[IncidentService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw backendError(statusCode: statusCode, data: data)
        }

        do {
            let decoded = try JSONDecoder().decode(IncidentResponse.self, from: data)
            print("[IncidentService] ✓ HTTP \(statusCode): incident #\(decoded.incidentId)")
            return decoded
        } catch {
            print("[IncidentService] ✗ Decode failed: \(error.localizedDescription). Raw: \(String(data: data, encoding: .utf8) ?? "")")
            throw error
        }
    }

    // MARK: - POST /operations/missions/{missionId}/teams/{missionTeamId}/incident
    func reportMissionTeamIncident(
        missionId: Int,
        missionTeamId: Int,
        request: MissionIncidentReportRequest
    ) async throws -> IncidentResponse {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/teams/\(missionTeamId)/incident") else {
            throw URLError(.badURL)
        }

        return try await postIncident(url: url, payload: try request.asAPIRequest())
    }

    // MARK: - POST /operations/missions/{missionId}/teams/{missionTeamId}/activity-incident
    func reportTeamActivityIncident(
        missionId: Int,
        missionTeamId: Int,
        request: ActivityIncidentReportRequest
    ) async throws -> IncidentResponse {
        guard let url = URL(string: "\(baseURL)/operations/missions/\(missionId)/teams/\(missionTeamId)/activity-incident") else {
            throw URLError(.badURL)
        }

        return try await postIncident(url: url, payload: try request.asAPIRequest())
    }

    // MARK: - GET /operations/team-incidents/by-mission/{missionId}
    func getIncidents(missionId: Int) async throws -> [Incident] {
        guard let url = URL(string: "\(baseURL)/operations/team-incidents/by-mission/\(missionId)") else {
            throw URLError(.badURL)
        }
        print("[IncidentService] → GET \(url.absoluteString)")
        let (data, response) = try await authExecutor.perform(authorizedRequest(url: url), using: session)
        let statusCode = response.statusCode
        guard (200...299).contains(statusCode) else {
            throw backendError(statusCode: statusCode, data: data)
        }
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
        let (data, response) = try await authExecutor.perform(req, using: session)
        let statusCode = response.statusCode
        guard (200...299).contains(statusCode) else {
            print("[IncidentService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw backendError(statusCode: statusCode, data: data)
        }
    }

    private func backendError(statusCode: Int, data: Data) -> Error {
        let message = extractBackendErrorMessage(from: data)
        if message.isEmpty {
            return IncidentServiceError.backend("Máy chủ trả về lỗi \(statusCode).")
        }
        return IncidentServiceError.backend(message)
    }

    private func extractBackendErrorMessage(from data: Data) -> String {
        guard !data.isEmpty else { return "" }

        if let decoded = APIErrorResponse.decode(from: data), decoded.message.isEmpty == false {
            return decoded.message
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["message", "error", "detail", "title"] {
                if let value = object[key] as? String, value.isEmpty == false {
                    return value
                }
            }
        }

        return String(data: data, encoding: .utf8) ?? ""
    }
}

private enum IncidentServiceError: LocalizedError {
    case backend(String)

    var errorDescription: String? {
        switch self {
        case let .backend(message):
            return message
        }
    }
}
