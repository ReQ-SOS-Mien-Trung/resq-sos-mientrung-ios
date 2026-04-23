import Foundation
import SwiftUI

struct MissionTeamReportView: View {
    let missionTitle: String

    @StateObject private var vm: MissionTeamReportViewModel
    @State private var completionNote = ""
    @State private var expandedActivityId: Int?

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
                heroSection
                    .padding(.top, DS.Spacing.sm)

                statsSection

                if resultHighlights.isEmpty == false {
                    resultHighlightsSection
                }

                overviewSection

                if shouldShowStructuredPayloadSection {
                    structuredPayloadSection
                }

                if let restriction = vm.saveDraftRestrictionMessage {
                    warningCard(message: restriction)
                }

                if vm.canCompleteExecution {
                    completeExecutionSection
                }

                activitiesSection

                if vm.memberEvaluations.isEmpty == false {
                    evaluationsSection
                }

                Spacer(minLength: shouldShowBottomActionBar ? 120 : DS.Spacing.lg)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(screenBackground.ignoresSafeArea())
        .navigationTitle("Báo cáo đội")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        vm.refresh()
                    } label: {
                        Label("Làm mới", systemImage: "arrow.clockwise")
                    }

                    Button {
                        vm.fillDemoReportData()
                    } label: {
                        Label("Điền nhanh báo cáo demo", systemImage: "sparkles")
                    }
                    .disabled(!canFillDemoData)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .foregroundColor(DS.Colors.warning)
                .disabled(vm.isLoading || vm.isSaving || vm.isSubmitting || vm.isCompletingExecution)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if shouldShowBottomActionBar {
                bottomActionBar
            }
        }
        .overlay {
            if vm.isLoading && vm.report == nil {
                loadingOverlay
            }
        }
        .alert("Lỗi", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Thông báo", isPresented: Binding(
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

    private var screenBackground: some View {
        LinearGradient(
            colors: [
                DS.Colors.background,
                DS.Colors.warning.opacity(0.06),
                DS.Colors.background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    EyebrowLabel(text: "BÁO CÁO NHIỆM VỤ", color: DS.Colors.accent)
                    Text(missionTitle)
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(DS.Colors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DS.Spacing.sm)

                ZStack {
                    Circle()
                        .fill(DS.Colors.warning.opacity(0.14))
                        .frame(width: 48, height: 48)

                    Image(systemName: "doc.text.image.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DS.Colors.warning)
                }
            }

            HStack(spacing: DS.Spacing.xs) {
                StatusBadge(
                    text: executionStatusDisplayText(vm.executionStatus),
                    color: executionStatusColor(vm.executionStatus)
                )

                StatusBadge(
                    text: reportStatusDisplayText(vm.reportStatus),
                    color: reportStatusColor(vm.reportStatus)
                )
            }

            Text(statusSummaryText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)

            MissionReportStageProgressView(
                executionStatus: vm.executionStatus,
                reportStatus: vm.reportStatus
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DS.Spacing.sm),
                    GridItem(.flexible(), spacing: DS.Spacing.sm)
                ],
                alignment: .leading,
                spacing: DS.Spacing.sm
            ) {
                metaPill(
                    title: "Bắt đầu",
                    value: formatTimestamp(vm.report?.startedAt),
                    icon: "calendar"
                )

                metaPill(
                    title: "Chỉnh sửa",
                    value: formatTimestamp(vm.report?.lastEditedAt),
                    icon: "square.and.pencil"
                )

                metaPill(
                    title: "Đã nộp",
                    value: formatTimestamp(vm.report?.submittedAt),
                    icon: "checkmark.circle"
                )

                metaPill(
                    title: "Quyền hiện tại",
                    value: permissionSummary,
                    icon: "person.crop.rectangle"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DS.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DS.Colors.warning.opacity(0.06))
                .frame(width: 96, height: 96)
                .padding(.top, 12)
                .padding(.trailing, 12)
                .allowsHitTesting(false)
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(title: "Tổng quan nhanh", subtitle: "Nhìn nhanh tiến độ và phạm vi báo cáo")

            HStack(spacing: DS.Spacing.sm) {
                quickStatCard(
                    title: "Hoạt động",
                    value: vm.activities.isEmpty ? "0" : "\(completedActivityCount)/\(vm.activities.count)",
                    detail: activitySummaryText,
                    icon: "checklist",
                    tint: DS.Colors.info
                )

                quickStatCard(
                    title: "Thành viên",
                    value: vm.memberEvaluations.isEmpty ? "0" : "\(evaluatedMemberCount)/\(vm.memberEvaluations.count)",
                    detail: memberSummaryText,
                    icon: "person.3.fill",
                    tint: DS.Colors.success
                )
            }
        }
    }

    private var resultHighlightsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(title: "Kết quả chính", subtitle: "Tóm tắt nhanh từ dữ liệu báo cáo đã nộp")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DS.Spacing.sm),
                    GridItem(.flexible(), spacing: DS.Spacing.sm)
                ],
                alignment: .leading,
                spacing: DS.Spacing.sm
            ) {
                ForEach(resultHighlights) { metric in
                    quickStatCard(
                        title: metric.title,
                        value: metric.value,
                        detail: metric.detail,
                        icon: metric.icon,
                        tint: metric.tint
                    )
                }
            }
        }
    }

    private var completeExecutionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(title: "Hoàn tất nhiệm vụ", subtitle: "Khóa giai đoạn triển khai và chuyển sang bước nộp báo cáo")

            SharpCardView(borderColor: DS.Colors.success.opacity(0.25), backgroundColor: DS.Colors.surface) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(spacing: DS.Spacing.sm) {
                        statusIcon(symbol: "flag.checkered.circle.fill", tint: DS.Colors.success)

                        VStack(alignment: .leading, spacing: DS.Spacing.xxxs) {
                            Text("Xác nhận đội đã hoàn thành nhiệm vụ")
                                .font(DS.Typography.headline)
                                .foregroundColor(DS.Colors.text)

                            Text("Sau bước này, trưởng đội có thể hoàn thiện báo cáo cuối cùng và gửi đi.")
                                .font(DS.Typography.subheadline)
                                .foregroundColor(DS.Colors.textSecondary)
                        }

                        Spacer()
                    }

                    MissionReportTextEditor(
                        title: "Ghi chú hoàn tất",
                        text: $completionNote,
                        placeholder: "Ví dụ: Đường vào bị ngập, đã đưa nạn nhân đến khu an toàn và bàn giao vật phẩm hỗ trợ.",
                        caption: "Ghi chú này sẽ đi kèm mốc hoàn tất nhiệm vụ của đội.",
                        isEditable: true,
                        minHeight: 104
                    )

                    Button {
                        vm.completeExecution(note: completionNote)
                    } label: {
                        actionLabel(
                            title: "Hoàn tất nhiệm vụ",
                            icon: "checkmark.seal.fill",
                            showsProgress: vm.isCompletingExecution
                        )
                    }
                    .buttonStyle(.plain)
                    .missionReportPrimaryButton(color: DS.Colors.success)
                    .disabled(vm.isCompletingExecution || vm.isLoading || vm.isSaving || vm.isSubmitting)
                }
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(title: "Phần chung của đội", subtitle: overviewSectionSubtitle)

            SharpCardView(borderColor: DS.Colors.borderSubtle, backgroundColor: DS.Colors.surface) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    MissionReportTextEditor(
                        title: "Tóm tắt đội",
                        text: $vm.teamSummary,
                        placeholder: "Ví dụ: Đội đã tiếp cận hiện trường, sơ cứu và di tản người dân đến khu an toàn.",
                        caption: vm.canEdit ? "Phần này nên nêu ngắn gọn kết quả chính của cả đội." : nil,
                        isEditable: vm.canEdit
                    )

                    MissionReportTextEditor(
                        title: "Ghi chú đội",
                        text: $vm.teamNote,
                        placeholder: "Ví dụ: Điều kiện đường đi khó khăn, thiếu ánh sáng, cần bổ sung thuyền nhỏ.",
                        caption: vm.canEdit ? "Mọi thành viên trong đội có thể cập nhật khi báo cáo chưa được nộp." : nil,
                        isEditable: vm.canEdit
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var structuredPayloadSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(
                title: "Biểu mẫu tổng hợp chung",
                subtitle: vm.canEdit
                    ? "Giữ phần tổng hợp chung của đội ở trên để gom dữ liệu hiện trường và kết quả"
                    : "Dữ liệu tổng hợp chung của đội đã được ghi nhận"
            )

            MissionReportPayloadFormSection(
                payload: $vm.teamStructuredPayload,
                isEditable: vm.canEdit,
                title: "Báo cáo tổng hợp của đội",
                subtitle: vm.canEdit
                    ? "Phần này dùng để tổng hợp chung cho toàn đội"
                    : "Dữ liệu tổng hợp của cả đội đã được ghi nhận"
            )
        }
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(
                title: "Báo cáo từng bước",
                subtitle: vm.canEdit
                    ? "Phần chung giữ ở trên; mỗi bước chỉ cần cập nhật trạng thái thực hiện và tóm tắt kết quả"
                    : "Phần chung đã được tổng hợp ở trên; mở từng bước để xem trạng thái và tóm tắt đã ghi nhận"
            )

            if vm.activities.isEmpty {
                emptyStateCard(
                    title: "Chưa có hoạt động nào",
                    message: "Nhiệm vụ này hiện chưa có hoạt động được giao cho đội."
                )
            } else {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(vm.activities.indices, id: \.self) { index in
                        MissionReportActivityCard(
                            activity: $vm.activities[index],
                            isEditable: vm.canEdit,
                            stepNumber: index + 1,
                            isUnlocked: isReportStepUnlocked(at: index),
                            isCurrentStep: reportCurrentStepIndex == index,
                            isExpanded: expandedActivityId == vm.activities[index].id,
                            onToggleExpand: {
                                toggleActivityExpansion(id: vm.activities[index].id, at: index)
                            }
                        )
                    }
                }
            }
        }
    }

    private var evaluationsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(title: "Đánh giá thành viên", subtitle: memberSectionSubtitle)

            if vm.canEvaluateMembers == false, isSubmitted == false {
                warningCard(message: "Chỉ trưởng đội mới có quyền lưu phần đánh giá thành viên. Dữ liệu hiện tại đang ở chế độ xem.")
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

    @ViewBuilder
    private var bottomActionBar: some View {
        if shouldShowBottomActionBar {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if vm.canEdit, let message = vm.saveDraftRestrictionMessage {
                    Text(message)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.warning)
                } else if vm.reportStatus.normalizedStatusKey != "submitted", vm.canSubmit == false {
                    Text("Chỉ trưởng đội, sau khi hoàn tất nhiệm vụ, mới có thể nộp báo cáo cuối.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }

                HStack(spacing: DS.Spacing.sm) {
                    if vm.canEdit {
                        Button {
                            vm.saveDraft()
                        } label: {
                            actionLabel(
                                title: "Lưu nháp",
                                icon: "square.and.arrow.down.fill",
                                showsProgress: vm.isSaving
                            )
                        }
                        .buttonStyle(.plain)
                        .missionReportSecondaryButton(enabled: vm.canSaveDraft)
                        .disabled(!vm.canSaveDraft)
                    }

                    if vm.reportStatus.normalizedStatusKey != "submitted" {
                        Button {
                            vm.submitReport()
                        } label: {
                            actionLabel(
                                title: "Nộp báo cáo",
                                icon: "paperplane.fill",
                                showsProgress: vm.isSubmitting
                            )
                        }
                        .buttonStyle(.plain)
                        .missionReportPrimaryButton(color: DS.Colors.accent)
                        .opacity(vm.canSubmit ? 1 : 0.55)
                        .disabled(!vm.canSubmit || vm.isLoading || vm.isSubmitting || vm.isSaving || vm.isCompletingExecution)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.sm)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DS.Colors.borderSubtle)
                    .frame(height: 1)
            }
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            DS.Colors.overlay(0.15).ignoresSafeArea()

            VStack(spacing: DS.Spacing.sm) {
                ProgressView()
                Text("Đang tải báo cáo đội...")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DS.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }

    private var statusSummaryText: String {
        if vm.reportStatus.normalizedStatusKey == "submitted" {
            return "Báo cáo đã được nộp. Màn hình hiện chỉ còn ở chế độ xem."
        }

        if vm.canEvaluateMembers {
            return "Bạn đang ở vai trò trưởng đội. Hãy rà soát nội dung chung, chấm thành viên và gửi báo cáo khi đủ điều kiện."
        }

        if vm.canEdit {
            return "Bạn có thể cập nhật phần nội dung chung của đội. Phần đánh giá thành viên chỉ trưởng đội mới được lưu."
        }

        return "Báo cáo hiện không ở trạng thái cho phép chỉnh sửa."
    }

    private var permissionSummary: String {
        if vm.canEvaluateMembers {
            return "Trưởng đội"
        }

        if vm.canEdit {
            return "Thành viên chỉnh sửa"
        }

        return "Chỉ xem"
    }

    private var isSubmitted: Bool {
        vm.reportStatus.normalizedStatusKey == "submitted"
    }

    private var canFillDemoData: Bool {
        vm.canEdit
            && !isSubmitted
            && !vm.isLoading
            && !vm.isSaving
            && !vm.isSubmitting
            && !vm.isCompletingExecution
    }

    private var shouldShowBottomActionBar: Bool {
        guard vm.report != nil else { return false }
        return vm.canEdit || isSubmitted == false
    }

    private var shouldShowStructuredPayloadSection: Bool {
        vm.canEdit || hasAnyTopLevelStructuredPayload
    }

    private var hasAnyTopLevelStructuredPayload: Bool {
        vm.teamStructuredPayload.hasAnyContent
    }

    private var reportCurrentStepIndex: Int? {
        if let onGoingIndex = vm.activities.firstIndex(where: { activity in
            let key = normalizedReportStepStatus(for: activity)
            return ["ongoing", "inprogress"].contains(key)
        }) {
            return onGoingIndex
        }

        return vm.activities.firstIndex(where: { activity in
            let key = normalizedReportStepStatus(for: activity)
            return ["planned", "pending", "assigned", "notstarted", ""].contains(key)
        })
    }

    private var reportUnlockedStepIndex: Int {
        guard vm.activities.isEmpty == false else { return -1 }
        return reportCurrentStepIndex ?? (vm.activities.count - 1)
    }

    private func isReportStepUnlocked(at index: Int) -> Bool {
        index <= reportUnlockedStepIndex
    }

    private func toggleActivityExpansion(id: Int, at index: Int) {
        guard isReportStepUnlocked(at: index) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            expandedActivityId = expandedActivityId == id ? nil : id
        }
    }

    private func normalizedReportStepStatus(for activity: MissionTeamReportActivityForm) -> String {
        (activity.executionStatus.nilIfBlank ?? activity.activityStatus ?? "").normalizedStatusKey
    }

    private var completedActivityCount: Int {
        vm.activities.filter { activity in
            ["succeed", "completed", "reported"].contains(activity.executionStatus.normalizedStatusKey)
        }.count
    }

    private var activitySummaryText: String {
        guard vm.activities.isEmpty == false else {
            return "Chưa có dữ liệu"
        }

        let failedCount = vm.activities.filter { $0.executionStatus.normalizedStatusKey == "failed" }.count
        if failedCount > 0 {
            return "\(failedCount) mục cần xử lý thêm"
        }

        let remaining = vm.activities.count - completedActivityCount
        if remaining == 0 {
            return "Tất cả đã hoàn tất"
        }

        return "\(remaining) mục chưa hoàn tất"
    }

    private var evaluatedMemberCount: Int {
        vm.memberEvaluations.filter(\.hasCompleteScore).count
    }

    private var memberSummaryText: String {
        guard vm.memberEvaluations.isEmpty == false else {
            return "Không có đánh giá"
        }

        if evaluatedMemberCount == 0 {
            return vm.canEvaluateMembers ? "Người cần chấm" : "Chưa có điểm được lưu"
        }

        return "\(evaluatedMemberCount) người đã chấm đủ"
    }

    private var memberSectionSubtitle: String {
        if vm.canEvaluateMembers {
            return "Chấm 5 tiêu chí cho từng thành viên trước khi nộp báo cáo cuối"
        }

        if isSubmitted {
            return "Điểm số thành viên đã được chốt trong báo cáo đã nộp"
        }

        return "Chỉ trưởng đội có quyền cập nhật và lưu đánh giá thành viên"
    }

    private var overviewSectionSubtitle: String {
        vm.canEdit
            ? "Giữ thông tin tổng hợp chung của toàn đội ở đầu báo cáo"
            : "Thông tin tổng hợp chung của đội đã được ghi nhận"
    }

    private var resultHighlights: [MissionReportHighlightMetric] {
        parseResultHighlights(from: vm.teamStructuredPayload)
    }

    private func parseResultHighlights(from payload: MissionReportStructuredPayloadForm) -> [MissionReportHighlightMetric] {
        let keyOrder = ["rescued", "treated", "referred", "missing", "fatalities"]
        var entries: [(String, String)] = []

        let metricMappings: [(String, String)] = [
            ("rescued", payload.resultMetrics.rescued),
            ("treated", payload.resultMetrics.treated),
            ("referred", payload.resultMetrics.referred),
            ("missing", payload.resultMetrics.missing),
            ("fatalities", payload.resultMetrics.fatalities)
        ]

        for (key, value) in metricMappings {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                entries.append((key, trimmed))
            }
        }

        for entry in payload.resultExtras {
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty || value.isEmpty {
                continue
            }

            guard shouldShowResultExtraAsHighlight(key: key, value: value) else {
                continue
            }

            entries.append((key, value))
        }

        guard entries.isEmpty == false else {
            return []
        }

        let sorted = entries.sorted { lhs, rhs in
            let lhsKey = lhs.0.normalizedStatusKey
            let rhsKey = rhs.0.normalizedStatusKey
            let lhsIndex = keyOrder.firstIndex(of: lhsKey) ?? Int.max
            let rhsIndex = keyOrder.firstIndex(of: rhsKey) ?? Int.max

            if lhsIndex == rhsIndex {
                return lhs.0.localizedCaseInsensitiveCompare(rhs.0) == .orderedAscending
            }

            return lhsIndex < rhsIndex
        }

        return sorted.map { key, value in
            let metric = metricPresentation(for: key)
            return MissionReportHighlightMetric(
                id: key,
                title: metric.title,
                value: value,
                detail: metric.detail,
                icon: metric.icon,
                tint: metric.tint
            )
        }
    }

    private func shouldShowResultExtraAsHighlight(key: String, value: String) -> Bool {
        let compactKeys: Set<String> = [
            "hodahotro",
            "thoigianphanungphut",
            "sosdaxuly",
            "songuoisotan",
            "tongvatphamdaphat",
            "tongvatphamdagiao",
            "tongvatphamhoantra"
        ]

        let normalizedKey = key.normalizedStatusKey
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard compactKeys.contains(normalizedKey) else {
            return false
        }

        return trimmedValue.count <= 18 && trimmedValue.contains(";") == false
    }

    private func metricPresentation(for key: String) -> (title: String, detail: String, icon: String, tint: Color) {
        switch key.normalizedStatusKey {
        case "rescued":
            return ("Đã di tản", "Người đã đưa tới nơi an toàn", "figure.run", DS.Colors.info)
        case "treated":
            return ("Đã sơ cứu", "Người được hỗ trợ y tế tại chỗ", "cross.case.fill", DS.Colors.success)
        case "referred":
            return ("Chuyển tuyến", "Ca được chuyển lên tuyến trên", "arrowshape.turn.up.right.fill", DS.Colors.warning)
        case "missing":
            return ("Mất liên lạc", "Trường hợp cần theo dõi", "questionmark.circle", DS.Colors.accent)
        case "fatalities":
            return ("Tử vong", "Số ca tử vong ghi nhận", "exclamationmark.octagon", DS.Colors.accent)
        default:
            return (friendlyMetricTitle(from: key), "Dữ liệu tổng hợp từ máy chủ", "chart.bar.doc.horizontal", DS.Colors.textSecondary)
        }
    }

    private func friendlyMetricTitle(from key: String) -> String {
        key
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .splitCamelCase
            .capitalized
    }

    private func metaPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DS.Colors.warning)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DS.Colors.textTertiary)

                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DS.Colors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DS.Colors.background)
        )
    }

    private func quickStatCard(title: String, value: String, detail: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                statusIcon(symbol: icon, tint: tint)
                Spacer()
                Text(value)
                    .font(.system(size: value.count > 8 ? 18 : 24, weight: .black, design: .rounded))
                    .foregroundColor(DS.Colors.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .multilineTextAlignment(.trailing)
                    .allowsTightening(true)
            }

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DS.Colors.text)

            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DS.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private func warningCard(message: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            statusIcon(symbol: "exclamationmark.triangle.fill", tint: DS.Colors.warning)

            Text(message)
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DS.Colors.warning.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DS.Colors.warning.opacity(0.18), lineWidth: 1)
        )
    }

    private func emptyStateCard(title: String, message: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "square.stack.3d.up.slash.fill")
                .font(.system(size: 28))
                .foregroundColor(DS.Colors.textTertiary)

            Text(title)
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)

            Text(message)
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DS.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxxs) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(DS.Colors.text)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
        }
    }

    private func statusIcon(symbol: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 34, height: 34)

            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
        }
    }

    @ViewBuilder
    private func actionLabel(title: String, icon: String, showsProgress: Bool) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            if showsProgress {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: icon)
            }

            Text(title)
                .font(.system(size: 16, weight: .bold))
        }
        .frame(maxWidth: .infinity)
    }

    private func executionStatusDisplayText(_ status: String) -> String {
        switch status.normalizedStatusKey {
        case "assigned":
            return "Đã phân công"
        case "inprogress":
            return "Đang thực hiện"
        case "completedwaitingreport":
            return "Chờ báo cáo"
        case "reported":
            return "Đã báo cáo"
        case "cancelled":
            return "Đã hủy"
        default:
            return status.nilIfBlank ?? "Chưa xác định"
        }
    }

    private func reportStatusDisplayText(_ status: String) -> String {
        switch status.normalizedStatusKey {
        case "notstarted":
            return "Chưa bắt đầu"
        case "draft":
            return "Bản nháp"
        case "submitted":
            return "Đã nộp"
        default:
            return status.nilIfBlank ?? "Chưa xác định"
        }
    }

    private func executionStatusColor(_ status: String) -> Color {
        switch status.normalizedStatusKey {
        case "assigned", "inprogress":
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
            return "Chưa có"
        }

        if let date = MissionTeamReportDateParser.parse(rawValue) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.dateFormat = "HH:mm • dd/MM/yyyy"
            return formatter.string(from: date)
        }

        return rawValue
    }
}

private struct MissionReportActivityCard: View {
    @Binding var activity: MissionTeamReportActivityForm
    let isEditable: Bool
    let stepNumber: Int
    let isUnlocked: Bool
    let isCurrentStep: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        SharpCardView(borderColor: DS.Colors.borderSubtle, backgroundColor: DS.Colors.surface) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack(spacing: 8) {
                            Text("BƯỚC \(stepNumber)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isUnlocked ? DS.Colors.info : DS.Colors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((isUnlocked ? DS.Colors.info : DS.Colors.textSecondary).opacity(0.12))
                                .clipShape(Capsule())

                            if isCurrentStep && isUnlocked {
                                Text("Bước cần điền")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(DS.Colors.warning)
                            }

                            if activity.needsDeliveryShortfallReason && isUnlocked {
                                Text("Cần lý do giao thiếu")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(DS.Colors.warning)
                            }
                        }

                        Text(localizedActivityTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(DS.Colors.text)

                        if let localizedCode = localizedCodeLabel {
                            Text(localizedCode)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        if let status = displayStatus {
                            StatusBadge(text: activityStatusText(status), color: activityStatusColor(status))
                        }

                        Button(action: onToggleExpand) {
                            HStack(spacing: 6) {
                                Image(systemName: expandButtonIcon)
                                    .font(.system(size: 11, weight: .bold))

                                Text(expandButtonTitle)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(expandButtonColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(expandButtonColor.opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isUnlocked == false)
                    }
                }

                if isUnlocked == false {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(DS.Colors.textSecondary)

                        Text("Chưa tới bước này. Hoàn thành các bước trước để mở báo cáo của bước này.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DS.Colors.background)
                    )
                } else if isExpanded {
                    if let activityType = activity.activityType, activityType.isEmpty == false {
                        Text("Loại hoạt động: \(localizedActivityTypeLabel)")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                    }

                    Text("Phần chung của đội đã nằm ở trên. Ở bước này chỉ cần cập nhật trạng thái thực hiện và tóm tắt kết quả.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DS.Colors.background)
                        )

                    if activity.hasDeliveryShortfall {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            IncidentInlineNotice(
                                icon: activity.needsDeliveryShortfallReason ? "exclamationmark.triangle.fill" : "shippingbox.fill",
                                text: activity.needsDeliveryShortfallReason
                                    ? "Bước này đang giao thiếu so với kế hoạch. Hãy nhập lý do ở phần tóm tắt trước khi nộp báo cáo cuối."
                                    : "Bước này có vật phẩm giao thiếu. Lý do đã được lưu trong phần tóm tắt của bước này.",
                                tone: activity.needsDeliveryShortfallReason ? DS.Colors.warning : DS.Colors.info
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(activity.deliveryShortfalls) { shortfall in
                                    Text(shortfallLine(shortfall))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(DS.Colors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.leading, DS.Spacing.xs)
                        }
                    }

                    ExecutionStatusMenuField(
                        title: "Trạng thái thực hiện",
                        value: $activity.executionStatus,
                        isEditable: isEditable
                    )

                    MissionReportTextEditor(
                        title: "Tóm tắt kết quả",
                        text: $activity.summary,
                        placeholder: "Mô tả ngắn kết quả thực hiện của hoạt động này.",
                        caption: summaryCaption,
                        isEditable: isEditable,
                        minHeight: 88
                    )
                } else {
                    Text("Nhấn \"Mở bước\" để cập nhật trạng thái thực hiện và tóm tắt kết quả cho bước này.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(DS.Colors.background)
                        )
                }
            }
        }
    }

    private var expandButtonTitle: String {
        if isUnlocked == false {
            return "Đang khóa"
        }

        return isExpanded ? "Ẩn bước" : "Mở bước"
    }

    private var expandButtonIcon: String {
        if isUnlocked == false {
            return "lock.fill"
        }

        return isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill"
    }

    private var expandButtonColor: Color {
        if isUnlocked == false {
            return DS.Colors.textSecondary
        }

        return isExpanded ? DS.Colors.warning : DS.Colors.info
    }

    private var displayStatus: String? {
        activity.executionStatus.nilIfBlank ?? activity.activityStatus?.nilIfBlank
    }

    private var localizedActivityTitle: String {
        activity.localizedActivityCode
            ?? activity.localizedActivityType
            ?? activity.title
    }

    private var localizedActivityTypeLabel: String {
        activity.localizedActivityType
            ?? localizedActivityLabel(from: activity.activityType)
            ?? activity.localizedActivityCode
            ?? "Không rõ"
    }

    private var localizedCodeLabel: String? {
        guard let localizedCode = activity.localizedActivityCode else {
            return nil
        }

        if localizedCode == localizedActivityTitle {
            return nil
        }

        return localizedCode
    }

    private var summaryCaption: String? {
        if activity.needsDeliveryShortfallReason {
            return "Bước này đang giao thiếu so với kế hoạch; cần ghi rõ lý do trong phần tóm tắt trước khi nộp báo cáo."
        }

        if isEditable {
            return "Trạng thái đầu việc sẽ thay đổi theo lựa chọn ở mục trạng thái thực hiện."
        }

        return nil
    }

    private func localizedActivityLabel(from rawValue: String?) -> String? {
        guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), rawValue.isEmpty == false else {
            return nil
        }

        switch rawValue.normalizedStatusKey {
        case "evacuation", "evacuate":
            return "Di tản"
        case "medical", "medicalsupport":
            return "Hỗ trợ y tế"
        case "search", "searchandrescue", "sar":
            return "Tìm kiếm cứu nạn"
        case "logistics", "supply":
            return "Hậu cần"
        case "transport", "transportation":
            return "Vận chuyển"
        case "firefighting", "fire":
            return "Chữa cháy"
        default:
            return nil
        }
    }

    private func activityStatusText(_ status: String) -> String {
        switch status.normalizedStatusKey {
        case "planned":
            return "Đã lên kế hoạch"
        case "ongoing":
            return "Đang thực hiện"
        case "succeed", "completed":
            return "Hoàn thành"
        case "reported":
            return "Đã báo cáo"
        case "failed":
            return "Thất bại"
        case "cancelled":
            return "Đã hủy"
        default:
            return status.nilIfBlank ?? "Không rõ"
        }
    }

    private func activityStatusColor(_ status: String) -> Color {
        switch status.normalizedStatusKey {
        case "planned":
            return DS.Colors.textSecondary
        case "ongoing":
            return DS.Colors.warning
        case "succeed", "completed", "reported":
            return DS.Colors.success
        case "failed":
            return DS.Colors.accent
        case "cancelled":
            return DS.Colors.textTertiary
        default:
            return DS.Colors.textSecondary
        }
    }

    private func shortfallLine(_ shortfall: MissionTeamReportDeliveryShortfall) -> String {
        let planned = quantityLabel(shortfall.plannedQuantity, unit: shortfall.unit)
        let actual = quantityLabel(shortfall.actualDeliveredQuantity, unit: shortfall.unit)
        let missing = quantityLabel(shortfall.shortfallQuantity, unit: shortfall.unit)

        return "\(shortfall.itemName): kế hoạch \(planned), thực tế \(actual), thiếu \(missing)."
    }

    private func quantityLabel(_ quantity: Int, unit: String?) -> String {
        if let unit, unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return "\(quantity) \(unit)"
        }

        return "\(quantity)"
    }
}

private struct MissionReportPayloadFormSection: View {
    @Binding var payload: MissionReportStructuredPayloadForm
    let isEditable: Bool
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DS.Colors.text)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            issuePresetSection
            resultMetricSection

            MissionReportKeyValueEditor(
                title: "Thông tin sự cố bổ sung",
                keyPlaceholder: "Tên trường",
                valuePlaceholder: "Giá trị",
                emptyMessage: "Chưa có dữ liệu sự cố bổ sung.",
                entries: $payload.issueExtras,
                isEditable: isEditable
            )

            MissionReportKeyValueEditor(
                title: "Kết quả bổ sung",
                keyPlaceholder: "Tên chỉ số",
                valuePlaceholder: "Giá trị",
                emptyMessage: "Chưa có chỉ số bổ sung.",
                entries: $payload.resultExtras,
                isEditable: isEditable
            )

            MissionReportEvidenceEditor(
                entries: $payload.evidenceEntries,
                isEditable: isEditable
            )
        }
        .padding(DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DS.Colors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private var issuePresetSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Sự cố thường gặp")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DS.Spacing.xs),
                    GridItem(.flexible(), spacing: DS.Spacing.xs)
                ],
                alignment: .leading,
                spacing: DS.Spacing.xs
            ) {
                issueToggleChip(
                    title: "Đường bị chặn",
                    icon: "road.lanes",
                    isOn: $payload.issueFlags.blockedRoad
                )
                issueToggleChip(
                    title: "Ngập lụt",
                    icon: "drop.triangle",
                    isOn: $payload.issueFlags.flooding
                )
                issueToggleChip(
                    title: "Sạt lở",
                    icon: "mountain.2",
                    isOn: $payload.issueFlags.landslide
                )
                issueToggleChip(
                    title: "Mất điện",
                    icon: "bolt.slash.fill",
                    isOn: $payload.issueFlags.powerOutage
                )
                issueToggleChip(
                    title: "Mất liên lạc",
                    icon: "wifi.slash",
                    isOn: $payload.issueFlags.communicationLoss
                )
                issueToggleChip(
                    title: "Khu vực nguy hiểm",
                    icon: "exclamationmark.triangle.fill",
                    isOn: $payload.issueFlags.unsafeArea
                )
                issueToggleChip(
                    title: "Quá tải y tế",
                    icon: "cross.case.fill",
                    isOn: $payload.issueFlags.medicalOverload
                )
            }

            if isEditable == false, payload.issueFlags.hasAnyTrue == false {
                Text("Không có sự cố được đánh dấu.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
    }

    private var resultMetricSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Kết quả chính")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: DS.Spacing.xs),
                    GridItem(.flexible(), spacing: DS.Spacing.xs)
                ],
                alignment: .leading,
                spacing: DS.Spacing.xs
            ) {
                resultMetricField(title: "Đã di tản", text: $payload.resultMetrics.rescued)
                resultMetricField(title: "Đã sơ cứu", text: $payload.resultMetrics.treated)
                resultMetricField(title: "Chuyển tuyến", text: $payload.resultMetrics.referred)
                resultMetricField(title: "Mất liên lạc", text: $payload.resultMetrics.missing)
                resultMetricField(title: "Tử vong", text: $payload.resultMetrics.fatalities)
            }
        }
    }

    private func issueToggleChip(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        let isSelected = isOn.wrappedValue

        return Button {
            guard isEditable else { return }
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundColor(isSelected ? DS.Colors.info : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? DS.Colors.info.opacity(0.12) : DS.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? DS.Colors.info.opacity(0.35) : DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isEditable == false)
        .opacity(isEditable || isSelected ? 1 : 0.65)
    }

    private func resultMetricField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DS.Colors.textSecondary)

            if isEditable {
                TextField("0", text: sanitizedNumberBinding(text))
                    .keyboardType(.numberPad)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.text)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DS.Colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                    )
            } else {
                Text(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : text.wrappedValue)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.text)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DS.Colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                    )
            }
        }
    }

    private func sanitizedNumberBinding(_ source: Binding<String>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue },
            set: { source.wrappedValue = $0.filter(\.isNumber) }
        )
    }
}

private struct MissionReportKeyValueEditor: View {
    let title: String
    let keyPlaceholder: String
    let valuePlaceholder: String
    let emptyMessage: String
    @Binding var entries: [MissionReportKeyValueEntry]
    let isEditable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(title)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)

                Spacer()

                if isEditable {
                    Button {
                        entries.append(MissionReportKeyValueEntry())
                    } label: {
                        Label("Thêm", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(DS.Colors.info)
                }
            }

            let visibleEntries = isEditable
                ? entries
                : entries.filter {
                    $0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    || $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                }

            if visibleEntries.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
            } else {
                ForEach($entries) { $entry in
                    let hasContent = entry.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                        || entry.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

                    if isEditable || hasContent {
                        HStack(spacing: DS.Spacing.xs) {
                            if isEditable {
                                TextField(keyPlaceholder, text: $entry.key)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(DS.Colors.surface)
                                    )

                                TextField(valuePlaceholder, text: $entry.value)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(DS.Colors.surface)
                                    )

                                Button {
                                    removeEntry(withId: entry.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(DS.Colors.accent)
                                        .frame(width: 28, height: 28)
                                        .background(DS.Colors.accent.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            } else {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.key)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(DS.Colors.textSecondary)

                                    Text(entry.value)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(DS.Colors.text)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(DS.Colors.surface)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func removeEntry(withId id: UUID) {
        entries.removeAll { $0.id == id }
    }
}

private struct MissionReportEvidenceEditor: View {
    @Binding var entries: [MissionReportEvidenceEntry]
    let isEditable: Bool

    private let typeOptions: [(value: String, label: String)] = [
        ("image", "Ảnh"),
        ("video", "Video"),
        ("document", "Tài liệu"),
        ("link", "Liên kết"),
        ("note", "Ghi chú")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text("Bằng chứng")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)

                Spacer()

                if isEditable {
                    Button {
                        entries.append(MissionReportEvidenceEntry())
                    } label: {
                        Label("Thêm", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(DS.Colors.info)
                }
            }

            let visibleEntries = isEditable
                ? entries
                : entries.filter { $0.hasContent }

            if visibleEntries.isEmpty {
                Text("Chưa có bằng chứng được ghi nhận.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
            } else {
                ForEach($entries) { $entry in
                    if isEditable || entry.hasContent {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            if isEditable {
                                HStack(spacing: DS.Spacing.xs) {
                                    Menu {
                                        ForEach(typeOptions, id: \.value) { option in
                                            Button(option.label) {
                                                entry.type = option.value
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(labelForType(entry.type))
                                                .font(.system(size: 12, weight: .semibold))
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10, weight: .semibold))
                                        }
                                        .foregroundColor(DS.Colors.text)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(DS.Colors.surface)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                                        )
                                    }

                                    Spacer()

                                    Button {
                                        removeEntry(withId: entry.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(DS.Colors.accent)
                                            .frame(width: 28, height: 28)
                                            .background(DS.Colors.accent.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }

                                TextField("Link bằng chứng (tuỳ chọn)", text: $entry.url)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.URL)
                                    .autocorrectionDisabled()
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(DS.Colors.surface)
                                    )

                                TextField("Ghi chú bằng chứng", text: $entry.note, axis: .vertical)
                                    .lineLimit(2...4)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(DS.Colors.surface)
                                    )
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(labelForType(entry.type))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(DS.Colors.textSecondary)

                                    if entry.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                                        Text(entry.url)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(DS.Colors.info)
                                            .textSelection(.enabled)
                                    }

                                    if entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                                        Text(entry.note)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(DS.Colors.text)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(DS.Colors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func removeEntry(withId id: UUID) {
        entries.removeAll { $0.id == id }
    }

    private func labelForType(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return typeOptions.first(where: { $0.value == normalized })?.label ?? "Bằng chứng"
    }
}

private struct MissionReportMemberEvaluationCard: View {
    @Binding var evaluation: MissionTeamMemberEvaluationForm
    let isEditable: Bool

    var body: some View {
        SharpCardView(borderColor: DS.Colors.borderSubtle, backgroundColor: DS.Colors.surface) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(evaluation.displayName)
                            .font(.system(size: 20, weight: .bold))
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
                        StatusBadge(text: "Điểm \(scoreLabel(averageScore))", color: missionReportScoreColor(averageScore))
                    }
                }

                HStack(alignment: .top, spacing: 6) {
                    ScoreWheelField(
                        title: "Phản ứng",
                        score: $evaluation.responseTimeScore,
                        tint: DS.Colors.success,
                        isEditable: isEditable
                    )

                    ScoreWheelField(
                        title: "Cứu hộ",
                        score: $evaluation.rescueEffectivenessScore,
                        tint: DS.Colors.info,
                        isEditable: isEditable
                    )

                    ScoreWheelField(
                        title: "Quyết định",
                        score: $evaluation.decisionHandlingScore,
                        tint: DS.Colors.warning,
                        isEditable: isEditable
                    )

                    ScoreWheelField(
                        title: "An toàn",
                        score: $evaluation.safetyMedicalSkillScore,
                        tint: DS.Colors.accent,
                        isEditable: isEditable
                    )

                    ScoreWheelField(
                        title: "Giao tiếp",
                        score: $evaluation.teamworkCommunicationScore,
                        tint: DS.Colors.danger,
                        isEditable: isEditable
                    )
                }
                .frame(maxWidth: .infinity)
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

            if isEditable {
                Menu {
                    Button("Không cập nhật") {
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
                            .foregroundColor(DS.Colors.text)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DS.Colors.background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                    )
                }
            } else {
                HStack(spacing: DS.Spacing.sm) {
                    Text(currentLabel)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.textSecondary)

                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(DS.Colors.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                )
            }
        }
    }

    private var currentLabel: String {
        if let option = ReportExecutionStatusOption(apiValue: value) {
            return option.displayLabel
        }

        return value.nilIfBlank ?? "Không cập nhật"
    }
}

private struct ScoreWheelField: View {
    let title: String
    @Binding var score: Double?
    let tint: Color
    let isEditable: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(tint)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 14)

            if isEditable {
                Picker(title, selection: selectionIndex) {
                    ForEach(Array(missionReportScoreOptions.enumerated()), id: \.offset) { index, value in
                        Text(scorePickerLabel(for: value))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .tag(index)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .clipped()
            } else {
                Text(scoreDisplayText)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(displayedScore != nil ? tint : DS.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .center)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.12))
                    )
            }
        }
        .frame(maxWidth: .infinity, minHeight: missionReportCompactScoreFieldHeight, alignment: .top)
        .padding(.horizontal, 5)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DS.Colors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.65), lineWidth: 1.1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(scoreDisplayText)
        .onAppear {
            if isEditable && score == nil {
                score = missionReportDefaultScore
            }
        }
    }

    private var selectionIndex: Binding<Int> {
        Binding(
            get: {
                let effectiveScore = score ?? missionReportDefaultScore
                return missionReportScoreOptions.firstIndex(where: { abs($0 - effectiveScore) < 0.001 }) ?? missionReportDefaultScoreIndex
            },
            set: { newValue in
                guard missionReportScoreOptions.indices.contains(newValue) else { return }
                score = missionReportScoreOptions[newValue]
            }
        )
    }

    private var displayedScore: Double? {
        if let score {
            return score
        }

        return isEditable ? missionReportDefaultScore : nil
    }

    private var scoreDisplayText: String {
        displayedScore.map(scoreLabel) ?? "-"
    }

    private func scorePickerLabel(for value: Double) -> String {
        return scoreLabel(value)
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
                .tracking(0.5)
                .foregroundColor(DS.Colors.textSecondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DS.Colors.background)

                if isEditable {
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
                        .background(Color.clear)
                        .frame(minHeight: minHeight)
                        .padding(DS.Spacing.xxs)
                } else {
                    Text(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Chưa cập nhật" : text)
                        .font(monospaced ? DS.Typography.mono : DS.Typography.body)
                        .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? DS.Colors.textTertiary : DS.Colors.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.sm)
                        .textSelection(.enabled)
                }
            }
            .frame(minHeight: isEditable ? minHeight : 0)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )

            if let caption, caption.isEmpty == false {
                Text(caption)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
    }
}

private struct MissionReportStageProgressView: View {
    let executionStatus: String
    let reportStatus: String

    private let titles = [
        "Tiếp nhận",
        "Thực hiện",
        "Hoàn tất",
        "Nộp báo cáo"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Tiến trình báo cáo")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.text)

                Spacer()

                Text("\(completedSteps)/4 bước")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DS.Colors.borderSubtle)
                        .frame(height: 8)

                    Capsule()
                        .fill(DS.Colors.warning)
                        .frame(width: width * progressValue, height: 8)
                }
            }
            .frame(height: 8)

            HStack(spacing: DS.Spacing.xs) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(index < completedSteps ? DS.Colors.warning : DS.Colors.borderSubtle)
                            .frame(width: 8, height: 8)

                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(index < completedSteps ? DS.Colors.text : DS.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var completedSteps: Int {
        if reportStatus.normalizedStatusKey == "submitted" {
            return 4
        }

        switch executionStatus.normalizedStatusKey {
        case "reported":
            return 4
        case "completedwaitingreport":
            return 3
        case "inprogress":
            return 2
        case "assigned":
            return 1
        default:
            return 1
        }
    }

    private var progressValue: CGFloat {
        CGFloat(completedSteps) / 4
    }
}

private struct MissionReportPrimaryButtonModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color)
            )
    }
}

private struct MissionReportHighlightMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
    let icon: String
    let tint: Color
}

private struct MissionReportSecondaryButtonModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .foregroundColor(enabled ? DS.Colors.text : DS.Colors.textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(DS.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(enabled ? DS.Colors.border : DS.Colors.borderSubtle, lineWidth: 1)
            )
    }
}

private extension View {
    func missionReportPrimaryButton(color: Color) -> some View {
        modifier(MissionReportPrimaryButtonModifier(color: color))
    }

    func missionReportSecondaryButton(enabled: Bool) -> some View {
        modifier(MissionReportSecondaryButtonModifier(enabled: enabled))
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
private let missionReportDefaultScore = 5.0
private let missionReportDefaultScoreIndex = missionReportScoreOptions.firstIndex(where: { abs($0 - missionReportDefaultScore) < 0.001 }) ?? 10
private let missionReportCompactScoreFieldHeight: CGFloat = 96

private func scoreLabel(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }

    return String(format: "%.1f", value)
}

private func missionReportScoreColor(_ value: Double) -> Color {
    switch value {
    case 8...10:
        return DS.Colors.success
    case 5..<8:
        return DS.Colors.warning
    default:
        return DS.Colors.accent
    }
}

private extension MissionReportIssueFlagsForm {
    var hasAnyTrue: Bool {
        blockedRoad
            || flooding
            || landslide
            || powerOutage
            || communicationLoss
            || unsafeArea
            || medicalOverload
    }
}

private extension MissionReportResultMetricsForm {
    var hasAnyValue: Bool {
        [rescued, treated, referred, missing, fatalities]
            .contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    }
}

private extension MissionReportEvidenceEntry {
    var hasContent: Bool {
        type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

private extension MissionReportStructuredPayloadForm {
    var hasAnyContent: Bool {
        issueFlags.hasAnyTrue
            || issueExtras.contains(where: {
                $0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    || $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            })
            || resultMetrics.hasAnyValue
            || resultExtras.contains(where: {
                $0.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    || $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            })
            || evidenceEntries.contains(where: \.hasContent)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var splitCamelCase: String {
        replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1 $2", options: .regularExpression)
    }

    var normalizedStatusKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }
}
