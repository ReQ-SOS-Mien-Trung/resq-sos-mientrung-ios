import Foundation
import SwiftUI

struct MissionTeamReportView: View {
    let missionTitle: String

    @StateObject private var vm: MissionTeamReportViewModel
    @State private var completionNote = ""

    init(missionId: Int, missionTeamId: Int, missionTitle: String) {
        self.missionTitle = missionTitle
        _vm = StateObject(wrappedValue: MissionTeamReportViewModel(
            missionId: missionId,
            missionTeamId: missionTeamId
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerCard
                    .padding(.top, DS.Spacing.md)

                if let restriction = vm.saveDraftRestrictionMessage {
                    warningCard(message: restriction)
                }

                if vm.canCompleteExecution {
                    completeExecutionSection
                }

                overviewSection
                jsonSection
                activitiesSection

                if vm.memberEvaluations.isEmpty == false {
                    evaluationsSection
                }

                actionSection

                Spacer(minLength: 80)
            }
            .padding(.horizontal, DS.Spacing.md)
        }
        .background(DS.Colors.background)
        .navigationTitle("Bao cao doi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    vm.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .foregroundColor(DS.Colors.warning)
                .disabled(vm.isLoading || vm.isSaving || vm.isSubmitting || vm.isCompletingExecution)
            }
        }
        .overlay {
            if vm.isLoading && vm.report == nil {
                loadingOverlay
            }
        }
        .alert("Loi", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Thong bao", isPresented: Binding(
            get: { vm.successMessage != nil },
            set: { if !$0 { vm.successMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.successMessage = nil }
        } message: {
            Text(vm.successMessage ?? "")
        }
        .onAppear {
            if vm.report == nil {
                vm.load()
            }
        }
    }

    private var headerCard: some View {
        SharpCardView(borderColor: DS.Colors.warning.opacity(0.35), backgroundColor: DS.Colors.surface) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        EyebrowLabel(text: "BAO CAO THUC DIA")
                        Text(missionTitle)
                            .font(DS.Typography.headline)
                            .foregroundColor(DS.Colors.text)
                    }

                    Spacer()
                }

                HStack(spacing: DS.Spacing.xs) {
                    StatusBadge(
                        text: vm.executionStatus.isEmpty ? "Chua xac dinh" : vm.executionStatus,
                        color: executionStatusColor(vm.executionStatus)
                    )

                    StatusBadge(
                        text: vm.reportStatus,
                        color: reportStatusColor(vm.reportStatus)
                    )
                }

                statusSummary

                EditorialDivider(height: DS.Border.thin)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    reportMetaRow(label: "Bat dau", value: vm.report?.startedAt)
                    reportMetaRow(label: "Chinh sua gan nhat", value: vm.report?.lastEditedAt)
                    reportMetaRow(label: "Da nop", value: vm.report?.submittedAt)
                }
            }
        }
    }

    @ViewBuilder
    private var statusSummary: some View {
        if vm.reportStatus.normalizedStatusKey == "submitted" {
            Text("Bao cao da duoc nop. Man hinh hien tai chi con che do xem.")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.success)
        } else if vm.canEvaluateMembers {
            Text("Ban dang o vai tro doi truong. Co the danh gia thanh vien va nop bao cao khi du dieu kien.")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
        } else if vm.canEdit {
            Text("Ban co the chinh sua phan chung cua bao cao. Danh gia thanh vien chi doi truong moi duoc luu.")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
        } else {
            Text("Bao cao hien khong o trang thai cho phep chinh sua.")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
        }
    }

    private var completeExecutionSection: some View {
        SharpCardView(borderColor: DS.Colors.success.opacity(0.35), backgroundColor: DS.Colors.surface) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Text("HOAN THANH THUC DIA")
                        .font(DS.Typography.caption)
                        .tracking(1)
                        .foregroundColor(DS.Colors.textSecondary)
                    Spacer()
                    StatusBadge(text: vm.executionStatus, color: executionStatusColor(vm.executionStatus))
                }

                Text("Sau buoc nay, team chuyen sang trang thai cho nop bao cao cuoi.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)

                MissionReportTextEditor(
                    title: "Ghi chu hoan tat",
                    text: $completionNote,
                    placeholder: "Duong vao bi ngap, da dua nan nhan den khu an toan...",
                    caption: "Ghi chu nay di kem voi buoc hoan tat thuc dia cua doi.",
                    isEditable: true,
                    minHeight: 96
                )

                Button {
                    vm.completeExecution(note: completionNote)
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        if vm.isCompletingExecution {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                        }

                        Text("HOAN THANH THUC DIA")
                            .font(DS.Typography.headline)
                            .tracking(1)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.success)
                    .overlay(Rectangle().stroke(DS.Colors.success.opacity(0.3), lineWidth: 1))
                }
                .disabled(vm.isCompletingExecution || vm.isLoading || vm.isSaving || vm.isSubmitting)
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("TONG QUAN DOI").sectionHeader()

            SharpCardView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    MissionReportTextEditor(
                        title: "Tong ket doi",
                        text: $vm.teamSummary,
                        placeholder: "Da tiep can hien truong va dua nan nhan den khu an toan...",
                        caption: "Noi dung chung cua bao cao doi.",
                        isEditable: vm.canEdit
                    )

                    MissionReportTextEditor(
                        title: "Ghi chu doi",
                        text: $vm.teamNote,
                        placeholder: "Thong tin them ve duong di, vat can, tai nguyen...",
                        caption: "Cho phep tat ca thanh vien trong team cap nhat khi report chua submit.",
                        isEditable: vm.canEdit
                    )
                }
            }
        }
    }

    private var jsonSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("DU LIEU JSON").sectionHeader()

            SharpCardView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    MissionReportTextEditor(
                        title: "Issues JSON",
                        text: $vm.issuesJson,
                        placeholder: "{\"blockedRoad\":true}",
                        caption: "De trong, app se gui {}.",
                        isEditable: vm.canEdit,
                        minHeight: 96,
                        monospaced: true
                    )

                    MissionReportTextEditor(
                        title: "Result JSON",
                        text: $vm.resultJson,
                        placeholder: "{\"rescuedVictims\":3}",
                        caption: "De trong, app se gui {}.",
                        isEditable: vm.canEdit,
                        minHeight: 96,
                        monospaced: true
                    )

                    MissionReportTextEditor(
                        title: "Evidence JSON",
                        text: $vm.evidenceJson,
                        placeholder: "[{\"type\":\"image\",\"url\":\"https://...\"}]",
                        caption: "De trong, app se gui [].",
                        isEditable: vm.canEdit,
                        minHeight: 112,
                        monospaced: true
                    )
                }
            }
        }
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("CHI TIET HOAT DONG").sectionHeader()

            if vm.activities.isEmpty {
                SharpCardView {
                    Text("Khong co activity nao duoc giao cho mission team nay.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach($vm.activities) { $activity in
                        MissionReportActivityCard(activity: $activity, isEditable: vm.canEdit)
                    }
                }
            }
        }
    }

    private var evaluationsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("DANH GIA THANH VIEN").sectionHeader()
                Spacer()
                if vm.canEvaluateMembers == false {
                    StatusBadge(text: "Chi xem", color: DS.Colors.textSecondary)
                }
            }

            if vm.canEvaluateMembers == false {
                Text("Danh gia thanh vien chi doi truong moi duoc luu. Cac muc da co se hien o che do xem.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }

            VStack(spacing: DS.Spacing.sm) {
                ForEach($vm.memberEvaluations) { $evaluation in
                    MissionReportMemberEvaluationCard(
                        evaluation: $evaluation,
                        isEditable: vm.canEvaluateMembers
                    )
                }
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if vm.canEdit {
                Button {
                    vm.saveDraft()
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        if vm.isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                        }

                        Text("LUU NHAP")
                            .font(DS.Typography.headline)
                            .tracking(1)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(vm.canSaveDraft ? DS.Colors.info : DS.Colors.textTertiary)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
                }
                .disabled(!vm.canSaveDraft)

                if let message = vm.saveDraftRestrictionMessage {
                    Text(message)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.warning)
                }
            }

            if vm.reportStatus.normalizedStatusKey != "submitted" {
                Button {
                    vm.submitReport()
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        if vm.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }

                        Text("NOP BAO CAO CUOI")
                            .font(DS.Typography.headline)
                            .tracking(1)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(vm.canSubmit ? DS.Colors.accent : DS.Colors.textTertiary)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
                }
                .disabled(!vm.canSubmit || vm.isLoading || vm.isSubmitting || vm.isSaving || vm.isCompletingExecution)

                if vm.canSubmit == false {
                    Text("Chi doi truong sau khi da hoan thanh thuc dia moi duoc nop bao cao.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            DS.Colors.overlay(0.15).ignoresSafeArea()

            VStack(spacing: DS.Spacing.sm) {
                ProgressView()
                Text("Dang tai bao cao doi...")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.surface)
            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
        }
    }

    private func warningCard(message: String) -> some View {
        SharpCardView(borderColor: DS.Colors.warning.opacity(0.4), backgroundColor: DS.Colors.warning.opacity(0.08)) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(DS.Colors.warning)

                Text(message)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func reportMetaRow(label: String, value: String?) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textTertiary)
                .frame(width: 120, alignment: .leading)

            Text(formatTimestamp(value))
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
        }
    }

    private func executionStatusColor(_ status: String) -> Color {
        switch status.normalizedStatusKey {
        case "assigned":
            return DS.Colors.warning
        case "inprogress":
            return DS.Colors.warning
        case "completedwaitingreport":
            return DS.Colors.info
        case "reported":
            return DS.Colors.success
        case "cancelled":
            return DS.Colors.textTertiary
        default:
            return DS.Colors.textSecondary
        }
    }

    private func reportStatusColor(_ status: String) -> Color {
        switch status.normalizedStatusKey {
        case "notstarted":
            return DS.Colors.textSecondary
        case "draft":
            return DS.Colors.warning
        case "submitted":
            return DS.Colors.success
        default:
            return DS.Colors.textSecondary
        }
    }

    private func formatTimestamp(_ rawValue: String?) -> String {
        guard let rawValue, rawValue.isEmpty == false else {
            return "--"
        }

        if let date = MissionTeamReportDateParser.parse(rawValue) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }

        return rawValue
    }
}

private struct MissionReportActivityCard: View {
    @Binding var activity: MissionTeamReportActivityForm
    let isEditable: Bool

    var body: some View {
        SharpCardView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(activity.title)
                            .font(DS.Typography.headline)
                            .foregroundColor(DS.Colors.text)

                        if let code = activity.activityCode, code.isEmpty == false {
                            Text(code)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    if let status = activity.activityStatus {
                        StatusBadge(text: status, color: activityStatusColor(status))
                    }
                }

                ExecutionStatusMenuField(
                    title: "Execution Status",
                    value: $activity.executionStatus,
                    isEditable: isEditable
                )

                MissionReportTextEditor(
                    title: "Summary",
                    text: $activity.summary,
                    placeholder: "Tom tat ket qua thuc hien cho activity nay...",
                    caption: "Trang thai activity chi doi khi ban chon Execution Status.",
                    isEditable: isEditable,
                    minHeight: 88
                )

                MissionReportTextEditor(
                    title: "Issues JSON",
                    text: $activity.issuesJson,
                    placeholder: "{}",
                    caption: "De trong, app se gui {}.",
                    isEditable: isEditable,
                    minHeight: 88,
                    monospaced: true
                )

                MissionReportTextEditor(
                    title: "Result JSON",
                    text: $activity.resultJson,
                    placeholder: "{\"count\":3}",
                    caption: "De trong, app se gui {}.",
                    isEditable: isEditable,
                    minHeight: 88,
                    monospaced: true
                )

                MissionReportTextEditor(
                    title: "Evidence JSON",
                    text: $activity.evidenceJson,
                    placeholder: "[]",
                    caption: "De trong, app se gui [].",
                    isEditable: isEditable,
                    minHeight: 96,
                    monospaced: true
                )
            }
        }
    }

    private func activityStatusColor(_ status: String) -> Color {
        switch status.normalizedStatusKey {
        case "planned":
            return DS.Colors.textSecondary
        case "ongoing":
            return DS.Colors.warning
        case "succeed", "completed":
            return DS.Colors.success
        case "failed":
            return DS.Colors.accent
        case "cancelled":
            return DS.Colors.textTertiary
        default:
            return DS.Colors.textSecondary
        }
    }
}

private struct MissionReportMemberEvaluationCard: View {
    @Binding var evaluation: MissionTeamMemberEvaluationForm
    let isEditable: Bool

    var body: some View {
        SharpCardView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(evaluation.displayName)
                            .font(DS.Typography.headline)
                            .foregroundColor(DS.Colors.text)

                        let meta = [evaluation.roleInTeam, evaluation.rescuerType]
                            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { $0.isEmpty == false }
                            .joined(separator: " • ")

                        if meta.isEmpty == false {
                            Text(meta)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    if let averageScore = evaluation.averageScore {
                        StatusBadge(text: scoreLabel(averageScore), color: DS.Colors.success)
                    }
                }

                ScoreMenuField(
                    title: "Response time",
                    score: $evaluation.responseTimeScore,
                    isEditable: isEditable
                )

                ScoreMenuField(
                    title: "Rescue effectiveness",
                    score: $evaluation.rescueEffectivenessScore,
                    isEditable: isEditable
                )

                ScoreMenuField(
                    title: "Decision handling",
                    score: $evaluation.decisionHandlingScore,
                    isEditable: isEditable
                )

                ScoreMenuField(
                    title: "Safety & medical",
                    score: $evaluation.safetyMedicalSkillScore,
                    isEditable: isEditable
                )

                ScoreMenuField(
                    title: "Teamwork communication",
                    score: $evaluation.teamworkCommunicationScore,
                    isEditable: isEditable
                )
            }
        }
    }
}

private struct ExecutionStatusMenuField: View {
    let title: String
    @Binding var value: String
    let isEditable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)

            Menu {
                Button("Khong cap nhat") {
                    value = ""
                }

                ForEach(ReportExecutionStatusOption.allCases) { option in
                    Button(option.displayLabel) {
                        value = option.rawValue
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Text(currentLabel)
                        .font(DS.Typography.body)
                        .foregroundColor(isEditable ? DS.Colors.text : DS.Colors.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .padding(DS.Spacing.sm)
                .background(DS.Colors.background)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
            }
            .disabled(!isEditable)
        }
    }

    private var currentLabel: String {
        if let option = ReportExecutionStatusOption(apiValue: value) {
            return option.displayLabel
        }

        return value.nilIfBlank ?? "Khong cap nhat"
    }
}

private struct ScoreMenuField: View {
    let title: String
    @Binding var score: Double?
    let isEditable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)

            Menu {
                Button("Chua cham") {
                    score = nil
                }

                ForEach(missionReportScoreOptions, id: \.self) { value in
                    Button(scoreLabel(value)) {
                        score = value
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Text(score.map(scoreLabel) ?? "Chua cham")
                        .font(DS.Typography.body.monospacedDigit())
                        .foregroundColor(isEditable ? DS.Colors.text : DS.Colors.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .padding(DS.Spacing.sm)
                .background(DS.Colors.background)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
            }
            .disabled(!isEditable)
        }
    }
}

private struct MissionReportTextEditor: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let caption: String?
    let isEditable: Bool
    var minHeight: CGFloat = 120
    var monospaced: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.caption)
                .tracking(1)
                .foregroundColor(DS.Colors.textSecondary)

            ZStack(alignment: .topLeading) {
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(monospaced ? DS.Typography.mono : DS.Typography.body)
                        .foregroundColor(DS.Colors.textTertiary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.sm)
                }

                TextEditor(text: $text)
                    .font(monospaced ? DS.Typography.mono : DS.Typography.body)
                    .foregroundColor(DS.Colors.text)
                    .scrollContentBackground(.hidden)
                    .background(DS.Colors.surface)
                    .frame(minHeight: minHeight)
                    .padding(DS.Spacing.xxs)
                    .disabled(!isEditable)
            }
            .background(DS.Colors.background)
            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))

            if let caption, caption.isEmpty == false {
                Text(caption)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
    }
}

private enum MissionTeamReportDateParser {
    static func parse(_ rawValue: String) -> Date? {
        let fullFormatter = ISO8601DateFormatter()
        fullFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = fullFormatter.date(from: rawValue) {
            return date
        }

        let basicFormatter = ISO8601DateFormatter()
        basicFormatter.formatOptions = [.withInternetDateTime]

        if let date = basicFormatter.date(from: rawValue) {
            return date
        }

        return nil
    }
}

private let missionReportScoreOptions = Array(stride(from: 0.0, through: 10.0, by: 0.5))

private func scoreLabel(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }

    return String(format: "%.1f", value)
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
