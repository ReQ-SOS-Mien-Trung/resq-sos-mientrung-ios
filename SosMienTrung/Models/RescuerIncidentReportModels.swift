import Foundation

enum RescuerIncidentScope: String, Codable, Equatable {
    case activity = "activity"
    case mission = "mission"
}

enum RescuerActivityIncidentType: String, Codable, CaseIterable, Identifiable {
    case lostSupplies = "lost_supplies"
    case equipmentDamage = "equipment_damage"
    case vehicleDamage = "vehicle_damage"
    case missingEquipment = "missing_equipment"
    case insufficientStaff = "insufficient_staff"
    case accessRouteBlocked = "access_route_blocked"
    case sceneMoreDangerous = "scene_more_dangerous"
    case beyondCurrentCapability = "beyond_current_capability"
    case handOverToAnotherTeam = "handover_to_another_team"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lostSupplies: return "Mất đồ / thất lạc vật phẩm"
        case .equipmentDamage: return "Hư hỏng thiết bị"
        case .vehicleDamage: return "Hư hỏng phương tiện"
        case .missingEquipment: return "Thiếu thiết bị để tiếp tục"
        case .insufficientStaff: return "Thiếu nhân lực cho activity"
        case .accessRouteBlocked: return "Đường tiếp cận bị chặn"
        case .sceneMoreDangerous: return "Điều kiện hiện trường nguy hiểm hơn dự kiến"
        case .beyondCurrentCapability: return "Nạn nhân / hiện trường vượt khả năng xử lý hiện tại"
        case .handOverToAnotherTeam: return "Bàn giao activity cho team khác"
        case .other: return "Khác"
        }
    }
}

enum ActivityAffectedResource: String, Codable, CaseIterable, Identifiable {
    case equipment = "equipment"
    case vehicle = "vehicle"
    case manpower = "manpower"
    case victims = "victims"
    case route = "route"
    case communication = "communication"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .equipment: return "Thiết bị"
        case .vehicle: return "Phương tiện"
        case .manpower: return "Nhân lực"
        case .victims: return "Nạn nhân đang hỗ trợ"
        case .route: return "Tuyến đường tiếp cận"
        case .communication: return "Liên lạc"
        case .other: return "Khác"
        }
    }
}

enum ActivityRequiredSkill: String, Codable, CaseIterable, Identifiable {
    case waterRescue = "water_rescue"
    case firstAid = "first_aid"
    case victimTransport = "victim_transport"
    case boatOperation = "boat_operation"
    case demolition = "demolition"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .waterRescue: return "Cứu hộ nước"
        case .firstAid: return "Sơ cứu"
        case .victimTransport: return "Vận chuyển nạn nhân"
        case .boatOperation: return "Lái thuyền"
        case .demolition: return "Phá dỡ"
        case .other: return "Khác"
        }
    }
}

enum ActivitySupportType: String, Codable, CaseIterable, Identifiable {
    case extraRescuerTeam = "extra_rescuer_team"
    case specializedTeam = "specialized_team"
    case replacementVehicle = "replacement_vehicle"
    case replacementEquipment = "replacement_equipment"
    case medicalTeam = "medical_team"
    case roadClearanceTeam = "road_clearance_team"
    case victimTransportTeam = "victim_transport_team"
    case fuelOrPowerSupply = "fuel_or_power_supply"
    case takeOverActivity = "takeover_activity"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .extraRescuerTeam: return "Thêm team rescuer hỗ trợ activity"
        case .specializedTeam: return "Team chuyên môn phù hợp hơn"
        case .replacementVehicle: return "Phương tiện thay thế"
        case .replacementEquipment: return "Thiết bị thay thế"
        case .medicalTeam: return "Đội y tế"
        case .roadClearanceTeam: return "Đội mở đường / phá dỡ"
        case .victimTransportTeam: return "Đội vận chuyển nạn nhân"
        case .fuelOrPowerSupply: return "Tiếp tế nhiên liệu / điện"
        case .takeOverActivity: return "Tiếp quản activity"
        case .other: return "Khác"
        }
    }
}

enum ActivitySupportPriority: String, Codable, CaseIterable, Identifiable {
    case immediate = "immediate"
    case within30Minutes = "within_30_minutes"
    case within1Hour = "within_1_hour"
    case canWaitCoordination = "can_wait_coordination"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .immediate: return "Khẩn cấp ngay"
        case .within30Minutes: return "Trong 30 phút"
        case .within1Hour: return "Trong 1 giờ"
        case .canWaitCoordination: return "Có thể chờ điều phối"
        }
    }
}

enum ActivityDamageSeverity: String, Codable, CaseIterable, Identifiable {
    case minor = "minor"
    case moderate = "moderate"
    case severe = "severe"
    case unusable = "unusable"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minor: return "Nhẹ"
        case .moderate: return "Vừa"
        case .severe: return "Nặng"
        case .unusable: return "Không dùng được"
        }
    }
}

enum ActivityVehicleCondition: String, Codable, CaseIterable, Identifiable {
    case operational = "operational"
    case limited = "limited"
    case unusable = "unusable"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .operational: return "Vẫn chạy được"
        case .limited: return "Chạy hạn chế"
        case .unusable: return "Không thể sử dụng"
        }
    }
}

enum RescuerMissionIncidentType: String, Codable, CaseIterable, Identifiable {
    case wholeTeamStranded = "whole_team_stranded"
    case multipleMembersInjured = "multiple_members_injured"
    case primaryVehicleDisabled = "primary_vehicle_disabled"
    case cannotExitDangerZone = "cannot_exit_danger_zone"
    case lostCommunication = "lost_communication"
    case missionBeyondCapability = "mission_beyond_capability"
    case forcedStopForSafety = "forced_stop_for_safety"
    case insufficientManpower = "insufficient_manpower"
    case missingCriticalEquipment = "missing_critical_equipment"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wholeTeamStranded: return "Cả team mắc kẹt"
        case .multipleMembersInjured: return "Nhiều thành viên bị thương"
        case .primaryVehicleDisabled: return "Phương tiện chính hỏng / lật / mất khả năng di chuyển"
        case .cannotExitDangerZone: return "Team không thể rút khỏi khu vực nguy hiểm"
        case .lostCommunication: return "Mất liên lạc / mất định vị"
        case .missionBeyondCapability: return "Hiện trường vượt quá khả năng mission"
        case .forcedStopForSafety: return "Buộc dừng mission vì nguy cơ an toàn"
        case .insufficientManpower: return "Không còn đủ nhân lực để tiếp tục"
        case .missingCriticalEquipment: return "Không còn phương tiện / thiết bị cốt lõi"
        case .other: return "Khác"
        }
    }
}

enum MissionDecision: String, Codable, CaseIterable, Identifiable {
    case continueMission = "continue_mission"
    case pauseMission = "pause_mission"
    case stopMission = "stop_mission"
    case handOverMission = "handover_mission"
    case rescueWholeTeamImmediately = "rescue_whole_team_immediately"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .continueMission: return "Mission vẫn tiếp tục được"
        case .pauseMission: return "Mission tạm dừng"
        case .stopMission: return "Mission buộc dừng"
        case .handOverMission: return "Cần bàn giao mission cho team khác"
        case .rescueWholeTeamImmediately: return "Cần giải cứu toàn đội ngay"
        }
    }
}

enum RescuerEmergencyType: String, Codable, CaseIterable, Identifiable {
    case severeBleeding = "severe_bleeding"
    case fracture = "fracture"
    case headInjury = "head_injury"
    case unconscious = "unconscious"
    case breathingDifficulty = "breathing_difficulty"
    case drowning = "drowning"
    case chestPainStroke = "chest_pain_stroke"
    case hypothermiaExhaustion = "hypothermia_exhaustion"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .severeBleeding: return "Chảy máu nặng"
        case .fracture: return "Gãy xương"
        case .headInjury: return "Chấn thương đầu"
        case .unconscious: return "Bất tỉnh"
        case .breathingDifficulty: return "Khó thở"
        case .drowning: return "Đuối nước"
        case .chestPainStroke: return "Đau ngực / nghi đột quỵ"
        case .hypothermiaExhaustion: return "Hạ thân nhiệt / kiệt sức"
        case .other: return "Khác"
        }
    }
}

enum MissionPrimaryVehicleType: String, Codable, CaseIterable, Identifiable {
    case boat = "boat"
    case canoe = "canoe"
    case car = "car"
    case motorbike = "motorbike"
    case onFoot = "on_foot"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .boat: return "Xuồng / thuyền"
        case .canoe: return "Ca nô"
        case .car: return "Ô tô"
        case .motorbike: return "Xe máy"
        case .onFoot: return "Đi bộ"
        case .other: return "Khác"
        }
    }
}

enum MissionVehicleStatus: String, Codable, CaseIterable, Identifiable {
    case operational = "operational"
    case limited = "limited"
    case severelyDamaged = "severely_damaged"
    case overturnedOrStuck = "overturned_or_stuck"
    case unusable = "unusable"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .operational: return "Còn hoạt động"
        case .limited: return "Hoạt động hạn chế"
        case .severelyDamaged: return "Hỏng nặng"
        case .overturnedOrStuck: return "Lật / mắc kẹt"
        case .unusable: return "Không thể sử dụng"
        }
    }
}

enum MissionRetreatCapability: String, Codable, CaseIterable, Identifiable {
    case selfRetreat = "self_retreat"
    case retreatWithSupport = "retreat_with_support"
    case cannotSelfRetreat = "cannot_self_retreat"
    case urgentRescueNeeded = "urgent_rescue_needed"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selfRetreat: return "Tự rút được"
        case .retreatWithSupport: return "Rút được nếu có hỗ trợ"
        case .cannotSelfRetreat: return "Không thể tự rút"
        case .urgentRescueNeeded: return "Cần giải cứu khẩn cấp"
        }
    }
}

enum MissionHazard: String, Codable, CaseIterable, Identifiable {
    case strongCurrent = "strong_current"
    case rapidlyRisingWater = "rapidly_rising_water"
    case landslide = "landslide"
    case damagedRoadOrBridge = "damaged_road_or_bridge"
    case isolatedArea = "isolated_area"
    case darknessPoorVisibility = "darkness_or_poor_visibility"
    case electricalOrFireRisk = "electrical_or_fire_risk"
    case vehicleOverturnRisk = "vehicle_overturn_risk"
    case lowOxygenSmokeChemical = "low_oxygen_smoke_chemical"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strongCurrent: return "Nước chảy xiết"
        case .rapidlyRisingWater: return "Nước dâng nhanh"
        case .landslide: return "Sạt lở"
        case .damagedRoadOrBridge: return "Đường / cầu hỏng"
        case .isolatedArea: return "Khu vực cô lập"
        case .darknessPoorVisibility: return "Trời tối / tầm nhìn kém"
        case .electricalOrFireRisk: return "Rò điện / cháy nổ"
        case .vehicleOverturnRisk: return "Nguy cơ lật phương tiện"
        case .lowOxygenSmokeChemical: return "Thiếu oxy / khói / hóa chất"
        case .other: return "Khác"
        }
    }
}

enum MissionRescueSupportType: String, Codable, CaseIterable, Identifiable {
    case rescuerExtractionTeam = "rescuer_extraction_team"
    case emergencyMedicalTeam = "emergency_medical_team"
    case evacuationVehicle = "evacuation_vehicle"
    case waterVehicle = "water_vehicle"
    case specializedVehicle = "specialized_vehicle"
    case advancedRescueEquipment = "advanced_rescue_equipment"
    case communicationTrackingSupport = "communication_tracking_support"
    case takeOverMissionTeam = "takeover_mission_team"
    case transferVictimsWithTeam = "transfer_victims_with_team"
    case other = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rescuerExtractionTeam: return "Đội giải cứu rescuer team"
        case .emergencyMedicalTeam: return "Đội y tế khẩn"
        case .evacuationVehicle: return "Phương tiện sơ tán"
        case .waterVehicle: return "Phương tiện đường thủy"
        case .specializedVehicle: return "Phương tiện chuyên dụng"
        case .advancedRescueEquipment: return "Thiết bị cứu hộ chuyên sâu"
        case .communicationTrackingSupport: return "Hỗ trợ liên lạc / định vị"
        case .takeOverMissionTeam: return "Đội tiếp quản mission dang dở"
        case .transferVictimsWithTeam: return "Tiếp nhận nạn nhân đang đi cùng"
        case .other: return "Khác"
        }
    }
}

enum MissionRescuePriority: String, Codable, CaseIterable, Identifiable {
    case immediate = "immediate"
    case within15Minutes = "within_15_minutes"
    case within30Minutes = "within_30_minutes"
    case within1Hour = "within_1_hour"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .immediate: return "Ngay lập tức"
        case .within15Minutes: return "Trong 15 phút"
        case .within30Minutes: return "Trong 30 phút"
        case .within1Hour: return "Trong 1 giờ"
        }
    }
}

enum MissionEvacuationPriority: String, Codable, CaseIterable, Identifiable {
    case injuredFirst = "injured_first"
    case wholeTeam = "whole_team"
    case victimsFirst = "victims_first"
    case sceneAssessment = "scene_assessment"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .injuredFirst: return "Sơ tán người bị thương trước"
        case .wholeTeam: return "Sơ tán toàn đội"
        case .victimsFirst: return "Tiếp nhận nạn nhân trước, đội chờ sau"
        case .sceneAssessment: return "Theo đánh giá hiện trường"
        }
    }
}

struct IncidentLocationSnapshot: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

struct RescuerIncidentEvidencePayload: Codable, Equatable {
    let hasPendingAttachments: Bool
    let attachmentPlaceholders: [String]
    let note: String?
}

struct ActivityIncidentSelectionContext: Codable, Equatable {
    let activityId: Int
    let title: String
    let activityType: String?
    let step: Int?
}

struct ActivityIncidentContextPayload: Codable, Equatable {
    let missionId: Int
    let missionTeamId: Int
    let missionTitle: String
    let teamName: String?
    let reporterId: String?
    let reporterName: String
    let reportedAt: String
    let location: IncidentLocationSnapshot
    let activities: [ActivityIncidentSelectionContext]
}

struct ActivityIncidentImpactPayload: Codable, Equatable {
    let canContinueActivity: Bool
    let needSupportSOS: Bool
    let needReassignActivity: Bool
}

struct ActivityIncidentEquipmentDetailsPayload: Codable, Equatable {
    let equipmentType: String
    let damageSeverity: String
    let hasReplacementEquipment: Bool
}

struct ActivityIncidentVehicleDetailsPayload: Codable, Equatable {
    let vehicleType: String
    let vehicleCondition: String
    let hasAffectedMembers: Bool
}

struct ActivityIncidentLostSupplyDetailsPayload: Codable, Equatable {
    let lostItemName: String
    let quantity: Int?
    let directlyAffectsActivity: Bool
}

struct ActivityIncidentStaffingDetailsPayload: Codable, Equatable {
    let currentPeopleCount: Int?
    let additionalPeopleNeeded: Int?
    let requiredSkills: [String]
}

struct ActivityIncidentSpecificDetailsPayload: Codable, Equatable {
    let equipmentDamage: ActivityIncidentEquipmentDetailsPayload?
    let vehicleDamage: ActivityIncidentVehicleDetailsPayload?
    let lostSupply: ActivityIncidentLostSupplyDetailsPayload?
    let staffingShortage: ActivityIncidentStaffingDetailsPayload?
}

struct ActivityIncidentSupportCountsPayload: Codable, Equatable {
    let teamCount: Int?
    let peopleCount: Int?
    let vehicleCount: Int?
}

struct ActivityIncidentSupportRequestPayload: Codable, Equatable {
    let supportTypes: [String]
    let priority: String
    let counts: ActivityIncidentSupportCountsPayload
    let meetupPoint: String?
    let takeoverNeeded: Bool
}

struct ActivityIncidentTeamStatusPayload: Codable, Equatable {
    let totalMembers: Int?
    let availableMembers: Int?
    let lightlyInjuredMembers: Int?
    let unavailableMembers: Int?
    let needsMemberEvacuation: Bool?
}

struct ActivityIncidentReportRequest: Codable, Equatable {
    let scope: String
    let context: ActivityIncidentContextPayload
    let incidentType: String
    let affectedResources: [String]
    let impact: ActivityIncidentImpactPayload
    let specificDetails: ActivityIncidentSpecificDetailsPayload?
    let supportRequest: ActivityIncidentSupportRequestPayload?
    let teamStatus: ActivityIncidentTeamStatusPayload
    let note: String
    let evidence: RescuerIncidentEvidencePayload?
}

struct MissionIncidentCivilianContextPayload: Codable, Equatable {
    let hasCiviliansWithTeam: Bool
    let civilianCount: Int?
    let civilianCondition: String?
}

struct MissionIncidentContextPayload: Codable, Equatable {
    let missionId: Int
    let missionTeamId: Int
    let missionTitle: String
    let teamName: String?
    let reporterId: String?
    let reporterName: String
    let reportedAt: String
    let location: IncidentLocationSnapshot
    let unfinishedActivityCount: Int
    let civiliansWithTeam: MissionIncidentCivilianContextPayload
}

struct MissionIncidentTeamStatusPayload: Codable, Equatable {
    let totalMembers: Int
    let safeMembers: Int
    let lightlyInjuredMembers: Int
    let severelyInjuredMembers: Int
    let immobileMembers: Int
    let missingContactMembers: Int
}

struct MissionIncidentUrgentMedicalPayload: Codable, Equatable {
    let needsImmediateEmergencyCare: Bool
    let emergencyTypes: [String]
}

struct MissionIncidentVehiclePayload: Codable, Equatable {
    let primaryVehicleType: String
    let status: String
    let retreatCapability: String
}

struct MissionIncidentRescueRequestPayload: Codable, Equatable {
    let supportTypes: [String]
    let priority: String
    let evacuationPriority: String
}

struct MissionIncidentHandoverPayload: Codable, Equatable {
    let needsMissionTakeover: Bool
    let unfinishedWork: String
    let unfinishedActivityCount: Int?
    let transferItems: String
    let notesForTakeoverTeam: String
    let safeHandoverPoint: String
}

struct MissionIncidentReportRequest: Codable, Equatable {
    let scope: String
    let context: MissionIncidentContextPayload
    let incidentType: String
    let missionDecision: String
    let teamStatus: MissionIncidentTeamStatusPayload
    let urgentMedical: MissionIncidentUrgentMedicalPayload
    let vehicleStatus: MissionIncidentVehiclePayload
    let hazards: [String]
    let rescueRequest: MissionIncidentRescueRequestPayload?
    let handover: MissionIncidentHandoverPayload?
    let note: String
    let evidence: RescuerIncidentEvidencePayload?
}

struct ActivityIncidentDraft: Equatable {
    var selectedActivityIds: Set<Int> = []
    var incidentType: RescuerActivityIncidentType?
    var canContinueActivity: Bool?
    var needSupportSOS = false
    var needReassignActivity = false
    var affectedResources: Set<ActivityAffectedResource> = []

    var equipmentType = ""
    var equipmentDamageSeverity: ActivityDamageSeverity?
    var hasReplacementEquipment: Bool?

    var vehicleType = ""
    var vehicleCondition: ActivityVehicleCondition?
    var vehicleAffectedMembers: Bool?

    var lostSupplyName = ""
    var lostSupplyQuantity = ""
    var lostSupplyDirectImpact: Bool?

    var currentPeopleCount = ""
    var additionalPeopleNeeded = ""
    var requiredSkills: Set<ActivityRequiredSkill> = []

    var supportTypes: Set<ActivitySupportType> = []
    var supportPriority: ActivitySupportPriority?
    var supportTeamCount = ""
    var supportPeopleCount = ""
    var supportVehicleCount = ""
    var supportMeetupPoint = ""

    var totalMembers = ""
    var availableMembers = ""
    var lightlyInjuredMembers = ""
    var unavailableMembers = ""
    var needsMemberEvacuation: Bool?

    var note = ""
    var evidencePlaceholderNote = ""

    mutating func enforceRules() {
        if needReassignActivity {
            needSupportSOS = true
            supportTypes.insert(.takeOverActivity)
        }

        if needSupportSOS == false {
            supportTypes.removeAll()
            supportPriority = nil
            supportTeamCount = ""
            supportPeopleCount = ""
            supportVehicleCount = ""
            supportMeetupPoint = ""
        }
    }

    var submitButtonTitle: String {
        needSupportSOS
            ? "Gửi báo cáo & yêu cầu hỗ trợ activity"
            : "Gửi báo cáo sự cố activity"
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isTypeSpecificSectionValid: Bool {
        switch incidentType {
        case .equipmentDamage:
            return equipmentType.incidentHasContent
                && equipmentDamageSeverity != nil
                && hasReplacementEquipment != nil
        case .vehicleDamage:
            return vehicleType.incidentHasContent
                && vehicleCondition != nil
                && vehicleAffectedMembers != nil
        case .lostSupplies:
            return lostSupplyName.incidentHasContent
                && lostSupplyDirectImpact != nil
        case .insufficientStaff:
            return currentPeopleCount.incidentParsedInt != nil
                && additionalPeopleNeeded.incidentParsedInt != nil
                && requiredSkills.isEmpty == false
        default:
            return true
        }
    }

    var isSupportSectionValid: Bool {
        guard needSupportSOS else { return true }
        return supportTypes.isEmpty == false && supportPriority != nil
    }

    var isValid: Bool {
        incidentType != nil
            && selectedActivityIds.isEmpty == false
            && canContinueActivity != nil
            && needsMemberEvacuation != nil
            && totalMembers.incidentParsedInt != nil
            && availableMembers.incidentParsedInt != nil
            && lightlyInjuredMembers.incidentParsedInt != nil
            && unavailableMembers.incidentParsedInt != nil
            && trimmedNote.isEmpty == false
            && isTypeSpecificSectionValid
            && isSupportSectionValid
    }

    func toRequest(
        missionId: Int,
        missionTeamId: Int,
        missionTitle: String,
        teamName: String?,
        reporterId: String?,
        reporterName: String,
        location: IncidentLocationSnapshot,
        selectedActivities: [Activity]
    ) -> ActivityIncidentReportRequest? {
        guard
            let incidentType,
            let canContinueActivity,
            isValid
        else {
            return nil
        }

        let specificDetails = ActivityIncidentSpecificDetailsPayload(
            equipmentDamage: incidentType == .equipmentDamage
                ? ActivityIncidentEquipmentDetailsPayload(
                    equipmentType: equipmentType.incidentTrimmed,
                    damageSeverity: equipmentDamageSeverity?.rawValue ?? "",
                    hasReplacementEquipment: hasReplacementEquipment ?? false
                )
                : nil,
            vehicleDamage: incidentType == .vehicleDamage
                ? ActivityIncidentVehicleDetailsPayload(
                    vehicleType: vehicleType.incidentTrimmed,
                    vehicleCondition: vehicleCondition?.rawValue ?? "",
                    hasAffectedMembers: vehicleAffectedMembers ?? false
                )
                : nil,
            lostSupply: incidentType == .lostSupplies
                ? ActivityIncidentLostSupplyDetailsPayload(
                    lostItemName: lostSupplyName.incidentTrimmed,
                    quantity: lostSupplyQuantity.incidentParsedInt,
                    directlyAffectsActivity: lostSupplyDirectImpact ?? false
                )
                : nil,
            staffingShortage: incidentType == .insufficientStaff
                ? ActivityIncidentStaffingDetailsPayload(
                    currentPeopleCount: currentPeopleCount.incidentParsedInt,
                    additionalPeopleNeeded: additionalPeopleNeeded.incidentParsedInt,
                    requiredSkills: requiredSkills.map(\.rawValue).sorted()
                )
                : nil
        )

        let evidence = evidencePayload
        let selectedContexts = selectedActivities.map {
            ActivityIncidentSelectionContext(
                activityId: $0.id,
                title: $0.title,
                activityType: $0.localizedActivityType,
                step: $0.step
            )
        }

        return ActivityIncidentReportRequest(
            scope: RescuerIncidentScope.activity.rawValue,
            context: ActivityIncidentContextPayload(
                missionId: missionId,
                missionTeamId: missionTeamId,
                missionTitle: missionTitle,
                teamName: teamName,
                reporterId: reporterId,
                reporterName: reporterName,
                reportedAt: Date.incidentISO8601String,
                location: location,
                activities: selectedContexts
            ),
            incidentType: incidentType.rawValue,
            affectedResources: affectedResources.map(\.rawValue).sorted(),
            impact: ActivityIncidentImpactPayload(
                canContinueActivity: canContinueActivity,
                needSupportSOS: needSupportSOS,
                needReassignActivity: needReassignActivity
            ),
            specificDetails: specificDetails.hasPayload ? specificDetails : nil,
            supportRequest: needSupportSOS
                ? ActivityIncidentSupportRequestPayload(
                    supportTypes: supportTypes.map(\.rawValue).sorted(),
                    priority: supportPriority?.rawValue ?? "",
                    counts: ActivityIncidentSupportCountsPayload(
                        teamCount: supportTeamCount.incidentParsedInt,
                        peopleCount: supportPeopleCount.incidentParsedInt,
                        vehicleCount: supportVehicleCount.incidentParsedInt
                    ),
                    meetupPoint: supportMeetupPoint.incidentNilIfBlank,
                    takeoverNeeded: needReassignActivity
                )
                : nil,
            teamStatus: ActivityIncidentTeamStatusPayload(
                totalMembers: totalMembers.incidentParsedInt,
                availableMembers: availableMembers.incidentParsedInt,
                lightlyInjuredMembers: lightlyInjuredMembers.incidentParsedInt,
                unavailableMembers: unavailableMembers.incidentParsedInt,
                needsMemberEvacuation: needsMemberEvacuation
            ),
            note: trimmedNote,
            evidence: evidence
        )
    }

    private var evidencePayload: RescuerIncidentEvidencePayload? {
        guard evidencePlaceholderNote.incidentHasContent else { return nil }
        return RescuerIncidentEvidencePayload(
            hasPendingAttachments: false,
            attachmentPlaceholders: [],
            note: evidencePlaceholderNote.incidentNilIfBlank
        )
    }
}

struct MissionIncidentDraft: Equatable {
    var incidentType: RescuerMissionIncidentType?
    var missionDecision: MissionDecision?

    var hasCiviliansWithTeam: Bool?
    var civilianCount = ""
    var civilianCondition = ""

    var totalMembers = ""
    var safeMembers = ""
    var lightlyInjuredMembers = ""
    var severelyInjuredMembers = ""
    var immobileMembers = ""
    var missingContactMembers = ""

    var needsImmediateEmergencyCare: Bool?
    var emergencyTypes: Set<RescuerEmergencyType> = []

    var primaryVehicleType: MissionPrimaryVehicleType?
    var vehicleStatus: MissionVehicleStatus?
    var retreatCapability: MissionRetreatCapability?

    var hazards: Set<MissionHazard> = []

    var needsRescueSOS = false
    var rescueSupportTypes: Set<MissionRescueSupportType> = []
    var rescuePriority: MissionRescuePriority?
    var evacuationPriority: MissionEvacuationPriority?

    var needsMissionHandover: Bool?
    var unfinishedWork = ""
    var unfinishedActivityCount = ""
    var transferItems = ""
    var notesForTakeoverTeam = ""
    var safeHandoverPoint = ""

    var note = ""
    var evidencePlaceholderNote = ""

    mutating func enforceRules(defaultUnfinishedActivityCount: Int) {
        if missionDecision == .rescueWholeTeamImmediately {
            needsRescueSOS = true
        }

        if missionDecision == .handOverMission {
            needsMissionHandover = true
        }

        if retreatCapability == .urgentRescueNeeded {
            needsRescueSOS = true
        }

        if needsRescueSOS == false {
            rescueSupportTypes.removeAll()
            rescuePriority = nil
            evacuationPriority = nil
        }

        if needsMissionHandover == true && unfinishedActivityCount.incidentHasContent == false && defaultUnfinishedActivityCount > 0 {
            unfinishedActivityCount = String(defaultUnfinishedActivityCount)
        }
    }

    var submitButtonTitle: String {
        if needsRescueSOS {
            return "Gửi báo cáo & yêu cầu giải cứu team"
        }

        if needsMissionHandover == true {
            return "Gửi báo cáo & bàn giao mission"
        }

        return "Gửi báo cáo sự cố mission"
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isRescueSectionValid: Bool {
        guard needsRescueSOS else { return true }
        return rescueSupportTypes.isEmpty == false
            && rescuePriority != nil
            && evacuationPriority != nil
    }

    var isHandoverSectionValid: Bool {
        guard needsMissionHandover == true else { return true }
        return unfinishedWork.incidentHasContent
            && transferItems.incidentHasContent
            && notesForTakeoverTeam.incidentHasContent
            && safeHandoverPoint.incidentHasContent
    }

    var isMedicalSectionValid: Bool {
        guard let needsImmediateEmergencyCare else { return false }
        if needsImmediateEmergencyCare {
            return emergencyTypes.isEmpty == false
        }
        return true
    }

    var isCivilianSectionValid: Bool {
        guard let hasCiviliansWithTeam else { return false }
        if hasCiviliansWithTeam {
            return civilianCount.incidentParsedInt != nil && civilianCondition.incidentHasContent
        }
        return true
    }

    var isValid: Bool {
        incidentType != nil
            && missionDecision != nil
            && isCivilianSectionValid
            && totalMembers.incidentParsedInt != nil
            && safeMembers.incidentParsedInt != nil
            && lightlyInjuredMembers.incidentParsedInt != nil
            && severelyInjuredMembers.incidentParsedInt != nil
            && immobileMembers.incidentParsedInt != nil
            && missingContactMembers.incidentParsedInt != nil
            && isMedicalSectionValid
            && primaryVehicleType != nil
            && vehicleStatus != nil
            && retreatCapability != nil
            && needsMissionHandover != nil
            && trimmedNote.isEmpty == false
            && isRescueSectionValid
            && isHandoverSectionValid
    }

    func toRequest(
        missionId: Int,
        missionTeamId: Int,
        missionTitle: String,
        teamName: String?,
        reporterId: String?,
        reporterName: String,
        location: IncidentLocationSnapshot,
        unfinishedActivityCount defaultUnfinishedActivityCount: Int
    ) -> MissionIncidentReportRequest? {
        guard
            let incidentType,
            let missionDecision,
            let hasCiviliansWithTeam,
            let needsImmediateEmergencyCare,
            let primaryVehicleType,
            let vehicleStatus,
            let retreatCapability,
            let needsMissionHandover,
            let totalMembers = totalMembers.incidentParsedInt,
            let safeMembers = safeMembers.incidentParsedInt,
            let lightlyInjuredMembers = lightlyInjuredMembers.incidentParsedInt,
            let severelyInjuredMembers = severelyInjuredMembers.incidentParsedInt,
            let immobileMembers = immobileMembers.incidentParsedInt,
            let missingContactMembers = missingContactMembers.incidentParsedInt,
            isValid
        else {
            return nil
        }

        return MissionIncidentReportRequest(
            scope: RescuerIncidentScope.mission.rawValue,
            context: MissionIncidentContextPayload(
                missionId: missionId,
                missionTeamId: missionTeamId,
                missionTitle: missionTitle,
                teamName: teamName,
                reporterId: reporterId,
                reporterName: reporterName,
                reportedAt: Date.incidentISO8601String,
                location: location,
                unfinishedActivityCount: defaultUnfinishedActivityCount,
                civiliansWithTeam: MissionIncidentCivilianContextPayload(
                    hasCiviliansWithTeam: hasCiviliansWithTeam,
                    civilianCount: hasCiviliansWithTeam ? civilianCount.incidentParsedInt : nil,
                    civilianCondition: hasCiviliansWithTeam ? civilianCondition.incidentNilIfBlank : nil
                )
            ),
            incidentType: incidentType.rawValue,
            missionDecision: missionDecision.rawValue,
            teamStatus: MissionIncidentTeamStatusPayload(
                totalMembers: totalMembers,
                safeMembers: safeMembers,
                lightlyInjuredMembers: lightlyInjuredMembers,
                severelyInjuredMembers: severelyInjuredMembers,
                immobileMembers: immobileMembers,
                missingContactMembers: missingContactMembers
            ),
            urgentMedical: MissionIncidentUrgentMedicalPayload(
                needsImmediateEmergencyCare: needsImmediateEmergencyCare,
                emergencyTypes: emergencyTypes.map(\.rawValue).sorted()
            ),
            vehicleStatus: MissionIncidentVehiclePayload(
                primaryVehicleType: primaryVehicleType.rawValue,
                status: vehicleStatus.rawValue,
                retreatCapability: retreatCapability.rawValue
            ),
            hazards: hazards.map(\.rawValue).sorted(),
            rescueRequest: needsRescueSOS
                ? MissionIncidentRescueRequestPayload(
                    supportTypes: rescueSupportTypes.map(\.rawValue).sorted(),
                    priority: rescuePriority?.rawValue ?? "",
                    evacuationPriority: evacuationPriority?.rawValue ?? ""
                )
                : nil,
            handover: needsMissionHandover
                ? MissionIncidentHandoverPayload(
                    needsMissionTakeover: true,
                    unfinishedWork: unfinishedWork.incidentTrimmed,
                    unfinishedActivityCount: unfinishedActivityCount.incidentParsedInt ?? defaultUnfinishedActivityCount,
                    transferItems: transferItems.incidentTrimmed,
                    notesForTakeoverTeam: notesForTakeoverTeam.incidentTrimmed,
                    safeHandoverPoint: safeHandoverPoint.incidentTrimmed
                )
                : nil,
            note: trimmedNote,
            evidence: evidencePayload
        )
    }

    private var evidencePayload: RescuerIncidentEvidencePayload? {
        guard evidencePlaceholderNote.incidentHasContent else { return nil }
        return RescuerIncidentEvidencePayload(
            hasPendingAttachments: false,
            attachmentPlaceholders: [],
            note: evidencePlaceholderNote.incidentNilIfBlank
        )
    }
}

private extension ActivityIncidentSpecificDetailsPayload {
    var hasPayload: Bool {
        equipmentDamage != nil || vehicleDamage != nil || lostSupply != nil || staffingShortage != nil
    }
}

private extension String {
    var incidentTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var incidentNilIfBlank: String? {
        let trimmed = incidentTrimmed
        return trimmed.isEmpty ? nil : trimmed
    }

    var incidentHasContent: Bool {
        incidentNilIfBlank != nil
    }

    var incidentParsedInt: Int? {
        Int(incidentTrimmed)
    }
}

private extension Date {
    static var incidentISO8601String: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
}
