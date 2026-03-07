import Foundation

// Note: SOSPacket.swift contains the unified data structures used for the API:
// - SOSLocation, SOSPeopleCount, SOSStructuredData, SOSNetworkMetadata, SOSSenderInfo
// - SOSPacket  →  POST /emergency/sos-requests

final class APIService {
    static let shared = APIService()

    private let baseURL: String
    private let session: URLSession

    private init() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "https://resq.somee.com"
        self.baseURL = configured
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - POST /emergency/sos-requests
    /// - Parameter relayingFor: userId gốc của người tạo SOS (khi thiết bị này chỉ relay)
    func uploadSOS(packet: SOSPacket, relayingFor originalUserId: String? = nil) async -> Bool {
        guard let url = URL(string: "\(baseURL)/emergency/sos-requests") else {
            print("[API] ✗ Invalid URL: \(baseURL)/emergency/sos-requests")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Debug token
        let token = AuthSessionStore.shared.session?.accessToken
        let sessionValid = AuthSessionStore.shared.isValid
        print("[API] 🔑 session=\(AuthSessionStore.shared.session != nil ? "exists" : "NIL"), valid=\(sessionValid), token=\(token != nil ? "✅ present" : "❌ NIL")")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("[API] ⚠️ No access token – request will be rejected with 401")
        }

        // Khi relay thay người khác: thêm header để BE biết userId gốc
        if let originalUserId = originalUserId {
            request.setValue(originalUserId, forHTTPHeaderField: "X-Relay-For")
            print("[API] 🔁 Relaying for original user: \(originalUserId)")
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(packet)
            request.httpBody = jsonData
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "<unreadable>"
            print("[API] ➜ POST \(url.absoluteString)")
            print("[API] 📤 Request JSON:\n\(jsonString)")

            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            if (200...299).contains(statusCode) {
                print("[API] ✅ SOS uploaded (HTTP \(statusCode))")
                return true
            } else {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("[API] ✗ HTTP \(statusCode): \(body)")
                return false
            }
        } catch {
            print("[API] ✗ \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Convenience: upload từ SOSPacketEnhanced
    func uploadSOS(enhanced packet: SOSPacketEnhanced, relayingFor originalUserId: String? = nil) async -> Bool {
        await uploadSOS(packet: packet.toBasicPacket(), relayingFor: originalUserId)
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
        guard let token = AuthSessionStore.shared.session?.accessToken else {
            print("[API] ⚠️ No token – skip fetchMySOS")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            print("[API] ➜ GET \(url.absoluteString)")
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
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
}
