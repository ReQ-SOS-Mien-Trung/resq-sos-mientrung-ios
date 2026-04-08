import Foundation

enum ServerRequestType: String, Codable {
    case sosBasic
    case sosEnhanced
    case victimSosUpdate
}

struct VictimSosUpdateRelayPayload: Codable {
    let requestId: String
    let targetLocalSosId: String
    let serverSosRequestId: Int?
    let packet: SOSPacket
    let requesterUserId: String?
    let victimPhone: String?
    let reporterPhone: String?
    let packetId: String?
    let originId: String?
}

struct ServerRequestEnvelope: Codable {
    let requestId: String
    let originDeviceId: String
    let timestamp: Int64
    let type: ServerRequestType
    let hopCount: Int
    let path: [String]
    let targetLocalSosId: String?
    let serverSosRequestId: Int?
    let sosPacket: SOSPacket?
    let sosEnhanced: SOSPacketEnhanced?
    let victimSosUpdate: VictimSosUpdateRelayPayload?

    static func basicSOS(_ packet: SOSPacket) -> ServerRequestEnvelope {
        ServerRequestEnvelope(
            requestId: packet.packetId,
            originDeviceId: packet.originId,
            timestamp: packet.ts,
            type: .sosBasic,
            hopCount: packet.hopCount,
            path: packet.path,
            targetLocalSosId: packet.packetId,
            serverSosRequestId: nil,
            sosPacket: packet,
            sosEnhanced: nil,
            victimSosUpdate: nil
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
            targetLocalSosId: packet.packetId,
            serverSosRequestId: nil,
            sosPacket: nil,
            sosEnhanced: packet,
            victimSosUpdate: nil
        )
    }

    static func victimSosUpdate(
        requestId: String,
        targetLocalSosId: String,
        serverSosRequestId: Int?,
        packet: SOSPacket,
        requesterUserId: String?,
        victimPhone: String?,
        reporterPhone: String?
    ) -> ServerRequestEnvelope {
        let payload = VictimSosUpdateRelayPayload(
            requestId: requestId,
            targetLocalSosId: targetLocalSosId,
            serverSosRequestId: serverSosRequestId,
            packet: packet,
            requesterUserId: requesterUserId,
            victimPhone: victimPhone,
            reporterPhone: reporterPhone,
            packetId: packet.packetId,
            originId: packet.originId
        )

        return ServerRequestEnvelope(
            requestId: requestId,
            originDeviceId: packet.originId,
            timestamp: Int64(Date().timeIntervalSince1970),
            type: .victimSosUpdate,
            hopCount: packet.hopCount,
            path: packet.path,
            targetLocalSosId: targetLocalSosId,
            serverSosRequestId: serverSosRequestId,
            sosPacket: nil,
            sosEnhanced: nil,
            victimSosUpdate: payload
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
            targetLocalSosId: targetLocalSosId,
            serverSosRequestId: serverSosRequestId,
            sosPacket: sosPacket?.relayed(by: relayId),
            sosEnhanced: sosEnhanced?.relayed(by: relayId),
            victimSosUpdate: victimSosUpdate.map {
                VictimSosUpdateRelayPayload(
                    requestId: $0.requestId,
                    targetLocalSosId: $0.targetLocalSosId,
                    serverSosRequestId: $0.serverSosRequestId,
                    packet: $0.packet.relayed(by: relayId),
                    requesterUserId: $0.requesterUserId,
                    victimPhone: $0.victimPhone,
                    reporterPhone: $0.reporterPhone,
                    packetId: $0.packetId,
                    originId: $0.originId
                )
            }
        )
    }
}

struct ServerRequestAck: Codable {
    let requestId: String
    let originDeviceId: String
    let success: Bool
    let timestamp: Int64
    let requestType: ServerRequestType?
    let targetLocalSosId: String?
}
