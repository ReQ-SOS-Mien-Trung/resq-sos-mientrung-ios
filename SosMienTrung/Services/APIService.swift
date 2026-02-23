import Foundation

// Note: SOSPacket.swift contains the unified data structures used for the API:
// - SOSLocation, SOSPeopleCount, SOSStructuredData, SOSNetworkMetadata, SOSSenderInfo
// - SOSPacket  →  POST /emergency/sos-requests

final class APIService {
    static let shared = APIService()

    private let baseURL: String
    private let session: URLSession

    private init() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String ?? "http://localhost:8080"
        #if targetEnvironment(simulator)
        if let url = URL(string: configured),
           let host = url.host,
           host != "localhost" && host != "127.0.0.1" {
            self.baseURL = configured.replacingOccurrences(of: host, with: "localhost")
        } else {
            self.baseURL = configured
        }
        #else
        self.baseURL = configured
        #endif
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - POST /emergency/sos-requests
    func uploadSOS(packet: SOSPacket) async -> Bool {
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

        do {
            let jsonData = try JSONEncoder().encode(packet)
            request.httpBody = jsonData
            print("[API] ➜ POST \(url.absoluteString)")

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
    func uploadSOS(enhanced packet: SOSPacketEnhanced) async -> Bool {
        await uploadSOS(packet: packet.toBasicPacket())
    }

    // Completion-based version (legacy support)
    func uploadSOS(packet: SOSPacket, completion: @escaping (Bool) -> Void) {
        Task {
            let result = await uploadSOS(packet: packet)
            await MainActor.run { completion(result) }
        }
    }
}
