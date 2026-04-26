import SwiftUI
import CoreLocation

struct MissionDetailView: View {
    private enum ActivityScopeFilter: String, CaseIterable, Identifiable {
        case myTeam
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .myTeam:
                return "Đội của bạn"
            case .all:
                return "Toàn nhiệm vụ"
            }
        }
    }

    let mission: Mission
    @StateObject private var vm = RescuerMissionViewModel()
    @StateObject private var incidentVM = IncidentViewModel()
    @ObservedObject private var authSession = AuthSessionStore.shared
    @State private var showReportIncident = false
    @State private var showMissionReport = false
    @State private var showAggregateRoute = false
    @State private var showMissionInventory = false
    @State private var pickupConfirmationActivity: Activity?
    @State private var deliveryConfirmationActivity: Activity?
    @State private var returnConfirmationActivity: Activity?
    @State private var completionProofActivity: Activity?
    @State private var routePreviewActivity: Activity?
    @State private var missionStatus: String
    @State private var missionDetail: Mission?
    @State private var activityScopeFilter: ActivityScopeFilter = .myTeam

    init(mission: Mission) {
        self.mission = mission
        _missionStatus = State(initialValue: mission.status)
    }

    private var activeMission: Mission { missionDetail ?? mission }

    private var fallbackViewerMissionTeamId: Int? { mission.missionTeamId }

    private var viewerMissionTeamId: Int? {
        vm.currentTeamMissionTeamIds.first ?? fallbackViewerMissionTeamId
    }

    private var viewerMissionTeam: MissionTeam? {
        guard let viewerMissionTeamId else {
            return activeMission.teams?.first
        }

        return activeMission.teams?.first(where: { $0.id == viewerMissionTeamId })
            ?? activeMission.teams?.first
    }

    private var canViewMissionWorkspace: Bool {
        authSession.session?.canViewMissionWorkspace ?? false
    }

    private var canManageMissionStatus: Bool {
        authSession.session?.canManageMissionStatus ?? false
    }

    private var canUpdateActivityStatus: Bool {
        authSession.session?.canUpdateActivityStatus ?? false
    }

    private var canAccessMissionRoutes: Bool {
        authSession.session?.canAccessMissionRoutes ?? false
    }

    private var canReportMissionIncidents: Bool {
        canViewMissionWorkspace
    }

    private var canOpenMissionReports: Bool {
        canViewMissionWorkspace
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                missionHeader
                    .padding(.top, DS.Spacing.sm)

                if canAccessMissionRoutes {
                    aggregateRouteButton
                }

                if canViewMissionWorkspace {
                    sectionHeader(
                        title: "Các bước thực hiện",
                        subtitle: activitySectionSubtitle
                    )

                    activityScopePicker

                    if pendingActivitySyncCount > 0 {
                        pendingSyncBanner
                    }

                    activitiesSection

                    inventorySection

                    incidentSectionHeader

                    IncidentTimelineView(incidents: incidentVM.incidents, isLoading: incidentVM.isLoading)
                } else {
                    restrictedNotice
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Colors.background)
        .navigationTitle("Chi tiết nhiệm vụ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canViewMissionWorkspace {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            refreshMissionWorkspace(triggerSync: true)
                        } label: {
                            Label("Làm mới", systemImage: "arrow.clockwise")
                        }

                        if inventoryEntryCount > 0 {
                            Button {
                                showMissionInventory = true
                            } label: {
                                Label("Túi đồ vật phẩm", systemImage: "shippingbox")
                            }
                        }

                        if canReportMissionIncidents {
                            Button {
                                showReportIncident = true
                            } label: {
                                Label("Báo cáo sự cố", systemImage: "exclamationmark.triangle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .foregroundColor(DS.Colors.accent)
                }
            }
        }
        .navigationDestination(isPresented: $showReportIncident) {
            ReportIncidentView(
                mission: activeMission,
                activities: currentTeamActivities,
                incidentVM: incidentVM
            ) {
                showReportIncident = false
            }
        }
        .navigationDestination(isPresented: $showMissionReport) {
            if let teamId = viewerMissionTeamId {
                MissionTeamReportView(
                    missionId: activeMission.id,
                    missionTeamId: teamId,
                    missionTitle: activeMission.title
                )
            }
        }
        .sheet(isPresented: $showAggregateRoute) {
            NavigationStack {
                MissionAggregateRouteSheetView(
                    mission: activeMission,
                    vm: vm,
                    preferredMissionTeamId: viewerMissionTeamId
                )
                    .navigationTitle("Lộ trình tổng hợp")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Đóng") {
                                showAggregateRoute = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showMissionInventory) {
            NavigationStack {
                MissionInventoryView(
                    missionTitle: activeMission.title,
                    activities: displayedActivities
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Đóng") {
                            showMissionInventory = false
                        }
                    }
                }
            }
        }
        .sheet(item: $pickupConfirmationActivity) { activity in
            NavigationStack {
                PickupConfirmationSheet(
                    activity: activity,
                    isSubmitting: vm.isLoadingActivities
                ) { bufferUsages, proofImage in
                    await vm.confirmPickup(
                        missionId: activeMission.id,
                        activityId: activity.id,
                        bufferUsages: bufferUsages,
                        proofImage: proofImage
                    )
                }
            }
            .presentationDetents([.large])
        }
        .sheet(item: $deliveryConfirmationActivity) { activity in
            NavigationStack {
                DeliveryConfirmationSheet(
                    activity: activity,
                    isSubmitting: vm.isLoadingActivities
                ) { actualDeliveredItems, deliveryNote, proofImage in
                    await vm.confirmDelivery(
                        missionId: activeMission.id,
                        activityId: activity.id,
                        actualDeliveredItems: actualDeliveredItems,
                        deliveryNote: deliveryNote,
                        proofImage: proofImage
                    )
                }
            }
            .presentationDetents([.large])
        }
        .sheet(item: $returnConfirmationActivity) { activity in
            NavigationStack {
                ReturnSuppliesConfirmationSheet(
                    activity: activity,
                    isSubmitting: vm.isLoadingActivities
                ) { proofImage in
                    await vm.completeActivity(
                        missionId: activeMission.id,
                        activityId: activity.id,
                        knownActivities: currentTeamActivities.isEmpty ? displayedActivities : currentTeamActivities,
                        proofImage: proofImage
                    )
                }
            }
            .presentationDetents([.large])
        }
        .sheet(item: $completionProofActivity) { activity in
            NavigationStack {
                ActivityCompletionProofSheet(
                    activity: activity,
                    isSubmitting: vm.isLoadingActivities
                ) { proofImage in
                    await vm.completeActivity(
                        missionId: activeMission.id,
                        activityId: activity.id,
                        knownActivities: currentTeamActivities.isEmpty ? displayedActivities : currentTeamActivities,
                        proofImage: proofImage
                    )
                }
            }
            .presentationDetents([.large])
        }
        .sheet(item: $routePreviewActivity) { activity in
            NavigationStack {
                ActivityRouteSheetView(
                    missionId: activeMission.id,
                    activity: activity,
                    fallbackOriginCoordinate: currentTeamCoordinate,
                    fallbackOriginLabel: currentTeamOriginLabel
                )
                .navigationTitle(activity.step.map { "Lộ trình bước \($0)" } ?? "Lộ trình hoạt động")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Đóng") {
                            routePreviewActivity = nil
                        }
                    }
                }
            }
            .presentationDetents([.large])
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
            guard canViewMissionWorkspace else { return }
            refreshMissionWorkspace()
        }
    }

    private var missionHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Nhiệm vụ")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DS.Colors.textSecondary)

                    Text(activeMission.title)
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(DS.Colors.text)
                        .fixedSize(horizontal: false, vertical: true)

                    if activeMission.shouldDisplayMissionTypeBadge,
                       let missionTypeBadgeText = activeMission.missionTypeBadgeText {
                        StatusBadge(
                            text: missionTypeBadgeText,
                            color: missionTypeColor(activeMission.missionTypeBadgeKey)
                        )
                    }
                }

                Spacer(minLength: DS.Spacing.sm)

                StatusBadge(
                    text: RescuerStatusBadgeText.mission(missionStatus),
                    color: missionStatusColor(missionStatus)
                )
            }

            if let desc = activeMission.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if shouldShowStartMissionButton && canManageMissionStatus {
                startMissionButton
            }

            missionMetaGrid
            progressSummary

            if shouldShowSafetyCheckInPanel, let viewerMissionTeam {
                safetyCheckInPanel(for: viewerMissionTeam)
            }

            if shouldShowMissionReportButton {
                missionReportButton
            }
        }
        .padding(20)
        .sharpCard(
            borderColor: DS.Colors.borderSubtle,
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.small,
            backgroundColor: DS.Colors.surface,
            radius: 18
        )
    }

    private var missionMetaGrid: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                infoChip(
                    title: "Thời gian bắt đầu",
                    value: formattedDisplayDate(activeMission.startDate) ?? "Chưa có",
                    icon: "calendar"
                )

                infoChip(
                    title: "Kết thúc dự kiến",
                    value: formattedDisplayDate(activeMission.endDate) ?? "Chưa có",
                    icon: "clock"
                )
            }

            HStack(spacing: DS.Spacing.sm) {
                infoChip(
                    title: "Số bước",
                    value: "\(activityCount)",
                    icon: "checklist"
                )

                infoChip(
                    title: teamSummaryTitle,
                    value: teamSummaryValue,
                    icon: "person.3"
                )
            }
        }
    }

    private var progressSummary: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text("Tiến độ nhiệm vụ")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.text)

                Spacer()

                Text("\(completedActivityCount)/\(max(activityCount, 1))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            ProgressView(value: activityProgress)
                .tint(DS.Colors.accent)
        }
    }

    private var shouldShowSafetyCheckInPanel: Bool {
        guard canViewMissionWorkspace, viewerMissionTeam != nil else { return false }

        switch normalizedStatus(missionStatus) {
        case "ongoing", "inprogress":
            return true
        default:
            return false
        }
    }

    private func safetyCheckInPanel(for team: MissionTeam) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(safetyStatusColor(team.safetyStatus).opacity(0.14))
                        .frame(width: 36, height: 36)

                    Image(systemName: "shield.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(safetyStatusColor(team.safetyStatus))
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text("Báo an toàn")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(DS.Colors.text)

                        StatusBadge(
                            text: safetyStatusLabel(team.safetyStatus),
                            color: safetyStatusColor(team.safetyStatus)
                        )
                    }

                    Text(safetyTeamName(team))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DS.Colors.textSecondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: DS.Spacing.sm) {
                safetyInfoChip(
                    title: "Lần báo gần nhất",
                    value: formattedDisplayDate(team.safetyLatestCheckInAt) ?? "Chưa có",
                    icon: "checkmark.seal"
                )

                safetyInfoChip(
                    title: "Hạn tiếp theo",
                    value: formattedDisplayDate(team.safetyTimeoutAt) ?? "Chưa có",
                    icon: "timer"
                )
            }

            if let generatedSosRequestId = team.generatedSosRequestId {
                Label("SOS tự động #\(generatedSosRequestId)", systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DS.Colors.accent)
            }

            Button {
                Task {
                    let didCheckIn = await vm.safetyCheckIn(
                        missionId: activeMission.id,
                        missionTeamId: team.id
                    )

                    if didCheckIn {
                        loadMissionDetail()
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    if vm.isSafetyCheckInSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Text(vm.isSafetyCheckInSubmitting ? "Đang báo an toàn..." : "Đội đang an toàn")
                        .font(.system(size: 14, weight: .bold))

                    Spacer(minLength: 0)
                }
                .foregroundColor(.white)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.success)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(vm.isSafetyCheckInSubmitting)
            .opacity(vm.isSafetyCheckInSubmitting ? 0.8 : 1)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(safetyStatusColor(team.safetyStatus).opacity(0.18), lineWidth: 1)
        )
    }

    private func safetyInfoChip(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DS.Colors.text)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private var pendingSyncBanner: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .foregroundColor(DS.Colors.info)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(pendingActivitySyncCount) hoạt động chưa đồng bộ máy chủ")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(DS.Colors.text)

                Text("Các cập nhật này đã được lưu cục bộ trên thiết bị. Ứng dụng sẽ giữ nguyên trạng thái cục bộ cho tới khi máy chủ hỗ trợ đồng bộ theo lô.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderColor: DS.Colors.info.opacity(0.25),
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 16
        )
    }

    @ViewBuilder
    private var activitiesSection: some View {
        let list = displayedActivities
        if vm.isLoadingActivities && list.isEmpty {
            HStack(spacing: DS.Spacing.sm) {
                ProgressView()
                Text("Đang tải các bước thực hiện...")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sharpCard(
                borderColor: DS.Colors.borderSubtle,
                borderWidth: DS.Border.thin,
                shadow: DS.Shadow.none,
                backgroundColor: DS.Colors.surface,
                radius: 16
            )
        } else if vm.hasLoadedActivities && list.isEmpty {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "checklist")
                    .font(.system(size: 32))
                    .foregroundColor(DS.Colors.textTertiary)
                Text("Chưa có bước thực hiện nào")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.textSecondary)
                Text(emptyActivitiesMessage)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
            .sharpCard(
                borderColor: DS.Colors.borderSubtle,
                borderWidth: DS.Border.thin,
                shadow: DS.Shadow.none,
                backgroundColor: DS.Colors.surface,
                radius: 16
            )
        } else {
            LazyVStack(spacing: DS.Spacing.sm) {
                ForEach(list) { activity in
                    ActivityRowView(
                        activity: activity,
                        executionContext: activityExecutionContextById[activity.id],
                        assignmentLabel: assignmentLabel(for: activity),
                        isStatusEditable: canEditActivity(activity),
                        pendingSyncState: vm.pendingSyncState(missionId: activeMission.id, activityId: activity.id),
                        onStatusChange: { status in
                            handleActivityStatusChange(status, for: activity, within: list)
                        },
                        allowsCompletionActions: canEditActivity(activity)
                            && missionActivityActionIsUnlocked(activity, within: allMissionActivities)
                            && !vm.hasPendingSync(missionId: activeMission.id, activityId: activity.id),
                        onNavigateTap: canOpenDirections(for: activity) ? {
                            routePreviewActivity = activity
                        } : nil
                    )
                }
            }
        }
    }

    private var activityScopePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Phạm vi theo dõi hoạt động", selection: $activityScopeFilter) {
                ForEach(ActivityScopeFilter.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            Text(activityFilterHelperText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var aggregateRouteButton: some View {
        Button {
            vm.triggerMissionActivitySync(reason: .manualRefresh)
            vm.loadActivities(missionId: activeMission.id)
            showAggregateRoute = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.info.opacity(0.12))
                        .frame(width: 34, height: 34)

                    Image(systemName: "map.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DS.Colors.info)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Lộ trình tổng hợp theo đội")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DS.Colors.text)

                    Text("Chỉ đường theo toàn bộ hoạt động chưa hoàn thành và tự cập nhật sau mỗi lần hoàn tất.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sharpCard(
                borderColor: DS.Colors.borderSubtle,
                borderWidth: DS.Border.thin,
                shadow: DS.Shadow.none,
                backgroundColor: DS.Colors.surface,
                radius: 16
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var inventorySection: some View {
        if inventoryEntryCount > 0 {
            Button {
                showMissionInventory = true
            } label: {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            DS.Colors.info.opacity(0.16),
                                            DS.Colors.info.opacity(0.06)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 52, height: 52)

                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(DS.Colors.info)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Túi đồ vật phẩm")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(DS.Colors.text)

                            Text("Theo dõi nhanh vật phẩm đang được xử lý trong toàn bộ nhiệm vụ.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DS.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DS.Colors.textTertiary)
                            .padding(.top, 6)
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(inventoryQuantityTotal)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(DS.Colors.text)

                        Text("đơn vị")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DS.Colors.textSecondary)

                        Spacer()

                        Text("\(inventoryItemTypeCount) loại vật phẩm")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DS.Colors.info)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(DS.Colors.info.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Text("Mở để xem chi tiết vật phẩm theo từng bước xử lý.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .padding(DS.Spacing.md)
                .sharpCard(
                    borderColor: DS.Colors.info.opacity(0.18),
                    borderWidth: DS.Border.thin,
                    shadow: DS.Shadow.none,
                    backgroundColor: DS.Colors.surface,
                    radius: 20
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var incidentSectionHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sự cố trong nhiệm vụ")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(DS.Colors.text)

            Text("Theo dõi tình huống phát sinh và báo ngay khi cần hỗ trợ")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
        }
    }

    private func infoChip(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(DS.Colors.text)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(DS.Colors.text)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
        }
    }

    private func missionStatusColor(_ status: String) -> Color {
        switch normalizedStatus(status) {
        case "ongoing", "inprogress":
            return DS.Colors.success
        case "planned", "pending", "scheduled":
            return DS.Colors.warning
        case "completed", "finished":
            return DS.Colors.info
        case "incompleted", "incomplete":
            return DS.Colors.accent
        case "cancelled":
            return DS.Colors.textTertiary
        default:
            return DS.Colors.textSecondary
        }
    }

    private func safetyStatusLabel(_ status: String?) -> String {
        switch normalizedStatus(status ?? "") {
        case "safe":
            return "An toàn"
        case "atrisk":
            return "Nguy cơ"
        case "soscreated":
            return "Đã tạo SOS"
        case "inactive":
            return "Tạm dừng"
        default:
            return "Chưa có"
        }
    }

    private func safetyStatusColor(_ status: String?) -> Color {
        switch normalizedStatus(status ?? "") {
        case "safe":
            return DS.Colors.success
        case "atrisk":
            return DS.Colors.warning
        case "soscreated":
            return DS.Colors.accent
        case "inactive":
            return DS.Colors.textTertiary
        default:
            return DS.Colors.info
        }
    }

    private func safetyTeamName(_ team: MissionTeam) -> String {
        let name = team.teamName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Đội của bạn" : name
    }

    private var shouldShowStartMissionButton: Bool {
        switch normalizedStatus(missionStatus) {
        case "planned", "pending", "scheduled":
            return true
        default:
            return false
        }
    }

    private var shouldShowMissionReportButton: Bool {
        guard canOpenMissionReports, viewerMissionTeamId != nil else { return false }
        guard currentTeamActivities.isEmpty == false else { return false }
        return currentTeamActivities.allSatisfy(isActivityCompletedForReport)
    }

    private var startMissionButton: some View {
        Button {
            Task {
                let didUpdate = await vm.updateMissionStatus(missionId: activeMission.id, status: "OnGoing")
                if didUpdate {
                    missionStatus = "OnGoing"
                    vm.loadActivities(missionId: activeMission.id)
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if vm.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(vm.isLoading ? "Đang bắt đầu nhiệm vụ..." : "Bắt đầu nhiệm vụ")
                    .font(.system(size: 14, weight: .bold))

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(vm.isLoading)
        .opacity(vm.isLoading ? 0.8 : 1)
    }

    private var missionReportButton: some View {
        Button {
            showMissionReport = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.info.opacity(0.14))
                        .frame(width: 34, height: 34)

                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DS.Colors.info)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Báo cáo tổng kết nhiệm vụ")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DS.Colors.text)

                    Text("Tất cả hoạt động của đội hiện tại đã hoàn thành. Mở để tổng kết và nộp báo cáo.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.info.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DS.Colors.info.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func missionTypeColor(_ missionTypeKey: String?) -> Color {
        switch missionTypeKey {
        case "rescue":
            return DS.Colors.accent
        case "evacuation", "evacuate":
            return DS.Colors.warning
        case "medical", "medicalaid", "medicalsupport":
            return DS.Colors.info
        case "supply", "supplies", "logistics", "relief":
            return DS.Colors.success
        case "mixed", "hybrid", "combined":
            return DS.Colors.textSecondary
        default:
            return DS.Colors.textSecondary
        }
    }

    private func loadMissionDetail() {
        Task {
            do {
                let detail = try await MissionService.shared.getMission(missionId: mission.id)
                missionDetail = detail
                missionStatus = detail.status
            } catch {
                // Keep the dashboard snapshot when detail hydration fails.
            }
        }
    }

    private func refreshMissionWorkspace(triggerSync: Bool = false) {
        if triggerSync {
            vm.triggerMissionActivitySync(reason: .manualRefresh)
        }
        loadMissionDetail()
        vm.loadActivities(missionId: activeMission.id)
        incidentVM.loadIncidents(missionId: activeMission.id)
    }

    private func handleActivityStatusChange(_ status: String, for activity: Activity, within knownActivities: [Activity]) {
        guard canEditActivity(activity) else { return }
        guard status.caseInsensitiveCompare("Cancelled") != .orderedSame else { return }

        if status.caseInsensitiveCompare(ActivityStatus.succeed.rawValue) == .orderedSame {
            if activity.isCollectSuppliesActivity {
                pickupConfirmationActivity = activity
                return
            }

            if activity.isDeliverSuppliesActivity {
                deliveryConfirmationActivity = activity
                return
            }

            if activity.isReturnSuppliesActivity {
                returnConfirmationActivity = activity
                return
            }

            completionProofActivity = activity
            return
        }

        vm.updateActivity(
            missionId: activeMission.id,
            activityId: activity.id,
            status: status,
            knownActivities: currentTeamActivities.isEmpty ? knownActivities : currentTeamActivities
        )
    }

    private func canEditActivity(_ activity: Activity) -> Bool {
        canUpdateActivityStatus && vm.belongsToCurrentTeam(activity, fallbackMissionTeamId: fallbackViewerMissionTeamId)
    }

    private func canOpenDirections(for activity: Activity) -> Bool {
        vm.belongsToCurrentTeam(activity, fallbackMissionTeamId: fallbackViewerMissionTeamId)
            && isActivityRouteAvailable(activity)
    }

    private var currentTeamCoordinate: CLLocationCoordinate2D? {
        guard let viewerMissionTeamId,
              let team = activeMission.teams?.first(where: { $0.id == viewerMissionTeamId }),
              let latitude = team.latitude,
              let longitude = team.longitude else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate),
              !(abs(latitude) < 0.000_001 && abs(longitude) < 0.000_001) else {
            return nil
        }

        return coordinate
    }

    private var currentTeamOriginLabel: String? {
        guard let viewerMissionTeamId,
              let team = activeMission.teams?.first(where: { $0.id == viewerMissionTeamId }) else {
            return nil
        }

        if let teamName = team.teamName?.trimmingCharacters(in: .whitespacesAndNewlines),
           teamName.isEmpty == false {
            return teamName
        }

        return team.assemblyPointName
    }

    private func isActivityRouteAvailable(_ activity: Activity) -> Bool {
        switch activity.activityStatus {
        case .planned, .onGoing:
            return activityDescriptionHasRouteInstruction(activity)
        case .succeed, .failed, .cancelled:
            return false
        }
    }

    private func assignmentLabel(for activity: Activity) -> String? {
        guard let missionTeamId = activity.missionTeamId else {
            return nil
        }

        let teamName = activeMission.teams?
            .first(where: { $0.id == missionTeamId })?
            .teamName?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if vm.belongsToCurrentTeam(activity, fallbackMissionTeamId: fallbackViewerMissionTeamId) {
            if let teamName, teamName.isEmpty == false {
                return "Đội của bạn: \(teamName)"
            }
            return "Đội của bạn"
        }

        if let teamName, teamName.isEmpty == false {
            return "Đội phối hợp: \(teamName)"
        }

        return "Đội #\(missionTeamId)"
    }

    private func normalizedStatus(_ status: String) -> String {
        RescuerStatusBadgeText.normalized(status)
    }

    private func isActivityCompletedForReport(_ activity: Activity) -> Bool {
        switch normalizedStatus(activity.status) {
        case "succeed", "completed", "reported", "failed", "cancelled":
            return true
        default:
            return false
        }
    }

    private var activityCount: Int {
        switch activityScopeFilter {
        case .myTeam:
            return displayedActivities.count
        case .all:
            return max(displayedActivities.count, activeMission.activityCount)
        }
    }

    private var completedActivityCount: Int {
        displayedActivities.filter { $0.activityStatus == .succeed }.count
    }

    private var pendingActivitySyncCount: Int {
        vm.pendingSyncCount(for: activeMission.id)
    }

    private var displayedActivities: [Activity] {
        switch activityScopeFilter {
        case .myTeam:
            return currentTeamActivities
        case .all:
            return vm.effectiveActivities(missionId: activeMission.id, fallback: activeMission.activities ?? [])
        }
    }

    private var activityExecutionContextById: [Int: MissionActivityExecutionContext] {
        buildMissionActivityExecutionContexts(activities: allMissionActivities)
    }

    private var currentTeamActivities: [Activity] {
        vm.effectiveCurrentTeamActivities(
            missionId: activeMission.id,
            fallback: activeMission.activities ?? [],
            fallbackMissionTeamId: fallbackViewerMissionTeamId
        )
    }

    private var activityProgress: Double {
        guard activityCount > 0 else { return 0 }
        return Double(completedActivityCount) / Double(activityCount)
    }

    private var inventoryActivities: [Activity] {
        displayedActivities.filter { ($0.suppliesToCollect ?? []).isEmpty == false }
    }

    private var participatingTeamNames: [String] {
        Array(Set(
            (activeMission.teams ?? []).compactMap { team in
                let trimmed = team.teamName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
        )).sorted()
    }

    private var teamSummaryTitle: String {
        participatingTeamNames.count > 1 ? "Đội tham gia" : "Đội phụ trách"
    }

    private var teamSummaryValue: String {
        guard participatingTeamNames.isEmpty == false else { return "Chưa gán" }
        if participatingTeamNames.count <= 2 {
            return participatingTeamNames.joined(separator: ", ")
        }
        return "\(participatingTeamNames.prefix(2).joined(separator: ", ")) +\(participatingTeamNames.count - 2)"
    }

    private var activitySectionSubtitle: String {
        switch activityScopeFilter {
        case .myTeam:
            if hiddenActivityCount > 0 {
                return "\(activityCount) bước của đội bạn • đang ẩn \(hiddenActivityCount) bước đội khác"
            }
            return "\(activityCount) bước của đội bạn"
        case .all:
            if participatingTeamNames.count > 1 {
                return "\(activityCount) bước cần theo dõi • \(participatingTeamNames.count) đội cùng nhiệm vụ"
            }
            return "\(activityCount) bước cần theo dõi"
        }
    }

    private var hiddenActivityCount: Int {
        max(allMissionActivities.count - currentTeamActivities.count, 0)
    }

    private var allMissionActivities: [Activity] {
        vm.effectiveActivities(missionId: activeMission.id, fallback: activeMission.activities ?? [])
    }

    private var activityFilterHelperText: String {
        switch activityScopeFilter {
        case .myTeam:
            if hiddenActivityCount > 0 {
                return "Đang ẩn \(hiddenActivityCount) hoạt động của đội khác để bạn tập trung theo dõi phần việc của đội mình."
            }
            return "Đang chỉ hiển thị hoạt động của đội bạn."
        case .all:
            return "Hoạt động của đội khác chỉ để theo dõi, không thể bấm hoàn thành hoặc thất bại."
        }
    }

    private var emptyActivitiesMessage: String {
        switch activityScopeFilter {
        case .myTeam:
            return "Hiện chưa có hoạt động nào được giao cho đội của bạn."
        case .all:
            return "Nhiệm vụ này chưa có bước thực hiện nào để theo dõi."
        }
    }

    private var inventoryEntries: [(activity: Activity, supply: MissionSupply)] {
        inventoryActivities.flatMap { activity in
            (activity.suppliesToCollect ?? []).map { (activity: activity, supply: $0) }
        }
    }

    private var inventoryEntryCount: Int {
        inventoryEntries.count
    }

    private var inventoryItemTypeCount: Int {
        Set(inventoryEntries.map {
            let name = $0.supply.itemName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Vật phẩm"
            let unit = $0.supply.unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "\(name)|\(unit)"
        }).count
    }

    private var inventoryQuantityTotal: Int {
        inventoryEntries.reduce(0) { $0 + $1.supply.quantity }
    }

    private var inventoryPendingPickupTotal: Int {
        inventoryQuantity(forTypes: ["collectsupplies"], statuses: ["planned", "pending", "scheduled", "ongoing", "inprogress"])
    }

    private var inventoryInHandTotal: Int {
        inventoryQuantity(forTypes: ["collectsupplies", "deliversupplies"], statuses: ["succeed", "completed", "ongoing", "inprogress", "planned", "pending", "scheduled"], custom: { activity, normalizedType, normalizedStatus in
            if normalizedType == "collectsupplies" {
                return normalizedStatus == "succeed" || normalizedStatus == "completed"
            }
            if normalizedType == "deliversupplies" {
                return normalizedStatus == "planned" || normalizedStatus == "pending" || normalizedStatus == "scheduled" || normalizedStatus == "ongoing" || normalizedStatus == "inprogress"
            }
            return false
        })
    }

    private var inventoryDeliveredTotal: Int {
        inventoryQuantity(forTypes: ["deliversupplies"], statuses: ["succeed", "completed"])
            + inventoryQuantity(forTypes: [], statuses: [], custom: { _, normalizedType, normalizedStatus in
                normalizedType != "collectsupplies"
                    && normalizedType != "deliversupplies"
                    && normalizedType != "returnsupplies"
                    && (normalizedStatus == "succeed" || normalizedStatus == "completed")
            })
    }

    private var restrictedNotice: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "lock.fill")
                .foregroundColor(DS.Colors.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text("Bạn chưa có quyền thao tác với nhiệm vụ này")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)

                Text("Hệ thống đang bảo vệ API nhiệm vụ và hoạt động bằng quyền động. Khi được cấp quyền phù hợp, phần hoạt động, báo cáo và sự cố sẽ tự mở.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderColor: DS.Colors.warning.opacity(0.3),
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 16
        )
    }

    private func inventoryQuantity(
        forTypes types: Set<String>,
        statuses: Set<String>,
        custom: ((Activity, String, String) -> Bool)? = nil
    ) -> Int {
        inventoryEntries.reduce(0) { partialResult, item in
            let normalizedType = (item.activity.activityType ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: "-", with: "")
                .lowercased()
            let normalizedStatus = normalizedStatus(item.activity.status)

            let matches: Bool
            if let custom {
                matches = custom(item.activity, normalizedType, normalizedStatus)
            } else {
                matches = (types.isEmpty || types.contains(normalizedType))
                    && (statuses.isEmpty || statuses.contains(normalizedStatus))
            }

            return partialResult + (matches ? item.supply.quantity : 0)
        }
    }

    private func formattedDisplayDate(_ raw: String?) -> String? {
        guard let raw, raw.isEmpty == false else { return nil }

        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]

        guard let date = isoFull.date(from: raw) ?? isoBasic.date(from: raw) else {
            return raw
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm, dd/MM/yyyy"
        return formatter.string(from: date)
    }
}
