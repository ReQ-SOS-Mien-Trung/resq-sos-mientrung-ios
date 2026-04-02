import Foundation

final class RescueTeamService {
    static let shared = RescueTeamService()

    enum RescueTeamServiceError: LocalizedError {
        case invalidURL
        case notAuthenticated
        case httpError(status: Int, message: String)
        case decodingError(Error)
        case network(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "URL không hợp lệ"
            case .notAuthenticated:
                return "Bạn chưa đăng nhập"
            case .httpError(let status, let message):
                return message.isEmpty ? "Máy chủ trả về lỗi \(status)" : message
            case .decodingError:
                return "Không đọc được dữ liệu phản hồi từ máy chủ"
            case .network(let error):
                return error.localizedDescription
            }
        }
    }

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

    private struct CheckInRequestBody: Codable {
        let latitude: Double
        let longitude: Double
    }

    // MARK: - GET /personnel/rescue-teams/my
    func getMyTeam() async throws -> RescueTeam {
        guard let url = URL(string: "\(baseURL)/personnel/rescue-teams/my") else {
            throw RescueTeamServiceError.invalidURL
        }

        guard let auth = authHeader else {
            throw RescueTeamServiceError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        print("[RescueTeamService] → GET \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                let backendMessage = Self.extractBackendErrorMessage(from: data)
                print("[RescueTeamService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                throw RescueTeamServiceError.httpError(status: statusCode, message: backendMessage)
            }

            do {
                return try JSONDecoder().decode(RescueTeam.self, from: data)
            } catch {
                throw RescueTeamServiceError.decodingError(error)
            }
        } catch let serviceError as RescueTeamServiceError {
            throw serviceError
        } catch {
            throw RescueTeamServiceError.network(error)
        }
    }

    // MARK: - POST /personnel/rescue-teams/{id}/set-available
    func setTeamAvailable(teamId: Int) async throws -> String? {
        try await updateTeamAvailability(teamId: teamId, action: "set-available")
    }

    // MARK: - POST /personnel/rescue-teams/{id}/set-unavailable
    func setTeamUnavailable(teamId: Int) async throws -> String? {
        try await updateTeamAvailability(teamId: teamId, action: "set-unavailable")
    }

    // MARK: - POST /personnel/assembly-point/events/{eventId}/check-in
    func checkIn(eventId: Int, latitude: Double, longitude: Double) async throws -> CheckInResponse {
        guard let url = URL(string: "\(baseURL)/personnel/assembly-point/events/\(eventId)/check-in") else {
            throw RescueTeamServiceError.invalidURL
        }

        guard let auth = authHeader else {
            throw RescueTeamServiceError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            CheckInRequestBody(latitude: latitude, longitude: longitude)
        )

        print("[RescueTeamService] → POST \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                let backendMessage = Self.extractBackendErrorMessage(from: data)
                print("[RescueTeamService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                throw RescueTeamServiceError.httpError(status: statusCode, message: backendMessage)
            }

            return (try? JSONDecoder().decode(CheckInResponse.self, from: data))
                ?? CheckInResponse(message: "Check-in thành công")
        } catch let serviceError as RescueTeamServiceError {
            throw serviceError
        } catch {
            throw RescueTeamServiceError.network(error)
        }
    }

    private func updateTeamAvailability(teamId: Int, action: String) async throws -> String? {
        guard let url = URL(string: "\(baseURL)/personnel/rescue-teams/\(teamId)/\(action)") else {
            throw RescueTeamServiceError.invalidURL
        }

        guard let auth = authHeader else {
            throw RescueTeamServiceError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(auth, forHTTPHeaderField: "Authorization")

        print("[RescueTeamService] → POST \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                let backendMessage = Self.extractBackendErrorMessage(from: data)
                print("[RescueTeamService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                throw RescueTeamServiceError.httpError(status: statusCode, message: backendMessage)
            }

            return Self.extractBackendSuccessMessage(from: data)
        } catch let serviceError as RescueTeamServiceError {
            throw serviceError
        } catch {
            throw RescueTeamServiceError.network(error)
        }
    }

    // MARK: - GET /personnel/assembly-point/{id}/events
    func resolveCheckInEventId(assemblyPointId: Int, preferredEventId: Int?) async throws -> Int {
        let events = try await getAssemblyPointEvents(assemblyPointId: assemblyPointId)

        if let preferredEventId,
           events.contains(where: { $0.eventId == preferredEventId }) {
            return preferredEventId
        }

        if let gatheringEvent = events.first(where: { normalizedStatus($0.eventStatus) == "gathering" }) {
            return gatheringEvent.eventId
        }

        if let ongoingEvent = events.first(where: { normalizedStatus($0.eventStatus) == "ongoing" }) {
            return ongoingEvent.eventId
        }

        if let plannedEvent = upcomingOrLatestEvent(from: events) {
            return plannedEvent.eventId
        }

        throw RescueTeamServiceError.httpError(
            status: 404,
            message: "Không tìm thấy sự kiện tập trung hợp lệ cho điểm tập kết này"
        )
    }

    private func getAssemblyPointEvents(assemblyPointId: Int, pageNumber: Int = 1, pageSize: Int = 10) async throws -> [AssemblyPointEvent] {
        guard var components = URLComponents(string: "\(baseURL)/personnel/assembly-point/\(assemblyPointId)/events") else {
            throw RescueTeamServiceError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "pageNumber", value: String(pageNumber)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]

        guard let url = components.url else {
            throw RescueTeamServiceError.invalidURL
        }

        guard let auth = authHeader else {
            throw RescueTeamServiceError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(auth, forHTTPHeaderField: "Authorization")

        print("[RescueTeamService] → GET \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                let backendMessage = Self.extractBackendErrorMessage(from: data)
                print("[RescueTeamService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                throw RescueTeamServiceError.httpError(status: statusCode, message: backendMessage)
            }

            do {
                let page = try JSONDecoder().decode(AssemblyPointEventsPage.self, from: data)
                return page.items
            } catch {
                throw RescueTeamServiceError.decodingError(error)
            }
        } catch let serviceError as RescueTeamServiceError {
            throw serviceError
        } catch {
            throw RescueTeamServiceError.network(error)
        }
    }

    // MARK: - GET /personnel/assembly-point/events/my
    func getMyAssemblyPointEvents(pageNumber: Int = 1, pageSize: Int = 10) async throws -> AssemblyPointEventsPage {
        guard var components = URLComponents(string: "\(baseURL)/personnel/assembly-point/events/my") else {
            throw RescueTeamServiceError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "pageNumber", value: String(pageNumber)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]

        guard let url = components.url else {
            throw RescueTeamServiceError.invalidURL
        }

        guard let auth = authHeader else {
            throw RescueTeamServiceError.notAuthenticated
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(auth, forHTTPHeaderField: "Authorization")

        print("[RescueTeamService] → GET \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard (200...299).contains(statusCode) else {
                let backendMessage = Self.extractBackendErrorMessage(from: data)
                print("[RescueTeamService] ✗ HTTP \(statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                throw RescueTeamServiceError.httpError(status: statusCode, message: backendMessage)
            }

            do {
                return try JSONDecoder().decode(AssemblyPointEventsPage.self, from: data)
            } catch {
                throw RescueTeamServiceError.decodingError(error)
            }
        } catch let serviceError as RescueTeamServiceError {
            throw serviceError
        } catch {
            throw RescueTeamServiceError.network(error)
        }
    }

    private func normalizedStatus(_ status: String?) -> String {
        (status ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func upcomingOrLatestEvent(from events: [AssemblyPointEvent]) -> AssemblyPointEvent? {
        guard events.isEmpty == false else { return nil }

        let now = Date()
        let datedEvents = events.map { ($0, parseISODate($0.assemblyDate) ?? Date.distantPast) }
        let futureEvents = datedEvents
            .filter { $0.1 >= now }
            .sorted { $0.1 < $1.1 }

        if let nearestFuture = futureEvents.first?.0 {
            return nearestFuture
        }

        return datedEvents
            .sorted { $0.1 > $1.1 }
            .first?.0
    }

    private func parseISODate(_ rawValue: String?) -> Date? {
        guard let rawValue, rawValue.isEmpty == false else { return nil }

        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoNoFraction = ISO8601DateFormatter()
        isoNoFraction.formatOptions = [.withInternetDateTime]

        return isoWithFraction.date(from: rawValue) ?? isoNoFraction.date(from: rawValue)
    }

    private static func extractBackendErrorMessage(from data: Data) -> String {
        guard !data.isEmpty else { return "" }

        if let decoded = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
           decoded.message.isEmpty == false {
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

    private static func extractBackendSuccessMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let decoded = try? JSONDecoder().decode(CheckInResponse.self, from: data),
           let message = decoded.message,
           message.isEmpty == false {
            return message
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["message", "detail", "title"] {
                if let value = object[key] as? String, value.isEmpty == false {
                    return value
                }
            }
        }

        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           text.isEmpty == false {
            return text
        }

        return nil
    }
}
