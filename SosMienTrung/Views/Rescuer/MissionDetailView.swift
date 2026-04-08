import SwiftUI

struct MissionDetailView: View {
    let mission: Mission
    @StateObject private var vm = RescuerMissionViewModel()
    @StateObject private var incidentVM = IncidentViewModel()
    @ObservedObject private var authSession = AuthSessionStore.shared
    @State private var showReportIncident = false
    @State private var showAggregateRoute = false
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
                        title: "Danh sách hoạt động",
                        subtitle: "\(activityCount) hoạt động cần theo dõi"
                    )

                    activitiesSection

                    sectionHeader(
                        title: "Báo cáo nhiệm vụ",
                        subtitle: "Cập nhật kết quả và tiến độ của đội"
                    )

                    reportSection

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
                    Button {
                        vm.loadActivities(missionId: mission.id)
                        incidentVM.loadIncidents(missionId: mission.id)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .foregroundColor(DS.Colors.accent)
                }
            }
        }
        .sheet(isPresented: $showReportIncident) {
            if let teamId = missionTeamId {
                ReportIncidentView(
                    missionTeamId: teamId,
                    activities: displayedActivities,
                    incidentVM: incidentVM,
                    missionId: mission.id
                )
            } else {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(DS.Colors.accent)
                    Text("Không tìm thấy thông tin team")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding()
                .presentationDetents([.medium])
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
        .alert("Lỗi", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onAppear {
            guard canViewMissionWorkspace else { return }
            vm.loadActivities(missionId: mission.id)
            incidentVM.loadIncidents(missionId: mission.id)
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
                    title: "Số hoạt động",
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
                Text("Đang tải hoạt động...")
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
                Text("Chưa có hoạt động nào")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.textSecondary)
                Text("Nhiệm vụ này chưa có hoạt động được phân công cho team.")
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
                            guard canUpdateActivityStatus else { return }

                            guard status.caseInsensitiveCompare("Cancelled") != .orderedSame else {
                                return
                            }

                            vm.updateActivity(missionId: mission.id, activityId: activity.id, status: status)
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
    private var reportSection: some View {
        if canOpenMissionReports, let teamId = missionTeamId {
            NavigationLink(destination: MissionTeamReportView(
                missionId: mission.id,
                missionTeamId: teamId,
                missionTitle: mission.title
            )) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DS.Colors.accent)
                        .frame(width: 42, height: 42)
                        .background(DS.Colors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mở báo cáo đội")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(DS.Colors.text)

                        Text("Lưu nháp, cập nhật kết quả từng hoạt động và nộp báo cáo cuối kỳ.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let teamStatus = mission.teams?.first?.status, teamStatus.isEmpty == false {
                            StatusBadge(text: teamStatus, color: missionStatusColor(teamStatus))
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .padding(DS.Spacing.md)
                .sharpCard(
                    borderColor: DS.Colors.borderSubtle,
                    borderWidth: DS.Border.thin,
                    shadow: DS.Shadow.none,
                    backgroundColor: DS.Colors.surface,
                    radius: 16
                )
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(DS.Colors.warning)
                Text(canOpenMissionReports
                    ? "Không tìm thấy đội được gán với nhiệm vụ này để mở báo cáo."
                    : "Tài khoản hiện tại chưa được cấp quyền mở báo cáo đội.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sharpCard(
                borderColor: DS.Colors.warning.opacity(0.25),
                borderWidth: DS.Border.thin,
                shadow: DS.Shadow.none,
                backgroundColor: DS.Colors.surface,
                radius: 16
            )
        }
    }

    private var incidentSectionHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sự cố trong nhiệm vụ")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(DS.Colors.text)

                Text("Theo dõi tình huống phát sinh và báo ngay khi cần hỗ trợ")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            if canReportMissionIncidents {
                Button { showReportIncident = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Báo sự cố")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 10)
                    .background(DS.Colors.accent)
                    .clipShape(Capsule())
                }
            }
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

    private var shouldShowStartMissionButton: Bool {
        switch normalizedStatus(missionStatus) {
        case "planned", "pending", "scheduled":
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
