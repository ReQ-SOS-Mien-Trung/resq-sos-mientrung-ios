import Foundation

struct SOSUploadPayload: Codable {
    let packetId: String
    let originId: String
    let ts: Int
    let loc: String
    let msg: String
    let hopCount: Int
    let path: [String]

    enum CodingKeys: String, CodingKey {
        case packetId = "packet_id"
        case originId = "origin_id"
        case ts
        case loc
        case msg
        case hopCount = "hop_count"
        case path
    }
}

final class APIService {
    static let shared = APIService()

    // MockAPI URL (set to the value you provided)
    private let baseURL = "https://690cc857a6d92d83e84f5f9e.mockapi.io/api/ResQ/SOS"

    private init() {}

    func uploadSOS(payload: SOSUploadPayload, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: baseURL) else {
            print("[API] Invalid URL: \(baseURL)")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(payload)
            request.httpBody = jsonData

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("[API] Uploading SOS payload: \(jsonString)")
            }

            let task = URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    print("[API] Upload failed: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                if statusCode == 201 {
                    print("[API] Upload succeeded.")
                    completion(true)
                } else {
                    print("[API] Upload returned status code \(statusCode).")
                    completion(false)
                }
            }
            task.resume()
        } catch {
            print("[API] Failed to encode SOS payload: \(error)")
            completion(false)
        }
    }

    func uploadSOS(packet: SOSPacket, completion: @escaping (Bool) -> Void) {
        let payload = SOSUploadPayload(
            packetId: packet.packetId,
            originId: packet.originId,
            ts: Int(packet.timestamp),
            loc: packet.loc,
            msg: packet.msg,
            hopCount: packet.hopCount,
            path: packet.path
        )
        uploadSOS(payload: payload, completion: completion)
    }
}
