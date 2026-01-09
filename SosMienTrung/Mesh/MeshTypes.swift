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
