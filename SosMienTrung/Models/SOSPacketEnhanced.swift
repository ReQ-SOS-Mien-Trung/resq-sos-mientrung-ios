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
    let createdAt: String
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
        case createdAt = "created_at"
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
        let supplyDetails: SupplyDetailData?
        
        // Rescue data
        let situation: String?
        let otherSituationDescription: String?
        let hasInjured: Bool?
        let medicalIssues: [String]?
        let otherMedicalDescription: String?
        let othersAreStable: Bool?
        let injuredPersons: [InjuredPersonData]?
        
        // Common
        let canMove: Bool?
        let peopleCount: PeopleCountData?
        let additionalDescription: String?
        
        enum CodingKeys: String, CodingKey {
            case supplies
            case otherSupplyDescription = "other_supply_description"
            case supplyDetails = "supply_details"
            case situation
            case otherSituationDescription = "other_situation_description"
            case hasInjured = "has_injured"
            case medicalIssues = "medical_issues"
            case otherMedicalDescription = "other_medical_description"
            case othersAreStable = "others_are_stable"
            case injuredPersons = "injured_persons"
            case canMove = "can_move"
            case peopleCount = "people_count"
            case additionalDescription = "additional_description"
        }
    }
    
    struct SupplyDetailData: Codable {
        // Water
        let waterDuration: String?
        let waterRemaining: String?
        // Food
        let foodDuration: String?
        let specialDietNeed: String?
        // Medicine
        let needsUrgentMedicine: Bool?
        let medicineConditions: [String]?
        let medicineOtherDescription: String?
        // Blanket
        let isColdOrWet: Bool?
        let blanketAvailability: String?
        // Clothes
        let clothingStatus: String?
        
        enum CodingKeys: String, CodingKey {
            case waterDuration = "water_duration"
            case waterRemaining = "water_remaining"
            case foodDuration = "food_duration"
            case specialDietNeed = "special_diet_need"
            case needsUrgentMedicine = "needs_urgent_medicine"
            case medicineConditions = "medicine_conditions"
            case medicineOtherDescription = "medicine_other_description"
            case isColdOrWet = "is_cold_or_wet"
            case blanketAvailability = "blanket_availability"
            case clothingStatus = "clothing_status"
        }
    }
    
    struct InjuredPersonData: Codable {
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
        let deviceId: String?
        let userId: String?
        let userName: String?
        let userPhone: String?
        let batteryLevel: Int?
        let gpsAccuracy: Double?
        let isOnline: Bool
        
        enum CodingKeys: String, CodingKey {
            case deviceId = "device_id"
            case userId = "user_id"
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
        self.createdAt = ISO8601DateFormatter().string(from: Date())
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
        var supplyDetails: SupplyDetailData? = nil
        if formData.needsReliefStep {
            supplies = formData.reliefData.supplies.map { $0.rawValue }
            otherSupplyDescription = formData.reliefData.otherSupplyDescription.isEmpty ? nil : formData.reliefData.otherSupplyDescription
            
            let relief = formData.reliefData
            let hasSomeDetail = relief.waterDuration != nil || relief.waterRemaining != nil ||
                relief.foodDuration != nil || relief.specialDietNeed != nil ||
                relief.needsUrgentMedicine != nil || !relief.medicineConditions.isEmpty ||
                relief.isColdOrWet != nil || relief.blanketAvailability != nil ||
                relief.clothingStatus != nil
            
            if hasSomeDetail {
                supplyDetails = SupplyDetailData(
                    waterDuration: relief.waterDuration?.rawValue,
                    waterRemaining: relief.waterRemaining?.rawValue,
                    foodDuration: relief.foodDuration?.rawValue,
                    specialDietNeed: relief.specialDietNeed?.rawValue,
                    needsUrgentMedicine: relief.needsUrgentMedicine,
                    medicineConditions: relief.medicineConditions.isEmpty ? nil : relief.medicineConditions.map { $0.rawValue },
                    medicineOtherDescription: relief.medicineOtherDescription.isEmpty ? nil : relief.medicineOtherDescription,
                    isColdOrWet: relief.isColdOrWet,
                    blanketAvailability: relief.blanketAvailability?.rawValue,
                    clothingStatus: relief.clothingStatus?.rawValue
                )
            }
        }
        
        // Rescue data - nếu có chọn rescue
        var canMove: Bool? = nil
        if formData.needsRescueStep {
            situation = formData.rescueData.situation?.rawValue
            otherSituationDescription = formData.rescueData.otherSituationDescription.isEmpty ? nil : formData.rescueData.otherSituationDescription
            hasInjured = formData.rescueData.hasInjured
            // Collect medical issues từ per-person data (new approach)
            let allMedicalIssues = formData.rescueData.medicalInfoByPerson.values
                .flatMap { $0.medicalIssues }
                .map { $0.rawValue }
            medicalIssues = allMedicalIssues.isEmpty ? nil : Array(Set(allMedicalIssues))
            otherMedicalDescription = formData.rescueData.otherMedicalDescription.isEmpty ? nil : formData.rescueData.otherMedicalDescription
            othersAreStable = formData.rescueData.othersAreStable
            canMove = formData.rescueData.situation != .cannotMove
        }
        
        // Build per-person injured data
        var injuredPersons: [InjuredPersonData]? = nil
        if formData.needsRescueStep && !formData.rescueData.injuredPersonIds.isEmpty {
            var persons: [InjuredPersonData] = []
            for personId in formData.rescueData.injuredPersonIds {
                if let person = formData.rescueData.people.first(where: { $0.id == personId }),
                   let info = formData.rescueData.medicalInfoByPerson[personId] {
                    persons.append(InjuredPersonData(
                        personType: person.type.rawValue,
                        index: person.index,
                        name: person.displayName,
                        customName: person.customName.isEmpty ? nil : person.customName,
                        medicalIssues: info.medicalIssues.map { $0.rawValue },
                        severity: "NONE"
                    ))
                }
            }
            injuredPersons = persons.isEmpty ? nil : persons
        }
        
        self.structuredData = StructuredData(
            supplies: supplies,
            otherSupplyDescription: otherSupplyDescription,
            supplyDetails: supplyDetails,
            situation: situation,
            otherSituationDescription: otherSituationDescription,
            hasInjured: hasInjured,
            medicalIssues: medicalIssues,
            otherMedicalDescription: otherMedicalDescription,
            othersAreStable: othersAreStable,
            injuredPersons: injuredPersons,
            canMove: canMove,
            peopleCount: peopleCount,
            additionalDescription: formData.additionalDescription.isEmpty ? nil : formData.additionalDescription
        )
        
        // Build sender info
        if let autoInfo = formData.autoInfo {
            self.senderInfo = SenderInfo(
                deviceId: autoInfo.deviceId,
                userId: autoInfo.userId,
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
        self.createdAt = ISO8601DateFormatter().string(from: timestamp)
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
                canMove: sd.canMove,
                needMedical: sd.hasInjured,
                injuredPersons: sd.injuredPersons?.map {
                    SOSInjuredPerson(
                        personType: $0.personType,
                        index: $0.index,
                        name: $0.name,
                        customName: $0.customName,
                        medicalIssues: $0.medicalIssues,
                        severity: $0.severity
                    )
                },
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
                deviceId: si.deviceId ?? originId,
                userId: si.userId,
                userName: si.userName,
                userPhone: si.userPhone,
                batteryLevel: si.batteryLevel,
                isOnline: si.isOnline
            )
        } else {
            sosSenderInfo = nil
        }
        
        var packet = SOSPacket(
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
        // Force the createdAt to match the original packet instead of current Date
        packet.createdAt = self.createdAt
        return packet
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
