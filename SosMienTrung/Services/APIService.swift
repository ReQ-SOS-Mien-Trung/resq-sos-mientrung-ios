import Foundation

// Note: SOSPacket.swift contains the unified data structures used for the API:
// - SOSLocation, SOSPeopleCount, SOSStructuredData, SOSNetworkMetadata, SOSSenderInfo
// - SOSPacket  →  POST /emergency/sos-requests

final class APIService {
    static let shared = APIService()

    struct SOSUploadResult {
        let isSuccess: Bool
        let statusCode: Int?
        let errorMessage: String?
    }

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

    private func authorizedRequest(
        url: URL,
        method: String,
        includeJSONContentType: Bool = false
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if includeJSONContentType {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func extractBackendErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let decoded = APIErrorResponse.decode(from: data), let msg = decoded.displayMessage, !msg.isEmpty {
            return msg
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["message", "error", "detail", "title"] {
                if let value = object[key] as? String {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty == false {
                        return trimmed
                    }
                }
            }
        }

        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return trimmed
            }
        }

        return nil
    }

    // MARK: - POST /emergency/sos-requests
    /// - Parameter relayingFor: userId gốc của người tạo SOS (khi thiết bị này chỉ relay)
    func uploadSOS(packet: SOSPacket, relayingFor originalUserId: String? = nil) async -> Bool {
        let result = await uploadSOSResult(packet: packet, relayingFor: originalUserId)
        return result.isSuccess
    }

    /// Phiên bản trả về chi tiết lỗi backend để hiển thị trên UI khi cần.
    func uploadSOSResult(packet: SOSPacket, relayingFor originalUserId: String? = nil) async -> SOSUploadResult {
        guard let url = URL(string: "\(baseURL)/emergency/sos-requests") else {
            print("[API] ✗ Invalid URL: \(baseURL)/emergency/sos-requests")
            return SOSUploadResult(isSuccess: false, statusCode: nil, errorMessage: "Invalid SOS endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Debug token
        let token = AuthSessionStore.shared.session?.accessToken
        let sessionValid = AuthSessionStore.shared.hasFreshAccessToken
        print("[API] 🔑 session=\(AuthSessionStore.shared.session != nil ? "exists" : "NIL"), valid=\(sessionValid), token=\(token != nil ? "✅ present" : "❌ NIL")")
        if token == nil {
            print("[API] ⚠️ No access token – request will be rejected with 401")
        }

        // Khi relay thay người khác: thêm header để BE biết userId gốc
        if let originalUserId = originalUserId {
            request.setValue(originalUserId, forHTTPHeaderField: "X-Relay-For")
            print("[API] 🔁 Relaying for original user: \(originalUserId)")
        }

        do {
            let encoder = makeEncoder()
            let jsonData = try encoder.encode(packet)
            request.httpBody = jsonData
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "<unreadable>"
            print("[API] ➜ POST \(url.absoluteString)")
            print("[API] 📤 Request JSON:\n\(jsonString)")

            let (data, response) = try await authExecutor.perform(request, using: session)
            let statusCode = response.statusCode

            if (200...299).contains(statusCode) {
                print("[API] ✅ SOS uploaded (HTTP \(statusCode))")
                return SOSUploadResult(isSuccess: true, statusCode: statusCode, errorMessage: nil)
            } else {
                let backendMessage = Self.extractBackendErrorMessage(from: data)
                if let backendMessage {
                    print("[API] ✗ HTTP \(statusCode): \(backendMessage)")
                } else {
                    print("[API] ✗ HTTP \(statusCode): <empty body>")
                }
                return SOSUploadResult(
                    isSuccess: false,
                    statusCode: statusCode,
                    errorMessage: backendMessage
                )
            }
        } catch {
            print("[API] ✗ \(error.localizedDescription)")
            return SOSUploadResult(
                isSuccess: false,
                statusCode: nil,
                errorMessage: error.localizedDescription
            )
        }
    }

    // MARK: - Convenience: upload từ SOSPacketEnhanced
    func uploadSOS(enhanced packet: SOSPacketEnhanced, relayingFor originalUserId: String? = nil) async -> Bool {
        await uploadSOS(packet: packet.toBasicPacket(), relayingFor: originalUserId)
    }

    func uploadSOSResult(enhanced packet: SOSPacketEnhanced, relayingFor originalUserId: String? = nil) async -> SOSUploadResult {
        await uploadSOSResult(packet: packet.toBasicPacket(), relayingFor: originalUserId)
    }

    // Completion-based version (legacy support)
    func uploadSOS(packet: SOSPacket, completion: @escaping (Bool) -> Void) {
        Task {
            let result = await uploadSOS(packet: packet)
            await MainActor.run { completion(result) }
        }
    }
    
    // MARK: - GET /emergency/sos-requests/me
    func fetchMySOS() async -> [SOSServerRecord]? {
        guard let url = URL(string: "\(baseURL)/emergency/sos-requests/me") else {
            print("[API] ✗ Invalid URL for fetchMySOS")
            return nil
        }
        let request = authorizedRequest(url: url, method: "GET")
        
        do {
            print("[API] ➜ GET \(url.absoluteString)")
            let (data, response) = try await authExecutor.perform(request, using: session)
            let statusCode = response.statusCode
            guard (200...299).contains(statusCode) else {
                print("[API] ✗ fetchMySOS HTTP \(statusCode)")
                return nil
            }
            let rawResponse = String(data: data, encoding: .utf8) ?? "<unreadable>"
            print("[API] 📥 fetchMySOS Response JSON:\n\(rawResponse)")
            let result = try JSONDecoder().decode(SOSServerResponse.self, from: data)
            print("[API] ✅ fetchMySOS: \(result.sosRequests.count) records")
            return result.sosRequests
        } catch {
            print("[API] ✗ fetchMySOS: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - GET /emergency/sos-requests/{id}
    func getSosRequestDetail(id: Int) async -> SOSServerRecord? {
        guard let url = URL(string: "\(baseURL)/emergency/sos-requests/\(id)") else {
            print("[API] ✗ Invalid URL for getSosRequestDetail")
            return nil
        }
        let request = authorizedRequest(url: url, method: "GET")

        do {
            print("[API] ➜ GET \(url.absoluteString)")
            let (data, response) = try await authExecutor.perform(request, using: session)
            let statusCode = response.statusCode
            guard (200...299).contains(statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("[API] ✗ getSosRequestDetail HTTP \(statusCode): \(body)")
                return nil
            }

            let result = try JSONDecoder().decode(SosRequestDetailResponse.self, from: data)
            return result.sosRequest
        } catch {
            print("[API] ✗ getSosRequestDetail: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - PATCH /emergency/sos-requests/{id}/victim-update
    func updateVictimSosRequest(
        id: Int,
        packet: SOSPacket
    ) async -> UpdateVictimSosRequestResponse? {
        guard let url = URL(string: "\(baseURL)/emergency/sos-requests/\(id)/victim-update") else {
            print("[API] ✗ Invalid URL for updateVictimSosRequest")
            return nil
        }
        var request = authorizedRequest(
            url: url,
            method: "PATCH",
            includeJSONContentType: true
        )

        do {
            let jsonData = try makeEncoder().encode(packet)
            request.httpBody = jsonData
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "<unreadable>"
            print("[API] ➜ PATCH \(url.absoluteString)")
            print("[API] 📤 Victim update JSON:\n\(jsonString)")

            let (data, response) = try await authExecutor.perform(request, using: session)
            let statusCode = response.statusCode
            guard (200...299).contains(statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("[API] ✗ victim-update HTTP \(statusCode): \(body)")
                return nil
            }

            let result = try JSONDecoder().decode(UpdateVictimSosRequestResponse.self, from: data)
            print("[API] ✅ victim-update success for SOS #\(result.sosRequestId)")
            return result
        } catch {
            print("[API] ✗ victim-update: \(error.localizedDescription)")
            return nil
        }
    }
}
