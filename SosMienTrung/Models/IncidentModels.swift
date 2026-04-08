import Foundation

struct IncidentReporter: Codable, Equatable {
    let id: String
    let firstName: String?
    let lastName: String?
    let phone: String?
    let email: String?
    let avatarUrl: String?

    var displayName: String {
        let components = [lastName, firstName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return components.isEmpty ? "Ẩn danh" : components.joined(separator: " ")
    }
}

// MARK: - Incident
struct Incident: Codable, Identifiable {
    let id: Int
    let missionTeamId: Int?
    let missionActivityId: Int?
    let incidentScope: String?
    let description: String?
    let latitude: Double?
    let longitude: Double?
    let status: String
    let hasInjuredMember: Bool?
    let reportedBy: IncidentReporter?
    let reportedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "incidentId"
        case missionTeamId
        case missionActivityId
        case incidentScope
        case description
        case latitude
        case longitude
        case status
        case hasInjuredMember
        case reportedBy
        case reportedAt
    }
}

struct MissionIncidentsResponse: Codable {
    let missionId: Int
    let incidents: [Incident]
}

struct IncidentAssistanceSosRequestData: Codable, Equatable {
    let rawMessage: String?
    let latitude: Double?
    let longitude: Double?
    let sosType: String?
    let situation: String?
    let hasInjured: Bool?
    let adultCount: Int?
    let childCount: Int?
    let elderlyCount: Int?
    let medicalIssues: [String]?
    let address: String?
    let additionalDescription: String?
}

// MARK: - Report Mission Team Incident Request
/// POST /operations/missions/{missionId}/teams/{missionTeamId}/incident
struct ReportMissionTeamIncidentRequest: Codable {
    let description: String
    let latitude: Double
    let longitude: Double
    let needsRescueAssistance: Bool
    let assistanceSos: IncidentAssistanceSosRequestData?
}

// MARK: - Report Mission Activity Incident Request
/// POST /operations/missions/{missionId}/activities/{activityId}/incident
struct ReportMissionActivityIncidentRequest: Codable {
    let description: String
    let latitude: Double
    let longitude: Double
}

// MARK: - Update Incident Status Request
/// PATCH /operations/team-incidents/{incidentId}/status
/// Valid status values: InProgress, Resolved
struct UpdateIncidentStatusRequest: Codable {
    let status: String
    let hasInjuredMember: Bool?
}

// MARK: - Incident Response
struct IncidentResponse: Codable {
    let incidentId: Int
    let missionId: Int
    let missionTeamId: Int
    let missionActivityId: Int?
    let incidentScope: String
    let status: String
    let incidentSosRequestIds: [Int]
    let assistanceSosRequestId: Int?
    let assistanceSosStatus: String?
    let assistanceSosPriorityLevel: String?
    let reportedAt: String?
}
