import Foundation

final class RescueTeamService {
    static let shared = RescueTeamService()

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

    // MARK: - GET /personnel/rescue-teams/my
    func getMyTeam() async throws -> RescueTeam {
        guard let url = URL(string: "\(baseURL)/personnel/rescue-teams/my") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let auth = authHeader { request.setValue(auth, forHTTPHeaderField: "Authorization") }
        print("[RescueTeamService] → GET \(url.absoluteString)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            print("[RescueTeamService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(RescueTeam.self, from: data)
    }

    // MARK: - POST /personnel/rescue-teams/{teamId}/members/check-in
    func checkIn(teamId: Int) async throws -> CheckInResponse {
        guard let url = URL(string: "\(baseURL)/personnel/rescue-teams/\(teamId)/members/check-in") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let auth = authHeader { request.setValue(auth, forHTTPHeaderField: "Authorization") }
        print("[RescueTeamService] → POST \(url.absoluteString)")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(statusCode) else {
            print("[RescueTeamService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return (try? JSONDecoder().decode(CheckInResponse.self, from: data)) ?? CheckInResponse(message: "OK")
    }
}
