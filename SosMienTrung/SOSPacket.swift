import Foundation

/// Packet format cho Mock server
struct SOSPacket: Codable {
    let packetId: String       // UUID v4
    let originId: String       // Device ID của người gửi gốc
    let ts: Int64              // Unix timestamp
    let loc: String            // "lat,long" format
    let msg: String            // Tin nhắn SOS
    var hopCount: Int          // Số lần relay
    var path: [String]         // Danh sách device đã relay

    enum CodingKeys: String, CodingKey {
        case packetId = "packet_id"
        case originId = "origin_id"
        case ts
        case loc
        case msg
        case hopCount = "hop_count"
        case path
    }

    init(
        packetId: String = UUID().uuidString,
        originId: String,
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        message: String,
        hopCount: Int = 0,
        path: [String] = []
    ) {
        self.packetId = packetId
        self.originId = originId
        self.ts = Int64(timestamp.timeIntervalSince1970)
        self.loc = "\(latitude),\(longitude)"
        self.msg = message
        self.hopCount = hopCount
        self.path = path.isEmpty ? [originId] : path
    }

    /// Tạo packet mới với hop count tăng lên và thêm relay ID vào path
    func relayed(by relayId: String) -> SOSPacket {
        var newPath = path
        if !newPath.contains(relayId) {
            newPath.append(relayId)
        }
        return SOSPacket(
            packetId: packetId,
            originId: originId,
            ts: ts,
            loc: loc,
            msg: msg,
            hopCount: hopCount + 1,
            path: newPath
        )
    }

    private init(packetId: String, originId: String, ts: Int64, loc: String, msg: String, hopCount: Int, path: [String]) {
        self.packetId = packetId
        self.originId = originId
        self.ts = ts
        self.loc = loc
        self.msg = msg
        self.hopCount = hopCount
        self.path = path
    }
}

/// Message type để phân biệt SOS relay packet
enum MeshMessageType: String, Codable {
    case chat           // Tin nhắn chat thường
    case sosLocation    // SOS từ local
    case sosRelay       // SOS packet cần relay lên server
    case userInfo       // User profile
}

/// Wrapper cho tất cả các loại tin nhắn qua mesh
struct MeshPayload: Codable {
    let meshType: MeshMessageType
    let chatPayload: MessagePayload?
    let sosPacket: SOSPacket?

    init(chatPayload: MessagePayload) {
        self.meshType = chatPayload.type == .sosLocation ? .sosLocation :
                        chatPayload.type == .userInfo ? .userInfo : .chat
        self.chatPayload = chatPayload
        self.sosPacket = nil
    }

    init(sosPacket: SOSPacket) {
        self.meshType = .sosRelay
        self.chatPayload = nil
        self.sosPacket = sosPacket
    }
}
