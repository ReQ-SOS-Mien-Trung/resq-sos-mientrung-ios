//
//  SOSPacketEnhanced.swift
//  SosMienTrung
//
//  Enhanced SOS Packet với structured data từ Wizard form
//

import Foundation

/// Extended SOS Packet với structured data
struct SOSPacketEnhanced: Codable {
    // Base fields (compatible với SOSPacket cũ)
    let packetId: String
    let originId: String
    let ts: Int64
    let loc: String
    let msg: String
    var hopCount: Int
    var path: [String]
    
    // Enhanced structured data
    let sosType: String?                    // "RESCUE" or "RELIEF"
    let priorityScore: Int?                 // Computed priority score
    let structuredData: StructuredData?     // Type-specific data
    let senderInfo: SenderInfo?             // User info
    
    enum CodingKeys: String, CodingKey {
        case packetId = "packet_id"
        case originId = "origin_id"
        case ts
        case loc
        case msg
        case hopCount = "hop_count"
        case path
        case sosType = "sos_type"
        case priorityScore = "priority_score"
        case structuredData = "structured_data"
        case senderInfo = "sender_info"
    }
    
    // MARK: - Nested Types
    
    struct StructuredData: Codable {
        // Relief data
        let supplies: [String]?
        let otherSupplyDescription: String?
        
        // Rescue data
        let situation: String?
        let otherSituationDescription: String?
        let hasInjured: Bool?
        let medicalIssues: [String]?
        let otherMedicalDescription: String?
        let othersAreStable: Bool?
        
        // Common
        let peopleCount: PeopleCountData?
        let additionalDescription: String?
        
        enum CodingKeys: String, CodingKey {
            case supplies
            case otherSupplyDescription = "other_supply_description"
            case situation
            case otherSituationDescription = "other_situation_description"
            case hasInjured = "has_injured"
            case medicalIssues = "medical_issues"
            case otherMedicalDescription = "other_medical_description"
            case othersAreStable = "others_are_stable"
            case peopleCount = "people_count"
            case additionalDescription = "additional_description"
        }
    }
    
    struct PeopleCountData: Codable {
        let total: Int
        let adults: Int
        let children: Int
        let elderly: Int
        let injured: Int
        
        enum CodingKeys: String, CodingKey {
            case total
            case adults
            case children
            case elderly
            case injured
        }
    }
    
    struct SenderInfo: Codable {
        let userName: String?
        let userPhone: String?
        let batteryLevel: Int?
        let gpsAccuracy: Double?
        let isOnline: Bool
        
        enum CodingKeys: String, CodingKey {
            case userName = "user_name"
            case userPhone = "user_phone"
            case batteryLevel = "battery_level"
            case gpsAccuracy = "gps_accuracy"
            case isOnline = "is_online"
        }
    }
    
    // MARK: - Initialization from FormData
    
    init(from formData: SOSFormData, originId: String, latitude: Double, longitude: Double) {
        self.packetId = UUID().uuidString
        self.originId = originId
        self.ts = Int64(Date().timeIntervalSince1970)
        self.loc = "\(latitude),\(longitude)"
        self.msg = formData.toSOSMessage()
        self.hopCount = 0
        self.path = [originId]
        
        self.sosType = formData.sosType?.rawValue
        self.priorityScore = formData.priorityScore
        
        // Build structured data
        var supplies: [String]? = nil
        var otherSupplyDescription: String? = nil
        var situation: String? = nil
        var otherSituationDescription: String? = nil
        var hasInjured: Bool? = nil
        var medicalIssues: [String]? = nil
        var otherMedicalDescription: String? = nil
        var othersAreStable: Bool? = nil
        var peopleCount: PeopleCountData? = nil
        
        // Sử dụng shared people count
        peopleCount = PeopleCountData(
            total: formData.sharedPeopleCount.total,
            adults: formData.sharedPeopleCount.adults,
            children: formData.sharedPeopleCount.children,
            elderly: formData.sharedPeopleCount.elderly,
            injured: formData.needsRescueStep ? formData.rescueData.injuredPersonIds.count : 0
        )
        
        // Relief data - nếu có chọn relief
        if formData.needsReliefStep {
            supplies = formData.reliefData.supplies.map { $0.rawValue }
            otherSupplyDescription = formData.reliefData.otherSupplyDescription.isEmpty ? nil : formData.reliefData.otherSupplyDescription
        }
        
        // Rescue data - nếu có chọn rescue
        if formData.needsRescueStep {
            situation = formData.rescueData.situation?.rawValue
            otherSituationDescription = formData.rescueData.otherSituationDescription.isEmpty ? nil : formData.rescueData.otherSituationDescription
            hasInjured = formData.rescueData.hasInjured
            medicalIssues = formData.rescueData.medicalIssues.isEmpty ? nil : formData.rescueData.medicalIssues.map { $0.rawValue }
            otherMedicalDescription = formData.rescueData.otherMedicalDescription.isEmpty ? nil : formData.rescueData.otherMedicalDescription
            othersAreStable = formData.rescueData.othersAreStable
        }
        
        self.structuredData = StructuredData(
            supplies: supplies,
            otherSupplyDescription: otherSupplyDescription,
            situation: situation,
            otherSituationDescription: otherSituationDescription,
            hasInjured: hasInjured,
            medicalIssues: medicalIssues,
            otherMedicalDescription: otherMedicalDescription,
            othersAreStable: othersAreStable,
            peopleCount: peopleCount,
            additionalDescription: formData.additionalDescription.isEmpty ? nil : formData.additionalDescription
        )
        
        // Build sender info
        if let autoInfo = formData.autoInfo {
            self.senderInfo = SenderInfo(
                userName: autoInfo.userName,
                userPhone: autoInfo.userPhone,
                batteryLevel: autoInfo.batteryLevel,
                gpsAccuracy: autoInfo.accuracy,
                isOnline: autoInfo.isOnline
            )
        } else {
            self.senderInfo = nil
        }
    }
    
    // MARK: - Standard init
    
    init(
        packetId: String = UUID().uuidString,
        originId: String,
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        message: String,
        hopCount: Int = 0,
        path: [String] = [],
        sosType: String? = nil,
        priorityScore: Int? = nil,
        structuredData: StructuredData? = nil,
        senderInfo: SenderInfo? = nil
    ) {
        self.packetId = packetId
        self.originId = originId
        self.ts = Int64(timestamp.timeIntervalSince1970)
        self.loc = "\(latitude),\(longitude)"
        self.msg = message
        self.hopCount = hopCount
        self.path = path.isEmpty ? [originId] : path
        self.sosType = sosType
        self.priorityScore = priorityScore
        self.structuredData = structuredData
        self.senderInfo = senderInfo
    }
    
    /// Convert to basic SOSPacket for mesh relay compatibility
    func toBasicPacket() -> SOSPacket {
        // Convert StructuredData to SOSStructuredData
        let sosStructuredData: SOSStructuredData?
        if let sd = structuredData {
            sosStructuredData = SOSStructuredData(
                situation: sd.situation,
                otherSituationDescription: sd.otherSituationDescription,
                hasInjured: sd.hasInjured,
                medicalIssues: sd.medicalIssues,
                otherMedicalDescription: sd.otherMedicalDescription,
                othersAreStable: sd.othersAreStable,
                canMove: nil,
                needMedical: sd.hasInjured,
                supplies: sd.supplies,
                otherSupplyDescription: sd.otherSupplyDescription,
                peopleCount: sd.peopleCount.map { SOSPeopleCount(adult: $0.adults, child: $0.children, elderly: $0.elderly) },
                additionalDescription: sd.additionalDescription
            )
        } else {
            sosStructuredData = nil
        }
        
        // Convert SenderInfo to SOSSenderInfo
        let sosSenderInfo: SOSSenderInfo?
        if let si = senderInfo {
            sosSenderInfo = SOSSenderInfo(
                deviceId: nil,
                userId: nil,
                userName: si.userName,
                userPhone: si.userPhone,
                batteryLevel: si.batteryLevel,
                isOnline: si.isOnline
            )
        } else {
            sosSenderInfo = nil
        }
        
        return SOSPacket(
            packetId: packetId,
            originId: originId,
            timestamp: Date(timeIntervalSince1970: TimeInterval(ts)),
            latitude: parseLatitude(),
            longitude: parseLongitude(),
            accuracy: senderInfo?.gpsAccuracy,
            sosType: sosType ?? "UNKNOWN",
            message: msg,
            structuredData: sosStructuredData,
            senderInfo: sosSenderInfo,
            hopCount: hopCount,
            path: path
        )
    }
    
    /// Relay packet
    func relayed(by relayId: String) -> SOSPacketEnhanced {
        var newPath = path
        if !newPath.contains(relayId) {
            newPath.append(relayId)
        }
        
        var relayed = self
        relayed.hopCount = hopCount + 1
        relayed.path = newPath
        return relayed
    }
    
    private func parseLatitude() -> Double {
        let parts = loc.split(separator: ",")
        return Double(parts.first ?? "0") ?? 0
    }
    
    private func parseLongitude() -> Double {
        let parts = loc.split(separator: ",")
        return Double(parts.last ?? "0") ?? 0
    }
}
