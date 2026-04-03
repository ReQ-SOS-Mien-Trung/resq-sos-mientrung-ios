import Foundation

struct CompleteMissionTeamExecutionRequest: Codable {
    let note: String?
}

struct CompleteMissionTeamExecutionResponse: Codable {
    let missionId: Int
    let missionTeamId: Int
    let status: String
    let note: String?
}

struct MissionTeamReportResponse: Codable {
    let missionId: Int
    let missionTeamId: Int
    let executionStatus: String
    let reportStatus: String
    let canEdit: Bool
    let canSubmit: Bool
    let canEvaluateMembers: Bool
    let startedAt: String?
    let lastEditedAt: String?
    let submittedAt: String?
    let teamSummary: String?
    let teamNote: String?
    let issuesJson: String?
    let resultJson: String?
    let evidenceJson: String?
    let activities: [MissionTeamReportActivity]
    let memberEvaluations: [MissionTeamReportMemberEvaluation]
}

struct MissionTeamReportActivity: Codable, Identifiable {
    let missionActivityId: Int
    let activityCode: String?
    let activityType: String?
    let activityStatus: String?
    let executionStatus: String?
    let summary: String?
    let issuesJson: String?
    let resultJson: String?
    let evidenceJson: String?

    var id: Int { missionActivityId }
}

struct MissionTeamReportMemberEvaluation: Codable, Identifiable {
    let rescuerId: String
    let fullName: String?
    let username: String?
    let phone: String?
    let avatarUrl: String?
    let rescuerType: String?
    let roleInTeam: String?
    let responseTimeScore: Double?
    let rescueEffectivenessScore: Double?
    let decisionHandlingScore: Double?
    let safetyMedicalSkillScore: Double?
    let teamworkCommunicationScore: Double?
    let overallScore: Double?

    var id: String { rescuerId }
}

struct SaveMissionTeamReportDraftRequest: Codable {
    let teamSummary: String?
    let teamNote: String?
    let issuesJson: String?
    let resultJson: String?
    let evidenceJson: String?
    let activities: [MissionTeamReportDraftActivityItem]
    let memberEvaluations: [MissionTeamMemberEvaluationInput]
}

struct MissionTeamReportDraftActivityItem: Codable {
    let missionActivityId: Int
    let executionStatus: String?
    let summary: String?
    let issuesJson: String?
    let resultJson: String?
    let evidenceJson: String?
}

struct SubmitMissionTeamReportRequest: Codable {
    let teamSummary: String?
    let teamNote: String?
    let issuesJson: String?
    let resultJson: String?
    let evidenceJson: String?
    let activities: [MissionTeamReportSubmitActivityItem]
    let memberEvaluations: [MissionTeamMemberEvaluationInput]
}

struct MissionTeamReportSubmitActivityItem: Codable {
    let missionActivityId: Int
    let executionStatus: String?
    let summary: String?
    let issuesJson: String?
    let resultJson: String?
    let evidenceJson: String?
}

struct MissionTeamMemberEvaluationInput: Codable {
    let rescuerId: String
    let responseTimeScore: Double
    let rescueEffectivenessScore: Double
    let decisionHandlingScore: Double
    let safetyMedicalSkillScore: Double
    let teamworkCommunicationScore: Double
}

enum ReportExecutionStatusOption: String, CaseIterable, Identifiable {
    case planned
    case ongoing
    case completed
    case failed
    case cancelled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .planned:
            return "Planned"
        case .ongoing:
            return "On Going"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }

    var displayLabel: String {
        switch self {
        case .planned:
            return "Chưa thực hiện"
        case .ongoing:
            return "Đang thực hiện"
        case .completed:
            return "Hoàn thành"
        case .failed:
            return "Thất bại"
        case .cancelled:
            return "Đã hủy"
        }
    }

    init?(apiValue: String) {
        let normalized = apiValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .lowercased()

        switch normalized {
        case "planned", "pending":
            self = .planned
        case "ongoing", "inprogress":
            self = .ongoing
        case "completed", "complete", "succeed", "succeeded", "success":
            self = .completed
        case "failed", "fail":
            self = .failed
        case "cancelled", "canceled", "cancel":
            self = .cancelled
        default:
            return nil
        }
    }
}

struct MissionTeamReportActivityForm: Identifiable, Equatable {
    let missionActivityId: Int
    let activityCode: String?
    let activityType: String?
    let activityStatus: String?
    var executionStatus: String
    var summary: String
    var issuesJson: String
    var resultJson: String
    var evidenceJson: String

    var id: Int { missionActivityId }

    var localizedActivityType: String? {
        localizedActivityTypeDisplay(activityType)
    }

    var localizedActivityCode: String? {
        localizedActivityCodeDisplay(activityCode)
    }

    init(activity: MissionTeamReportActivity) {
        missionActivityId = activity.missionActivityId
        activityCode = activity.activityCode
        activityType = activity.activityType
        activityStatus = activity.activityStatus
        executionStatus = activity.executionStatus ?? activity.activityStatus ?? ""
        summary = activity.summary ?? ""
        issuesJson = activity.issuesJson ?? ""
        resultJson = activity.resultJson ?? ""
        evidenceJson = activity.evidenceJson ?? ""
    }

    var title: String {
        if let localizedActivityCode {
            return localizedActivityCode
        }

        if let localizedActivityType {
            return localizedActivityType
        }

        return "Hoạt động #\(missionActivityId)"
    }
}

struct MissionTeamMemberEvaluationForm: Identifiable, Equatable {
    let rescuerId: String
    let fullName: String?
    let username: String?
    let phone: String?
    let avatarUrl: String?
    let rescuerType: String?
    let roleInTeam: String?
    var responseTimeScore: Double?
    var rescueEffectivenessScore: Double?
    var decisionHandlingScore: Double?
    var safetyMedicalSkillScore: Double?
    var teamworkCommunicationScore: Double?

    var id: String { rescuerId }

    init(evaluation: MissionTeamReportMemberEvaluation) {
        rescuerId = evaluation.rescuerId
        fullName = evaluation.fullName
        username = evaluation.username
        phone = evaluation.phone
        avatarUrl = evaluation.avatarUrl
        rescuerType = evaluation.rescuerType
        roleInTeam = evaluation.roleInTeam
        responseTimeScore = evaluation.responseTimeScore
        rescueEffectivenessScore = evaluation.rescueEffectivenessScore
        decisionHandlingScore = evaluation.decisionHandlingScore
        safetyMedicalSkillScore = evaluation.safetyMedicalSkillScore
        teamworkCommunicationScore = evaluation.teamworkCommunicationScore
    }

    var displayName: String {
        let trimmed = [fullName, username, phone]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.isEmpty == false })

        return trimmed ?? "Thành viên"
    }

    var hasAnyScore: Bool {
        responseTimeScore != nil ||
        rescueEffectivenessScore != nil ||
        decisionHandlingScore != nil ||
        safetyMedicalSkillScore != nil ||
        teamworkCommunicationScore != nil
    }

    var hasCompleteScore: Bool {
        responseTimeScore != nil &&
        rescueEffectivenessScore != nil &&
        decisionHandlingScore != nil &&
        safetyMedicalSkillScore != nil &&
        teamworkCommunicationScore != nil
    }

    var averageScore: Double? {
        let values = [
            responseTimeScore,
            rescueEffectivenessScore,
            decisionHandlingScore,
            safetyMedicalSkillScore,
            teamworkCommunicationScore
        ].compactMap { $0 }

        guard values.isEmpty == false else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
