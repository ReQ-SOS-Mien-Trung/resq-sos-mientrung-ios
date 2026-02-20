import Foundation

// Note: SOSPacket.swift contains the unified data structures:
// - SOSLocation
// - SOSPeopleCount
// - SOSStructuredData
// - SOSNetworkMetadata
// - SOSPacket

final class APIService {
    static let shared = APIService()

    // MockAPI URL (set to the value you provided)
    private let baseURL = "https://690cc857a6d92d83e84f5f9e.mockapi.io/api/ResQ/SOS"

    private init() {}

    // MARK: - Upload SOS Packet (unified structure)
    func uploadSOS(packet: SOSPacket, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: baseURL) else {
            print("[API] Invalid URL: \(baseURL)")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(packet)
            request.httpBody = jsonData

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("[API] Uploading SOS packet:")
                print(jsonString)
            }

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("[API] Upload failed: \(error.localizedDescription)")
                    DispatchQueue.main.async { completion(false) }
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                if (200...299).contains(statusCode) {
                    print("[API] Upload succeeded with status \(statusCode).")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("[API] Server response: \(responseString)")
                    }
                    DispatchQueue.main.async { completion(true) }
                } else {
                    print("[API] Upload returned status code \(statusCode).")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("[API] Error response: \(responseString)")
                    }
                    DispatchQueue.main.async { completion(false) }
                }
            }
            task.resume()
        } catch {
            print("[API] Failed to encode SOS packet: \(error)")
            completion(false)
        }
    }
    
    // Async version
    func uploadSOS(packet: SOSPacket) async -> Bool {
        await withCheckedContinuation { continuation in
            uploadSOS(packet: packet) { success in
                continuation.resume(returning: success)
            }
        }
    }
}
