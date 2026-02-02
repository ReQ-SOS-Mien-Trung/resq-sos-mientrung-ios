import Foundation

// Note: SOSPacket.swift contains the canonical data structures:
// - PeopleCountData
// - MedicalIssueInfo
// - InjuredPersonInfo
// - RescueSituationInfo
// - RescueDataInfo
// - ReliefDataInfo
// - AutoCollectedInfoData

// MARK: - Legacy SOS Upload Payload (for backward compatibility)
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

    // MARK: - Upload SOS Packet with Full Form Details
    func uploadDetailedSOS(packet: SOSPacket, completion: @escaping (Bool) -> Void) {
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
                print("[API] Uploading Detailed SOS packet:")
                print(jsonString)
            }

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("[API] Upload failed: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                if statusCode == 201 || statusCode == 200 {
                    print("[API] Upload succeeded.")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("[API] Server response: \(responseString)")
                    }
                    completion(true)
                } else {
                    print("[API] Upload returned status code \(statusCode).")
                    completion(false)
                }
            }
            task.resume()
        } catch {
            print("[API] Failed to encode SOS packet: \(error)")
            completion(false)
        }
    }

    // MARK: - Upload Legacy SOS
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
            ts: Int(packet.ts),
            loc: packet.loc,
            msg: packet.msg,
            hopCount: packet.hopCount,
            path: packet.path
        )
        uploadSOS(payload: payload, completion: completion)
    }
}
