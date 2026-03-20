import Foundation

// MARK: - Incident
struct Incident: Codable, Identifiable {
    let id: Int
    let missionTeamId: Int?
    let description: String?
    let latitude: Double?
    let longitude: Double?
    let status: String
    let needsAssistance: Bool?
    let hasInjuredMember: Bool?
    let createdAt: String?
}

// MARK: - Report Incident Request
/// POST /operations/team-incidents
struct ReportIncidentRequest: Codable {
    let missionTeamId: Int
    let description: String
    let latitude: Double
    let longitude: Double
}

// MARK: - Update Incident Status Request
/// PATCH /operations/team-incidents/{incidentId}/status
/// Valid status values: Reported, Acknowledged, InProgress, Resolved, Closed
struct UpdateIncidentStatusRequest: Codable {
    let status: String
    let needsAssistance: Bool?
    let hasInjuredMember: Bool?
}

// MARK: - Incident Response
struct IncidentResponse: Codable {
    let id: Int?
    let message: String?
}
