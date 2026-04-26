//
//  SOSStorage.swift
//  SosMienTrung
//
//  Lưu trữ SOS đã gửi với đầy đủ structured data để xem lại và chỉnh sửa
//

import Foundation
import SwiftUI
import Combine

/// SOS đã lưu với đầy đủ thông tin
struct SavedSOS: Codable, Identifiable, Equatable {
    var id: String                          // packetId (có thể được update sang server packetId sau sync)
    let timestamp: Date
    var sosType: SOSType?
    var latitude: Double?
    var longitude: Double?
    var message: String
    
    // Structured data
    var sharedPeople: [Person]
    var personSourceMode: SOSPersonSourceMode
    var selectedRelativeSnapshots: [SelectedRelativeSnapshot]
    var reliefData: ReliefData?
    var rescueData: SavedRescueData?
    var additionalDescription: String
    
    // Status
    var status: SOSSendStatus
    var lastUpdated: Date
    
    // Lịch sử gửi
    var sendHistory: [SOSSendEvent]
    
    // Victim / reporter info
    let reportingTarget: SOSReportingTarget
    var victimName: String?
    var victimPhone: String?
    var reporterName: String?
    var reporterPhone: String?
    var addressQuery: String
    var resolvedAddress: String?
    var manualLocation: SOSManualLocation?
    var serverSosRequestId: Int?
    var isCompanion: Bool
    var latestIncidentNote: String?
    var latestIncidentAt: Date?
    
    /// Kiểm tra có phải của mình không
    var isMine: Bool
    
    /// Tạo từ SOSFormData khi gửi mới
    init(from formData: SOSFormData, packetId: String, latitude: Double?, longitude: Double?) {
        self.id = packetId
        self.timestamp = Date()
        self.sosType = formData.sosType
        self.latitude = latitude
        self.longitude = longitude
        self.message = formData.toSOSMessage()
        self.sharedPeople = formData.sharedPeople
        self.personSourceMode = formData.personSourceMode
        self.selectedRelativeSnapshots = formData.selectedRelativeSnapshots
        
        // Lưu cả relief và rescue data nếu có
        if formData.needsReliefStep {
            self.reliefData = formData.reliefData
        } else {
            self.reliefData = nil
        }
        
        if formData.needsRescueStep {
            self.rescueData = SavedRescueData(from: formData.rescueData)
        } else {
            self.rescueData = nil
        }
        
        self.additionalDescription = formData.additionalDescription
        self.status = .pending
        self.lastUpdated = Date()
        self.sendHistory = [SOSSendEvent(type: .created)]
        self.reportingTarget = formData.reportingTarget
        self.victimName = formData.effectiveVictimName
        self.victimPhone = formData.effectiveVictimPhone
        self.reporterName = formData.autoInfo?.userName
        self.reporterPhone = formData.autoInfo?.userPhone
        self.addressQuery = formData.addressQuery
        self.resolvedAddress = formData.resolvedAddress
        self.manualLocation = formData.manualLocation
        self.serverSosRequestId = nil
        self.isCompanion = false
        self.latestIncidentNote = nil
        self.latestIncidentAt = nil
        self.isMine = true
    }
    
    /// Khôi phục lại SOSFormData để chỉnh sửa
    func toFormData() -> SOSFormData {
        let formData = SOSFormData()
        
        // Khôi phục selectedTypes từ sosType và data có sẵn
        if let type = sosType {
            formData.selectedTypes.insert(type)
        }
        // Nếu có cả relief và rescue data, thêm cả 2 type
        if reliefData != nil && !formData.selectedTypes.contains(.relief) {
            formData.selectedTypes.insert(.relief)
        }
        if rescueData != nil && !formData.selectedTypes.contains(.rescue) {
            formData.selectedTypes.insert(.rescue)
        }
        
        formData.additionalDescription = additionalDescription
        
        if let relief = reliefData {
            formData.reliefData = relief
            formData.sharedPeopleCount = relief.peopleCount
        }
        
        if let rescue = rescueData {
            formData.rescueData = rescue.toRescueData()
            formData.sharedPeopleCount = rescue.peopleCount
        }

        formData.personSourceMode = personSourceMode
        formData.selectedRelativeSnapshots = selectedRelativeSnapshots

        let restoredPeople = !sharedPeople.isEmpty
            ? sharedPeople
            : (rescueData?.people ?? [])
        if !restoredPeople.isEmpty {
            formData.restoreSharedPeople(restoredPeople)
        } else {
            formData.syncPeopleCount()
        }
        
        formData.reportingTarget = reportingTarget
        formData.victimName = victimName ?? ""
        formData.victimPhone = victimPhone ?? ""
        formData.addressQuery = addressQuery
        formData.resolvedAddress = resolvedAddress
        formData.manualLocation = manualLocation

        // Set auto info nếu có location
        if let lat = latitude, let lon = longitude {
            formData.autoInfo = AutoCollectedInfo(
                deviceId: UserProfile.shared.currentUser?.id.uuidString ?? "",
                userId: AuthSessionStore.shared.session?.userId,
                userName: reporterName,
                userPhone: reporterPhone,
                timestamp: timestamp,
                latitude: lat,
                longitude: lon
            )
        }
        
        return formData
    }

    private init(
        id: String,
        timestamp: Date,
        sosType: SOSType?,
        latitude: Double?,
        longitude: Double?,
        message: String,
        sharedPeople: [Person],
        personSourceMode: SOSPersonSourceMode,
        selectedRelativeSnapshots: [SelectedRelativeSnapshot],
        reliefData: ReliefData?,
        rescueData: SavedRescueData?,
        additionalDescription: String,
        status: SOSSendStatus,
        lastUpdated: Date,
        sendHistory: [SOSSendEvent],
        reportingTarget: SOSReportingTarget,
        victimName: String?,
        victimPhone: String?,
        reporterName: String?,
        reporterPhone: String?,
        addressQuery: String,
        resolvedAddress: String?,
        manualLocation: SOSManualLocation?,
        serverSosRequestId: Int?,
        isCompanion: Bool,
        latestIncidentNote: String?,
        latestIncidentAt: Date?,
        isMine: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sosType = sosType
        self.latitude = latitude
        self.longitude = longitude
        self.message = message
        self.sharedPeople = sharedPeople
        self.personSourceMode = personSourceMode
        self.selectedRelativeSnapshots = selectedRelativeSnapshots
        self.reliefData = reliefData
        self.rescueData = rescueData
        self.additionalDescription = additionalDescription
        self.status = status
        self.lastUpdated = lastUpdated
        self.sendHistory = sendHistory
        self.reportingTarget = reportingTarget
        self.victimName = victimName
        self.victimPhone = victimPhone
        self.reporterName = reporterName
        self.reporterPhone = reporterPhone
        self.addressQuery = addressQuery
        self.resolvedAddress = resolvedAddress
        self.manualLocation = manualLocation
        self.serverSosRequestId = serverSosRequestId
        self.isCompanion = isCompanion
        self.latestIncidentNote = latestIncidentNote
        self.latestIncidentAt = latestIncidentAt
        self.isMine = isMine
    }

    private static func trimmedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func serverDate(from rawValue: String?) -> Date? {
        guard let rawValue = trimmedValue(rawValue) else { return nil }

        let fullFormatter = ISO8601DateFormatter()
        fullFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let basicFormatter = ISO8601DateFormatter()
        basicFormatter.formatOptions = [.withInternetDateTime]

        return fullFormatter.date(from: rawValue) ?? basicFormatter.date(from: rawValue)
    }

    private static func personType(from rawValue: String, personId: String) -> Person.PersonType {
        if let type = Person.PersonType(rawValue: rawValue.uppercased()) {
            return type
        }
        if personId.lowercased().contains("child") {
            return .child
        }
        if personId.lowercased().contains("elderly") || personId.lowercased().contains("senior") {
            return .elderly
        }
        return .adult
    }

    private static func derivedPeopleCount(
        incident: SOSIncidentData?,
        victims: [SOSVictimEntry]
    ) -> PeopleCount {
        let derivedFromVictims = PeopleCount(
            adults: victims.filter { personType(from: $0.personType, personId: $0.personId) == .adult }.count,
            children: victims.filter { personType(from: $0.personType, personId: $0.personId) == .child }.count,
            elderly: victims.filter { personType(from: $0.personType, personId: $0.personId) == .elderly }.count
        )

        guard let peopleCount = incident?.peopleCount else {
            return derivedFromVictims
        }

        return PeopleCount(
            adults: max(peopleCount.adult, derivedFromVictims.adults),
            children: max(peopleCount.child, derivedFromVictims.children),
            elderly: max(peopleCount.elderly, derivedFromVictims.elderly)
        )
    }

    private static func buildSharedPeople(
        victims: [SOSVictimEntry],
        peopleCount: PeopleCount
    ) -> [Person] {
        var people = victims.map { victim in
            Person(
                id: victim.personId,
                type: personType(from: victim.personType, personId: victim.personId),
                index: victim.index,
                customName: trimmedValue(victim.customName) ?? ""
            )
        }

        func appendPlaceholders(
            type: Person.PersonType,
            targetCount: Int
        ) {
            let existing = people.filter { $0.type == type }
            guard existing.count < targetCount else { return }

            let nextIndexStart = max(existing.map(\.index).max() ?? 0, existing.count)
            for offset in 1...(targetCount - existing.count) {
                let index = nextIndexStart + offset
                people.append(
                    Person(
                        id: "\(type.idPrefix)_\(index)",
                        type: type,
                        index: index
                    )
                )
            }
        }

        appendPlaceholders(type: .adult, targetCount: peopleCount.adults)
        appendPlaceholders(type: .child, targetCount: peopleCount.children)
        appendPlaceholders(type: .elderly, targetCount: peopleCount.elderly)

        return people.sorted {
            if $0.type == $1.type {
                return $0.index < $1.index
            }
            return $0.type.rawValue < $1.type.rawValue
        }
    }

    private static func buildRescueData(
        sosType: String?,
        incident: SOSIncidentData?,
        victims: [SOSVictimEntry],
        sharedPeople: [Person],
        peopleCount: PeopleCount
    ) -> SavedRescueData? {
        let normalizedSOSType = sosType?.uppercased()
        let shouldCreateRescueData = normalizedSOSType == "RESCUE"
            || normalizedSOSType == "BOTH"
            || incident?.situation != nil
            || incident?.hasInjured != nil
            || incident?.othersAreStable != nil
            || incident?.otherMedicalDescription != nil
            || victims.contains(where: { $0.incidentStatus.isInjured || !$0.incidentStatus.medicalIssues.isEmpty })

        guard shouldCreateRescueData else { return nil }

        var rescueData = RescueData()
        rescueData.situation = incident?.situation
        rescueData.otherSituationDescription = incident?.otherSituationDescription ?? ""
        rescueData.peopleCount = peopleCount
        rescueData.people = sharedPeople
        rescueData.hasInjured = incident?.hasInjured ?? victims.contains(where: \.incidentStatus.isInjured)
        rescueData.canMove = incident?.canMove
        rescueData.otherMedicalDescription = incident?.otherMedicalDescription ?? ""
        rescueData.othersAreStable = incident?.othersAreStable ?? false

        var allMedicalIssues: Set<String> = []
        for victim in victims where victim.incidentStatus.isInjured || !victim.incidentStatus.medicalIssues.isEmpty {
            let personIssues = Set(victim.incidentStatus.medicalIssues)
            allMedicalIssues.formUnion(personIssues)
            rescueData.injuredPersonIds.insert(victim.personId)
            rescueData.medicalInfoByPerson[victim.personId] = PersonMedicalInfo(
                personId: victim.personId,
                medicalIssues: personIssues
            )
        }

        if !rescueData.injuredPersonIds.isEmpty {
            rescueData.hasInjured = true
        }
        rescueData.medicalIssues = allMedicalIssues

        return SavedRescueData(from: rescueData)
    }

    private static func buildReliefData(
        sosType: String?,
        groupNeeds: SOSGroupNeedsData?,
        victims: [SOSVictimEntry],
        peopleCount: PeopleCount
    ) -> ReliefData? {
        let normalizedSOSType = sosType?.uppercased()
        let shouldCreateReliefData = normalizedSOSType == "RELIEF"
            || normalizedSOSType == "BOTH"
            || groupNeeds != nil
            || victims.contains(where: {
                $0.personalNeeds.clothing.needed
                    || $0.personalNeeds.diet.hasSpecialDiet
                    || trimmedValue($0.personalNeeds.diet.description) != nil
            })

        guard shouldCreateReliefData else { return nil }

        var reliefData = ReliefData()
        reliefData.peopleCount = peopleCount
        reliefData.supplies = Set((groupNeeds?.supplies ?? []).compactMap(SupplyNeed.init(rawValue:)))
        reliefData.otherSupplyDescription = groupNeeds?.otherSupplyDescription ?? ""
        reliefData.waterDuration = groupNeeds?.water?.duration
        reliefData.waterRemaining = groupNeeds?.water?.remaining.flatMap(WaterRemaining.init(rawValue:))
        reliefData.foodDuration = groupNeeds?.food?.duration
        reliefData.needsUrgentMedicine = groupNeeds?.medicine?.needsUrgentMedicine
        reliefData.medicineConditions = Set((groupNeeds?.medicine?.conditions ?? []).compactMap(MedicineCondition.init(rawValue:)))
        reliefData.medicineOtherDescription = groupNeeds?.medicine?.otherDescription ?? ""
        reliefData.medicalNeeds = Set((groupNeeds?.medicine?.medicalNeeds ?? []).compactMap(MedicalSupportNeed.init(rawValue:)))
        reliefData.medicalDescription = groupNeeds?.medicine?.medicalDescription ?? ""
        reliefData.isColdOrWet = groupNeeds?.blanket?.isColdOrWet
        reliefData.blanketAvailability = groupNeeds?.blanket?.availability.flatMap(BlanketAvailability.init(rawValue:))
        reliefData.blanketRequestCount = groupNeeds?.blanket?.requestCount
        if let blanketAvailability = reliefData.blanketAvailability {
            reliefData.areBlanketsEnough = blanketAvailability == .enough
            if blanketAvailability == .enough {
                reliefData.blanketRequestCount = nil
            }
        } else if reliefData.blanketRequestCount != nil {
            reliefData.areBlanketsEnough = false
        }
        reliefData.clothingStatus = groupNeeds?.clothing?.status.flatMap(ClothingStatus.init(rawValue:))

        for victim in victims {
            if victim.personalNeeds.clothing.needed {
                reliefData.clothingPersonIds.insert(victim.personId)
                reliefData.clothingInfoByPerson[victim.personId] = ClothingPersonInfo(
                    personId: victim.personId,
                    gender: victim.personalNeeds.clothing.gender.flatMap(ClothingGender.init(rawValue:))
                )
            }

            let hasSpecialDiet = victim.personalNeeds.diet.hasSpecialDiet
                || trimmedValue(victim.personalNeeds.diet.description) != nil
            if hasSpecialDiet {
                reliefData.specialDietPersonIds.insert(victim.personId)
                if let description = trimmedValue(victim.personalNeeds.diet.description) {
                    reliefData.specialDietInfoByPerson[victim.personId] = PersonSpecialDietInfo(
                        personId: victim.personId,
                        dietDescription: description
                    )
                }
            }
        }

        return reliefData
    }
    
    /// Tạo từ record trả về bởi server (GET /emergency/sos-requests/me)
    init(fromServer record: SOSServerRecord) {
        let serverVictims = record.structuredData?.victims ?? []
        let peopleCount = Self.derivedPeopleCount(
            incident: record.structuredData?.incident,
            victims: serverVictims
        )
        let sharedPeople = Self.buildSharedPeople(
            victims: serverVictims,
            peopleCount: peopleCount
        )
        let rescueData = Self.buildRescueData(
            sosType: record.sosType,
            incident: record.structuredData?.incident,
            victims: serverVictims,
            sharedPeople: sharedPeople,
            peopleCount: peopleCount
        )
        let reliefData = Self.buildReliefData(
            sosType: record.sosType,
            groupNeeds: record.structuredData?.groupNeeds,
            victims: serverVictims,
            peopleCount: peopleCount
        )
        let derivedVictimName: String? = {
            if let explicitName = Self.trimmedValue(record.victimInfo?.userName) {
                return explicitName
            }
            if serverVictims.count > 1 {
                return "Nhóm \(serverVictims.count) người"
            }
            if let victim = serverVictims.first {
                return Self.trimmedValue(victim.customName)
            }
            return record.senderInfo?.userName
        }()
        let derivedVictimPhone: String? = {
            if let explicitPhone = Self.trimmedValue(record.victimInfo?.userPhone) {
                return explicitPhone
            }
            if serverVictims.count == 1 {
                return Self.trimmedValue(serverVictims.first?.personPhone)
            }
            return nil
        }()

        self.init(
            id: record.packetId,
            timestamp: Self.serverDate(from: record.createdAt)
                ?? Date(timeIntervalSince1970: TimeInterval(record.timestamp)),
            sosType: SOSType(rawValue: record.sosType ?? ""),
            latitude: record.latitude,
            longitude: record.longitude,
            message: record.rawMessage,
            sharedPeople: sharedPeople,
            personSourceMode: .manual,
            selectedRelativeSnapshots: [],
            reliefData: reliefData,
            rescueData: rescueData,
            additionalDescription: record.structuredData?.additionalDescription ?? "",
            status: SOSServerRecord.mapStatus(record.status),
            lastUpdated: Date(),
            sendHistory: [SOSSendEvent(type: .serverAcknowledged, note: "Đồng bộ từ server (trạng thái: \(record.status ?? "unknown"))")],
            reportingTarget: record.isSentOnBehalf == true ? .other : .self,
            victimName: derivedVictimName,
            victimPhone: derivedVictimPhone,
            reporterName: record.reporterInfo?.userName ?? (record.isSentOnBehalf == true ? nil : record.senderInfo?.userName),
            reporterPhone: record.reporterInfo?.userPhone ?? (record.isSentOnBehalf == true ? nil : record.senderInfo?.userPhone),
            addressQuery: record.structuredData?.address ?? "",
            resolvedAddress: record.structuredData?.address,
            manualLocation: {
                guard record.structuredData?.address != nil,
                      let latitude = record.latitude,
                      let longitude = record.longitude else {
                    return nil
                }
                return SOSManualLocation(latitude: latitude, longitude: longitude, accuracy: record.locationAccuracy)
            }(),
            serverSosRequestId: record.id,
            isCompanion: record.isCompanion ?? false,
            latestIncidentNote: Self.trimmedValue(record.latestIncidentNote),
            latestIncidentAt: Self.serverDate(from: record.latestIncidentAt),
            isMine: true
        )
    }

    func merged(withServer record: SOSServerRecord) -> SavedSOS {
        let serverSnapshot = SavedSOS(fromServer: record)
        let serverStatus = SOSServerRecord.mapStatus(record.status)

        var mergedHistory = sendHistory
        if status != serverStatus {
            mergedHistory.append(
                SOSSendEvent(
                    type: .serverAcknowledged,
                    note: "Cập nhật từ server: \(serverStatus.title)"
                )
            )
        }

        return SavedSOS(
            id: serverSnapshot.id,
            timestamp: serverSnapshot.timestamp,
            sosType: serverSnapshot.sosType ?? sosType,
            latitude: serverSnapshot.latitude ?? latitude,
            longitude: serverSnapshot.longitude ?? longitude,
            message: Self.trimmedValue(serverSnapshot.message) ?? message,
            sharedPeople: serverSnapshot.sharedPeople.isEmpty ? sharedPeople : serverSnapshot.sharedPeople,
            personSourceMode: personSourceMode,
            selectedRelativeSnapshots: selectedRelativeSnapshots,
            reliefData: serverSnapshot.reliefData ?? reliefData,
            rescueData: serverSnapshot.rescueData ?? rescueData,
            additionalDescription: Self.trimmedValue(serverSnapshot.additionalDescription) ?? additionalDescription,
            status: serverStatus,
            lastUpdated: Date(),
            sendHistory: mergedHistory,
            reportingTarget: serverSnapshot.reportingTarget,
            victimName: serverSnapshot.victimName ?? victimName,
            victimPhone: serverSnapshot.victimPhone ?? victimPhone,
            reporterName: serverSnapshot.reporterName ?? reporterName,
            reporterPhone: serverSnapshot.reporterPhone ?? reporterPhone,
            addressQuery: Self.trimmedValue(serverSnapshot.addressQuery) ?? addressQuery,
            resolvedAddress: serverSnapshot.resolvedAddress ?? resolvedAddress,
            manualLocation: serverSnapshot.manualLocation ?? manualLocation,
            serverSosRequestId: serverSnapshot.serverSosRequestId ?? serverSosRequestId,
            isCompanion: isCompanion || serverSnapshot.isCompanion,
            latestIncidentNote: serverSnapshot.latestIncidentNote ?? latestIncidentNote,
            latestIncidentAt: serverSnapshot.latestIncidentAt ?? latestIncidentAt,
            isMine: isMine || serverSnapshot.isMine
        )
    }
    
    // MARK: - Codable (backward compat cho sendHistory)
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, sosType, latitude, longitude, message
        case sharedPeople, personSourceMode, selectedRelativeSnapshots, reliefData, rescueData, additionalDescription
        case status, lastUpdated, sendHistory
        case reportingTarget, victimName, victimPhone, reporterName, reporterPhone
        case addressQuery, resolvedAddress, manualLocation
        case serverSosRequestId, isCompanion, latestIncidentNote, latestIncidentAt
        case senderName, senderPhone, isMine
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let legacySenderName = try c.decodeIfPresent(String.self, forKey: .senderName)
        let legacySenderPhone = try c.decodeIfPresent(String.self, forKey: .senderPhone)
        id                   = try c.decode(String.self, forKey: .id)
        timestamp            = try c.decode(Date.self, forKey: .timestamp)
        sosType              = try c.decodeIfPresent(SOSType.self, forKey: .sosType)
        latitude             = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude            = try c.decodeIfPresent(Double.self, forKey: .longitude)
        message              = try c.decode(String.self, forKey: .message)
        sharedPeople         = (try? c.decodeIfPresent([Person].self, forKey: .sharedPeople)) ?? []
        personSourceMode     = try c.decodeIfPresent(SOSPersonSourceMode.self, forKey: .personSourceMode) ?? .manual
        selectedRelativeSnapshots = (try? c.decodeIfPresent([SelectedRelativeSnapshot].self, forKey: .selectedRelativeSnapshots)) ?? []
        reliefData           = try c.decodeIfPresent(ReliefData.self, forKey: .reliefData)
        rescueData           = try c.decodeIfPresent(SavedRescueData.self, forKey: .rescueData)
        additionalDescription = try c.decode(String.self, forKey: .additionalDescription)
        status               = try c.decode(SOSSendStatus.self, forKey: .status)
        lastUpdated          = try c.decode(Date.self, forKey: .lastUpdated)
        // sendHistory không tồn tại ở dữ liệu cũ → mặc định []
        sendHistory          = (try? c.decodeIfPresent([SOSSendEvent].self, forKey: .sendHistory)) ?? []
        reportingTarget      = try c.decodeIfPresent(SOSReportingTarget.self, forKey: .reportingTarget) ?? .self
        victimName           = try c.decodeIfPresent(String.self, forKey: .victimName) ?? legacySenderName
        victimPhone          = try c.decodeIfPresent(String.self, forKey: .victimPhone) ?? legacySenderPhone
        reporterName         = try c.decodeIfPresent(String.self, forKey: .reporterName) ?? legacySenderName
        reporterPhone        = try c.decodeIfPresent(String.self, forKey: .reporterPhone) ?? legacySenderPhone
        addressQuery         = try c.decodeIfPresent(String.self, forKey: .addressQuery) ?? ""
        resolvedAddress      = try c.decodeIfPresent(String.self, forKey: .resolvedAddress)
        manualLocation       = try c.decodeIfPresent(SOSManualLocation.self, forKey: .manualLocation)
        serverSosRequestId   = try c.decodeIfPresent(Int.self, forKey: .serverSosRequestId)
        isCompanion          = try c.decodeIfPresent(Bool.self, forKey: .isCompanion) ?? false
        latestIncidentNote   = try c.decodeIfPresent(String.self, forKey: .latestIncidentNote)
        latestIncidentAt     = try c.decodeIfPresent(Date.self, forKey: .latestIncidentAt)
        isMine               = try c.decode(Bool.self, forKey: .isMine)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sosType, forKey: .sosType)
        try c.encodeIfPresent(latitude, forKey: .latitude)
        try c.encodeIfPresent(longitude, forKey: .longitude)
        try c.encode(message, forKey: .message)
        try c.encode(sharedPeople, forKey: .sharedPeople)
        try c.encode(personSourceMode, forKey: .personSourceMode)
        try c.encode(selectedRelativeSnapshots, forKey: .selectedRelativeSnapshots)
        try c.encodeIfPresent(reliefData, forKey: .reliefData)
        try c.encodeIfPresent(rescueData, forKey: .rescueData)
        try c.encode(additionalDescription, forKey: .additionalDescription)
        try c.encode(status, forKey: .status)
        try c.encode(lastUpdated, forKey: .lastUpdated)
        try c.encode(sendHistory, forKey: .sendHistory)
        try c.encode(reportingTarget, forKey: .reportingTarget)
        try c.encodeIfPresent(victimName, forKey: .victimName)
        try c.encodeIfPresent(victimPhone, forKey: .victimPhone)
        try c.encodeIfPresent(reporterName, forKey: .reporterName)
        try c.encodeIfPresent(reporterPhone, forKey: .reporterPhone)
        try c.encode(addressQuery, forKey: .addressQuery)
        try c.encodeIfPresent(resolvedAddress, forKey: .resolvedAddress)
        try c.encodeIfPresent(manualLocation, forKey: .manualLocation)
        try c.encodeIfPresent(serverSosRequestId, forKey: .serverSosRequestId)
        try c.encode(isCompanion, forKey: .isCompanion)
        try c.encodeIfPresent(latestIncidentNote, forKey: .latestIncidentNote)
        try c.encodeIfPresent(latestIncidentAt, forKey: .latestIncidentAt)
        // Keep legacy keys so older local payloads can still read the victim identity.
        try c.encodeIfPresent(victimName, forKey: .senderName)
        try c.encodeIfPresent(victimPhone, forKey: .senderPhone)
        try c.encode(isMine, forKey: .isMine)
    }
}

/// Status của SOS đã gửi
enum SOSSendStatus: String, Codable {
    case draft = "DRAFT"        // Nháp
    case pending = "PENDING"    // Đang gửi (chưa lên server)
    case sent = "SENT"          // Đã gửi lên server
    case delivered = "DELIVERED" // Server đã xác nhận
    case relayed = "RELAYED"    // Đang relay qua mesh
    case resolved = "RESOLVED"  // Đã xử lý xong
    
    var title: String {
        switch self {
        case .draft: return "Nháp"
        case .pending: return "Đang gửi"
        case .sent: return "Đã gửi"
        case .delivered: return "Đã nhận"
        case .relayed: return "Đang relay"
        case .resolved: return "Đã xử lý"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return .gray
        case .pending: return .orange
        case .sent: return .blue
        case .delivered: return .green
        case .relayed: return .purple
        case .resolved: return Color(red: 0.2, green: 0.7, blue: 0.4)
        }
    }
    
    var icon: String {
        switch self {
        case .draft: return "doc"
        case .pending: return "clock.arrow.circlepath"
        case .sent: return "arrow.up.circle.fill"
        case .delivered: return "checkmark.circle.fill"
        case .relayed: return "antenna.radiowaves.left.and.right"
        case .resolved: return "checkmark.seal.fill"
        }
    }
}

// MARK: - SOS Send Event

/// Loại sự kiện trong lịch sử gửi SOS
enum SOSSendEventType: String, Codable {
    case created = "CREATED"                   // Tạo ra cục bộ
    case sentViaNetwork = "SENT_NETWORK"        // Gửi trực tiếp qua mạng lên server
    case sentViaMesh = "SENT_MESH"              // Broadcast qua Mesh để nhờ relay
    case pendingRetry = "PENDING_RETRY"         // Đang chờ retry (chưa có mạng)
    case serverAcknowledged = "SERVER_ACK"      // Server đã xác nhận nhận được
    
    var title: String {
        switch self {
        case .created:            return "Đã tạo"
        case .sentViaNetwork:     return "Gửi qua Internet"
        case .sentViaMesh:        return "Phát qua Mesh Network"
        case .pendingRetry:       return "Chờ gửi lại"
        case .serverAcknowledged: return "Server xác nhận"
        }
    }
    
    var icon: String {
        switch self {
        case .created:            return "plus.circle.fill"
        case .sentViaNetwork:     return "wifi"
        case .sentViaMesh:        return "antenna.radiowaves.left.and.right"
        case .pendingRetry:       return "clock.arrow.circlepath"
        case .serverAcknowledged: return "checkmark.seal.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .created:            return .gray
        case .sentViaNetwork:     return .blue
        case .sentViaMesh:        return .purple
        case .pendingRetry:       return .orange
        case .serverAcknowledged: return .green
        }
    }
}

/// Một sự kiện trong lịch sử gửi SOS
struct SOSSendEvent: Codable, Identifiable, Equatable {
    let id: String
    let timestamp: Date
    let type: SOSSendEventType
    let note: String?
    
    init(type: SOSSendEventType, note: String? = nil) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.type = type
        self.note = note
    }
}

/// Phiên bản lưu trữ của RescueData (Codable friendly)
struct SavedRescueData: Codable, Equatable {
    var situation: String?
    var otherSituationDescription: String
    var peopleCount: PeopleCount
    var hasInjured: Bool
    var injuredPersonIds: [String]
    var canMove: Bool?
    var medicalInfoByPerson: [String: PersonMedicalInfo]
    var medicalIssues: [String]
    var otherMedicalDescription: String
    var othersAreStable: Bool
    var people: [Person]
    
    init(from rescueData: RescueData) {
        self.situation = rescueData.situation
        self.otherSituationDescription = rescueData.otherSituationDescription
        self.peopleCount = rescueData.peopleCount
        self.hasInjured = rescueData.hasInjured
        self.injuredPersonIds = Array(rescueData.injuredPersonIds)
        self.canMove = rescueData.canMove
        self.medicalInfoByPerson = rescueData.medicalInfoByPerson
        self.medicalIssues = Array(rescueData.medicalIssues)
        self.otherMedicalDescription = rescueData.otherMedicalDescription
        self.othersAreStable = rescueData.othersAreStable
        self.people = rescueData.people
    }
    
    func toRescueData() -> RescueData {
        var data = RescueData()
        data.situation = situation
        data.otherSituationDescription = otherSituationDescription
        data.peopleCount = peopleCount
        data.hasInjured = hasInjured
        data.injuredPersonIds = Set(injuredPersonIds)
        data.canMove = canMove
        data.medicalInfoByPerson = medicalInfoByPerson
        data.medicalIssues = Set(medicalIssues)
        data.otherMedicalDescription = otherMedicalDescription
        data.othersAreStable = othersAreStable
        data.people = people
        if data.people.isEmpty {
            data.generatePeople()
        }
        return data
    }
}

// MARK: - Server Response Models

/// Record SOS trả về từ API /emergency/sos-requests/me
struct SOSServerRecord: Decodable {
    let id: Int
    let packetId: String
    let clusterId: Int?
    let userId: String?
    let sosType: String?
    let rawMessage: String
    let structuredData: SOSStructuredData?
    let networkMetadata: SOSNetworkMetadata?
    let victimInfo: SOSVictimInfo?
    let reporterInfo: SOSReporterInfo?
    let isSentOnBehalf: Bool?
    let senderInfo: SOSSenderInfo?
    let originId: String?
    let status: String?
    let priorityLevel: String?
    let waitTimeMinutes: Int?
    let latitude: Double?
    let longitude: Double?
    let locationAccuracy: Double?
    let timestamp: Int64
    let createdAt: String?
    let lastUpdatedAt: String?
    let reviewedAt: String?
    let reviewedById: String?
    let latestIncidentNote: String?
    let latestIncidentAt: String?
    let isCompanion: Bool?
    let incidentHistory: [SosIncidentHistoryItem]?
    let companions: [CompanionResult]?

    enum CodingKeys: String, CodingKey {
        case id, packetId, clusterId, userId, sosType, rawMessage, msg
        case structuredData = "structuredData"
        case networkMetadata = "networkMetadata"
        case victimInfo = "victimInfo"
        case reporterInfo = "reporterInfo"
        case isSentOnBehalf = "isSentOnBehalf"
        case senderInfo = "senderInfo"
        case originId, status, priorityLevel, waitTimeMinutes
        case latitude, longitude, locationAccuracy, timestamp
        case createdAt, lastUpdatedAt, reviewedAt, reviewedById
        case latestIncidentNote, latestIncidentAt, isCompanion, incidentHistory, companions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        packetId = try container.decodeIfPresent(String.self, forKey: .packetId)
            ?? container.decodeIfPresent(String.self, forKey: .originId)
            ?? "server-\(id)"
        clusterId = try container.decodeIfPresent(Int.self, forKey: .clusterId)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        sosType = try container.decodeIfPresent(String.self, forKey: .sosType)
        rawMessage = try container.decodeIfPresent(String.self, forKey: .rawMessage)
            ?? container.decode(String.self, forKey: .msg)
        structuredData = try container.decodeIfPresent(SOSStructuredData.self, forKey: .structuredData)
        networkMetadata = try container.decodeIfPresent(SOSNetworkMetadata.self, forKey: .networkMetadata)
        victimInfo = try container.decodeIfPresent(SOSVictimInfo.self, forKey: .victimInfo)
        reporterInfo = try container.decodeIfPresent(SOSReporterInfo.self, forKey: .reporterInfo)
        isSentOnBehalf = try container.decodeIfPresent(Bool.self, forKey: .isSentOnBehalf)
        senderInfo = try container.decodeIfPresent(SOSSenderInfo.self, forKey: .senderInfo)
        originId = try container.decodeIfPresent(String.self, forKey: .originId)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        priorityLevel = try container.decodeIfPresent(String.self, forKey: .priorityLevel)
        waitTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .waitTimeMinutes)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        locationAccuracy = try container.decodeIfPresent(Double.self, forKey: .locationAccuracy)
        timestamp = try container.decodeIfPresent(Int64.self, forKey: .timestamp) ?? 0
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        lastUpdatedAt = try container.decodeIfPresent(String.self, forKey: .lastUpdatedAt)
        reviewedAt = try container.decodeIfPresent(String.self, forKey: .reviewedAt)
        reviewedById = try container.decodeIfPresent(String.self, forKey: .reviewedById)
        latestIncidentNote = try container.decodeIfPresent(String.self, forKey: .latestIncidentNote)
        latestIncidentAt = try container.decodeIfPresent(String.self, forKey: .latestIncidentAt)
        isCompanion = try container.decodeIfPresent(Bool.self, forKey: .isCompanion)
        incidentHistory = try container.decodeIfPresent([SosIncidentHistoryItem].self, forKey: .incidentHistory)
        companions = try container.decodeIfPresent([CompanionResult].self, forKey: .companions)
    }

    /// Map server status string → SOSSendStatus
    static func mapStatus(_ raw: String?) -> SOSSendStatus {
        switch raw {
        case "Pending":                 return .sent
        case "Approved", "InProgress":  return .delivered
        case "Resolved", "Closed":      return .resolved
        default:                        return .sent
        }
    }
}

struct SOSServerResponse: Decodable {
    let sosRequests: [SOSServerRecord]
}

struct SosIncidentHistoryItem: Decodable, Identifiable, Equatable {
    let id: Int
    let teamIncidentId: Int?
    let missionId: Int?
    let missionTeamId: Int?
    let missionActivityId: Int?
    let incidentScope: String?
    let note: String
    let reportedById: String?
    let createdAt: String
    let teamName: String?
    let activityType: String?
}

struct CompanionResult: Decodable, Identifiable, Equatable {
    let userId: String
    let fullName: String?
    let phone: String?
    let addedAt: String?

    var id: String { userId }
}

struct SosRequestDetailResponse: Decodable {
    let sosRequest: SOSServerRecord
}

struct UpdateVictimSosRequestResponse: Decodable {
    let sosRequestId: Int
    let updateType: String
    let updatedAt: String?
}

// MARK: - SOS Storage Manager

final class SOSStorageManager: ObservableObject {
    nonisolated static let shared = SOSStorageManager()
    
    private var currentUserId: String?
    @Published private(set) var savedSOSList: [SavedSOS] = []
    
    private init() {
        // Nếu app restart và user đã đăng nhập trước đó
        if let userId = AuthSessionStore.shared.session?.userId {
            currentUserId = userId
            loadFromStorage()
        }
    }
    
    private func storageKey(for userId: String) -> String {
        "saved_sos_list_\(userId)"
    }
    
    // MARK: - Session Management
    
    /// Gọi khi đăng nhập thành công — load dữ liệu local của user đó
    func reloadForUser(_ userId: String) {
        currentUserId = userId
        loadFromStorage()
    }
    
    /// Gọi khi đăng xuất — xóa in-memory (dữ liệu local vẫn giữ trong UserDefaults)
    func clearSession() {
        currentUserId = nil
        savedSOSList = []
    }
    
    // MARK: - Public Methods
    
    /// Lưu SOS mới khi gửi
    func saveSOS(_ formData: SOSFormData, packetId: String, latitude: Double?, longitude: Double?) {
        let savedSOS = SavedSOS(from: formData, packetId: packetId, latitude: latitude, longitude: longitude)
        savedSOSList.insert(savedSOS, at: 0) // Mới nhất lên đầu
        saveToStorage()
    }
    
    /// Cập nhật SOS đã lưu
    func updateSOS(_ sos: SavedSOS) {
        if let index = savedSOSList.firstIndex(where: { $0.id == sos.id }) {
            var updated = sos
            updated.lastUpdated = Date()
            savedSOSList[index] = updated
            saveToStorage()
        }
    }
    
    /// Cập nhật status của SOS
    func updateStatus(id: String, status: SOSSendStatus) {
        if let index = savedSOSList.firstIndex(where: { $0.id == id }) {
            savedSOSList[index].status = status
            savedSOSList[index].lastUpdated = Date()
            saveToStorage()
        }
    }
    
    /// Ghi thêm sự kiện vào lịch sử gửi của SOS
    func addSendEvent(id: String, event: SOSSendEvent) {
        if let index = savedSOSList.firstIndex(where: { $0.id == id }) {
            savedSOSList[index].sendHistory.append(event)
            savedSOSList[index].lastUpdated = Date()
            saveToStorage()
        }
    }
    
    /// Cập nhật status và đồng thời ghi sự kiện vào lịch sử
    func updateStatusWithEvent(id: String, status: SOSSendStatus, event: SOSSendEvent) {
        if let index = savedSOSList.firstIndex(where: { $0.id == id }) {
            savedSOSList[index].status = status
            savedSOSList[index].lastUpdated = Date()
            savedSOSList[index].sendHistory.append(event)
            saveToStorage()
        }
    }
    
    /// Xóa SOS
    func deleteSOS(id: String) {
        savedSOSList.removeAll { $0.id == id }
        saveToStorage()
    }
    
    /// Lấy SOS theo ID
    func getSOS(id: String) -> SavedSOS? {
        savedSOSList.first { $0.id == id }
    }

    func getSOS(serverSosRequestId: Int) -> SavedSOS? {
        savedSOSList.first { $0.serverSosRequestId == serverSosRequestId }
    }
    
    /// SOS do mình gửi
    var mySOS: [SavedSOS] {
        savedSOSList.filter { $0.isMine }
    }
    
    // MARK: - Server Sync
    
    /// Fetch từ /emergency/sos-requests/me và merge vào local list
    func fetchAndMergeFromServer() async {
        guard let records = await APIService.shared.fetchMySOS() else { return }
        await MainActor.run {
            for record in records {
                let serverTs = Date(timeIntervalSince1970: TimeInterval(record.timestamp))

                // 1. Khớp theo server numeric id nếu đã có
                if let index = savedSOSList.firstIndex(where: { $0.serverSosRequestId == record.id }) {
                    savedSOSList[index] = savedSOSList[index].merged(withServer: record)

                // 2. Khớp chính xác theo packetId
                } else if let index = savedSOSList.firstIndex(where: { $0.id.caseInsensitiveCompare(record.packetId) == .orderedSame }) {
                    savedSOSList[index] = savedSOSList[index].merged(withServer: record)

                // 3. Khớp mờ: cùng sosType + timestamp ±120s (server có thể dùng UUID riêng)
                } else if let index = savedSOSList.firstIndex(where: {
                    $0.isMine &&
                    $0.sosType?.rawValue == record.sosType &&
                    abs($0.timestamp.timeIntervalSince(serverTs)) < 120
                }) {
                    print("[SOS Sync] 🔄 Fuzzy match – cập nhật id local \(savedSOSList[index].id) → server \(record.packetId)")
                    savedSOSList[index] = savedSOSList[index].merged(withServer: record)

                // 4. Record chỉ tồn tại trên server (gửi từ session/thiết bị khác)
                } else {
                    let saved = SavedSOS(fromServer: record)
                    savedSOSList.append(saved)
                }
            }
            savedSOSList.sort { $0.timestamp > $1.timestamp }
            saveToStorage()
        }
    }
    
    // MARK: - Private Methods
    
    private func saveToStorage() {
        guard let userId = currentUserId else { return }
        do {
            let data = try JSONEncoder().encode(savedSOSList)
            UserDefaults.standard.set(data, forKey: storageKey(for: userId))
        } catch {
            print("❌ Failed to save SOS list: \(error)")
        }
    }
    
    private func loadFromStorage() {
        guard let userId = currentUserId else {
            savedSOSList = []
            return
        }
        let key = storageKey(for: userId)
        guard let data = UserDefaults.standard.data(forKey: key) else {
            savedSOSList = []
            return
        }
        do {
            var list = try JSONDecoder().decode([SavedSOS].self, from: data)
            // Loại bỏ trùng lặp: cùng message + sosType + timestamp ±30s
            // Ưu tiên giữ bản có sendHistory dài hơn (bản đã sync với server)
            list = deduplicateList(list)
            savedSOSList = list
        } catch {
            print("❌ Failed to load SOS list: \(error)")
            savedSOSList = []
        }
    }
    
    /// Loại bỏ các entry trùng nội dung, giữ bản có nhiều sendHistory nhất
    private func deduplicateList(_ list: [SavedSOS]) -> [SavedSOS] {
        var seen: [SavedSOS] = []
        for item in list {
            if let existingIndex = seen.firstIndex(where: {
                $0.sosType == item.sosType &&
                $0.message == item.message &&
                abs($0.timestamp.timeIntervalSince(item.timestamp)) < 30
            }) {
                // Giữ bản có sendHistory dài hơn (hoặc mới được update hơn)
                if item.sendHistory.count > seen[existingIndex].sendHistory.count ||
                   item.lastUpdated > seen[existingIndex].lastUpdated {
                    seen[existingIndex] = item
                }
            } else {
                seen.append(item)
            }
        }
        let before = list.count
        let after = seen.count
        if before != after {
            print("[SOS Storage] 🧹 Dedup: \(before) → \(after) records")
        }
        return seen
    }}
