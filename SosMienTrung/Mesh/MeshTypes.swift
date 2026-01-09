import Foundation

enum PacketType: String, Codable {
    case heartbeat = "HEARTBEAT"
    case sos = "SOS"
}

struct MeshEnvelope: Codable {
    let type: PacketType
    let heartbeat: HeartbeatPayload?
    let sos: SOSPacket?

    static func heartbeat(_ payload: HeartbeatPayload) -> MeshEnvelope {
        MeshEnvelope(type: .heartbeat, heartbeat: payload, sos: nil)
    }

    static func sos(_ packet: SOSPacket) -> MeshEnvelope {
        MeshEnvelope(type: .sos, heartbeat: nil, sos: packet)
    }
}

struct HeartbeatPayload: Codable, Hashable {
    let senderId: String
    let level: Int
    let battery: Int
}

struct SOSPacket: Codable, Hashable {
    let packetId: String
    let originId: String
    let msg: String
    let loc: String
    var hopCount: Int
    var path: [String]
    let timestamp: TimeInterval

    var content: String {
        let payload = ["msg": msg, "loc": loc]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case packetId = "packet_id"
        case originId = "origin_id"
        case msg
        case loc
        case hopCount = "hop_count"
        case path
        case timestamp
    }
}

final class Neighbor {
    let id: String
    var level: Int
    var rssi: Int
    var lastSeen: TimeInterval

    init(id: String, level: Int, rssi: Int, lastSeen: TimeInterval) {
        self.id = id
        self.level = level
        self.rssi = rssi
        self.lastSeen = lastSeen
    }

    func update(level: Int, rssi: Int, lastSeen: TimeInterval) {
        self.level = level
        self.rssi = rssi
        self.lastSeen = lastSeen
    }
}
