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

    init?(apiValue: String?) {
        switch normalizedActivityStatusKey(apiValue) {
        case "planned", "pending", "scheduled":
            self = .planned
        case "ongoing", "inprogress":
            self = .onGoing
        case "pendingconfirmation":
            self = .planned
        case "completed", "complete", "succeed", "succeeded", "success", "done":
            self = .succeed
        case "failed", "fail":
            self = .failed
        case "cancelled", "canceled", "cancel":
            self = .cancelled
        default:
            return nil
        }
    }

    var apiUpdateCandidates: [String] {
        switch self {
        case .planned:
            return ["Planned"]
        case .onGoing:
            return ["OnGoing"]
        case .succeed:
            return ["Succeed"]
        case .failed:
            return ["Failed"]
        case .cancelled:
            return ["Cancelled"]
        }
    }
}

// MARK: - Activity Supply
struct MissionSupply: Codable, Identifiable {
    let itemId: Int?
    let itemName: String?
    let imageUrl: String?
    let quantity: Int
    let unit: String?
    let bufferRatio: Double?
    let bufferQuantity: Int?
    let bufferUsedQuantity: Int?
    let bufferUsedReason: String?
    let actualDeliveredQuantity: Int?

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
        ActivityStatus(apiValue: status) ?? .planned
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
            return "Bước thực hiện #\(step)"
        }

        return "Bước thực hiện"
    }

    var latitude: Double? { targetLatitude }
    var longitude: Double? { targetLongitude }
    var assignedTeamId: Int? { missionTeamId }

    func replacing(status newStatus: String) -> Activity {
        Activity(
            id: id,
            step: step,
            activityCode: activityCode,
            activityType: activityType,
            description: description,
            priority: priority,
            estimatedTime: estimatedTime,
            sosRequestId: sosRequestId,
            depotId: depotId,
            depotName: depotName,
            depotAddress: depotAddress,
            suppliesToCollect: suppliesToCollect,
            targetLatitude: targetLatitude,
            targetLongitude: targetLongitude,
            status: newStatus,
            missionTeamId: missionTeamId,
            assignedAt: assignedAt,
            completedAt: completedAt,
            completedBy: completedBy
        )
    }

    var normalizedActivityTypeKey: String {
        (activityType ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }

    var isCollectSuppliesActivity: Bool {
        normalizedActivityTypeKey == "collectsupplies"
    }

    var isDeliverSuppliesActivity: Bool {
        normalizedActivityTypeKey == "deliversupplies"
    }
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
/// Holds missionTeamId — required when reporting incidents via mission route endpoints.
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

    private var resolvedMissionTypeRaw: String? {
        firstNonEmptyTrimmed(missionType, suggestedMissionType)
    }

    var missionTypeBadgeText: String? {
        guard let rawType = resolvedMissionTypeRaw else { return nil }
        return missionTypeDisplayName(rawType)
    }

    var missionTypeBadgeKey: String? {
        guard let rawType = resolvedMissionTypeRaw else { return nil }
        return normalizedMissionTypeKey(rawType)
    }

    var shouldDisplayMissionTypeBadge: Bool {
        guard let missionTypeBadgeText = missionTypeBadgeText else { return false }

        return normalizedMissionLabelForComparison(missionTypeBadgeText)
            != normalizedMissionLabelForComparison(title)
    }

    var title: String {
        if let missionTypeBadgeText = missionTypeBadgeText {
            return missionTypeBadgeText
        }

        if let suggestedMissionTitle = firstNonEmptyTrimmed(suggestedMissionTitle) {
            let cleanedTitle = sanitizeMissionTitle(suggestedMissionTitle)
            return cleanedTitle.isEmpty ? "Nhiệm vụ" : cleanedTitle
        }

        return "Nhiệm vụ"
    }

    var description: String? {
        var parts: [String] = []

        if let clusterId = clusterId {
            parts.append("Cụm yêu cầu SOS #\(clusterId)")
        }

        if let teamName = teams?.first?.teamName,
           teamName.isEmpty == false {
            parts.append(teamName)
        }

        if let severity = suggestedSeverityLevel,
           severity.isEmpty == false {
            parts.append("Mức độ \(severity)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    var startDate: String? { startTime }
    var endDate: String? { expectedEndTime }

    /// Convenience: first team's id = missionTeamId used for mission-level incident reporting
    var missionTeamId: Int? { teams?.first?.id }
}

private func missionTypeDisplayName(_ missionType: String) -> String {
    switch normalizedMissionTypeKey(missionType) {
    case "rescue":
        return "Cứu hộ"
    case "evacuation", "evacuate":
        return "Di tản"
    case "medical", "medicalaid", "medicalsupport":
        return "Y tế"
    case "supply", "supplies", "logistics", "relief":
        return "Cứu trợ"
    case "mixed", "hybrid", "combined":
        return "Tổng hợp"
    case "rescuer":
        return "Điều động người cứu hộ"
    default:
        return humanizedMissionTypeText(missionType)
    }
}

private func normalizedMissionTypeKey(_ missionType: String) -> String {
    missionType
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "_", with: "")
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: " ", with: "")
        .lowercased()
}

private func normalizedMissionLabelForComparison(_ value: String) -> String {
    value
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "_", with: "")
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: " ", with: "")
}

private func firstNonEmptyTrimmed(_ values: String?...) -> String? {
    for value in values {
        guard let value = value else { continue }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false {
            return trimmed
        }
    }

    return nil
}

private func sanitizeMissionTitle(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let withoutTrailingId = trimmed.replacingOccurrences(
        of: "\\s*#\\d+\\s*$",
        with: "",
        options: .regularExpression
    )
    return withoutTrailingId.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func humanizedMissionTypeText(_ rawValue: String) -> String {
    humanizedActivityText(rawValue) ?? rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
}

func localizedActivityTypeDisplay(_ rawValue: String?) -> String? {
    guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), rawValue.isEmpty == false else {
        return nil
    }

    switch normalizedActivityKey(rawValue) {
    case "collectsupplies":
        return "Tiếp nhận vật phẩm"
    case "deliversupplies":
        return "Phân phát vật phẩm"
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

func normalizedActivityStatusKey(_ rawValue: String?) -> String {
    (rawValue ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "_", with: "")
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: " ", with: "")
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

func missionActivityActionIsUnlocked(_ activity: Activity, within list: [Activity]) -> Bool {
    guard let currentStep = activity.step, currentStep > 1 else {
        return true
    }

    let previousSteps = list.filter { candidate in
        guard let candidateStep = candidate.step else { return false }
        return candidateStep < currentStep
    }

    guard previousSteps.isEmpty == false else {
        return true
    }

    return previousSteps.allSatisfy { $0.activityStatus == .succeed }
}

// MARK: - Mission Update Request
struct MissionStatusUpdate: Codable {
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

struct MissionTeamRoute: Decodable {
    let missionId: Int?
    let missionTeamId: Int?
    let originLatitude: Double?
    let originLongitude: Double?
    let vehicle: String?
    let status: String?
    let errorMessage: String?
    let totalDistanceMeters: Double?
    let totalDurationSeconds: Double?
    let overviewPolyline: String?
    let waypoints: [MissionTeamRouteWaypoint]
    let legs: [MissionTeamRouteLeg]
    let route: ActivityRouteSummary?
    let activityRoutes: [ActivityRoute]

    enum CodingKeys: String, CodingKey {
        case missionId
        case missionTeamId
        case originLatitude
        case originLongitude
        case originLat
        case originLng
        case vehicle
        case status
        case errorMessage
        case totalDistanceMeters
        case totalDurationSeconds
        case overviewPolyline
        case waypoints
        case legs
        case route
        case activityRoutes
        case activities
        case routes
    }

    init(
        missionId: Int?,
        missionTeamId: Int?,
        originLatitude: Double?,
        originLongitude: Double?,
        vehicle: String?,
        route: ActivityRouteSummary?,
        activityRoutes: [ActivityRoute],
        status: String? = nil,
        errorMessage: String? = nil,
        totalDistanceMeters: Double? = nil,
        totalDurationSeconds: Double? = nil,
        overviewPolyline: String? = nil,
        waypoints: [MissionTeamRouteWaypoint] = [],
        legs: [MissionTeamRouteLeg] = []
    ) {
        self.missionId = missionId
        self.missionTeamId = missionTeamId
        self.originLatitude = originLatitude
        self.originLongitude = originLongitude
        self.vehicle = vehicle
        self.status = status
        self.errorMessage = errorMessage
        self.totalDistanceMeters = totalDistanceMeters
        self.totalDurationSeconds = totalDurationSeconds
        self.overviewPolyline = overviewPolyline
        self.waypoints = waypoints
        self.legs = legs
        self.route = route
            ?? Self.makeRouteSummary(
                totalDistanceMeters: totalDistanceMeters ?? legs.first?.distanceMeters,
                totalDistanceText: legs.first?.distanceText,
                totalDurationSeconds: totalDurationSeconds ?? legs.first?.durationSeconds,
                totalDurationText: legs.first?.durationText,
                overviewPolyline: overviewPolyline
            )
        self.activityRoutes = activityRoutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        missionId = try container.decodeIfPresent(Int.self, forKey: .missionId)
        missionTeamId = try container.decodeIfPresent(Int.self, forKey: .missionTeamId)
        originLatitude = try container.decodeIfPresent(Double.self, forKey: .originLatitude)
            ?? container.decodeLossyDoubleIfPresent(forKey: .originLat)
        originLongitude = try container.decodeIfPresent(Double.self, forKey: .originLongitude)
            ?? container.decodeLossyDoubleIfPresent(forKey: .originLng)
        vehicle = try container.decodeIfPresent(String.self, forKey: .vehicle)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        totalDistanceMeters = container.decodeLossyDoubleIfPresent(forKey: .totalDistanceMeters)
        totalDurationSeconds = container.decodeLossyDoubleIfPresent(forKey: .totalDurationSeconds)
        overviewPolyline = try container.decodeIfPresent(String.self, forKey: .overviewPolyline)
        waypoints = (try? container.decode([MissionTeamRouteWaypoint].self, forKey: .waypoints)) ?? []
        legs = (try? container.decode([MissionTeamRouteLeg].self, forKey: .legs)) ?? []

        let nestedRoute = try container.decodeIfPresent(ActivityRouteSummary.self, forKey: .route)
        route = nestedRoute
            ?? Self.makeRouteSummary(
                totalDistanceMeters: totalDistanceMeters ?? legs.first?.distanceMeters,
                totalDistanceText: legs.first?.distanceText,
                totalDurationSeconds: totalDurationSeconds ?? legs.first?.durationSeconds,
                totalDurationText: legs.first?.durationText,
                overviewPolyline: overviewPolyline
            )

        let decodedActivityRoutes = (try? container.decode([ActivityRoute].self, forKey: .activityRoutes))
            ?? (try? container.decode([ActivityRoute].self, forKey: .activities))
            ?? (try? container.decode([ActivityRoute].self, forKey: .routes))
            ?? []

        if decodedActivityRoutes.isEmpty, waypoints.isEmpty == false {
            activityRoutes = Self.makeActivityRoutesFromWaypoints(
                waypoints: waypoints,
                originLatitude: originLatitude,
                originLongitude: originLongitude,
                vehicle: vehicle
            )
        } else {
            activityRoutes = decodedActivityRoutes
        }
    }

    private static func makeRouteSummary(
        totalDistanceMeters: Double?,
        totalDistanceText: String?,
        totalDurationSeconds: Double?,
        totalDurationText: String?,
        overviewPolyline: String?
    ) -> ActivityRouteSummary? {
        guard totalDistanceMeters != nil
            || totalDistanceText?.isEmpty == false
            || totalDurationSeconds != nil
            || totalDurationText?.isEmpty == false
            || overviewPolyline?.isEmpty == false else {
            return nil
        }

        return ActivityRouteSummary(
            totalDistanceMeters: totalDistanceMeters,
            totalDistanceText: totalDistanceText,
            totalDurationSeconds: totalDurationSeconds,
            totalDurationText: totalDurationText,
            overviewPolyline: overviewPolyline,
            summary: nil,
            steps: nil
        )
    }

    private static func makeActivityRoutesFromWaypoints(
        waypoints: [MissionTeamRouteWaypoint],
        originLatitude: Double?,
        originLongitude: Double?,
        vehicle: String?
    ) -> [ActivityRoute] {
        let orderedWaypoints = waypoints.sorted { lhs, rhs in
            switch (lhs.step, rhs.step) {
            case let (l?, r?):
                if l != r { return l < r }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            return lhs.activityId < rhs.activityId
        }

        var currentOriginLatitude = originLatitude ?? orderedWaypoints.first?.latitude ?? 0
        var currentOriginLongitude = originLongitude ?? orderedWaypoints.first?.longitude ?? 0

        return orderedWaypoints.map { waypoint in
            let route = ActivityRoute(
                activityId: waypoint.activityId,
                activityType: waypoint.activityType ?? "Activity",
                description: waypoint.description,
                destinationLatitude: waypoint.latitude,
                destinationLongitude: waypoint.longitude,
                originLatitude: currentOriginLatitude,
                originLongitude: currentOriginLongitude,
                vehicle: vehicle ?? "car",
                route: nil
            )

            currentOriginLatitude = waypoint.latitude
            currentOriginLongitude = waypoint.longitude
            return route
        }
    }
}

struct MissionTeamRouteWaypoint: Decodable {
    let activityId: Int
    let step: Int?
    let activityType: String?
    let description: String?
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case activityId
        case step
        case activityType
        case description
        case latitude
        case longitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedActivityId = try? container.decode(Int.self, forKey: .activityId) {
            activityId = decodedActivityId
        } else if let stringActivityId = try? container.decode(String.self, forKey: .activityId),
                  let parsedActivityId = Int(stringActivityId) {
            activityId = parsedActivityId
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .activityId,
                in: container,
                debugDescription: "Invalid activityId in mission team route waypoint"
            )
        }

        if let decodedStep = try? container.decodeIfPresent(Int.self, forKey: .step) {
            step = decodedStep
        } else if let stringStep = try? container.decodeIfPresent(String.self, forKey: .step),
                  let parsedStep = Int(stringStep) {
            step = parsedStep
        } else {
            step = nil
        }

        activityType = try container.decodeIfPresent(String.self, forKey: .activityType)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        latitude = container.decodeLossyDoubleIfPresent(forKey: .latitude) ?? 0
        longitude = container.decodeLossyDoubleIfPresent(forKey: .longitude) ?? 0
    }
}

struct MissionTeamRouteLeg: Decodable {
    let distanceMeters: Double?
    let distanceText: String?
    let durationSeconds: Double?
    let durationText: String?

    enum CodingKeys: String, CodingKey {
        case distanceMeters
        case distanceText
        case durationSeconds
        case durationText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        distanceMeters = container.decodeLossyDoubleIfPresent(forKey: .distanceMeters)
        distanceText = try container.decodeIfPresent(String.self, forKey: .distanceText)
        durationSeconds = container.decodeLossyDoubleIfPresent(forKey: .durationSeconds)
        durationText = try container.decodeIfPresent(String.self, forKey: .durationText)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyDoubleIfPresent(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }

        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }

        if let stringValue = try? decodeIfPresent(String.self, forKey: key),
           let parsed = Double(stringValue) {
            return parsed
        }

        return nil
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
