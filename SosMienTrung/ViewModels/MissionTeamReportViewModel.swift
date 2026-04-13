import Foundation
import Combine

@MainActor
final class MissionTeamReportViewModel: ObservableObject {
    @Published private(set) var report: MissionTeamReportResponse?
    @Published var teamSummary = ""
    @Published var teamNote = ""
    @Published var issuesJson = ""
    @Published var resultJson = ""
    @Published var evidenceJson = ""
    @Published var activities: [MissionTeamReportActivityForm] = []
    @Published var memberEvaluations: [MissionTeamMemberEvaluationForm] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isSubmitting = false
    @Published var isCompletingExecution = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    let missionId: Int
    let missionTeamId: Int

    init(missionId: Int, missionTeamId: Int) {
        self.missionId = missionId
        self.missionTeamId = missionTeamId
    }

    var executionStatus: String {
        report?.executionStatus ?? ""
    }

    var reportStatus: String {
        report?.reportStatus ?? "NotStarted"
    }

    var canEdit: Bool {
        report?.canEdit == true
    }

    var canSubmit: Bool {
        report?.canSubmit == true
    }

    var canEvaluateMembers: Bool {
        report?.canEvaluateMembers == true
    }

    var canCompleteExecution: Bool {
        guard let report else { return false }
        let status = report.executionStatus.normalizedStatusKey
        let reportStatus = report.reportStatus.normalizedStatusKey
        return status != "cancelled"
            && status != "completedwaitingreport"
            && status != "reported"
            && reportStatus != "submitted"
    }

    var hasPersistedMemberEvaluations: Bool {
        memberEvaluations.contains(where: \.hasAnyScore)
    }

    var saveDraftRestrictionMessage: String? {
        guard canEdit else { return nil }

        if canEvaluateMembers == false && hasPersistedMemberEvaluations {
            return "Chỉ đội trưởng mới được lưu đánh giá thành viên. Nếu bạn lưu nháp lúc này, hệ thống sẽ xóa phần đánh giá đã có."
        }

        return nil
    }

    var canSaveDraft: Bool {
        canEdit
            && saveDraftRestrictionMessage == nil
            && !isLoading
            && !isSaving
            && !isSubmitting
            && !isCompletingExecution
    }

    func load() {
        errorMessage = nil
        isLoading = true

        Task {
            defer { isLoading = false }

            do {
                let response = try await MissionService.shared.getMissionTeamReport(
                    missionId: missionId,
                    missionTeamId: missionTeamId
                )
                apply(response)
            } catch {
                errorMessage = "Không thể tải báo cáo đội: \(error.localizedDescription)"
            }
        }
    }

    func refresh() {
        load()
    }

    func completeExecution(note: String?) {
        errorMessage = nil
        successMessage = nil
        isCompletingExecution = true

        Task {
            defer { isCompletingExecution = false }

            do {
                _ = try await MissionService.shared.completeMissionTeamExecution(
                    missionId: missionId,
                    missionTeamId: missionTeamId,
                    note: note?.nilIfBlank
                )

                let response = try await MissionService.shared.getMissionTeamReport(
                    missionId: missionId,
                    missionTeamId: missionTeamId
                )
                apply(response)
                successMessage = "Đội đã được chuyển sang trạng thái chờ nộp báo cáo."
            } catch {
                errorMessage = "Không thể hoàn tất thực địa: \(error.localizedDescription)"
            }
        }
    }

    func saveDraft() {
        guard canEdit else { return }

        if let restriction = saveDraftRestrictionMessage {
            errorMessage = restriction
            return
        }

        errorMessage = nil
        successMessage = nil
        isSaving = true

        Task {
            defer { isSaving = false }

            do {
                let request = try makeDraftRequest()
                let response = try await MissionService.shared.saveMissionTeamReportDraft(
                    missionId: missionId,
                    missionTeamId: missionTeamId,
                    request: request
                )
                apply(response)
                successMessage = "Đã lưu nháp báo cáo đội."
            } catch {
                errorMessage = "Không thể lưu nháp báo cáo: \(error.localizedDescription)"
            }
        }
    }

    func submitReport() {
        guard canSubmit else { return }

        errorMessage = nil
        successMessage = nil
        isSubmitting = true

        Task {
            defer { isSubmitting = false }

            do {
                let request = try makeSubmitRequest()
                let response = try await MissionService.shared.submitMissionTeamReport(
                    missionId: missionId,
                    missionTeamId: missionTeamId,
                    request: request
                )
                apply(response)
                successMessage = "Đã nộp báo cáo cuối cùng."
            } catch {
                errorMessage = "Không thể nộp báo cáo: \(error.localizedDescription)"
            }
        }
    }

    private func apply(_ response: MissionTeamReportResponse) {
        report = response
        teamSummary = response.teamSummary ?? ""
        teamNote = response.teamNote ?? ""
        issuesJson = response.issuesJson ?? ""
        resultJson = response.resultJson ?? ""
        evidenceJson = response.evidenceJson ?? ""
        activities = response.activities.map(MissionTeamReportActivityForm.init(activity:))
        memberEvaluations = response.memberEvaluations.map { evaluation in
            var form = MissionTeamMemberEvaluationForm(evaluation: evaluation)

            if response.canEvaluateMembers {
                form.responseTimeScore = form.responseTimeScore ?? 5
                form.rescueEffectivenessScore = form.rescueEffectivenessScore ?? 5
                form.decisionHandlingScore = form.decisionHandlingScore ?? 5
                form.safetyMedicalSkillScore = form.safetyMedicalSkillScore ?? 5
                form.teamworkCommunicationScore = form.teamworkCommunicationScore ?? 5
            }

            return form
        }
    }

    private func makeDraftRequest() throws -> SaveMissionTeamReportDraftRequest {
        SaveMissionTeamReportDraftRequest(
            teamSummary: teamSummary.nilIfBlank,
            teamNote: teamNote.nilIfBlank,
            issuesJson: try normalizeJSON(issuesJson, fieldName: "Issues JSON", emptyValue: "{}"),
            resultJson: try normalizeJSON(resultJson, fieldName: "Result JSON", emptyValue: "{}"),
            evidenceJson: try normalizeJSON(evidenceJson, fieldName: "Evidence JSON", emptyValue: "[]"),
            activities: try buildDraftActivities(),
            memberEvaluations: try buildMemberEvaluationInputs(requireAllMembers: false)
        )
    }

    private func makeSubmitRequest() throws -> SubmitMissionTeamReportRequest {
        SubmitMissionTeamReportRequest(
            teamSummary: teamSummary.nilIfBlank,
            teamNote: teamNote.nilIfBlank,
            issuesJson: try normalizeJSON(issuesJson, fieldName: "Issues JSON", emptyValue: "{}"),
            resultJson: try normalizeJSON(resultJson, fieldName: "Result JSON", emptyValue: "{}"),
            evidenceJson: try normalizeJSON(evidenceJson, fieldName: "Evidence JSON", emptyValue: "[]"),
            activities: try buildSubmitActivities(),
            memberEvaluations: try buildMemberEvaluationInputs(requireAllMembers: true)
        )
    }

    private func buildDraftActivities() throws -> [MissionTeamReportDraftActivityItem] {
        try activities.map { activity in
            MissionTeamReportDraftActivityItem(
                missionActivityId: activity.missionActivityId,
                executionStatus: activity.executionStatus.nilIfBlank,
                summary: activity.summary.nilIfBlank,
                issuesJson: try normalizeJSON(activity.issuesJson, fieldName: "\(activity.title) - Issues JSON", emptyValue: "{}"),
                resultJson: try normalizeJSON(activity.resultJson, fieldName: "\(activity.title) - Result JSON", emptyValue: "{}"),
                evidenceJson: try normalizeJSON(activity.evidenceJson, fieldName: "\(activity.title) - Evidence JSON", emptyValue: "[]")
            )
        }
    }

    private func buildSubmitActivities() throws -> [MissionTeamReportSubmitActivityItem] {
        try activities.map { activity in
            MissionTeamReportSubmitActivityItem(
                missionActivityId: activity.missionActivityId,
                executionStatus: activity.executionStatus.nilIfBlank,
                summary: activity.summary.nilIfBlank,
                issuesJson: try normalizeJSON(activity.issuesJson, fieldName: "\(activity.title) - Issues JSON", emptyValue: "{}"),
                resultJson: try normalizeJSON(activity.resultJson, fieldName: "\(activity.title) - Result JSON", emptyValue: "{}"),
                evidenceJson: try normalizeJSON(activity.evidenceJson, fieldName: "\(activity.title) - Evidence JSON", emptyValue: "[]")
            )
        }
    }

    private func buildMemberEvaluationInputs(requireAllMembers: Bool) throws -> [MissionTeamMemberEvaluationInput] {
        if canEvaluateMembers == false {
            if memberEvaluations.contains(where: \.hasAnyScore) {
                throw MissionTeamReportValidationError.nonLeaderCannotSaveWithExistingEvaluations
            }

            return []
        }

        var inputs: [MissionTeamMemberEvaluationInput] = []

        for evaluation in memberEvaluations {
            if evaluation.hasAnyScore == false {
                if requireAllMembers {
                    throw MissionTeamReportValidationError.missingMemberEvaluation(evaluation.displayName)
                }

                continue
            }

            guard evaluation.hasCompleteScore else {
                throw MissionTeamReportValidationError.partialMemberEvaluation(evaluation.displayName)
            }

            inputs.append(
                MissionTeamMemberEvaluationInput(
                    rescuerId: evaluation.rescuerId,
                    responseTimeScore: evaluation.responseTimeScore ?? 0,
                    rescueEffectivenessScore: evaluation.rescueEffectivenessScore ?? 0,
                    decisionHandlingScore: evaluation.decisionHandlingScore ?? 0,
                    safetyMedicalSkillScore: evaluation.safetyMedicalSkillScore ?? 0,
                    teamworkCommunicationScore: evaluation.teamworkCommunicationScore ?? 0
                )
            )
        }

        return inputs
    }

    private func normalizeJSON(_ rawValue: String, fieldName: String, emptyValue: String) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? emptyValue : trimmed

        guard let data = source.data(using: .utf8) else {
            throw MissionTeamReportValidationError.invalidJSON(fieldName)
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [])
            let normalizedData = try JSONSerialization.data(withJSONObject: object, options: [])
            return String(data: normalizedData, encoding: .utf8) ?? source
        } catch {
            throw MissionTeamReportValidationError.invalidJSON(fieldName)
        }
    }
}

private enum MissionTeamReportValidationError: LocalizedError {
    case invalidJSON(String)
    case partialMemberEvaluation(String)
    case missingMemberEvaluation(String)
    case nonLeaderCannotSaveWithExistingEvaluations

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let field):
            return "\(field) không phải JSON hợp lệ."
        case .partialMemberEvaluation(let memberName):
            return "Hãy chấm đủ 5 tiêu chí cho \(memberName) hoặc xóa toàn bộ điểm đang nhập dở."
        case .missingMemberEvaluation(let memberName):
            return "Cần đánh giá đầy đủ cho \(memberName) trước khi nộp báo cáo."
        case .nonLeaderCannotSaveWithExistingEvaluations:
            return "Chỉ đội trưởng mới được lưu đánh giá thành viên. Vui lòng nhờ đội trưởng lưu báo cáo để tránh mất dữ liệu."
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedStatusKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }
}
