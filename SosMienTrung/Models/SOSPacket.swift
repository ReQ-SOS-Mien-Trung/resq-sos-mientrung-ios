import Foundation

// MARK: - Location Data

struct SOSLocation: Codable {
    let lat: Double
    let lng: Double
    let accuracy: Double?
    let address: String?

    enum CodingKeys: String, CodingKey {
        case lat
        case lng
        case accuracy
        case address
    }

    init(lat: Double, lng: Double, accuracy: Double? = nil, address: String? = nil) {
        self.lat = lat
        self.lng = lng
        self.accuracy = accuracy
        self.address = address
    }
}

// MARK: - Common Data

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

// MARK: - Legacy Flat Types (decode compatibility)

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
    let waterDuration: String?
    let waterRemaining: String?
    let foodDuration: String?
    let specialDietNeed: String?
    let specialDietPersons: [SOSSpecialDietPerson]?
    let needsUrgentMedicine: Bool?
    let medicineConditions: [String]?
    let medicineOtherDescription: String?
    let medicalNeeds: [String]?
    let medicalDescription: String?
    let isColdOrWet: Bool?
    let blanketAvailability: String?
    let areBlanketsEnough: Bool?
    let blanketRequestCount: Int?
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

// MARK: - Victims

struct SOSVictimIncidentStatus: Codable {
    let isInjured: Bool
    let severity: String?
    let medicalIssues: [String]

    enum CodingKeys: String, CodingKey {
        case isInjured = "is_injured"
        case severity
        case medicalIssues = "medical_issues"
    }
}

struct SOSVictimClothingNeed: Codable {
    let needed: Bool
    let gender: String?
}

struct SOSVictimDietNeed: Codable {
    let hasSpecialDiet: Bool
    let description: String?

    enum CodingKeys: String, CodingKey {
        case hasSpecialDiet = "has_special_diet"
        case description
    }
}

struct SOSVictimPersonalNeeds: Codable {
    let clothing: SOSVictimClothingNeed
    let diet: SOSVictimDietNeed
}

struct SOSVictimEntry: Codable, Identifiable {
    let personId: String
    let personType: String
    let index: Int
    let customName: String
    let personPhone: String?
    let incidentStatus: SOSVictimIncidentStatus
    let personalNeeds: SOSVictimPersonalNeeds

    var id: String { personId }

    enum CodingKeys: String, CodingKey {
        case personId = "person_id"
        case personType = "person_type"
        case index
        case customName = "custom_name"
        case personPhone = "person_phone"
        case incidentStatus = "incident_status"
        case personalNeeds = "personal_needs"
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case name
    }

    init(
        personId: String,
        personType: String,
        index: Int,
        customName: String,
        personPhone: String?,
        incidentStatus: SOSVictimIncidentStatus,
        personalNeeds: SOSVictimPersonalNeeds
    ) {
        self.personId = personId
        self.personType = personType
        self.index = index
        self.customName = customName
        self.personPhone = personPhone
        self.incidentStatus = incidentStatus
        self.personalNeeds = personalNeeds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)

        personId = try container.decode(String.self, forKey: .personId)
        personType = try container.decode(String.self, forKey: .personType)
        index = try container.decode(Int.self, forKey: .index)
        customName = try container.decodeIfPresent(String.self, forKey: .customName)?.trimmedNilIfEmpty
            ?? legacyContainer.decodeIfPresent(String.self, forKey: .name)?.trimmedNilIfEmpty
            ?? "Người \(index)"
        personPhone = try container.decodeIfPresent(String.self, forKey: .personPhone)
        incidentStatus = try container.decode(SOSVictimIncidentStatus.self, forKey: .incidentStatus)
        personalNeeds = try container.decode(SOSVictimPersonalNeeds.self, forKey: .personalNeeds)
    }
}

// MARK: - Prepared Profiles

struct SOSPreparedMedicationSnapshot: Codable, Identifiable {
    let id: String
    let name: String
    let frequency: String
    let note: String
}

struct SOSPreparedSpecialSituationSnapshot: Codable {
    let isPregnant: Bool
    let isSenior: Bool
    let isYoungChild: Bool
    let hasDisability: Bool

    enum CodingKeys: String, CodingKey {
        case isPregnant = "is_pregnant"
        case isSenior = "is_senior"
        case isYoungChild = "is_young_child"
        case hasDisability = "has_disability"
    }
}

struct SOSPreparedMedicalProfileSnapshot: Codable {
    let chronicConditions: [String]
    let otherChronicCondition: String?
    let allergyOptions: [String]
    let allergyDetails: String?
    let hasLongTermMedication: Bool
    let longTermMedications: [SOSPreparedMedicationSnapshot]
    let mobilityStatus: String
    let medicalDevices: [String]
    let otherMedicalDevice: String?
    let specialSituation: SOSPreparedSpecialSituationSnapshot
    let medicalHistory: [String]
    let medicalHistoryDetails: String?
    let bloodType: String

    enum CodingKeys: String, CodingKey {
        case chronicConditions = "chronic_conditions"
        case otherChronicCondition = "other_chronic_condition"
        case allergyOptions = "allergy_options"
        case allergyDetails = "allergy_details"
        case hasLongTermMedication = "has_long_term_medication"
        case longTermMedications = "long_term_medications"
        case mobilityStatus = "mobility_status"
        case medicalDevices = "medical_devices"
        case otherMedicalDevice = "other_medical_device"
        case specialSituation = "special_situation"
        case medicalHistory = "medical_history"
        case medicalHistoryDetails = "medical_history_details"
        case bloodType = "blood_type"
    }

    init(profile: RelativeMedicalProfile) {
        chronicConditions = profile.chronicConditions.map(\.rawValue)
        otherChronicCondition = profile.otherChronicCondition.nilIfBlank
        allergyOptions = profile.allergyOptions.map(\.rawValue)
        allergyDetails = profile.allergyDetails.nilIfBlank
        hasLongTermMedication = profile.hasLongTermMedication
        longTermMedications = profile.longTermMedications.map {
            SOSPreparedMedicationSnapshot(
                id: $0.id,
                name: $0.name,
                frequency: $0.frequency,
                note: $0.note
            )
        }
        mobilityStatus = profile.mobilityStatus.rawValue
        medicalDevices = profile.medicalDevices.map(\.rawValue)
        otherMedicalDevice = profile.otherMedicalDevice.nilIfBlank
        let sanitizedSpecialSituation = profile.specialSituation.sanitizedForProfileEditor
        specialSituation = SOSPreparedSpecialSituationSnapshot(
            isPregnant: sanitizedSpecialSituation.isPregnant,
            isSenior: sanitizedSpecialSituation.isSenior,
            isYoungChild: sanitizedSpecialSituation.isYoungChild,
            hasDisability: sanitizedSpecialSituation.hasDisability
        )
        medicalHistory = profile.medicalHistory.map(\.rawValue)
        medicalHistoryDetails = profile.medicalHistoryDetails.nilIfBlank
        bloodType = profile.bloodType.rawValue
    }
}

struct SOSPreparedProfileSnapshot: Codable, Identifiable {
    let profileId: String
    let displayName: String
    let phoneNumber: String?
    let personType: String
    let gender: String?
    let relationGroup: String
    let medicalProfile: SOSPreparedMedicalProfileSnapshot
    let medicalBaselineNote: String?
    let specialNeedsNote: String?
    let specialDietNote: String?
    let updatedAt: String

    var id: String { profileId }

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case displayName = "display_name"
        case phoneNumber = "phone_number"
        case personType = "person_type"
        case gender
        case relationGroup = "relation_group"
        case medicalProfile = "medical_profile"
        case medicalBaselineNote = "medical_baseline_note"
        case specialNeedsNote = "special_needs_note"
        case specialDietNote = "special_diet_note"
        case updatedAt = "updated_at"
    }

    init(snapshot: SelectedRelativeSnapshot) {
        let formatter = ISO8601DateFormatter()
        profileId = snapshot.profileId
        displayName = snapshot.displayName
        phoneNumber = snapshot.phoneNumber?.trimmedNilIfEmpty
        personType = snapshot.personType.rawValue
        gender = snapshot.gender?.rawValue
        relationGroup = snapshot.relationGroup.rawValue
        medicalProfile = SOSPreparedMedicalProfileSnapshot(profile: snapshot.medicalProfile)
        medicalBaselineNote = snapshot.medicalBaselineNote.nilIfBlank
        specialNeedsNote = snapshot.specialNeedsNote.nilIfBlank
        specialDietNote = snapshot.specialDietNote.nilIfBlank
        updatedAt = formatter.string(from: snapshot.updatedAt)
    }
}

// MARK: - Incident and Group Needs

struct SOSIncidentData: Codable {
    let situation: String?
    let otherSituationDescription: String?
    let address: String?
    let additionalDescription: String?
    let peopleCount: SOSPeopleCount
    let hasInjured: Bool?
    let othersAreStable: Bool?
    let canMove: Bool?
    let needMedical: Bool?
    let otherMedicalDescription: String?

    enum CodingKeys: String, CodingKey {
        case situation
        case otherSituationDescription = "other_situation_description"
        case address
        case additionalDescription = "additional_description"
        case peopleCount = "people_count"
        case hasInjured = "has_injured"
        case othersAreStable = "others_are_stable"
        case canMove = "can_move"
        case needMedical = "need_medical"
        case otherMedicalDescription = "other_medical_description"
    }
}

struct SOSWaterNeedData: Codable {
    let duration: String?
    let remaining: String?
}

struct SOSFoodNeedData: Codable {
    let duration: String?
}

struct SOSBlanketNeedData: Codable {
    let isColdOrWet: Bool?
    let availability: String?
    let requestCount: Int?

    enum CodingKeys: String, CodingKey {
        case isColdOrWet = "is_cold_or_wet"
        case availability
        case requestCount = "request_count"
    }
}

struct SOSMedicineNeedData: Codable {
    let needsUrgentMedicine: Bool?
    let conditions: [String]?
    let otherDescription: String?
    let medicalNeeds: [String]?
    let medicalDescription: String?

    enum CodingKeys: String, CodingKey {
        case needsUrgentMedicine = "needs_urgent_medicine"
        case conditions
        case otherDescription = "other_description"
        case medicalNeeds = "medical_needs"
        case medicalDescription = "medical_description"
    }
}

struct SOSClothingGroupNeedData: Codable {
    let status: String?
}

struct SOSGroupNeedsData: Codable {
    let supplies: [String]?
    let water: SOSWaterNeedData?
    let food: SOSFoodNeedData?
    let blanket: SOSBlanketNeedData?
    let medicine: SOSMedicineNeedData?
    let clothing: SOSClothingGroupNeedData?
    let otherSupplyDescription: String?

    enum CodingKeys: String, CodingKey {
        case supplies
        case water
        case food
        case blanket
        case medicine
        case clothing
        case otherSupplyDescription = "other_supply_description"
    }
}

// MARK: - Structured Data

struct SOSStructuredData: Codable {
    let incident: SOSIncidentData?
    let groupNeeds: SOSGroupNeedsData?
    let victims: [SOSVictimEntry]?

    enum CodingKeys: String, CodingKey {
        case incident
        case groupNeeds = "group_needs"
        case victims
        case preparedProfiles = "prepared_profiles"
        case personSourceMode = "person_source_mode"
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
        case address
    }

    init(
        incident: SOSIncidentData? = nil,
        groupNeeds: SOSGroupNeedsData? = nil,
        victims: [SOSVictimEntry]? = nil
    ) {
        self.incident = incident
        self.groupNeeds = groupNeeds
        self.victims = victims
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(incident, forKey: .incident)
        try container.encodeIfPresent(groupNeeds, forKey: .groupNeeds)
        try container.encodeIfPresent(victims, forKey: .victims)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedIncident = try container.decodeIfPresent(SOSIncidentData.self, forKey: .incident)
        let decodedGroupNeeds = try container.decodeIfPresent(SOSGroupNeedsData.self, forKey: .groupNeeds)
        let decodedVictims = try container.decodeIfPresent([SOSVictimEntry].self, forKey: .victims)

        if decodedIncident != nil || decodedGroupNeeds != nil || decodedVictims != nil {
            incident = decodedIncident
            groupNeeds = decodedGroupNeeds
            victims = decodedVictims
            return
        }

        let legacyPeopleCount = try container.decodeIfPresent(SOSPeopleCount.self, forKey: .peopleCount) ?? SOSPeopleCount()
        let legacySupplyDetails = try container.decodeIfPresent(SOSSupplyDetailData.self, forKey: .supplyDetails)

        incident = SOSIncidentData(
            situation: try container.decodeIfPresent(String.self, forKey: .situation),
            otherSituationDescription: try container.decodeIfPresent(String.self, forKey: .otherSituationDescription),
            address: try container.decodeIfPresent(String.self, forKey: .address),
            additionalDescription: try container.decodeIfPresent(String.self, forKey: .additionalDescription),
            peopleCount: legacyPeopleCount,
            hasInjured: try container.decodeIfPresent(Bool.self, forKey: .hasInjured),
            othersAreStable: try container.decodeIfPresent(Bool.self, forKey: .othersAreStable),
            canMove: try container.decodeIfPresent(Bool.self, forKey: .canMove),
            needMedical: try container.decodeIfPresent(Bool.self, forKey: .needMedical),
            otherMedicalDescription: try container.decodeIfPresent(String.self, forKey: .otherMedicalDescription)
        )

        let legacySupplies = try container.decodeIfPresent([String].self, forKey: .supplies)
        let legacyOtherSupplyDescription = try container.decodeIfPresent(String.self, forKey: .otherSupplyDescription)
        if legacySupplies != nil || legacyOtherSupplyDescription != nil || legacySupplyDetails != nil {
            groupNeeds = SOSGroupNeedsData(
                supplies: legacySupplies,
                water: legacySupplyDetails?.waterDuration != nil || legacySupplyDetails?.waterRemaining != nil
                    ? SOSWaterNeedData(
                        duration: legacySupplyDetails?.waterDuration,
                        remaining: legacySupplyDetails?.waterRemaining
                    )
                    : nil,
                food: legacySupplyDetails?.foodDuration != nil
                    ? SOSFoodNeedData(duration: legacySupplyDetails?.foodDuration)
                    : nil,
                blanket: legacySupplyDetails?.isColdOrWet != nil ||
                    legacySupplyDetails?.blanketAvailability != nil ||
                    legacySupplyDetails?.blanketRequestCount != nil ||
                    legacySupplyDetails?.areBlanketsEnough != nil
                    ? SOSBlanketNeedData(
                        isColdOrWet: legacySupplyDetails?.isColdOrWet,
                        availability: legacySupplyDetails?.blanketAvailability,
                        requestCount: legacySupplyDetails?.areBlanketsEnough == true ? nil : legacySupplyDetails?.blanketRequestCount
                    )
                    : nil,
                medicine: legacySupplyDetails?.needsUrgentMedicine != nil ||
                    legacySupplyDetails?.medicineConditions != nil ||
                    legacySupplyDetails?.medicineOtherDescription != nil ||
                    legacySupplyDetails?.medicalNeeds != nil ||
                    legacySupplyDetails?.medicalDescription != nil
                    ? SOSMedicineNeedData(
                        needsUrgentMedicine: legacySupplyDetails?.needsUrgentMedicine,
                        conditions: legacySupplyDetails?.medicineConditions,
                        otherDescription: legacySupplyDetails?.medicineOtherDescription,
                        medicalNeeds: legacySupplyDetails?.medicalNeeds,
                        medicalDescription: legacySupplyDetails?.medicalDescription
                    )
                    : nil,
                clothing: legacySupplyDetails?.clothingStatus != nil
                    ? SOSClothingGroupNeedData(status: legacySupplyDetails?.clothingStatus)
                    : nil,
                otherSupplyDescription: legacyOtherSupplyDescription
            )
        } else {
            groupNeeds = nil
        }

        victims = nil
    }

    var peopleCount: SOSPeopleCount? {
        incident?.peopleCount
    }

    var additionalDescription: String? {
        incident?.additionalDescription
    }

    var address: String? {
        incident?.address
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

// MARK: - Victim / Reporter / Sender Info

struct SOSVictimInfo: Codable {
    let userId: String?
    let userName: String?
    let userPhone: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case userName = "user_name"
        case userPhone = "user_phone"
    }

    init(
        userId: String? = nil,
        userName: String? = nil,
        userPhone: String? = nil
    ) {
        self.userId = userId
        self.userName = userName
        self.userPhone = userPhone
    }
}

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

typealias SOSReporterInfo = SOSSenderInfo

// MARK: - SOS Packet

struct SOSPacket: Codable {
    let packetId: String
    let originId: String
    let ts: Int64
    var createdAt: String
    let location: SOSLocation
    let sosType: String?
    let msg: String
    let structuredData: SOSStructuredData?
    var networkMetadata: SOSNetworkMetadata
    let victimInfo: SOSVictimInfo?
    let reporterInfo: SOSReporterInfo?
    let isSentOnBehalf: Bool?
    let senderInfo: SOSSenderInfo?

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
    }

    init(
        packetId: String = UUID().uuidString,
        originId: String,
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        accuracy: Double? = nil,
        address: String? = nil,
        message: String,
        victimInfo: SOSVictimInfo? = nil,
        reporterInfo: SOSReporterInfo? = nil,
        isSentOnBehalf: Bool? = nil,
        senderInfo: SOSSenderInfo? = nil,
        hopCount: Int = 0,
        path: [String] = []
    ) {
        self.init(
            packetId: packetId,
            originId: originId,
            ts: Int64(timestamp.timeIntervalSince1970),
            createdAt: ISO8601DateFormatter().string(from: timestamp),
            location: SOSLocation(lat: latitude, lng: longitude, accuracy: accuracy, address: address),
            sosType: nil,
            msg: message,
            structuredData: nil,
            networkMetadata: SOSNetworkMetadata(hopCount: hopCount, path: path.isEmpty ? [originId] : path),
            victimInfo: victimInfo,
            reporterInfo: reporterInfo,
            isSentOnBehalf: isSentOnBehalf,
            senderInfo: senderInfo
        )
    }

    init(
        packetId: String = UUID().uuidString,
        originId: String,
        timestamp: Date = Date(),
        latitude: Double,
        longitude: Double,
        accuracy: Double? = nil,
        address: String? = nil,
        sosType: String,
        message: String,
        structuredData: SOSStructuredData?,
        victimInfo: SOSVictimInfo? = nil,
        reporterInfo: SOSReporterInfo? = nil,
        isSentOnBehalf: Bool? = nil,
        senderInfo: SOSSenderInfo? = nil,
        hopCount: Int = 0,
        path: [String] = []
    ) {
        self.init(
            packetId: packetId,
            originId: originId,
            ts: Int64(timestamp.timeIntervalSince1970),
            createdAt: ISO8601DateFormatter().string(from: timestamp),
            location: SOSLocation(lat: latitude, lng: longitude, accuracy: accuracy, address: address),
            sosType: sosType,
            msg: message,
            structuredData: structuredData,
            networkMetadata: SOSNetworkMetadata(hopCount: hopCount, path: path.isEmpty ? [originId] : path),
            victimInfo: victimInfo,
            reporterInfo: reporterInfo,
            isSentOnBehalf: isSentOnBehalf,
            senderInfo: senderInfo
        )
    }

    init(
        packetId: String,
        originId: String,
        ts: Int64,
        createdAt: String,
        location: SOSLocation,
        sosType: String?,
        msg: String,
        structuredData: SOSStructuredData?,
        networkMetadata: SOSNetworkMetadata,
        victimInfo: SOSVictimInfo?,
        reporterInfo: SOSReporterInfo?,
        isSentOnBehalf: Bool?,
        senderInfo: SOSSenderInfo?
    ) {
        self.packetId = packetId
        self.originId = originId
        self.ts = ts
        self.createdAt = createdAt
        self.location = location
        self.sosType = sosType
        self.msg = msg
        self.structuredData = structuredData
        self.networkMetadata = networkMetadata
        self.victimInfo = victimInfo
        self.reporterInfo = reporterInfo
        self.isSentOnBehalf = isSentOnBehalf
        self.senderInfo = senderInfo
    }

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

// MARK: - Legacy Types

struct PeopleCountData: Codable {
    let total: Int
    let adults: Int
    let children: Int
    let elderly: Int
    let injured: Int

    init(total: Int = 0, adults: Int = 0, children: Int = 0, elderly: Int = 0, injured: Int = 0) {
        self.total = total
        self.adults = adults
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

// MARK: - Mesh Payload

enum MeshMessageType: String, Codable {
    case chat
    case sosLocation
    case sosRelay
    case serverRequest
    case serverAck
    case userInfo
}

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

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmedNilIfEmpty: String? {
        nilIfBlank
    }
}

private extension Optional where Wrapped == String {
    var trimmedNilIfEmpty: String? {
        switch self {
        case .some(let value):
            return value.trimmedNilIfEmpty
        case .none:
            return nil
        }
    }
}
