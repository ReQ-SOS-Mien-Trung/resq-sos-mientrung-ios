import Foundation

// MARK: - Location Data
struct SOSLocation: Codable {
    let lat: Double
    let lng: Double
    let accuracy: Double?
    
    init(lat: Double, lng: Double, accuracy: Double? = nil) {
        self.lat = lat
        self.lng = lng
        self.accuracy = accuracy
    }
}

// MARK: - People Count (unified)
struct SOSPeopleCount: Codable {
    let adult: Int
    let child: Int
    let elderly: Int
    
    init(adult: Int = 0, child: Int = 0, elderly: Int = 0) {
        self.adult = adult
        self.child = child
        self.elderly = elderly
    }
    
    var total: Int { adult + child + elderly }
}

// MARK: - Injured Person Data
struct SOSInjuredPerson: Codable {
    let personType: String
    let index: Int
    let name: String
    let customName: String?
    let medicalIssues: [String]
    let severity: String
    
    enum CodingKeys: String, CodingKey {
        case personType = "person_type"
        case index
        case name
        case customName = "custom_name"
        case medicalIssues = "medical_issues"
        case severity
    }
    
    init(personType: String, index: Int, name: String, customName: String? = nil, medicalIssues: [String] = [], severity: String = "MODERATE") {
        self.personType = personType
        self.index = index
        self.name = name
        self.customName = customName
        self.medicalIssues = medicalIssues
        self.severity = severity
    }
}

struct SOSSpecialDietPerson: Codable {
    let personType: String
    let index: Int
    let name: String
    let customName: String?
    let dietDescription: String?

    enum CodingKeys: String, CodingKey {
        case personType = "person_type"
        case index
        case name
        case customName = "custom_name"
        case dietDescription = "diet_description"
    }
}

struct SOSClothingPerson: Codable {
    let personType: String
    let index: Int
    let name: String
    let customName: String?
    let gender: String

    enum CodingKeys: String, CodingKey {
        case personType = "person_type"
        case index
        case name
        case customName = "custom_name"
        case gender
    }
}

struct SOSSupplyDetailData: Codable {
    // Water
    let waterDuration: String?
    let waterRemaining: String?
    // Food
    let foodDuration: String?
    let specialDietNeed: String?
    let specialDietPersons: [SOSSpecialDietPerson]?
    // Medicine / Medical
    let needsUrgentMedicine: Bool?
    let medicineConditions: [String]?
    let medicineOtherDescription: String?
    let medicalNeeds: [String]?
    let medicalDescription: String?
    // Blanket
    let isColdOrWet: Bool?
    let blanketAvailability: String?
    let areBlanketsEnough: Bool?
    let blanketRequestCount: Int?
    // Clothes
    let clothingStatus: String?
    let clothingPersons: [SOSClothingPerson]?

    enum CodingKeys: String, CodingKey {
        case waterDuration = "water_duration"
        case waterRemaining = "water_remaining"
        case foodDuration = "food_duration"
        case specialDietNeed = "special_diet_need"
        case specialDietPersons = "special_diet_persons"
        case needsUrgentMedicine = "needs_urgent_medicine"
        case medicineConditions = "medicine_conditions"
        case medicineOtherDescription = "medicine_other_description"
        case medicalNeeds = "medical_needs"
        case medicalDescription = "medical_description"
        case isColdOrWet = "is_cold_or_wet"
        case blanketAvailability = "blanket_availability"
        case areBlanketsEnough = "are_blankets_enough"
        case blanketRequestCount = "blanket_request_count"
        case clothingStatus = "clothing_status"
        case clothingPersons = "clothing_persons"
    }
}

// MARK: - Structured Data (unified rescue + relief)
struct SOSStructuredData: Codable {
    // === RESCUE fields ===
    let situation: String?
    let otherSituationDescription: String?
    let hasInjured: Bool?
    let medicalIssues: [String]?
    let otherMedicalDescription: String?
    let othersAreStable: Bool?
    let canMove: Bool?
    let needMedical: Bool?
    let injuredPersons: [SOSInjuredPerson]?
    
    // === RELIEF fields ===
    let supplies: [String]?
    let otherSupplyDescription: String?
    let supplyDetails: SOSSupplyDetailData?
    
    // === COMMON fields ===
    let peopleCount: SOSPeopleCount?
    let additionalDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case situation
        case otherSituationDescription = "other_situation_description"
        case hasInjured = "has_injured"
        case medicalIssues = "medical_issues"
        case otherMedicalDescription = "other_medical_description"
        case othersAreStable = "others_are_stable"
        case canMove = "can_move"
        case needMedical = "need_medical"
        case injuredPersons = "injured_persons"
        case supplies
        case otherSupplyDescription = "other_supply_description"
        case supplyDetails = "supply_details"
        case peopleCount = "people_count"
        case additionalDescription = "additional_description"
    }
    
    init(
        situation: String? = nil,
        otherSituationDescription: String? = nil,
        hasInjured: Bool? = nil,
        medicalIssues: [String]? = nil,
        otherMedicalDescription: String? = nil,
        othersAreStable: Bool? = nil,
        canMove: Bool? = nil,
        needMedical: Bool? = nil,
        injuredPersons: [SOSInjuredPerson]? = nil,
        supplies: [String]? = nil,
        otherSupplyDescription: String? = nil,
        supplyDetails: SOSSupplyDetailData? = nil,
        peopleCount: SOSPeopleCount? = nil,
        additionalDescription: String? = nil
    ) {
        self.situation = situation
        self.otherSituationDescription = otherSituationDescription
        self.hasInjured = hasInjured
        self.medicalIssues = medicalIssues
        self.otherMedicalDescription = otherMedicalDescription
        self.othersAreStable = othersAreStable
        self.canMove = canMove
        self.needMedical = needMedical
        self.injuredPersons = injuredPersons
        self.supplies = supplies
        self.otherSupplyDescription = otherSupplyDescription
        self.supplyDetails = supplyDetails
        self.peopleCount = peopleCount
        self.additionalDescription = additionalDescription
    }
}

// MARK: - Network Metadata
struct SOSNetworkMetadata: Codable {
    var hopCount: Int
    var path: [String]
    
    enum CodingKeys: String, CodingKey {
        case hopCount = "hop_count"
        case path
    }
    
    init(hopCount: Int = 0, path: [String] = []) {
        self.hopCount = hopCount
        self.path = path
    }
}

// MARK: - Sender Info (auto collected)
struct SOSSenderInfo: Codable {
    let deviceId: String?
    let userId: String?
    let userName: String?
    let userPhone: String?
    let batteryLevel: Int?
    let isOnline: Bool?
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case userId = "user_id"
        case userName = "user_name"
        case userPhone = "user_phone"
        case batteryLevel = "battery_level"
        case isOnline = "is_online"
    }
    
    init(
        deviceId: String? = nil,
        userId: String? = nil,
        userName: String? = nil,
        userPhone: String? = nil,
        batteryLevel: Int? = nil,
        isOnline: Bool? = nil
    ) {
        self.deviceId = deviceId
        self.userId = userId
        self.userName = userName
        self.userPhone = userPhone
        self.batteryLevel = batteryLevel
        self.isOnline = isOnline
    }
}

// MARK: - SOS Packet (unified structure matching BE)
struct SOSPacket: Codable {
    let packetId: String                    // UUID v4
    let originId: String                    // Original sender's ID (for mesh routing)
    let ts: Int64                           // Unix timestamp
    var createdAt: String                   // ISO8601 date string
    let location: SOSLocation               // { lat, lng, accuracy }
    let sosType: String?                    // "RESCUE", "RELIEF", or "BOTH"
    let msg: String                         // Short message
    let structuredData: SOSStructuredData?  // Unified rescue + relief data
    var networkMetadata: SOSNetworkMetadata // { hop_count, path }
    let senderInfo: SOSSenderInfo?          // Auto collected info
    
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
        case senderInfo = "sender_info"
    }
    
    // MARK: - Initializers
    
    /// Basic init for simple SOS
    init(
        packetId: String = UUID().uuidString,
        originId: String,
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        accuracy: Double? = nil,
        message: String,
        senderInfo: SOSSenderInfo? = nil,
        hopCount: Int = 0,
        path: [String] = []
    ) {
        self.packetId = packetId
        self.originId = originId
        self.ts = Int64(timestamp.timeIntervalSince1970)
        self.createdAt = ISO8601DateFormatter().string(from: timestamp)
        self.location = SOSLocation(lat: latitude, lng: longitude, accuracy: accuracy)
        self.sosType = nil
        self.msg = message
        self.structuredData = nil
        self.senderInfo = senderInfo
        self.networkMetadata = SOSNetworkMetadata(hopCount: hopCount, path: path.isEmpty ? [packetId] : path)
    }
    
    /// Full init with structured data
    init(
        packetId: String = UUID().uuidString,
        originId: String,
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        accuracy: Double? = nil,
        sosType: String,
        message: String,
        structuredData: SOSStructuredData?,
        senderInfo: SOSSenderInfo? = nil,
        hopCount: Int = 0,
        path: [String] = []
    ) {
        self.packetId = packetId
        self.originId = originId
        self.ts = Int64(timestamp.timeIntervalSince1970)
        self.createdAt = ISO8601DateFormatter().string(from: timestamp)
        self.location = SOSLocation(lat: latitude, lng: longitude, accuracy: accuracy)
        self.sosType = sosType
        self.msg = message
        self.structuredData = structuredData
        self.senderInfo = senderInfo
        self.networkMetadata = SOSNetworkMetadata(hopCount: hopCount, path: path.isEmpty ? [packetId] : path)
    }
    
    /// Tạo packet mới với hop count tăng lên và thêm relay ID vào path
    func relayed(by relayId: String) -> SOSPacket {
        var newPath = networkMetadata.path
        if !newPath.contains(relayId) {
            newPath.append(relayId)
        }
        
        var relayed = self
        relayed.networkMetadata = SOSNetworkMetadata(
            hopCount: networkMetadata.hopCount + 1,
            path: newPath
        )
        return relayed
    }
    
    // MARK: - Computed Properties (backward compatibility)
    
    var loc: String {
        "\(location.lat),\(location.lng)"
    }
    
    var hopCount: Int {
        get { networkMetadata.hopCount }
        set { networkMetadata.hopCount = newValue }
    }
    
    var path: [String] {
        get { networkMetadata.path }
        set { networkMetadata.path = newValue }
    }
}

// MARK: - Legacy types for backward compatibility
// These are kept for existing code that may use them

struct PeopleCountData: Codable {
    let total: Int
    let children: Int
    let elderly: Int
    let injured: Int
    
    init(total: Int = 0, children: Int = 0, elderly: Int = 0, injured: Int = 0) {
        self.total = total
        self.children = children
        self.elderly = elderly
        self.injured = injured
    }
}

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
