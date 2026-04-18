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
struct MissionSupplyLotAllocation: Codable, Identifiable {
    let lotId: String?
    let quantityTaken: Int?
    let receivedDate: String?
    let expiredDate: String?
    let remainingQuantityAfterExecution: Int?

    var id: String {
        let lotLabel = lotId?.trimmingCharacters(in: .whitespacesAndNewlines)
        return lotLabel?.isEmpty == false
            ? lotLabel!
            : "unknown-\(receivedDate ?? "")-\(expiredDate ?? "")-\(quantityTaken ?? -1)-\(remainingQuantityAfterExecution ?? -1)"
    }

    var hasDisplayableValue: Bool {
        let cleanedLotId = lotId?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanedLotId?.isEmpty == false
            || quantityTaken != nil
            || receivedDate?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || expiredDate?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || remainingQuantityAfterExecution != nil
    }

    var numericLotId: Int? {
        guard let lotId = lotId?.trimmingCharacters(in: .whitespacesAndNewlines), lotId.isEmpty == false else {
            return nil
        }

        return Int(lotId)
    }

    enum CodingKeys: String, CodingKey {
        case lotId
        case quantityTaken
        case receivedDate
        case expiredDate
        case remainingQuantityAfterExecution
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let textValue = try? container.decodeIfPresent(String.self, forKey: .lotId) {
            lotId = textValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .lotId) {
            lotId = String(intValue)
        } else if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: .lotId) {
            lotId = String(Int(doubleValue.rounded()))
        } else {
            lotId = nil
        }

        quantityTaken = MissionSupplyLotAllocation.decodeLossyInt(container: container, key: .quantityTaken)
        receivedDate = try? container.decodeIfPresent(String.self, forKey: .receivedDate)
        expiredDate = try? container.decodeIfPresent(String.self, forKey: .expiredDate)
        remainingQuantityAfterExecution = MissionSupplyLotAllocation.decodeLossyInt(container: container, key: .remainingQuantityAfterExecution)
    }

    private static func decodeLossyInt(
        container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Int? {
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }

        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue.rounded())
        }

        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }
}

struct MissionSupplyReusableUnit: Codable, Identifiable {
    let reusableItemId: Int?
    let itemModelId: Int?
    let itemName: String?
    let serialNumber: String?
    let condition: String?
    let note: String?

    var id: String {
        if let reusableItemId {
            return "reusable-\(reusableItemId)"
        }

        let serialNumber = serialNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        return serialNumber?.isEmpty == false
            ? "serial-\(serialNumber!)"
            : "reusable-unknown-\(itemModelId ?? -1)"
    }

    private enum CodingKeys: String, CodingKey {
        case reusableItemId
        case itemModelId
        case itemName
        case serialNumber
        case condition
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reusableItemId = MissionSupplyReusableUnit.decodeLossyInt(container: container, key: .reusableItemId)
        itemModelId = MissionSupplyReusableUnit.decodeLossyInt(container: container, key: .itemModelId)
        itemName = try? container.decodeIfPresent(String.self, forKey: .itemName)
        serialNumber = try? container.decodeIfPresent(String.self, forKey: .serialNumber)
        condition = try? container.decodeIfPresent(String.self, forKey: .condition)
        note = try? container.decodeIfPresent(String.self, forKey: .note)
    }

    private static func decodeLossyInt(
        container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Int? {
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }

        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue.rounded())
        }

        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }
}

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
    let plannedPickupLotAllocations: [MissionSupplyLotAllocation]?
    let plannedPickupReusableUnits: [MissionSupplyReusableUnit]?
    let pickupLotAllocations: [MissionSupplyLotAllocation]?
    let pickedReusableUnits: [MissionSupplyReusableUnit]?
    let availableDeliveryLotAllocations: [MissionSupplyLotAllocation]?
    let availableDeliveryReusableUnits: [MissionSupplyReusableUnit]?
    let deliveredLotAllocations: [MissionSupplyLotAllocation]?
    let deliveredReusableUnits: [MissionSupplyReusableUnit]?

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
    let imageUrl: String?
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
            return L10n.Mission.executionStepNumbered(String(step))
        }

        return L10n.Mission.executionStepTitle
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
            imageUrl: imageUrl,
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

    var isReturnSuppliesActivity: Bool {
        normalizedActivityTypeKey == "returnsupplies"
    }

    var isDepotSupplyActivity: Bool {
        isCollectSuppliesActivity || isReturnSuppliesActivity
    }
}

struct MissionActivityExecutionContext {
    let groupKey: String
    let sosRequestId: Int?
    let coordinateLabel: String?
    let coordinateSource: MissionActivityCoordinateSource?
    let sharedActivityCount: Int

    var badgeText: String {
        if let sosRequestId {
            return L10n.Mission.sosBadge(String(sosRequestId))
        }

        if sharedActivityCount > 1 {
            return L10n.Mission.sharedExecutionPoint
        }

        return L10n.Mission.executionPoint
    }

    var detailText: String? {
        var parts: [String] = []

        if sharedActivityCount > 1 {
            parts.append(L10n.Mission.sharedStepsAtPoint(String(sharedActivityCount)))
        }

        if let coordinateLabel {
            if coordinateSource == .description {
                parts.append(L10n.Mission.coordinateReadFromDescription(coordinateLabel))
            } else {
                parts.append(L10n.Mission.coordinateLabel(coordinateLabel))
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

enum MissionActivityCoordinateSource: Equatable {
    case target
    case description
}

private struct MissionActivityExecutionSeed {
    let groupKey: String
    let sosRequestId: Int?
    let coordinateKey: String?
    let coordinateLabel: String?
    let coordinateSource: MissionActivityCoordinateSource?
    let shouldSurface: Bool
}

private struct MissionActivityCoordinate {
    let latitude: Double
    let longitude: Double
    let source: MissionActivityCoordinateSource
}

func buildMissionActivityExecutionContexts(activities: [Activity]) -> [Int: MissionActivityExecutionContext] {
    let seedsByActivityId = Dictionary(uniqueKeysWithValues: activities.map { activity in
        (activity.id, missionActivityExecutionSeed(for: activity))
    })

    var sharedCounts: [String: Int] = [:]
    for seed in seedsByActivityId.values where seed.coordinateKey != nil || seed.sosRequestId != nil {
        sharedCounts[seed.groupKey, default: 0] += 1
    }

    var results: [Int: MissionActivityExecutionContext] = [:]

    for activity in activities {
        guard let seed = seedsByActivityId[activity.id] else { continue }

        let sharedActivityCount = sharedCounts[seed.groupKey, default: 1]
        guard seed.shouldSurface || sharedActivityCount > 1 else {
            continue
        }

        results[activity.id] = MissionActivityExecutionContext(
            groupKey: seed.groupKey,
            sosRequestId: seed.sosRequestId,
            coordinateLabel: seed.coordinateLabel,
            coordinateSource: seed.coordinateSource,
            sharedActivityCount: sharedActivityCount
        )
    }

    return results
}

func activityDescriptionHasRouteInstruction(_ activity: Activity) -> Bool {
    guard let description = activity.description?.trimmingCharacters(in: .whitespacesAndNewlines),
          description.isEmpty == false else {
        return false
    }

    return missionActivityDescriptionHasRouteInstruction(description)
}

func missionActivityDescriptionHasRouteInstruction(_ description: String) -> Bool {
    let normalizedDescription = description
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard normalizedDescription.isEmpty == false else {
        return false
    }

    let routeInstructionPhrases = [
        "di chuyen den",
        "di chuyen toi",
        "di chuyen ve",
        "di chuyen sang",
        "di chuyen qua",
        "di den",
        "dua den",
        "dua toi",
        "van chuyen den",
        "van chuyen toi",
        "move to",
        "go to",
        "head to",
        "proceed to",
        "travel to",
        "transport to"
    ]

    return routeInstructionPhrases.contains { normalizedDescription.contains($0) }
}

private func missionActivityExecutionSeed(for activity: Activity) -> MissionActivityExecutionSeed {
    guard activity.isDepotSupplyActivity == false else {
        return MissionActivityExecutionSeed(
            groupKey: "activity-\(activity.id)",
            sosRequestId: nil,
            coordinateKey: nil,
            coordinateLabel: nil,
            coordinateSource: nil,
            shouldSurface: false
        )
    }

    let resolvedSosRequestId = resolveMissionActivitySOSRequestId(for: activity)
    let resolvedCoordinate = resolveMissionActivityCoordinate(for: activity)
    let coordinateKey = resolvedCoordinate.map {
        String(format: "%.4f:%.4f", $0.latitude, $0.longitude)
    }
    let coordinateLabel = resolvedCoordinate.map {
        String(format: "%.4f, %.4f", $0.latitude, $0.longitude)
    }

    let groupKey: String
    if let resolvedSosRequestId, let coordinateKey {
        groupKey = "sos-\(resolvedSosRequestId)-point-\(coordinateKey)"
    } else if let resolvedSosRequestId {
        groupKey = "sos-\(resolvedSosRequestId)"
    } else if let coordinateKey {
        groupKey = "point-\(coordinateKey)"
    } else {
        groupKey = "activity-\(activity.id)"
    }

    return MissionActivityExecutionSeed(
        groupKey: groupKey,
        sosRequestId: resolvedSosRequestId,
        coordinateKey: coordinateKey,
        coordinateLabel: coordinateLabel,
        coordinateSource: resolvedCoordinate?.source,
        shouldSurface: resolvedSosRequestId != nil
    )
}

private func resolveMissionActivitySOSRequestId(for activity: Activity) -> Int? {
    if let sosRequestId = activity.sosRequestId, sosRequestId > 0 {
        return sosRequestId
    }

    guard let description = activity.description?.trimmingCharacters(in: .whitespacesAndNewlines),
          description.isEmpty == false else {
        return nil
    }

    let regex = try? NSRegularExpression(pattern: #"SOS\s*#?\s*(\d+)"#, options: [.caseInsensitive])
    let range = NSRange(description.startIndex..<description.endIndex, in: description)
    guard let match = regex?.firstMatch(in: description, options: [], range: range),
          let idRange = Range(match.range(at: 1), in: description) else {
        return nil
    }

    return Int(description[idRange])
}

private func resolveMissionActivityCoordinate(for activity: Activity) -> MissionActivityCoordinate? {
    if let latitude = activity.targetLatitude,
       let longitude = activity.targetLongitude,
       isUsableMissionActivityCoordinate(latitude: latitude, longitude: longitude) {
        return MissionActivityCoordinate(
            latitude: latitude,
            longitude: longitude,
            source: .target
        )
    }

    guard let description = activity.description?.trimmingCharacters(in: .whitespacesAndNewlines),
          description.isEmpty == false else {
        return nil
    }

    return extractMissionActivityCoordinate(from: description)
}

private func extractMissionActivityCoordinate(from description: String) -> MissionActivityCoordinate? {
    let regex = try? NSRegularExpression(pattern: #"(-?\d{1,2}\.\d{2,6})[,\s]\s*(-?\d{1,3}\.\d{2,6})"#)
    let range = NSRange(description.startIndex..<description.endIndex, in: description)
    guard let match = regex?.firstMatch(in: description, options: [], range: range),
          let firstRange = Range(match.range(at: 1), in: description),
          let secondRange = Range(match.range(at: 2), in: description),
          let firstValue = Double(description[firstRange]),
          let secondValue = Double(description[secondRange]) else {
        return nil
    }

    if (8...24).contains(firstValue), (100...115).contains(secondValue) {
        return MissionActivityCoordinate(
            latitude: firstValue,
            longitude: secondValue,
            source: .description
        )
    }

    if (8...24).contains(secondValue), (100...115).contains(firstValue) {
        return MissionActivityCoordinate(
            latitude: secondValue,
            longitude: firstValue,
            source: .description
        )
    }

    return nil
}

private func isUsableMissionActivityCoordinate(latitude: Double, longitude: Double) -> Bool {
    (-90...90).contains(latitude)
        && (-180...180).contains(longitude)
        && !(abs(latitude) < 0.000001 && abs(longitude) < 0.000001)
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
            return cleanedTitle.isEmpty ? L10n.Mission.defaultTitle : cleanedTitle
        }

        return L10n.Mission.defaultTitle
    }

    var description: String? {
        var parts: [String] = []

        if let clusterId = clusterId {
            parts.append(L10n.Mission.clusterSos(String(clusterId)))
        }

        if let teamName = teams?.first?.teamName,
           teamName.isEmpty == false {
            parts.append(teamName)
        }

        if let severity = suggestedSeverityLevel,
           severity.isEmpty == false {
            parts.append(L10n.Mission.severity(severity))
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
        return L10n.Mission.missionTypeRescue
    case "evacuation", "evacuate":
        return L10n.Mission.missionTypeEvacuation
    case "medical", "medicalaid", "medicalsupport":
        return L10n.Mission.missionTypeMedical
    case "supply", "supplies", "logistics", "relief":
        return L10n.Mission.missionTypeRelief
    case "mixed", "hybrid", "combined":
        return L10n.Mission.missionTypeMixed
    case "rescuer":
        return L10n.Mission.missionTypeRescuerDispatch
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
        return L10n.Domain.activityTypeCollectSupplies
    case "deliversupplies":
        return L10n.Domain.activityTypeDeliverSupplies
    case "returnsupplies":
        return L10n.Domain.activityTypeReturnSupplies
    case "returnassemblypoint":
        return L10n.Domain.activityTypeReturnAssemblyPoint
    case "rescue":
        return L10n.Domain.activityTypeRescue
    case "medicalaid":
        return L10n.Domain.activityTypeFirstAid
    case "medicalsupport", "medical":
        return L10n.Domain.activityTypeMedicalSupport
    case "evacuate", "evacuation":
        return L10n.Domain.activityTypeEvacuate
    case "searchandrescue", "sar":
        return L10n.Domain.activityTypeSearchAndRescue
    case "logistics":
        return L10n.Domain.activityTypeLogistics
    case "transport", "transportation":
        return L10n.Domain.activityTypeTransport
    case "assessment":
        return L10n.Domain.activityTypeAssessment
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
        return L10n.Mission.numberedLabel(localizedBase, String(suffix))
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
    let imageUrl: String?
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
