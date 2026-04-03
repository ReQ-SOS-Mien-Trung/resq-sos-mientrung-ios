import Foundation

// MARK: - Mission List Response
struct MissionListResponse: Codable {
    let missions: [Mission]
}

// MARK: - Activity Status Enum
enum ActivityStatus: String, Codable, CaseIterable {
    case planned = "Planned"
    case onGoing = "OnGoing"
    case succeed = "Succeed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

// MARK: - Activity Supply
struct MissionSupply: Codable, Identifiable {
    let itemId: Int?
    let itemName: String?
    let quantity: Int
    let unit: String?

    var id: String {
        "\(itemId ?? -1)-\(itemName ?? "supply")-\(quantity)"
    }
}

// MARK: - Activity
struct Activity: Codable, Identifiable {
    let id: Int
    let step: Int?
    let activityCode: String?
    let activityType: String?
    let description: String?
    let priority: String?
    let estimatedTime: Int?
    let sosRequestId: Int?
    let depotId: Int?
    let depotName: String?
    let depotAddress: String?
    let suppliesToCollect: [MissionSupply]?
    let targetLatitude: Double?
    let targetLongitude: Double?
    let status: String
    let missionTeamId: Int?
    let assignedAt: String?
    let completedAt: String?
    let completedBy: String?

    var activityStatus: ActivityStatus {
        ActivityStatus(rawValue: status) ?? .planned
    }

    var missionId: Int? { nil }

    var localizedActivityType: String? {
        localizedActivityTypeDisplay(activityType)
    }

    var localizedActivityCode: String? {
        localizedActivityCodeDisplay(activityCode)
    }

    var title: String {
        if let localizedActivityCode {
            return localizedActivityCode
        }

        if let localizedActivityType {
            return localizedActivityType
        }

        if let step {
            return "Hoạt động #\(step)"
        }

        return "Hoạt động"
    }

    var latitude: Double? { targetLatitude }
    var longitude: Double? { targetLongitude }
    var assignedTeamId: Int? { missionTeamId }
}

// MARK: - Mission Team Member
struct MissionTeamMember: Codable, Identifiable {
    let userId: String
    let fullName: String?
    let avatarUrl: String?
    let rescuerType: String?
    let roleInTeam: String?
    let isLeader: Bool?
    let status: String?
    let checkedIn: Bool?

    var id: String { userId }
}

// MARK: - MissionTeam
/// Holds missionTeamId — required when reporting incidents via POST /operations/team-incidents
struct MissionTeam: Codable, Identifiable {
    let id: Int
    let teamId: Int?
    let teamName: String?
    let teamCode: String?
    let assemblyPointName: String?
    let teamType: String?
    let status: String?
    let teamStatus: String?
    let memberCount: Int?
    let latitude: Double?
    let longitude: Double?
    let locationUpdatedAt: String?
    let assignedAt: String?
    let members: [MissionTeamMember]?

    enum CodingKeys: String, CodingKey {
        case id = "missionTeamId"
        case teamId = "rescueTeamId"
        case teamName
        case teamCode
        case assemblyPointName
        case teamType
        case status
        case teamStatus
        case memberCount
        case latitude
        case longitude
        case locationUpdatedAt
        case assignedAt
        case members
    }
}

// MARK: - Mission
struct Mission: Codable, Identifiable {
    let id: Int
    let clusterId: Int?
    let missionType: String?
    let priorityScore: Double?
    let status: String
    let startTime: String?
    let expectedEndTime: String?
    let createdAt: String?
    let completedAt: String?
    let activityCount: Int
    let teams: [MissionTeam]?
    let activities: [Activity]?
    let suggestedMissionTitle: String?
    let suggestedMissionType: String?
    let suggestedPriorityScore: Double?
    let suggestedSeverityLevel: String?

    var title: String {
        if let suggestedMissionTitle, suggestedMissionTitle.isEmpty == false {
            return suggestedMissionTitle
        }

        if let missionType, missionType.isEmpty == false {
            return "\(missionTypeDisplayName(missionType)) #\(id)"
        }

        return "Mission #\(id)"
    }

    var description: String? {
        let parts = [
            clusterId.map { "Cluster #\($0)" },
            teams?.first?.teamName,
            suggestedSeverityLevel.map { "Mức độ \($0)" }
        ].compactMap { $0 }.filter { $0.isEmpty == false }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    var startDate: String? { startTime }
    var endDate: String? { expectedEndTime }

    /// Convenience: first team's id = missionTeamId used for incident reporting
    var missionTeamId: Int? { teams?.first?.id }
}

private func missionTypeDisplayName(_ missionType: String) -> String {
    switch missionType.lowercased() {
    case "rescue":
        return "Cứu hộ"
    case "rescuer":
        return "Điều động cứu hộ"
    default:
        return missionType
    }
}

func localizedActivityTypeDisplay(_ rawValue: String?) -> String? {
    guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), rawValue.isEmpty == false else {
        return nil
    }

    switch normalizedActivityKey(rawValue) {
    case "collectsupplies":
        return "Thu gom vật tư"
    case "deliversupplies":
        return "Bàn giao vật tư"
    case "rescue":
        return "Cứu hộ"
    case "medicalaid":
        return "Sơ cứu y tế"
    case "medicalsupport", "medical":
        return "Hỗ trợ y tế"
    case "evacuate", "evacuation":
        return "Di tản"
    case "searchandrescue", "sar":
        return "Tìm kiếm cứu nạn"
    case "logistics":
        return "Hậu cần"
    case "transport", "transportation":
        return "Vận chuyển"
    case "assessment":
        return "Đánh giá hiện trường"
    default:
        return humanizedActivityText(rawValue)
    }
}

func localizedActivityCodeDisplay(_ rawValue: String?) -> String? {
    guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), rawValue.isEmpty == false else {
        return nil
    }

    let parts = rawValue
        .split(separator: "_")
        .map(String.init)

    guard parts.isEmpty == false else {
        return nil
    }

    let hasSequence = parts.count > 1 && Int(parts.last ?? "") != nil
    let base = hasSequence ? parts.dropLast().joined(separator: "_") : rawValue
    let localizedBase = localizedActivityTypeDisplay(base) ?? humanizedActivityText(base)

    guard let localizedBase else {
        return nil
    }

    if hasSequence, let suffix = parts.last {
        return "\(localizedBase) #\(suffix)"
    }

    return localizedBase
}

private func normalizedActivityKey(_ rawValue: String) -> String {
    rawValue
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "_", with: "")
        .replacingOccurrences(of: "-", with: "")
        .lowercased()
}

private func humanizedActivityText(_ rawValue: String) -> String? {
    let sanitized = rawValue
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "-", with: " ")

    guard sanitized.isEmpty == false else { return nil }

    return sanitized
        .split(separator: " ")
        .map { token in
            let lowercased = token.lowercased()
            return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
        }
        .joined(separator: " ")
}

// MARK: - Activity Update Request
struct ActivityStatusUpdate: Codable {
    let status: String
}

// MARK: - Activity Route
struct ActivityRoute: Codable {
    let activityId: Int
    let activityType: String
    let description: String?
    let destinationLatitude: Double
    let destinationLongitude: Double
    let originLatitude: Double
    let originLongitude: Double
    let vehicle: String
    let route: ActivityRouteSummary?

    var polyline: String? { route?.overviewPolyline }
    var distance: Double? { route?.totalDistanceMeters }
    var duration: Double? { route?.totalDurationSeconds }
    var waypoints: [RouteWaypoint]? { route?.waypoints }
}

struct ActivityRouteSummary: Codable {
    let totalDistanceMeters: Double?
    let totalDistanceText: String?
    let totalDurationSeconds: Double?
    let totalDurationText: String?
    let overviewPolyline: String?
    let summary: String?
    let steps: [RouteStep]?

    var waypoints: [RouteWaypoint]? {
        steps?.map {
            RouteWaypoint(latitude: $0.endLat, longitude: $0.endLng)
        }
    }
}

struct RouteStep: Codable {
    let instruction: String?
    let distanceMeters: Double?
    let distanceText: String?
    let durationSeconds: Double?
    let durationText: String?
    let maneuver: String?
    let startLat: Double
    let startLng: Double
    let endLat: Double
    let endLng: Double
    let polyline: String?
}

struct RouteWaypoint: Codable {
    let latitude: Double
    let longitude: Double
}
