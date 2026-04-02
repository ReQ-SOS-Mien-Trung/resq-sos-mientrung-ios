//
//  SOSPacketEnhanced.swift
//  SosMienTrung
//
//  Thin wrapper để giữ compatibility nội bộ quanh SOSPacket mới
//

import Foundation

struct SOSPacketEnhanced: Codable {
    let packet: SOSPacket
    let priorityScore: Int?

    enum CodingKeys: String, CodingKey {
        case packetId = "packet_id"
        case originId = "origin_id"
        case ts
        case createdAt = "created_at"
        case location
        case sosType = "sos_type"
        case msg
        case structuredData = "structured_data"
        case networkMetadata = "network_metadata"
        case victimInfo = "victim_info"
        case reporterInfo = "reporter_info"
        case isSentOnBehalf = "is_sent_on_behalf"
        case senderInfo = "sender_info"
        case priorityScore = "priority_score"
    }

    var packetId: String { packet.packetId }
    var originId: String { packet.originId }
    var ts: Int64 { packet.ts }
    var createdAt: String { packet.createdAt }
    var location: SOSLocation { packet.location }
    var msg: String { packet.msg }
    var hopCount: Int { packet.hopCount }
    var path: [String] { packet.path }
    var sosType: String? { packet.sosType }
    var structuredData: SOSStructuredData? { packet.structuredData }
    var victimInfo: SOSVictimInfo? { packet.victimInfo }
    var reporterInfo: SOSReporterInfo? { packet.reporterInfo }
    var isSentOnBehalf: Bool? { packet.isSentOnBehalf }
    var senderInfo: SOSSenderInfo? { packet.senderInfo }

    init(from formData: SOSFormData, originId: String, latitude: Double, longitude: Double) {
        self.packet = formData.toSOSPacket(originIdOverride: originId)
        self.priorityScore = formData.priorityScore
    }

    init(packet: SOSPacket, priorityScore: Int? = nil) {
        self.packet = packet
        self.priorityScore = priorityScore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let packetId = try container.decode(String.self, forKey: .packetId)
        let originId = try container.decode(String.self, forKey: .originId)
        let ts = try container.decode(Int64.self, forKey: .ts)
        let createdAt = try container.decode(String.self, forKey: .createdAt)
        let location = try container.decode(SOSLocation.self, forKey: .location)
        let sosType = try container.decodeIfPresent(String.self, forKey: .sosType)
        let msg = try container.decode(String.self, forKey: .msg)
        let structuredData = try container.decodeIfPresent(SOSStructuredData.self, forKey: .structuredData)
        let networkMetadata = try container.decodeIfPresent(SOSNetworkMetadata.self, forKey: .networkMetadata) ?? SOSNetworkMetadata()
        let victimInfo = try container.decodeIfPresent(SOSVictimInfo.self, forKey: .victimInfo)
        let reporterInfo = try container.decodeIfPresent(SOSReporterInfo.self, forKey: .reporterInfo)
        let isSentOnBehalf = try container.decodeIfPresent(Bool.self, forKey: .isSentOnBehalf)
        let senderInfo = try container.decodeIfPresent(SOSSenderInfo.self, forKey: .senderInfo)
        let priorityScore = try container.decodeIfPresent(Int.self, forKey: .priorityScore)

        self.packet = SOSPacket(
            packetId: packetId,
            originId: originId,
            ts: ts,
            createdAt: createdAt,
            location: location,
            sosType: sosType,
            msg: msg,
            structuredData: structuredData,
            networkMetadata: networkMetadata,
            victimInfo: victimInfo,
            reporterInfo: reporterInfo,
            isSentOnBehalf: isSentOnBehalf,
            senderInfo: senderInfo
        )
        self.priorityScore = priorityScore
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(packet.packetId, forKey: .packetId)
        try container.encode(packet.originId, forKey: .originId)
        try container.encode(packet.ts, forKey: .ts)
        try container.encode(packet.createdAt, forKey: .createdAt)
        try container.encode(packet.location, forKey: .location)
        try container.encodeIfPresent(packet.sosType, forKey: .sosType)
        try container.encode(packet.msg, forKey: .msg)
        try container.encodeIfPresent(packet.structuredData, forKey: .structuredData)
        try container.encode(packet.networkMetadata, forKey: .networkMetadata)
        try container.encodeIfPresent(packet.victimInfo, forKey: .victimInfo)
        try container.encodeIfPresent(packet.reporterInfo, forKey: .reporterInfo)
        try container.encodeIfPresent(packet.isSentOnBehalf, forKey: .isSentOnBehalf)
        try container.encodeIfPresent(packet.senderInfo, forKey: .senderInfo)
        try container.encodeIfPresent(priorityScore, forKey: .priorityScore)
    }

    func toBasicPacket() -> SOSPacket {
        packet
    }

    func relayed(by relayId: String) -> SOSPacketEnhanced {
        SOSPacketEnhanced(packet: packet.relayed(by: relayId), priorityScore: priorityScore)
    }
}
