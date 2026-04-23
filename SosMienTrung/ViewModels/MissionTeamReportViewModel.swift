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
    @Published var teamStructuredPayload = MissionReportStructuredPayloadForm()
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
            return L10n.MissionTeamReport.nonLeaderDraftRestriction
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
                errorMessage = L10n.MissionTeamReport.cannotLoad(error.localizedDescription)
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
                successMessage = L10n.MissionTeamReport.waitingForSubmitStatus
            } catch {
                errorMessage = L10n.MissionTeamReport.cannotCompleteFieldWork(error.localizedDescription)
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
                successMessage = L10n.MissionTeamReport.draftSaved
            } catch {
                errorMessage = L10n.MissionTeamReport.cannotSaveDraft(error.localizedDescription)
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
                successMessage = L10n.MissionTeamReport.finalSubmitted
            } catch {
                errorMessage = L10n.MissionTeamReport.cannotSubmit(error.localizedDescription)
            }
        }
    }

    func fillDemoReportData() {
        guard canEdit else { return }
        guard reportStatus.normalizedStatusKey != "submitted" else { return }

        errorMessage = nil
        successMessage = nil

        let timestamp = MissionTeamReportDemoData.timestampLabel()
        let scenario = MissionTeamReportDemoData.scenario(
            forMissionId: missionId,
            activityIds: activities.map(\.missionActivityId),
            timestamp: timestamp
        )

        if let scenario {
            teamSummary = scenario.teamSummary
            teamNote = scenario.teamNote
            teamStructuredPayload = scenario.teamPayload
        } else {
            let activityTotal = max(activities.count, 1)
            let rescuedCount = max(activityTotal * 2, 2)
            let treatedCount = max(activityTotal, 1)
            let referredCount = activityTotal >= 3 ? 1 : 0

            teamSummary = "Đội đã hoàn thành nhiệm vụ và bàn giao hiện trường an toàn. Dữ liệu này được điền nhanh để demo luồng báo cáo."
            teamNote = "Mẫu demo tạo lúc \(timestamp). Vui lòng chỉnh lại nội dung thực tế trước khi gửi báo cáo chính thức."

            teamStructuredPayload = MissionReportStructuredPayloadForm(
                issueFlags: MissionReportIssueFlagsForm(
                    blockedRoad: activityTotal >= 3,
                    flooding: true,
                    landslide: activityTotal >= 4,
                    powerOutage: true,
                    communicationLoss: false,
                    unsafeArea: true,
                    medicalOverload: false
                ),
                issueExtras: [
                    MissionReportKeyValueEntry(key: "thoiTiet", value: "Mưa vừa, tầm nhìn hạn chế"),
                    MissionReportKeyValueEntry(key: "khuVuc", value: "Điểm tập kết trung tâm")
                ],
                resultMetrics: MissionReportResultMetricsForm(
                    rescued: "\(rescuedCount)",
                    treated: "\(treatedCount)",
                    referred: "\(referredCount)",
                    missing: "0",
                    fatalities: "0"
                ),
                resultExtras: [
                    MissionReportKeyValueEntry(key: "hoDaHoTro", value: "\(max(rescuedCount / 2, 1))"),
                    MissionReportKeyValueEntry(key: "thoiGianPhanUngPhut", value: "18")
                ],
                evidenceEntries: [
                    MissionReportEvidenceEntry(
                        type: "note",
                        url: "",
                        note: "Dữ liệu mẫu phục vụ demo nhanh biểu mẫu báo cáo đội cứu hộ."
                    )
                ]
            )
        }

        activities = activities.enumerated().map { index, activity in
            var updated = activity
            let step = index + 1
            let activityDemo = scenario?.activities[activity.missionActivityId]

            updated.executionStatus = demoExecutionStatus(for: activity)
            updated.summary = activityDemo?.summary
                ?? "Bước \(step) đã hoàn tất theo phương án điều phối, đội đã xác nhận kết quả tại hiện trường."
            updated.structuredPayload = MissionReportStructuredPayloadForm()
            updated.issuesJson = ""
            updated.resultJson = ""
            updated.evidenceJson = ""

            return updated
        }

        if canEvaluateMembers {
            memberEvaluations = memberEvaluations.enumerated().map { index, evaluation in
                var updated = evaluation
                let baseScore = demoMemberBaseScore(at: index)

                updated.responseTimeScore = baseScore
                updated.rescueEffectivenessScore = min(baseScore + 0.5, 10)
                updated.decisionHandlingScore = baseScore
                updated.safetyMedicalSkillScore = min(baseScore + 0.5, 10)
                updated.teamworkCommunicationScore = min(baseScore + 1.0, 10)

                return updated
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
        teamStructuredPayload = MissionReportJSONBridge.decodePayload(
            issuesJson: issuesJson,
            resultJson: resultJson,
            evidenceJson: evidenceJson
        )

        activities = response.activities.map { activity in
            var form = MissionTeamReportActivityForm(activity: activity)
            form.structuredPayload = MissionReportJSONBridge.decodePayload(
                issuesJson: form.issuesJson,
                resultJson: form.resultJson,
                evidenceJson: form.evidenceJson
            )
            return form
        }

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

    private func demoExecutionStatus(for activity: MissionTeamReportActivityForm) -> String {
        if let current = ReportExecutionStatusOption(apiValue: activity.executionStatus) {
            return current == .failed || current == .cancelled
                ? ReportExecutionStatusOption.completed.rawValue
                : current.rawValue
        }

        if let fallback = ReportExecutionStatusOption(apiValue: activity.activityStatus ?? "") {
            return fallback == .failed || fallback == .cancelled
                ? ReportExecutionStatusOption.completed.rawValue
                : fallback.rawValue
        }

        return ReportExecutionStatusOption.completed.rawValue
    }

    private func demoActivityPayload(step: Int) -> MissionReportStructuredPayloadForm {
        let isLogisticStep = step % 2 == 0

        return MissionReportStructuredPayloadForm(
            issueFlags: MissionReportIssueFlagsForm(
                blockedRoad: step % 3 == 0,
                flooding: true,
                landslide: step % 4 == 0,
                powerOutage: isLogisticStep,
                communicationLoss: false,
                unsafeArea: step % 5 == 0,
                medicalOverload: false
            ),
            issueExtras: [
                MissionReportKeyValueEntry(key: "phatSinh", value: "Bước \(step) gặp cản trở nhẹ")
            ],
            resultMetrics: MissionReportResultMetricsForm(
                rescued: isLogisticStep ? "1" : "2",
                treated: "1",
                referred: step % 4 == 0 ? "1" : "0",
                missing: "0",
                fatalities: "0"
            ),
            resultExtras: [
                MissionReportKeyValueEntry(key: "vatPhamBanGiao", value: isLogisticStep ? "12" : "6")
            ],
            evidenceEntries: [
                MissionReportEvidenceEntry(
                    type: "note",
                    url: "",
                    note: "Bước \(step): dữ liệu minh họa để demo luồng nhập báo cáo."
                )
            ]
        )
    }

    private func demoMemberBaseScore(at index: Int) -> Double {
        let rotation = index % 4
        switch rotation {
        case 0:
            return 7.5
        case 1:
            return 8.0
        case 2:
            return 8.5
        default:
            return 9.0
        }
    }

    private func makeDraftRequest() throws -> SaveMissionTeamReportDraftRequest {
        let teamPayloadJSON = try buildPayloadJSON(
            from: teamStructuredPayload,
            context: "Tổng quan đội"
        )

        issuesJson = teamPayloadJSON.issuesJson
        resultJson = teamPayloadJSON.resultJson
        evidenceJson = teamPayloadJSON.evidenceJson

        return SaveMissionTeamReportDraftRequest(
            teamSummary: teamSummary.nilIfBlank,
            teamNote: teamNote.nilIfBlank,
            issuesJson: teamPayloadJSON.issuesJson,
            resultJson: teamPayloadJSON.resultJson,
            evidenceJson: teamPayloadJSON.evidenceJson,
            activities: try buildDraftActivities(),
            memberEvaluations: try buildMemberEvaluationInputs(requireAllMembers: false)
        )
    }

    private func makeSubmitRequest() throws -> SubmitMissionTeamReportRequest {
        try validateDeliveryShortfallReasonsForSubmit()

        let teamPayloadJSON = try buildPayloadJSON(
            from: teamStructuredPayload,
            context: "Tổng quan đội"
        )

        issuesJson = teamPayloadJSON.issuesJson
        resultJson = teamPayloadJSON.resultJson
        evidenceJson = teamPayloadJSON.evidenceJson

        return SubmitMissionTeamReportRequest(
            teamSummary: teamSummary.nilIfBlank,
            teamNote: teamNote.nilIfBlank,
            issuesJson: teamPayloadJSON.issuesJson,
            resultJson: teamPayloadJSON.resultJson,
            evidenceJson: teamPayloadJSON.evidenceJson,
            activities: try buildSubmitActivities(),
            memberEvaluations: try buildMemberEvaluationInputs(requireAllMembers: true)
        )
    }

    private func buildDraftActivities() throws -> [MissionTeamReportDraftActivityItem] {
        try activities.map { activity in
            let payloadJSON = try buildPayloadJSON(
                from: activity.structuredPayload,
                context: activity.title
            )

            return MissionTeamReportDraftActivityItem(
                missionActivityId: activity.missionActivityId,
                executionStatus: activity.executionStatus.nilIfBlank,
                summary: activity.summary.nilIfBlank,
                issuesJson: payloadJSON.issuesJson,
                resultJson: payloadJSON.resultJson,
                evidenceJson: payloadJSON.evidenceJson
            )
        }
    }

    private func validateDeliveryShortfallReasonsForSubmit() throws {
        if let activity = activities.first(where: \.needsDeliveryShortfallReason) {
            throw MissionTeamReportValidationError.missingDeliveryShortfallReason(activity.title)
        }
    }

    private func buildSubmitActivities() throws -> [MissionTeamReportSubmitActivityItem] {
        try activities.map { activity in
            let payloadJSON = try buildPayloadJSON(
                from: activity.structuredPayload,
                context: activity.title
            )

            return MissionTeamReportSubmitActivityItem(
                missionActivityId: activity.missionActivityId,
                executionStatus: activity.executionStatus.nilIfBlank,
                summary: activity.summary.nilIfBlank,
                issuesJson: payloadJSON.issuesJson,
                resultJson: payloadJSON.resultJson,
                evidenceJson: payloadJSON.evidenceJson
            )
        }
    }

    private func buildPayloadJSON(
        from payload: MissionReportStructuredPayloadForm,
        context: String
    ) throws -> (issuesJson: String, resultJson: String, evidenceJson: String) {
        let encoded = MissionReportJSONBridge.encodePayload(payload)

        return (
            issuesJson: try normalizeJSON(
                encoded.issuesJson,
                fieldName: "\(context) - dữ liệu sự cố",
                emptyValue: "{}"
            ),
            resultJson: try normalizeJSON(
                encoded.resultJson,
                fieldName: "\(context) - dữ liệu kết quả",
                emptyValue: "{}"
            ),
            evidenceJson: try normalizeJSON(
                encoded.evidenceJson,
                fieldName: "\(context) - dữ liệu bằng chứng",
                emptyValue: "[]"
            )
        )
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

private enum MissionReportJSONBridge {
    static func decodePayload(
        issuesJson: String,
        resultJson: String,
        evidenceJson: String
    ) -> MissionReportStructuredPayloadForm {
        var form = MissionReportStructuredPayloadForm()

        let issuesObject = decodeJSONObject(from: issuesJson)
        for (key, value) in issuesObject {
            if applyIssueFlag(value, for: key, to: &form.issueFlags) {
                continue
            }

            let valueLabel = scalarString(from: value)
            if valueLabel.isEmpty == false {
                form.issueExtras.append(
                    MissionReportKeyValueEntry(key: key, value: valueLabel)
                )
            }
        }

        let resultObject = decodeJSONObject(from: resultJson)
        for (key, value) in resultObject {
            if applyResultMetric(value, for: key, to: &form.resultMetrics) {
                continue
            }

            let valueLabel = scalarString(from: value)
            if valueLabel.isEmpty == false {
                form.resultExtras.append(
                    MissionReportKeyValueEntry(key: key, value: valueLabel)
                )
            }
        }

        let evidenceArray = decodeJSONArray(from: evidenceJson)
        form.evidenceEntries = evidenceArray.compactMap { raw in
            if let object = raw as? [String: Any] {
                let type = scalarString(from: object["type"] ?? "")
                let url = scalarString(from: object["url"] ?? object["link"] ?? "")
                let note = scalarString(from: object["note"] ?? object["description"] ?? "")

                guard type.isEmpty == false || url.isEmpty == false || note.isEmpty == false else {
                    return nil
                }

                return MissionReportEvidenceEntry(
                    type: type.isEmpty ? "image" : type,
                    url: url,
                    note: note
                )
            }

            let value = scalarString(from: raw)
            guard value.isEmpty == false else { return nil }

            return MissionReportEvidenceEntry(type: "note", url: "", note: value)
        }

        form.issueExtras.sort { lhs, rhs in
            lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
        }
        form.resultExtras.sort { lhs, rhs in
            lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
        }

        return form
    }

    static func encodePayload(_ payload: MissionReportStructuredPayloadForm) -> (
        issuesJson: String,
        resultJson: String,
        evidenceJson: String
    ) {
        var issueObject: [String: Any] = [:]

        if payload.issueFlags.blockedRoad {
            issueObject["blockedRoad"] = true
        }
        if payload.issueFlags.flooding {
            issueObject["flooding"] = true
        }
        if payload.issueFlags.landslide {
            issueObject["landslide"] = true
        }
        if payload.issueFlags.powerOutage {
            issueObject["powerOutage"] = true
        }
        if payload.issueFlags.communicationLoss {
            issueObject["communicationLoss"] = true
        }
        if payload.issueFlags.unsafeArea {
            issueObject["unsafeArea"] = true
        }
        if payload.issueFlags.medicalOverload {
            issueObject["medicalOverload"] = true
        }

        for entry in payload.issueExtras {
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.isEmpty == false, value.isEmpty == false else { continue }
            issueObject[key] = typedValue(from: value)
        }

        var resultObject: [String: Any] = [:]
        appendMetric(payload.resultMetrics.rescued, key: "rescued", to: &resultObject)
        appendMetric(payload.resultMetrics.treated, key: "treated", to: &resultObject)
        appendMetric(payload.resultMetrics.referred, key: "referred", to: &resultObject)
        appendMetric(payload.resultMetrics.missing, key: "missing", to: &resultObject)
        appendMetric(payload.resultMetrics.fatalities, key: "fatalities", to: &resultObject)

        for entry in payload.resultExtras {
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.isEmpty == false, value.isEmpty == false else { continue }
            resultObject[key] = typedValue(from: value)
        }

        let evidenceArray: [[String: Any]] = payload.evidenceEntries.compactMap { entry in
            let type = entry.type.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = entry.url.trimmingCharacters(in: .whitespacesAndNewlines)
            let note = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)

            guard type.isEmpty == false || url.isEmpty == false || note.isEmpty == false else {
                return nil
            }

            var object: [String: Any] = [
                "type": type.isEmpty ? "image" : type
            ]

            if url.isEmpty == false {
                object["url"] = url
            }

            if note.isEmpty == false {
                object["note"] = note
            }

            return object
        }

        return (
            issuesJson: encodeJSONObject(issueObject) ?? "{}",
            resultJson: encodeJSONObject(resultObject) ?? "{}",
            evidenceJson: encodeJSONArray(evidenceArray) ?? "[]"
        )
    }

    private static func appendMetric(_ rawValue: String, key: String, to object: inout [String: Any]) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        object[key] = typedValue(from: trimmed)
    }

    private static func applyIssueFlag(
        _ value: Any,
        for rawKey: String,
        to flags: inout MissionReportIssueFlagsForm
    ) -> Bool {
        switch normalizedJSONKey(rawKey) {
        case "blockedroad", "roadblocked":
            flags.blockedRoad = boolValue(from: value)
            return true
        case "flood", "flooding", "ngap", "ngaplut", "inundation":
            flags.flooding = boolValue(from: value)
            return true
        case "landslide", "satlo":
            flags.landslide = boolValue(from: value)
            return true
        case "poweroutage", "powerdown", "matdien", "electricityoutage":
            flags.powerOutage = boolValue(from: value)
            return true
        case "communicationloss", "communicationlost", "matlienlac", "networkdown":
            flags.communicationLoss = boolValue(from: value)
            return true
        case "unsafearea", "dangerzone":
            flags.unsafeArea = boolValue(from: value)
            return true
        case "medicaloverload", "medicalcapacityoverload", "quataiyte":
            flags.medicalOverload = boolValue(from: value)
            return true
        default:
            return false
        }
    }

    private static func applyResultMetric(
        _ value: Any,
        for rawKey: String,
        to metrics: inout MissionReportResultMetricsForm
    ) -> Bool {
        let key = normalizedJSONKey(rawKey)
        let valueLabel = scalarString(from: value)

        switch key {
        case "rescued", "rescue", "rescuedvictims", "victimsrescued":
            metrics.rescued = valueLabel
            return true
        case "treated", "treatment", "medicallytreated":
            metrics.treated = valueLabel
            return true
        case "referred", "transferred", "hospitalreferred":
            metrics.referred = valueLabel
            return true
        case "missing", "missingpersons":
            metrics.missing = valueLabel
            return true
        case "fatalities", "fatality", "deaths", "death":
            metrics.fatalities = valueLabel
            return true
        default:
            return false
        }
    }

    private static func decodeJSONObject(from raw: String) -> [String: Any] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = object as? [String: Any]
        else {
            return [:]
        }

        return dictionary
    }

    private static func decodeJSONArray(from raw: String) -> [Any] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let array = object as? [Any]
        else {
            return []
        }

        return array
    }

    private static func encodeJSONObject(_ object: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static func encodeJSONArray(_ object: [[String: Any]]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static func boolValue(from raw: Any) -> Bool {
        if let bool = raw as? Bool {
            return bool
        }

        if let number = raw as? NSNumber {
            return number.doubleValue != 0
        }

        if let string = raw as? String {
            let normalized = string
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            return ["true", "1", "yes", "co", "có"].contains(normalized)
        }

        return false
    }

    private static func scalarString(from value: Any) -> String {
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let number = value as? NSNumber {
            let doubleValue = number.doubleValue
            if doubleValue.rounded() == doubleValue {
                return String(Int(doubleValue))
            }

            return String(format: "%.2f", doubleValue)
        }

        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }

        if let array = value as? [Any],
           let data = try? JSONSerialization.data(withJSONObject: array, options: []),
           let json = String(data: data, encoding: .utf8) {
            return json
        }

        if let object = value as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: object, options: []),
           let json = String(data: data, encoding: .utf8) {
            return json
        }

        return ""
    }

    private static func typedValue(from raw: String) -> Any {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        if lowered == "true" {
            return true
        }

        if lowered == "false" {
            return false
        }

        if let intValue = Int(trimmed) {
            return intValue
        }

        if let doubleValue = Double(trimmed) {
            return doubleValue
        }

        if let data = trimmed.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data, options: []),
           (object is [Any] || object is [String: Any]) {
            return object
        }

        return trimmed
    }

    private static func normalizedJSONKey(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}

private enum MissionTeamReportValidationError: LocalizedError {
    case invalidJSON(String)
    case partialMemberEvaluation(String)
    case missingMemberEvaluation(String)
    case missingDeliveryShortfallReason(String)
    case nonLeaderCannotSaveWithExistingEvaluations

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let field):
            return L10n.MissionTeamReport.invalidJSON(field)
        case .partialMemberEvaluation(let memberName):
            return L10n.MissionTeamReport.partialMemberEvaluation(memberName)
        case .missingMemberEvaluation(let memberName):
            return L10n.MissionTeamReport.missingMemberEvaluation(memberName)
        case .missingDeliveryShortfallReason(let activityName):
            return L10n.MissionTeamReport.missingDeliveryShortfallReason(activityName)
        case .nonLeaderCannotSaveWithExistingEvaluations:
            return L10n.MissionTeamReport.nonLeaderCannotSaveEvaluations
        }
    }
}

private struct MissionTeamReportDemoScenario {
    let teamSummary: String
    let teamNote: String
    let teamPayload: MissionReportStructuredPayloadForm
    let activities: [Int: MissionTeamReportDemoActivity]
}

private struct MissionTeamReportDemoActivity {
    let summary: String
    let payload: MissionReportStructuredPayloadForm
}

private enum MissionTeamReportDemoData {
    static func timestampLabel() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm dd/MM/yyyy"
        return formatter.string(from: Date())
    }

    static func scenario(
        forMissionId missionId: Int,
        activityIds: [Int],
        timestamp: String
    ) -> MissionTeamReportDemoScenario? {
        guard isHueMixedRouteDemoMission(missionId: missionId, activityIds: activityIds) else {
            return nil
        }

        return hueMixedRouteScenario(timestamp: timestamp)
    }

    private static func isHueMixedRouteDemoMission(missionId: Int, activityIds: [Int]) -> Bool {
        let hueRouteActivityIds = Set(421...430)
        let matchingActivityCount = Set(activityIds).intersection(hueRouteActivityIds).count

        return missionId == 101 || matchingActivityCount >= 6
    }

    private static func hueMixedRouteScenario(timestamp: String) -> MissionTeamReportDemoScenario {
        MissionTeamReportDemoScenario(
            teamSummary: "Đội Hường đã xử lý mission mixed #101 tại cụm #111: tiếp nhận vật phẩm ở kho Uỷ Ban MTTQVN Tỉnh Thừa Thiên Huế, phân phát cho SOS #361 và SOS #7, cứu hộ/y tế cho nhóm ưu tiên, sơ tán 7 người về điểm an toàn, trả 3 nước dừa và áo phao LIFEJACKET-D01-003 về kho. Bước quay về điểm tập kết là chặng cuối của đội.",
            teamNote: "Dữ liệu demo tạo lúc \(timestamp). Nội dung bám theo mission #101 ngày 22/04/2026: Đội Hường hoàn tất các bước cứu trợ, cứu hộ, y tế, sơ tán và hoàn trả vật phẩm trước khi quay về Sân vận động Tự Do để bàn giao.",
            teamPayload: MissionReportStructuredPayloadForm(
                issueFlags: MissionReportIssueFlagsForm(
                    blockedRoad: true,
                    flooding: true,
                    landslide: false,
                    powerOutage: false,
                    communicationLoss: false,
                    unsafeArea: true,
                    medicalOverload: false
                ),
                issueExtras: [
                    MissionReportKeyValueEntry(key: "missionId", value: "101"),
                    MissionReportKeyValueEntry(key: "clusterId", value: "111"),
                    MissionReportKeyValueEntry(key: "doiThucHien", value: "Đội Hường"),
                    MissionReportKeyValueEntry(key: "khuVuc", value: "TP. Huế - SOS #361 và SOS #7"),
                    MissionReportKeyValueEntry(key: "khoVatPham", value: "Uỷ Ban MTTQVN Tỉnh Thừa Thiên Huế, 46 Đống Đa"),
                    MissionReportKeyValueEntry(key: "diemTapKet", value: "Sân vận động Tự Do (Thừa Thiên Huế)"),
                    MissionReportKeyValueEntry(key: "canhBao", value: "Nước lên nhanh; SOS #361 có người gãy xương, mất nhiệt và trẻ lạc người thân")
                ],
                resultMetrics: metrics(rescued: 7, treated: 5, referred: 1),
                resultExtras: [
                    MissionReportKeyValueEntry(key: "sosDaXuLy", value: "361, 7"),
                    MissionReportKeyValueEntry(key: "vatPhamDaNhan", value: "Nước dừa x14; Nước khoáng 500ml x14; Nước tinh khiết x14; Viên lọc nước x14; Áo phao LIFEJACKET-D01-003 x1"),
                    MissionReportKeyValueEntry(key: "vatPhamDaGiao", value: "53 đơn vị tiêu hao (SOS #361: 24; SOS #7: 29)"),
                    MissionReportKeyValueEntry(key: "vatPhamHoanTra", value: "Nước dừa đóng hộp x3; Áo phao cứu sinh LIFEJACKET-D01-003 x1"),
                    MissionReportKeyValueEntry(key: "trangThaiCuoi", value: "Đã cứu hộ, y tế, sơ tán và hoàn trả vật phẩm; còn bước quay về điểm tập kết")
                ],
                evidenceEntries: [
                    MissionReportEvidenceEntry(
                        type: "note",
                        url: "",
                        note: "Báo cáo demo tổng hợp từ mission #101: hoàn thành cứu trợ SOS #361/#7, bàn giao y tế, sơ tán nhóm 7 người và hoàn trả vật phẩm dư."
                    )
                ]
            ),
            activities: [
                421: activity(
                    summary: "Đội Hường tiếp nhận vật phẩm tại kho Uỷ Ban MTTQVN Tỉnh Thừa Thiên Huế: nước dừa x14, nước khoáng 500ml x14, nước tinh khiết x14, viên lọc nước khẩn cấp x14 và áo phao LIFEJACKET-D01-003 x1. Đã kiểm tra lô/hạn dùng và sẵn sàng phân phát.",
                    issueFlags: MissionReportIssueFlagsForm(),
                    issueExtras: [
                        MissionReportKeyValueEntry(key: "kho", value: "Uỷ Ban MTTQVN Tỉnh Thừa Thiên Huế"),
                        MissionReportKeyValueEntry(key: "diaChi", value: "46 Đống Đa, TP. Huế"),
                        MissionReportKeyValueEntry(key: "thoiGianHoanTatUTC", value: "2026-04-22T05:30:25Z")
                    ],
                    resultMetrics: metrics(),
                    resultExtras: [
                        MissionReportKeyValueEntry(key: "vatPhamTieuHaoDaNhan", value: "56"),
                        MissionReportKeyValueEntry(key: "thietBiReusableDaNhan", value: "Áo phao LIFEJACKET-D01-003")
                    ],
                    evidenceNote: "Ảnh/biên nhận kho có thể đính kèm cho bước tiếp nhận vật phẩm."
                ),
                422: activity(
                    summary: "Đã phân phát ưu tiên cho SOS #361 trước khi cứu hộ: mỗi loại 6 đơn vị gồm nước dừa, nước khoáng 500ml, nước tinh khiết và viên lọc nước khẩn cấp. Tổng giao 24 đơn vị, còn 8 đơn vị mỗi loại để xử lý SOS #7.",
                    issueFlags: routeIssueFlags(),
                    issueExtras: [
                        MissionReportKeyValueEntry(key: "sosRequestId", value: "361"),
                        MissionReportKeyValueEntry(key: "diaChi", value: "2 Trần Hưng Đạo, Phú Hòa, Thành phố Huế"),
                        MissionReportKeyValueEntry(key: "uuTien", value: "Giao nhanh trước khi xử lý ca gãy xương, trẻ lạc người thân và người già mất nhiệt")
                    ],
                    resultMetrics: metrics(),
                    resultExtras: [
                        MissionReportKeyValueEntry(key: "tongVatPhamDaGiao", value: "24"),
                        MissionReportKeyValueEntry(key: "chiTiet", value: "4 mặt hàng x6 đơn vị")
                    ],
                    evidenceNote: "Ghi nhận bàn giao vật phẩm cho SOS #361."
                ),
                423: activity(
                    summary: "Đội tiếp cận SOS #361 và hỗ trợ 3 nạn nhân ưu tiên: Khoa bị gãy xương/không thể di chuyển/mất phương hướng, Thảo là trẻ em lạc người thân, Người già 1 có nguy cơ mất nhiệt. Khu vực đã được kiểm soát để chuyển sang sơ cứu.",
                    issueFlags: routeIssueFlags(),
                    issueExtras: [
                        MissionReportKeyValueEntry(key: "sosRequestId", value: "361"),
                        MissionReportKeyValueEntry(key: "nanNhanUuTien", value: "Khoa; Thảo; Người già 1"),
                        MissionReportKeyValueEntry(key: "nguyCo", value: "Gãy xương, hạ thân nhiệt, trẻ lạc người thân")
                    ],
                    resultMetrics: metrics(rescued: 3),
                    resultExtras: [
                        MissionReportKeyValueEntry(key: "nguoiLon", value: "1"),
                        MissionReportKeyValueEntry(key: "treEm", value: "1"),
                        MissionReportKeyValueEntry(key: "nguoiGia", value: "1")
                    ],
                    evidenceNote: "Ghi nhận tiếp cận và phân loại nhanh nhóm nạn nhân SOS #361."
                ),
                424: activity(
                    summary: "Đã cố định gãy xương cho Khoa, xử trí nguy cơ hạ thân nhiệt, kiểm tra bệnh nền/người già và ổn định trẻ Thảo trước khi di chuyển. Khoa cần bàn giao y tế để theo dõi gãy xương và tình trạng lú lẫn.",
                    issueFlags: routeIssueFlags(),
                    issueExtras: [
                        MissionReportKeyValueEntry(key: "sosRequestId", value: "361"),
                        MissionReportKeyValueEntry(key: "canThiepYTe", value: "Cố định gãy xương; giữ ấm; ổn định trẻ em; kiểm tra dấu hiệu sinh tồn"),
                        MissionReportKeyValueEntry(key: "caCanBanGiao", value: "Khoa")
                    ],
                    resultMetrics: metrics(treated: 3, referred: 1),
                    resultExtras: [
                        MissionReportKeyValueEntry(key: "benhNhanTheoDoi", value: "Khoa - gãy xương/mất phương hướng"),
                        MissionReportKeyValueEntry(key: "treEmOnDinh", value: "Thảo")
                    ],
                    evidenceNote: "Ghi nhận xử trí y tế tại SOS #361 trước khi sơ tán."
                ),
                425: activity(
                    summary: "Đã phân phát phần vật phẩm còn lại cho SOS #7: nước khoáng 500ml x8, nước tinh khiết x8, viên lọc nước khẩn cấp x8 và nước dừa x5. Thiếu 3 nước dừa so với kế hoạch do nhu cầu thực nhận thấp hơn sau đánh giá tại hiện trường; 3 đơn vị này được giữ nguyên và hoàn trả kho ở bước 9.",
                    issueFlags: routeIssueFlags(),
                    issueExtras: [
                        MissionReportKeyValueEntry(key: "sosRequestId", value: "7"),
                        MissionReportKeyValueEntry(key: "toaDo", value: "16.471658, 107.595076"),
                        MissionReportKeyValueEntry(key: "lyDoGiaoThieu", value: "3 nước dừa không sử dụng tại SOS #7, hoàn trả kho ở bước 9")
                    ],
                    resultMetrics: metrics(),
                    resultExtras: [
                        MissionReportKeyValueEntry(key: "tongVatPhamDaGiao", value: "29"),
                        MissionReportKeyValueEntry(key: "nuocDuaDaGiao", value: "5"),
                        MissionReportKeyValueEntry(key: "nuocDuaHoanTra", value: "3"),
                        MissionReportKeyValueEntry(key: "matHangGiaoDu", value: "Nước khoáng x8; Nước tinh khiết x8; Viên lọc nước x8")
                    ],
                    evidenceNote: "Ghi nhận bàn giao vật phẩm SOS #7 và lý do giao thiếu nước dừa."
                ),
                426: activity(
                    summary: "Đội tiếp cận SOS #7, hỗ trợ nhóm nạn nhân khi nước đang lên nhanh, ưu tiên người già không thể di chuyển và người bị thương nhẹ. Nhóm được đưa ra khỏi vị trí nguy hiểm để chuẩn bị sơ cứu và sơ tán.",
                    issueFlags: routeIssueFlags(),
                    issueExtras: [
                        MissionReportKeyValueEntry(key: "sosRequestId", value: "7"),
                        MissionReportKeyValueEntry(key: "nguyCo", value: "Nước lên nhanh; có người già hạn chế di chuyển và người bị thương nhẹ")
                    ],
                    resultMetrics: metrics(rescued: 4),
                    resultExtras: [
                        MissionReportKeyValueEntry(key: "nhomSos7HoTro", value: "4"),
                        MissionReportKeyValueEntry(key: "uuTien", value: "Người già không thể di chuyển")
                    ],
                    evidenceNote: "Ghi nhận tiếp cận và di chuyển nhóm SOS #7 khỏi khu vực nguy hiểm."
                ),
                427: activity(
                    summary: "Đã sơ cứu người bị thương nhẹ tại SOS #7 và kiểm tra dấu hiệu sinh tồn của người già trước khi sơ tán. Không ghi nhận ca tử vong hoặc mất tích; nhóm đủ điều kiện di chuyển về điểm an toàn.",
                    issueFlags: routeIssueFlags(),
                    issueExtras: [
                        MissionReportKeyValueEntry(key: "sosRequestId", value: "7"),
                        MissionReportKeyValueEntry(key: "canThiepYTe", value: "Sơ cứu vết thương nhẹ; kiểm tra dấu hiệu sinh tồn người già")
                    ],
                    resultMetrics: metrics(treated: 2),
                    resultExtras: [
                        MissionReportKeyValueEntry(key: "nguoiBiThuongNhe", value: "1"),
                        MissionReportKeyValueEntry(key: "nguoiGiaKiemTra", value: "1")
                    ],
                    evidenceNote: "Ghi nhận sơ cứu và đánh giá ổn định trước sơ tán SOS #7."
                ),
                428: activity(
                    summary: "Đội sơ tán toàn bộ nhóm 7 người về điểm an toàn, bàn giao ca y tế cần theo dõi và ghi nhận nhu cầu cứu trợ bổ sung để tạo mission RELIEF riêng.",
                    issueFlags: routeIssueFlags(),
                    issueExtras: [
                        MissionReportKeyValueEntry(key: "diemAnToan", value: "16.4706395, 107.593927"),
                        MissionReportKeyValueEntry(key: "banGiaoYTe", value: "Có"),
                        MissionReportKeyValueEntry(key: "deXuatTachRelief", value: "Có")
                    ],
                    resultMetrics: metrics(rescued: 7, referred: 1),
                    resultExtras: [
                        MissionReportKeyValueEntry(key: "soNguoiSoTan", value: "7"),
                        MissionReportKeyValueEntry(key: "nhuCauReliefRieng", value: "Ghi nhận sau sơ tán")
                    ],
                    evidenceNote: "Ghi nhận bàn giao nhóm 7 người tại điểm an toàn."
                ),
                429: activity(
                    summary: "Đã trả vật phẩm còn lại về kho: nước dừa đóng hộp x3 và áo phao cứu sinh LIFEJACKET-D01-003 x1. Tình trạng áo phao còn Good, tồn kho tiêu hao/reusable đã được cập nhật theo bàn giao.",
                    issueFlags: MissionReportIssueFlagsForm(),
                    issueExtras: [
                        MissionReportKeyValueEntry(key: "khoNhanLai", value: "Uỷ Ban MTTQVN Tỉnh Thừa Thiên Huế"),
                        MissionReportKeyValueEntry(key: "thoiGianHoanTatUTC", value: "2026-04-22T05:39:31Z")
                    ],
                    resultMetrics: metrics(),
                    resultExtras: [
                        MissionReportKeyValueEntry(key: "nuocDuaHoanTra", value: "3"),
                        MissionReportKeyValueEntry(key: "aoPhaoHoanTra", value: "LIFEJACKET-D01-003"),
                        MissionReportKeyValueEntry(key: "tinhTrangAoPhao", value: "Good")
                    ],
                    evidenceNote: "Ghi nhận hoàn trả vật phẩm tiêu hao còn lại và thiết bị reusable."
                ),
                430: activity(
                    summary: "Đội Hường quay về điểm tập kết Sân vận động Tự Do (Thừa Thiên Huế), hoàn tất bàn giao thông tin hiện trường, trạng thái vật phẩm và các ca cần theo dõi. Đây là bước cuối để đóng mission sau khi đội cập nhật vị trí tại điểm tập kết.",
                    issueFlags: MissionReportIssueFlagsForm(
                        blockedRoad: true,
                        flooding: true,
                        landslide: false,
                        powerOutage: false,
                        communicationLoss: false,
                        unsafeArea: false,
                        medicalOverload: false
                    ),
                    issueExtras: [
                        MissionReportKeyValueEntry(key: "diemTapKet", value: "Sân vận động Tự Do (Thừa Thiên Huế)"),
                        MissionReportKeyValueEntry(key: "toaDoDiemTapKet", value: "16.46751083681696, 107.59761456770599"),
                        MissionReportKeyValueEntry(key: "trangThai", value: "Chặng cuối quay về điểm tập kết")
                    ],
                    resultMetrics: metrics(),
                    resultExtras: [
                        MissionReportKeyValueEntry(key: "banGiaoThongTinHienTruong", value: "Có"),
                        MissionReportKeyValueEntry(key: "banGiaoTrangThaiVatPham", value: "Có")
                    ],
                    evidenceNote: "Ghi nhận bàn giao cuối tại điểm tập kết của đội."
                )
            ]
        )
    }

    private static func activity(
        summary: String,
        issueFlags: MissionReportIssueFlagsForm,
        issueExtras: [MissionReportKeyValueEntry],
        resultMetrics: MissionReportResultMetricsForm,
        resultExtras: [MissionReportKeyValueEntry],
        evidenceNote: String
    ) -> MissionTeamReportDemoActivity {
        MissionTeamReportDemoActivity(
            summary: summary,
            payload: MissionReportStructuredPayloadForm(
                issueFlags: issueFlags,
                issueExtras: issueExtras,
                resultMetrics: resultMetrics,
                resultExtras: resultExtras,
                evidenceEntries: [
                    MissionReportEvidenceEntry(type: "note", url: "", note: evidenceNote)
                ]
            )
        )
    }

    private static func metrics(
        rescued: Int = 0,
        treated: Int = 0,
        referred: Int = 0,
        missing: Int = 0,
        fatalities: Int = 0
    ) -> MissionReportResultMetricsForm {
        MissionReportResultMetricsForm(
            rescued: "\(rescued)",
            treated: "\(treated)",
            referred: "\(referred)",
            missing: "\(missing)",
            fatalities: "\(fatalities)"
        )
    }

    private static func routeIssueFlags() -> MissionReportIssueFlagsForm {
        MissionReportIssueFlagsForm(
            blockedRoad: true,
            flooding: true,
            landslide: false,
            powerOutage: false,
            communicationLoss: false,
            unsafeArea: true,
            medicalOverload: false
        )
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
