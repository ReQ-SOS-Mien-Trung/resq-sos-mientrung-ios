import SwiftUI

struct MissionDetailView: View {
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
    @State private var missionStatus: String

    init(mission: Mission) {
        self.mission = mission
        _missionStatus = State(initialValue: mission.status)
    }

    private var missionTeamId: Int? { mission.missionTeamId }

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
                        subtitle: "\(activityCount) bước cần theo dõi"
                    )

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
                            refreshMissionWorkspace()
                        } label: {
                            Label("Làm mới", systemImage: "arrow.clockwise")
                        }

                        if canReportMissionIncidents {
                            Button {
                                showReportIncident = true
                            } label: {
                                Label("Báo cáo sự cố", systemImage: "exclamationmark.triangle")
                            }
                        }

                        if shouldShowMissionReportMenuItem {
                            Button {
                                showMissionReport = true
                            } label: {
                                Label("Báo cáo nhiệm vụ", systemImage: "doc.text")
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
                mission: mission,
                activities: displayedActivities,
                incidentVM: incidentVM
            )
        }
        .navigationDestination(isPresented: $showMissionReport) {
            if let teamId = missionTeamId {
                MissionTeamReportView(
                    missionId: mission.id,
                    missionTeamId: teamId,
                    missionTitle: mission.title
                )
            }
        }
        .sheet(isPresented: $showAggregateRoute) {
            NavigationStack {
                MissionAggregateRouteSheetView(mission: mission, vm: vm)
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
                    missionTitle: mission.title,
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
                ) { bufferUsages in
                    await vm.confirmPickup(
                        missionId: mission.id,
                        activityId: activity.id,
                        bufferUsages: bufferUsages
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
                ) { actualDeliveredItems, deliveryNote in
                    await vm.confirmDelivery(
                        missionId: mission.id,
                        activityId: activity.id,
                        actualDeliveredItems: actualDeliveredItems,
                        deliveryNote: deliveryNote
                    )
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

                    Text(mission.title)
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(DS.Colors.text)
                        .fixedSize(horizontal: false, vertical: true)

                    if mission.shouldDisplayMissionTypeBadge,
                       let missionTypeBadgeText = mission.missionTypeBadgeText {
                        StatusBadge(
                            text: missionTypeBadgeText,
                            color: missionTypeColor(mission.missionTypeBadgeKey)
                        )
                    }
                }

                Spacer(minLength: DS.Spacing.sm)

                StatusBadge(
                    text: RescuerStatusBadgeText.mission(missionStatus),
                    color: missionStatusColor(missionStatus)
                )
            }

            if let desc = mission.description, !desc.isEmpty {
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
                    value: formattedDisplayDate(mission.startDate) ?? "Chưa có",
                    icon: "calendar"
                )

                infoChip(
                    title: "Kết thúc dự kiến",
                    value: formattedDisplayDate(mission.endDate) ?? "Chưa có",
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
                    title: "Đội phụ trách",
                    value: mission.teams?.first?.teamName ?? "Chưa gán",
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
                Text("Nhiệm vụ này chưa có bước thực hiện nào được phân công cho đội.")
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
                        onStatusChange: { status in
                            handleActivityStatusChange(status, for: activity)
                        },
                        allowsCompletionActions: canUpdateActivityStatus && isActivityActionUnlocked(activity, within: list)
                    )
                }
            }
        }
    }

    private var aggregateRouteButton: some View {
        Button {
            vm.loadActivities(missionId: mission.id)
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
                    Text("Lộ trình tổng hợp theo team")
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

                            Text("Theo dõi nhanh vật phẩm đội đang cần lấy, đang giữ và đã giao trong nhiệm vụ.")
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

                    HStack(spacing: DS.Spacing.sm) {
                        inventoryMetricTile(
                            title: "Cần lấy",
                            value: inventoryPendingPickupTotal,
                            color: DS.Colors.warning,
                            icon: "tray.and.arrow.down.fill"
                        )

                        inventoryMetricTile(
                            title: "Đang giữ",
                            value: inventoryInHandTotal,
                            color: DS.Colors.accent,
                            icon: "shippingbox.circle.fill"
                        )

                        inventoryMetricTile(
                            title: "Đã giao",
                            value: inventoryDeliveredTotal,
                            color: DS.Colors.success,
                            icon: "checkmark.circle.fill"
                        )
                    }

                    Text("Mở để xem chi tiết từng vật phẩm theo bước và trạng thái xử lý.")
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

    private func inventoryMetricTile(title: String, value: Int, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)

            Text("\(value)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(DS.Colors.text)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.sm)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        )
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

    private var shouldShowStartMissionButton: Bool {
        switch normalizedStatus(missionStatus) {
        case "planned", "pending", "scheduled":
            return true
        default:
            return false
        }
    }

    private var shouldShowMissionReportMenuItem: Bool {
        guard canOpenMissionReports, missionTeamId != nil else { return false }

        switch normalizedStatus(missionStatus) {
        case "completed", "finished":
            return true
        default:
            return false
        }
    }

    private var startMissionButton: some View {
        Button {
            Task {
                let didUpdate = await vm.updateMissionStatus(missionId: mission.id, status: "OnGoing")
                if didUpdate {
                    missionStatus = "OnGoing"
                    vm.loadActivities(missionId: mission.id)
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

    private func refreshMissionWorkspace() {
        vm.loadActivities(missionId: mission.id)
        incidentVM.loadIncidents(missionId: mission.id)
    }

    private func handleActivityStatusChange(_ status: String, for activity: Activity) {
        guard canUpdateActivityStatus else { return }
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
        }

        vm.updateActivity(missionId: mission.id, activityId: activity.id, status: status)
    }

    private func normalizedStatus(_ status: String) -> String {
        RescuerStatusBadgeText.normalized(status)
    }

    private var activityCount: Int {
        max(displayedActivities.count, mission.activityCount)
    }

    private var completedActivityCount: Int {
        displayedActivities.filter { $0.activityStatus == .succeed }.count
    }

    private var displayedActivities: [Activity] {
        let source = vm.activities.isEmpty ? (mission.activities ?? []) : vm.activities

        return source.sorted { lhs, rhs in
            switch (lhs.step, rhs.step) {
            case let (l?, r?):
                if l != r { return l < r }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            return lhs.id < rhs.id
        }
    }

    private var activityProgress: Double {
        guard activityCount > 0 else { return 0 }
        return Double(completedActivityCount) / Double(activityCount)
    }

    private var inventoryActivities: [Activity] {
        displayedActivities.filter { ($0.suppliesToCollect ?? []).isEmpty == false }
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

                Text("Backend đang bảo vệ các API mission và activity bằng permission động. Khi được cấp quyền phù hợp, phần hoạt động, báo cáo và sự cố sẽ tự mở.")
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

    private func isActivityActionUnlocked(_ activity: Activity, within list: [Activity]) -> Bool {
        guard let currentStep = activity.step, currentStep > 1 else {
            return true
        }

        let previousSteps = list.filter { candidate in
            guard let candidateStep = candidate.step else { return false }
            return candidateStep < currentStep
        }

        guard previousSteps.isEmpty == false else {
            return true
        }

        return previousSteps.allSatisfy { $0.activityStatus == .succeed }
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
