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
    case nonLeaderCannotSaveWithExistingEvaluations

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let field):
            return L10n.MissionTeamReport.invalidJSON(field)
        case .partialMemberEvaluation(let memberName):
            return L10n.MissionTeamReport.partialMemberEvaluation(memberName)
        case .missingMemberEvaluation(let memberName):
            return L10n.MissionTeamReport.missingMemberEvaluation(memberName)
        case .nonLeaderCannotSaveWithExistingEvaluations:
            return L10n.MissionTeamReport.nonLeaderCannotSaveEvaluations
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
