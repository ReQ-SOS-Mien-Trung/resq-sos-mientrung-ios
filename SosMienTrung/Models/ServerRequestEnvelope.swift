import Foundation

enum ServerRequestType: String, Codable {
    case sosBasic
    case sosEnhanced
}

struct ServerRequestEnvelope: Codable {
    let requestId: String
    let originDeviceId: String
    let timestamp: Int64
    let type: ServerRequestType
    let hopCount: Int
    let path: [String]
    let sosPacket: SOSPacket?
    let sosEnhanced: SOSPacketEnhanced?

    static func basicSOS(_ packet: SOSPacket) -> ServerRequestEnvelope {
        ServerRequestEnvelope(
            requestId: packet.packetId,
            originDeviceId: packet.originId,
            timestamp: packet.ts,
            type: .sosBasic,
            hopCount: packet.hopCount,
            path: packet.path,
            sosPacket: packet,
            sosEnhanced: nil
        )
    }

    static func enhancedSOS(_ packet: SOSPacketEnhanced) -> ServerRequestEnvelope {
        ServerRequestEnvelope(
            requestId: packet.packetId,
            originDeviceId: packet.originId,
            timestamp: packet.ts,
            type: .sosEnhanced,
            hopCount: packet.hopCount,
            path: packet.path,
            sosPacket: nil,
            sosEnhanced: packet
        )
    }

    func relayed(by relayId: String) -> ServerRequestEnvelope {
        var updatedPath = path
        if !updatedPath.contains(relayId) {
            updatedPath.append(relayId)
        }
        return ServerRequestEnvelope(
            requestId: requestId,
            originDeviceId: originDeviceId,
            timestamp: timestamp,
            type: type,
            hopCount: hopCount + 1,
            path: updatedPath,
            sosPacket: sosPacket?.relayed(by: relayId),
            sosEnhanced: sosEnhanced?.relayed(by: relayId)
        )
    }
}

struct ServerRequestAck: Codable {
    let requestId: String
    let originDeviceId: String
    let success: Bool
    let timestamp: Int64
}
