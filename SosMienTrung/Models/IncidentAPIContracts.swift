import Foundation

struct MissionIncidentAPIRequest: Encodable {
    let scope: String
    let context: MissionIncidentAPIContext
    let incidentType: String
    let missionDecision: String
    let teamStatus: MissionIncidentAPITeamStatus
    let urgentMedical: MissionIncidentAPIUrgentMedical
    let vehicleStatus: MissionIncidentAPIVehicleStatus
    let hazards: [String]
    let rescueRequest: MissionIncidentAPIRescueRequest?
    let handover: MissionIncidentAPIHandover?
    let note: String?
    let evidence: [String]?
}

struct MissionIncidentAPIContext: Encodable {
    let missionId: Int
    let missionTeamId: Int
    let missionTitle: String
    let teamName: String?
    let reporterId: String?
    let reporterName: String
    let reportedAt: String
    let location: IncidentAPILocation
    let unfinishedActivityCount: Int
    let civiliansWithTeam: MissionIncidentAPICivilianContext
}

struct MissionIncidentAPICivilianContext: Encodable {
    let hasCiviliansWithTeam: Bool
    let civilianCount: Int?
    let civilianCondition: String?
}

struct MissionIncidentAPITeamStatus: Encodable {
    let totalMembers: Int
    let safeMembers: Int
    let lightlyInjuredMembers: Int
    let severelyInjuredMembers: Int
    let immobileMembers: Int
    let missingContactMembers: Int
}

struct MissionIncidentAPIUrgentMedical: Encodable {
    let needsImmediateEmergencyCare: Bool
    let emergencyTypes: [String]
}

struct MissionIncidentAPIVehicleStatus: Encodable {
    let primaryVehicleType: String
    let status: String
    let retreatCapability: String
}

struct MissionIncidentAPIRescueRequest: Encodable {
    let supportTypes: [String]
    let priority: String
    let evacuationPriority: String
}

struct MissionIncidentAPIHandover: Encodable {
    let needsMissionTakeover: Bool
    let unfinishedWork: String
    let unfinishedActivityCount: Int?
    let transferItems: [String]?
    let notesForTakeoverTeam: String
    let safeHandoverPoint: String
}

struct ActivityIncidentAPIRequest: Encodable {
    let scope: String
    let context: ActivityIncidentAPIContext
    let incidentType: String
    let affectedResources: [String]
    let impact: ActivityIncidentAPIImpact
    let specificDetails: ActivityIncidentAPISpecificDetails?
    let supportRequest: ActivityIncidentAPISupportRequest?
    let teamStatus: ActivityIncidentAPITeamStatus
    let note: String?
    let evidence: [String]?
}

struct ActivityIncidentAPIContext: Encodable {
    let missionId: Int
    let missionTeamId: Int
    let missionTitle: String
    let teamName: String?
    let reporterId: String?
    let reporterName: String
    let reportedAt: String
    let location: IncidentAPILocation
    let activities: [ActivityIncidentAPISnapshot]
}

struct ActivityIncidentAPISnapshot: Encodable {
    let activityId: Int
    let title: String
    let activityType: String?
    let step: Int?
}

struct ActivityIncidentAPIImpact: Encodable {
    let canContinueActivity: Bool
    let needSupportSOS: Bool
    let needReassignActivity: Bool
}

struct ActivityIncidentAPISpecificDetails: Encodable {
    let equipmentDamage: String?
    let vehicleDamage: String?
    let lostSupply: String?
    let staffingShortage: String?
}

struct ActivityIncidentAPISupportRequest: Encodable {
    let supportTypes: [String]
    let priority: String
    let counts: ActivityIncidentAPISupportCounts
    let meetupPoint: String?
    let takeoverNeeded: Bool?
}

struct ActivityIncidentAPISupportCounts: Encodable {
    let teamCount: Int?
    let peopleCount: Int?
    let vehicleCount: Int?
}

struct ActivityIncidentAPITeamStatus: Encodable {
    let totalMembers: Int?
    let availableMembers: Int?
    let lightlyInjuredMembers: Int
    let unavailableMembers: Int?
    let needsMemberEvacuation: Bool?
}

struct IncidentAPILocation: Encodable {
    let latitude: Double
    let longitude: Double
}

extension MissionIncidentReportRequest {
    func asAPIRequest() throws -> MissionIncidentAPIRequest {
        MissionIncidentAPIRequest(
            scope: "Mission",
            context: MissionIncidentAPIContext(
                missionId: context.missionId,
                missionTeamId: context.missionTeamId,
                missionTitle: context.missionTitle,
                teamName: context.teamName,
                reporterId: context.reporterId,
                reporterName: context.reporterName,
                reportedAt: context.reportedAt,
                location: IncidentAPILocation(
                    latitude: context.location.latitude,
                    longitude: context.location.longitude
                ),
                unfinishedActivityCount: context.unfinishedActivityCount,
                civiliansWithTeam: MissionIncidentAPICivilianContext(
                    hasCiviliansWithTeam: context.civiliansWithTeam.hasCiviliansWithTeam,
                    civilianCount: context.civiliansWithTeam.civilianCount,
                    civilianCondition: context.civiliansWithTeam.civilianCondition
                )
            ),
            incidentType: incidentType,
            missionDecision: missionDecision,
            teamStatus: MissionIncidentAPITeamStatus(
                totalMembers: teamStatus.totalMembers,
                safeMembers: teamStatus.safeMembers,
                lightlyInjuredMembers: teamStatus.lightlyInjuredMembers,
                severelyInjuredMembers: teamStatus.severelyInjuredMembers,
                immobileMembers: teamStatus.immobileMembers,
                missingContactMembers: teamStatus.missingContactMembers
            ),
            urgentMedical: MissionIncidentAPIUrgentMedical(
                needsImmediateEmergencyCare: urgentMedical.needsImmediateEmergencyCare,
                emergencyTypes: urgentMedical.emergencyTypes
            ),
            vehicleStatus: MissionIncidentAPIVehicleStatus(
                primaryVehicleType: vehicleStatus.primaryVehicleType,
                status: vehicleStatus.status,
                retreatCapability: vehicleStatus.retreatCapability
            ),
            hazards: hazards,
            rescueRequest: rescueRequest.map {
                MissionIncidentAPIRescueRequest(
                    supportTypes: $0.supportTypes,
                    priority: $0.priority,
                    evacuationPriority: $0.evacuationPriority
                )
            },
            handover: handover.map {
                MissionIncidentAPIHandover(
                    needsMissionTakeover: $0.needsMissionTakeover,
                    unfinishedWork: $0.unfinishedWork,
                    unfinishedActivityCount: $0.unfinishedActivityCount,
                    transferItems: $0.transferItems.incidentNilIfBlank.map { [$0] },
                    notesForTakeoverTeam: $0.notesForTakeoverTeam,
                    safeHandoverPoint: $0.safeHandoverPoint
                )
            },
            note: note.incidentNilIfBlank,
            evidence: try IncidentAPIEncoding.wrapAsJSONArrayString(evidence)
        )
    }
}

extension ActivityIncidentReportRequest {
    func asAPIRequest() throws -> ActivityIncidentAPIRequest {
        ActivityIncidentAPIRequest(
            scope: "Activity",
            context: ActivityIncidentAPIContext(
                missionId: context.missionId,
                missionTeamId: context.missionTeamId,
                missionTitle: context.missionTitle,
                teamName: context.teamName,
                reporterId: context.reporterId,
                reporterName: context.reporterName,
                reportedAt: context.reportedAt,
                location: IncidentAPILocation(
                    latitude: context.location.latitude,
                    longitude: context.location.longitude
                ),
                activities: context.activities.map {
                    ActivityIncidentAPISnapshot(
                        activityId: $0.activityId,
                        title: $0.title,
                        activityType: $0.activityType,
                        step: $0.step
                    )
                }
            ),
            incidentType: incidentType,
            affectedResources: affectedResources,
            impact: ActivityIncidentAPIImpact(
                canContinueActivity: impact.canContinueActivity,
                needSupportSOS: impact.needSupportSOS,
                needReassignActivity: impact.needReassignActivity
            ),
            specificDetails: try specificDetails.map {
                ActivityIncidentAPISpecificDetails(
                    equipmentDamage: try IncidentAPIEncoding.jsonString($0.equipmentDamage),
                    vehicleDamage: try IncidentAPIEncoding.jsonString($0.vehicleDamage),
                    lostSupply: try IncidentAPIEncoding.jsonString($0.lostSupply),
                    staffingShortage: try IncidentAPIEncoding.jsonString($0.staffingShortage)
                )
            },
            supportRequest: supportRequest.map {
                ActivityIncidentAPISupportRequest(
                    supportTypes: $0.supportTypes,
                    priority: $0.priority,
                    counts: ActivityIncidentAPISupportCounts(
                        teamCount: $0.counts.teamCount,
                        peopleCount: $0.counts.peopleCount,
                        vehicleCount: $0.counts.vehicleCount
                    ),
                    meetupPoint: $0.meetupPoint,
                    takeoverNeeded: $0.takeoverNeeded
                )
            },
            teamStatus: ActivityIncidentAPITeamStatus(
                totalMembers: teamStatus.totalMembers,
                availableMembers: teamStatus.availableMembers,
                lightlyInjuredMembers: teamStatus.lightlyInjuredMembers ?? 0,
                unavailableMembers: teamStatus.unavailableMembers,
                needsMemberEvacuation: teamStatus.needsMemberEvacuation
            ),
            note: note.incidentNilIfBlank,
            evidence: try IncidentAPIEncoding.wrapAsJSONArrayString(evidence)
        )
    }
}

private enum IncidentAPIEncoding {
    static func wrapAsJSONArrayString<T: Encodable>(_ value: T?) throws -> [String]? {
        guard let encoded = try jsonString(value) else { return nil }
        return [encoded]
    }

    static func jsonString<T: Encodable>(_ value: T?) throws -> String? {
        guard let value else { return nil }
        let data = try JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8)
    }
}

private extension String {
    var incidentTrimmedForAPI: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var incidentNilIfBlank: String? {
        let trimmed = incidentTrimmedForAPI
        return trimmed.isEmpty ? nil : trimmed
    }
}
