import Foundation

// MARK: - Relief Supply Info
struct SupplyInfo: Codable {
    let type: String // "water", "food", "medicine", "clothing", "shelter", "other"
    let quantity: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case type
        case quantity
        case description
    }
}

// MARK: - Medical Issue Info
struct MedicalIssueInfo: Codable {
    let issue: String // "bleeding", "fracture", "unconscious", "breathing_difficulty", "chronic_disease", "burns"
    let severity: String // "critical", "serious", "moderate", "mild"
    let description: String?

    enum CodingKeys: String, CodingKey {
        case issue
        case severity
        case description
    }
}

// MARK: - Injured Person Info
struct InjuredPersonInfo: Codable {
    let personId: String
    let name: String
    let age: String? // "adult", "child", "elderly"
    let medicalIssues: [MedicalIssueInfo]
    let severity: String // "critical", "serious", "moderate", "mild"

    enum CodingKeys: String, CodingKey {
        case personId = "person_id"
        case name
        case age
        case medicalIssues = "medical_issues"
        case severity
    }
}

// MARK: - Rescue Situation
struct RescueSituationInfo: Codable {
    let type: String // "hasInjured", "trapped", "flooding", "collapsed", "dangerZone", "cannotMove"
    let description: String?

    enum CodingKeys: String, CodingKey {
        case type
        case description
    }
}

// MARK: - People Count Details
struct PeopleCountData: Codable {
    let total: Int
    let children: Int
    let elderly: Int
    let injured: Int

    enum CodingKeys: String, CodingKey {
        case total
        case children
        case elderly
        case injured
    }
}

// MARK: - Rescue Data Details
struct RescueDataInfo: Codable {
    let situation: RescueSituationInfo?
    let peopleCount: PeopleCountData
    let injuredPeople: [InjuredPersonInfo]?

    enum CodingKeys: String, CodingKey {
        case situation
        case peopleCount = "people_count"
        case injuredPeople = "injured_people"
    }
}

// MARK: - Relief Data Details
struct ReliefDataInfo: Codable {
    let supplies: [SupplyInfo]?
    let peopleCount: PeopleCountData
    let otherDescription: String?

    enum CodingKeys: String, CodingKey {
        case supplies
        case peopleCount = "people_count"
        case otherDescription = "other_description"
    }
}

// MARK: - Auto Collected Info
struct AutoCollectedInfoData: Codable {
    let deviceId: String?
    let userId: String?
    let userName: String?
    let userPhone: String?
    let latitude: Double?
    let longitude: Double?
    let batteryLevel: Int?
    let isOnline: Bool?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case userId = "user_id"
        case userName = "user_name"
        case userPhone = "user_phone"
        case latitude
        case longitude
        case batteryLevel = "battery_level"
        case isOnline = "is_online"
    }
}

/// Packet format cho Mock server - Enhanced version với SOS form details
struct SOSPacket: Codable {
    // Basic packet info
    let packetId: String       // UUID v4
    let originId: String       // Device ID của người gửi gốc
    let ts: Int64              // Unix timestamp
    let loc: String            // "lat,long" format
    let msg: String            // Tin nhắn SOS ngắn
    var hopCount: Int          // Số lần relay
    var path: [String]         // Danh sách device đã relay

    // SOS Form Details
    let sosType: String?       // "RESCUE" hoặc "RELIEF"
    let status: String?        // "pending", "acknowledged", "in_progress", "resolved"
    let description: String?   // Mô tả chi tiết về tình huống
    
    // Form Data - Chứa reliefData hoặc rescueData tùy sosType
    let reliefData: ReliefDataInfo?
    let rescueData: RescueDataInfo?
    
    // Auto collected info
    let autoInfo: AutoCollectedInfoData?

    enum CodingKeys: String, CodingKey {
        case packetId = "packet_id"
        case originId = "origin_id"
        case ts
        case loc
        case msg
        case hopCount = "hop_count"
        case path
        case sosType = "sos_type"
        case status
        case description
        case reliefData = "relief_data"
        case rescueData = "rescue_data"
        case autoInfo = "auto_info"
    }

    // MARK: - Initializers
    
    /// Basic init (backward compatible)
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
        
        // Form details
        self.sosType = nil
        self.status = nil
        self.description = nil
        self.reliefData = nil
        self.rescueData = nil
        self.autoInfo = nil
    }

    /// Full init with SOS form details
    init(
        packetId: String = UUID().uuidString,
        originId: String,
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        message: String,
        sosType: String,
        status: String = "pending",
        description: String?,
        reliefData: ReliefDataInfo? = nil,
        rescueData: RescueDataInfo? = nil,
        autoInfo: AutoCollectedInfoData? = nil,
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
        
        // Form details
        self.sosType = sosType
        self.status = status
        self.description = description
        self.reliefData = reliefData
        self.rescueData = rescueData
        self.autoInfo = autoInfo
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
            timestamp: Date(timeIntervalSince1970: TimeInterval(ts)),
            latitude: extractLatitude(),
            longitude: extractLongitude(),
            message: msg,
            sosType: sosType ?? "",
            status: status ?? "pending",
            description: description,
            reliefData: reliefData,
            rescueData: rescueData,
            autoInfo: autoInfo,
            hopCount: hopCount + 1,
            path: newPath
        )
    }

    private func extractLatitude() -> Double {
        let coords = loc.split(separator: ",")
        return Double(coords.first ?? "0") ?? 0
    }

    private func extractLongitude() -> Double {
        let coords = loc.split(separator: ",")
        return Double(coords.last ?? "0") ?? 0
    }

    private init(
        packetId: String,
        originId: String,
        ts: Int64,
        loc: String,
        msg: String,
        sosType: String?,
        status: String?,
        description: String?,
        reliefData: ReliefDataInfo?,
        rescueData: RescueDataInfo?,
        autoInfo: AutoCollectedInfoData?,
        hopCount: Int,
        path: [String]
    ) {
        self.packetId = packetId
        self.originId = originId
        self.ts = ts
        self.loc = loc
        self.msg = msg
        self.sosType = sosType
        self.status = status
        self.description = description
        self.reliefData = reliefData
        self.rescueData = rescueData
        self.autoInfo = autoInfo
        self.hopCount = hopCount
        self.path = path
    }
}

/// Message type để phân biệt SOS relay packet
enum MeshMessageType: String, Codable {
    case chat           // Tin nhắn chat thường
    case sosLocation    // SOS từ local
    case sosRelay       // SOS packet cần relay lên server
    case serverRequest  // Relay request lên server (generic)
    case serverAck      // ACK cho request lên server
    case userInfo       // User profile
}

/// Wrapper cho tất cả các loại tin nhắn qua mesh
struct MeshPayload: Codable {
    let meshType: MeshMessageType
    let chatPayload: MessagePayload?
    let sosPacket: SOSPacket?
    let serverRequest: ServerRequestEnvelope?
    let serverAck: ServerRequestAck?

    init(chatPayload: MessagePayload) {
        self.meshType = chatPayload.type == .sosLocation ? .sosLocation :
                        chatPayload.type == .userInfo ? .userInfo : .chat
        self.chatPayload = chatPayload
        self.sosPacket = nil
        self.serverRequest = nil
        self.serverAck = nil
    }

    init(sosPacket: SOSPacket) {
        self.meshType = .sosRelay
        self.chatPayload = nil
        self.sosPacket = sosPacket
        self.serverRequest = nil
        self.serverAck = nil
    }

    init(serverRequest: ServerRequestEnvelope) {
        self.meshType = .serverRequest
        self.chatPayload = nil
        self.sosPacket = nil
        self.serverRequest = serverRequest
        self.serverAck = nil
    }

    init(serverAck: ServerRequestAck) {
        self.meshType = .serverAck
        self.chatPayload = nil
        self.sosPacket = nil
        self.serverRequest = nil
        self.serverAck = serverAck
    }
}
