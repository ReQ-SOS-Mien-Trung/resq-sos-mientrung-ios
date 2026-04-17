import SwiftUI
import MapKit

// MARK: - Status Badge (shared across Rescuer views)
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(DS.Typography.caption.bold())
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .overlay(Rectangle().stroke(color.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Status Badge Text Mapping
enum RescuerStatusBadgeText {
    static func mission(_ status: String) -> String {
        switch normalized(status) {
        case "ongoing", "inprogress":
            return L10n.Domain.missionInProgress
        case "planned", "pending", "scheduled":
            return L10n.Domain.missionPlanned
        case "completed", "finished":
            return L10n.Domain.missionCompleted
        case "incompleted", "incomplete":
            return L10n.Domain.missionIncomplete
        case "cancelled":
            return L10n.Domain.missionCancelled
        default:
            return fallbackLabel(from: status)
        }
    }

    static func team(_ status: String) -> String {
        switch normalized(status) {
        case "ready", "available":
            return L10n.Domain.teamReady
        case "gathering":
            return L10n.Domain.teamGathering
        case "assigned":
            return L10n.Domain.teamAssigned
        case "onmission":
            return L10n.Domain.teamOnMission
        case "stuck":
            return L10n.Domain.teamStuck
        case "awaitingacceptance":
            return L10n.Domain.teamAwaitingAcceptance
        case "unavailable":
            return L10n.Domain.teamUnavailable
        case "disbanded":
            return L10n.Domain.teamDisbanded
        default:
            return fallbackLabel(from: status)
        }
    }

    static func activity(_ status: ActivityStatus) -> String {
        switch status {
        case .planned:
            return L10n.Domain.missionPlanned
        case .onGoing:
            return L10n.Domain.missionInProgress
        case .succeed:
            return L10n.Domain.activityCompleted
        case .failed:
            return L10n.Domain.activityFailed
        case .cancelled:
            return L10n.Domain.missionCancelled
        }
    }

    static func activity(_ rawStatus: String, fallback: ActivityStatus) -> String {
        switch normalized(rawStatus) {
        case "pendingconfirmation":
            return L10n.Domain.activityPendingWarehouseConfirmation
        default:
            return activity(fallback)
        }
    }

    static func assemblyEvent(_ status: String?) -> String {
        switch normalized(status) {
        case "scheduled", "planned":
            return L10n.Domain.assemblyScheduled
        case "gathering", "ongoing":
            return L10n.Domain.assemblyGathering
        case "completed", "finished":
            return L10n.Domain.assemblyCompleted
        case "cancelled":
            return L10n.Domain.missionCancelled
        default:
            return fallbackLabel(from: status)
        }
    }

    static func incident(_ status: String) -> String {
        switch normalized(status) {
        case "reported":
            return L10n.Domain.incidentReported
        case "inprogress":
            return L10n.Domain.incidentInProgress
        case "resolved":
            return L10n.Domain.incidentResolved
        default:
            return fallbackLabel(from: status)
        }
    }

    static func normalized(_ status: String?) -> String {
        (status ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }

    private static func fallbackLabel(from status: String?) -> String {
        let raw = (status ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard raw.isEmpty == false else {
            return L10n.Common.unknown
        }

        return raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }
}

// MARK: - Mission Row
struct MissionRowView: View {
    let mission: Mission

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mission.title)
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)
                    if let desc = mission.description, !desc.isEmpty {
                        Text(desc)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(DS.Colors.textTertiary)
            }

            HStack(spacing: DS.Spacing.sm) {
                if mission.shouldDisplayMissionTypeBadge,
                   let missionTypeBadgeText = mission.missionTypeBadgeText {
                    StatusBadge(
                        text: missionTypeBadgeText,
                        color: missionTypeColor(mission.missionTypeBadgeKey)
                    )
                }

                StatusBadge(
                    text: RescuerStatusBadgeText.mission(mission.status),
                    color: missionStatusColor(mission.status)
                )

                if mission.activityCount > 0 {
                    Label("\(mission.activityCount) bước", systemImage: "checklist")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
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
}

// MARK: - Rescuer Dashboard
struct RescuerDashboardView: View {
    @StateObject private var vm: RescuerMissionViewModel
    @StateObject private var assemblyVM: RescuerAssemblyEventsViewModel
    @ObservedObject private var authSession = AuthSessionStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isMembersExpanded = false
    @State private var showAssemblyEventsSheet = false
    @State private var showLeaveTeamConfirmation = false

    init(locationManager: LocationManager = .shared) {
        _vm = StateObject(wrappedValue: RescuerMissionViewModel(locationManager: locationManager))
        _assemblyVM = StateObject(wrappedValue: RescuerAssemblyEventsViewModel(locationManager: locationManager))
    }

    private var currentUserId: String? {
        AuthSessionStore.shared.session?.userId
    }

    private var currentUserFullName: String? {
        AuthSessionStore.shared.session?.fullName
    }

    private func normalizedIdentity(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private var currentMember: RescueTeamMember? {
        guard let members = vm.team?.members, members.isEmpty == false else { return nil }

        let normalizedUserId = normalizedIdentity(currentUserId)
        if normalizedUserId.isEmpty == false,
           let byUserId = members.first(where: { normalizedIdentity($0.userId) == normalizedUserId }) {
            return byUserId
        }

        let normalizedName = normalizedIdentity(currentUserFullName)
        if normalizedName.isEmpty == false,
           let byFullName = members.first(where: { normalizedIdentity($0.fullName) == normalizedName }) {
            return byFullName
        }

        return nil
    }

    private var isCurrentUserLeader: Bool {
        currentMember?.isLeader == true
    }

    private var normalizedTeamStatus: String {
        RescuerStatusBadgeText.normalized(vm.team?.status)
    }

    private var canSetTeamAvailable: Bool {
        ["gathering", "unavailable"].contains(normalizedTeamStatus)
    }

    private var canSetTeamUnavailable: Bool {
        ["available", "ready"].contains(normalizedTeamStatus)
    }

    private var canLeaveTeam: Bool {
        vm.canLeaveCurrentTeam
    }

    private func isCurrentUser(_ member: RescueTeamMember) -> Bool {
        let normalizedSessionId = normalizedIdentity(currentUserId)
        if normalizedSessionId.isEmpty == false,
           normalizedIdentity(member.userId) == normalizedSessionId {
            return true
        }

        let normalizedSessionName = normalizedIdentity(currentUserFullName)
        if normalizedSessionName.isEmpty == false,
           normalizedIdentity(member.fullName) == normalizedSessionName {
            return true
        }

        return false
    }

    private var isMissionAccessUnlocked: Bool {
        assemblyVM.events.contains(where: { $0.isCheckedIn })
    }

    private var canAccessRescuerWorkspace: Bool {
        authSession.session?.canAccessRescuerWorkspace ?? false
    }

    private var canViewMissionWorkspace: Bool {
        authSession.session?.canViewMissionWorkspace ?? false
    }

    private var canManageTeamAvailability: Bool {
        authSession.session?.canManageTeamAvailability ?? false
    }

    private var shouldShowMissionSection: Bool {
        canViewMissionWorkspace
    }

    private var shouldShowAssemblySection: Bool {
        guard assemblyVM.events.isEmpty == false else { return false }
        return isMissionAccessUnlocked == false || canViewMissionWorkspace == false
    }

    private var assemblyEventsSummary: String {
        if assemblyVM.isLoading && assemblyVM.events.isEmpty {
            return "Đang tải sự kiện tập kết..."
        }

        let totalCount = assemblyVM.events.count
        let checkedInCount = assemblyVM.events.filter(\.isCheckedIn).count

        guard totalCount > 0 else {
            return "Xem lịch triệu tập và xác nhận có mặt của bạn"
        }

        if checkedInCount == totalCount {
            return "Bạn đã xác nhận có mặt đầy đủ \(totalCount) sự kiện"
        }

        if checkedInCount > 0 {
            return "Bạn đã xác nhận có mặt \(checkedInCount)/\(totalCount) sự kiện"
        }

        return "Có \(totalCount) sự kiện đang chờ xác nhận"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if canAccessRescuerWorkspace == false {
                        restrictedStateView
                            .padding(.top, DS.Spacing.md)
                    } else {
                        if canViewMissionWorkspace {
                            teamCard
                                .padding(.top, DS.Spacing.md)
                        }

                        if shouldShowAssemblySection {
                            Text("TRIỆU TẬP").sectionHeader()
                                .padding(.top, canViewMissionWorkspace ? 0 : DS.Spacing.md)
                            assemblyEventsSection

                            if canViewMissionWorkspace {
                                checkInGateMessage
                            }
                        }

                        if shouldShowMissionSection {
                            Text("NHIỆM VỤ CỦA ĐỘI").sectionHeader()

                            if vm.isLoading && vm.missions.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, DS.Spacing.lg)
                            } else if vm.missions.isEmpty {
                                emptyMissionsView
                            } else {
                                missionsList
                            }
                        }
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, DS.Spacing.md)
            }
            .background(DS.Colors.background)
            .navigationTitle("Nhiệm Vụ")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(DS.Colors.accent)
                }
                if canAccessRescuerWorkspace {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            if canViewMissionWorkspace {
                                vm.refreshDashboard()
                            }

                            if isMissionAccessUnlocked == false || canViewMissionWorkspace == false {
                                assemblyVM.refresh()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .foregroundColor(DS.Colors.warning)
                        .disabled(vm.isLoading || assemblyVM.isLoading)
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
            .alert("Thông báo", isPresented: Binding(
                get: { vm.successMessage != nil },
                set: { if !$0 { vm.successMessage = nil } }
            )) {
                Button("OK", role: .cancel) { vm.successMessage = nil }
            } message: {
                Text(vm.successMessage ?? "")
            }
            .alert("Rời đội cứu hộ?", isPresented: $showLeaveTeamConfirmation) {
                Button("Ở lại", role: .cancel) {}
                Button("Rời đội", role: .destructive) {
                    vm.leaveCurrentTeam()
                }
            } message: {
                Text("Bạn sẽ rời khỏi đội cứu hộ hiện tại. Điều phối viên có thể phân đội lại cho bạn khi cần.")
            }
            .alert("Lỗi xác nhận có mặt", isPresented: Binding(
                get: { assemblyVM.errorMessage != nil },
                set: { if !$0 { assemblyVM.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { assemblyVM.errorMessage = nil }
            } message: {
                Text(assemblyVM.errorMessage ?? "")
            }
            .alert("Thông báo xác nhận có mặt", isPresented: Binding(
                get: { assemblyVM.successMessage != nil },
                set: { if !$0 { assemblyVM.successMessage = nil } }
            )) {
                Button("OK", role: .cancel) { assemblyVM.successMessage = nil }
            } message: {
                Text(assemblyVM.successMessage ?? "")
            }
            .sheet(isPresented: $showAssemblyEventsSheet) {
                RescuerAssemblyEventsView()
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            guard canAccessRescuerWorkspace else { return }

            vm.startLocationTracking()
            assemblyVM.startLocationTracking()

            if assemblyVM.events.isEmpty {
                assemblyVM.refresh()
            }

            if canViewMissionWorkspace {
                vm.refreshDashboard()
            }
        }
        .onChange(of: isMissionAccessUnlocked) { unlocked in
            if unlocked && canViewMissionWorkspace {
                vm.refreshDashboard()
            }
        }
        .onDisappear {
            vm.stopLocationTracking()
            assemblyVM.stopLocationTracking()
        }
    }

    // MARK: Team Card
    @ViewBuilder
    private var teamCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .center, spacing: DS.Spacing.xs) {
                EyebrowLabel(text: "ĐỘI CỦA BẠN")
                Spacer()

                if vm.team != nil {
                    HStack(spacing: DS.Spacing.xs) {
                        if let status = vm.team?.status {
                            StatusBadge(text: RescuerStatusBadgeText.team(status), color: teamStatusColor(status))
                        }

                        leaveTeamCompactButton
                    }
                } else if let status = vm.team?.status {
                    StatusBadge(text: RescuerStatusBadgeText.team(status), color: teamStatusColor(status))
                }
            }

            if let team = vm.team {
                Text(team.name)
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)

                VStack(alignment: .leading, spacing: 4) {
                    if let members = team.members, !members.isEmpty {
                        Text("\(members.count) thành viên")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                    }

                    if let assemblyPointName = team.assemblyPointName, !assemblyPointName.isEmpty {
                        Text("Điểm tập kết: \(assemblyPointName)")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }

                if let members = team.members, !members.isEmpty {
                    memberDropdown(members: members)
                }

                if isCurrentUserLeader && canManageTeamAvailability {
                    teamAvailabilityButton
                        .padding(.top, DS.Spacing.xs)
                } else if isCurrentUserLeader {
                    Label("Tài khoản hiện tại chưa được cấp quyền đổi trạng thái đội cứu hộ", systemImage: "lock.fill")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                        .padding(.top, DS.Spacing.xs)
                } else {
                    Label("Chỉ đội trưởng có thể đổi trạng thái sẵn sàng của đội cứu hộ", systemImage: "lock.fill")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                        .padding(.top, DS.Spacing.xs)
                }

                if canLeaveTeam == false {
                    Text("Không thể rời đội khi đội đang được phân công hoặc đang làm nhiệm vụ")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                        .padding(.top, DS.Spacing.xs)
                }
            } else if vm.isLoadingTeam {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                    Text("Đang tải thông tin đội cứu hộ...")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            } else {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(DS.Colors.warning.opacity(0.12))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle().stroke(DS.Colors.warning.opacity(0.28), lineWidth: 1)
                            )

                        Image(systemName: "person.3.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DS.Colors.warning)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bạn chưa có đội cứu hộ")
                            .font(DS.Typography.subheadline.bold())
                            .foregroundColor(DS.Colors.text)

                        Text(vm.noTeamMessage ?? "Hiện tại bạn chưa được phân vào đội cứu hộ. Vui lòng chờ điều phối viên phân công.")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            assemblyEventsTriggerButton
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(DS.Colors.warning.opacity(0.5), lineWidth: DS.Border.medium))
    }

    private var assemblyEventsTriggerButton: some View {
        Button {
            showAssemblyEventsSheet = true
        } label: {
            HStack(alignment: .center, spacing: DS.Spacing.xs) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.Colors.info)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sự kiện điểm tập kết")
                        .font(DS.Typography.subheadline.bold())
                        .foregroundColor(DS.Colors.text)

                    Text(assemblyEventsSummary)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.sm)
            .background(DS.Colors.info.opacity(0.08))
            .overlay(Rectangle().stroke(DS.Colors.info.opacity(0.28), lineWidth: DS.Border.thin))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sự kiện điểm tập kết")
    }

    @ViewBuilder
    private var teamAvailabilityButton: some View {
        if canSetTeamAvailable {
            Button { vm.setTeamAvailable() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                    Text(vm.isUpdatingTeamAvailability ? "ĐANG CẬP NHẬT" : "SẴN SÀNG NHẬN NHIỆM VỤ")
                        .font(DS.Typography.caption.bold())
                        .tracking(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .foregroundColor(.white)
                .background(DS.Colors.success)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .disabled(vm.isUpdatingTeamAvailability)
        } else if canSetTeamUnavailable {
            Button { vm.setTeamUnavailable() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pause.circle")
                    Text(vm.isUpdatingTeamAvailability ? "ĐANG CẬP NHẬT" : "TẠM NGƯNG NHẬN NHIỆM VỤ")
                        .font(DS.Typography.caption.bold())
                        .tracking(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .foregroundColor(.white)
                .background(DS.Colors.accent)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .disabled(vm.isUpdatingTeamAvailability)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal")
                Text("TRẠNG THÁI ĐÃ CẬP NHẬT")
                    .font(DS.Typography.caption.bold())
                    .tracking(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .foregroundColor(DS.Colors.textTertiary)
            .background(DS.Colors.background)
            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }

    private var leaveTeamCompactButton: some View {
        Button {
            showLeaveTeamConfirmation = true
        } label: {
            ZStack {
                if vm.isLeavingTeam {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(canLeaveTeam ? .red : DS.Colors.textTertiary)
                } else {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .frame(width: 34, height: 34)
            .foregroundColor(canLeaveTeam ? .red : DS.Colors.textTertiary)
            .background(canLeaveTeam ? Color.red.opacity(0.08) : DS.Colors.background)
            .overlay(
                Rectangle()
                    .stroke(canLeaveTeam ? Color.red.opacity(0.35) : DS.Colors.border, lineWidth: DS.Border.thin)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .buttonStyle(.plain)
        .disabled(vm.isLeavingTeam || vm.isUpdatingTeamAvailability || canLeaveTeam == false)
        .accessibilityLabel("Rời đội")
    }

    // MARK: Missions List
    private var missionsList: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(vm.missions) { mission in
                NavigationLink(destination: MissionDetailView(mission: mission)) {
                    MissionRowView(mission: mission)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Empty State
    private var emptyMissionsView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(DS.Colors.textTertiary)
            Text("Chưa có nhiệm vụ nào")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.textSecondary)
            Text("Đội cứu hộ của bạn chưa được giao nhiệm vụ")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.lg * 2)
    }

    private var checkInGateMessage: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(DS.Colors.info)

            VStack(alignment: .leading, spacing: 4) {
                Text("Xác nhận có mặt để mở nhiệm vụ")
                    .font(DS.Typography.subheadline.bold())
                    .foregroundColor(DS.Colors.text)

                Text("Sau khi bạn bấm Xác nhận có mặt ở phần Triệu tập & Xác nhận có mặt, thông tin Đội cứu hộ của bạn và Nhiệm vụ của đội sẽ hiển thị.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(DS.Colors.info.opacity(0.3), lineWidth: DS.Border.medium))
    }

    @ViewBuilder
    private var assemblyEventsSection: some View {
        if assemblyVM.isLoading && assemblyVM.events.isEmpty {
            HStack(spacing: DS.Spacing.sm) {
                ProgressView()
                Text("Đang tải sự kiện triệu tập...")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
        } else if assemblyVM.events.isEmpty {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(DS.Colors.textTertiary)
                Text("Hiện chưa có sự kiện triệu tập")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.textSecondary)
                Text("Khi người điều phối tạo phiên tập trung, bạn sẽ thấy lịch triệu tập và có thể xác nhận có mặt ngay tại đây.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
            .background(DS.Colors.surface)
            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
        } else {
            VStack(spacing: DS.Spacing.sm) {
                ForEach(assemblyVM.events) { event in
                    AssemblyEventRowView(
                        event: event,
                        hasCheckedOut: assemblyVM.hasCheckedOut(event: event),
                        isCheckingIn: assemblyVM.loadingEventId == event.eventId && assemblyVM.loadingAction == .checkIn,
                        isCheckingOut: assemblyVM.loadingEventId == event.eventId && assemblyVM.loadingAction == .checkOut,
                        allowsCheckOut: assemblyVM.isTeamAssignedOrOnMission == false,
                        onCheckIn: { assemblyVM.checkIn(event: event) },
                        onCheckOut: { assemblyVM.checkOut(event: event) }
                    )
                }
            }
        }
    }

    private func teamStatusColor(_ status: String) -> Color {
        switch normalizedStatus(status) {
        case "ready", "available":
            return DS.Colors.success
        case "gathering", "assigned", "onmission":
            return DS.Colors.warning
        case "stuck":
            return DS.Colors.accent
        case "awaitingacceptance", "unavailable":
            return DS.Colors.textSecondary
        case "disbanded":
            return DS.Colors.textTertiary
        default:
            return DS.Colors.textSecondary
        }
    }

    private func normalizedStatus(_ status: String) -> String {
        RescuerStatusBadgeText.normalized(status)
    }

    @ViewBuilder
    private func memberDropdown(members: [RescueTeamMember]) -> some View {
        let sortedMembers = members.sorted { lhs, rhs in
            if lhs.isLeader != rhs.isLeader {
                return lhs.isLeader && !rhs.isLeader
            }
            return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        }

        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isMembersExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Danh sách thành viên")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.text)

                    Spacer()

                    Image(systemName: isMembersExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.background)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
            }
            .buttonStyle(.plain)

            if isMembersExpanded {
                VStack(spacing: DS.Spacing.xxs) {
                    ForEach(sortedMembers) { member in
                        let isCurrentUserMember = isCurrentUser(member)

                        HStack(spacing: DS.Spacing.xs) {
                            TeamMemberAvatarView(member: member)

                            Text(member.fullName)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text)
                                .lineLimit(1)

                            Spacer()

                            Text(member.isLeader ? "Đội trưởng" : "Thành viên")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(isCurrentUserMember ? DS.Colors.accent.opacity(0.06) : DS.Colors.background)
                        .overlay(
                            Rectangle().stroke(
                                isCurrentUserMember ? DS.Colors.accent.opacity(0.5) : DS.Colors.border.opacity(0.8),
                                lineWidth: DS.Border.thin
                            )
                        )
                    }
                }
            }
        }
    }

    private var restrictedStateView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            EyebrowLabel(text: "TRUY CẬP BỊ GIỚI HẠN")

            Text("Tài khoản hiện tại chưa được cấp quyền truy cập khu vực nhiệm vụ cứu hộ.")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)

            Text("Ứng dụng đang đồng bộ quyền từ /identity/user/me. Khi hệ thống cấp một trong các quyền nhiệm vụ, hoạt động hoặc nhân sự liên quan, nút truy cập sẽ tự hiển thị.")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
    }
}

private struct TeamMemberAvatarView: View {
    let member: RescueTeamMember

    private var avatarSize: CGFloat { 30 }
    private let defaultAvatarURLString = "https://res.cloudinary.com/dezgwdrfs/image/upload/v1773504004/611251674_1432765175119052_6622750233977483141_n_sgxqxd.png"

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let avatarURL {
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(DS.Colors.warning)
                                .scaleEffect(0.7)
                                .frame(width: avatarSize, height: avatarSize)
                                .background(DS.Colors.background)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: avatarSize, height: avatarSize)
                        case .failure:
                            initialsFallback
                        @unknown default:
                            initialsFallback
                        }
                    }
                } else {
                    initialsFallback
                }
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(
                    member.isLeader ? DS.Colors.warning.opacity(0.9) : DS.Colors.border,
                    lineWidth: member.isLeader ? 1.5 : 1
                )
            )

            if member.isLeader {
                Image(systemName: "crown.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(DS.Colors.warning)
                    .padding(3)
                    .background(DS.Colors.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DS.Colors.warning.opacity(0.7), lineWidth: 1))
                    .offset(x: 2, y: 2)
            }
        }
    }

    private var avatarURL: URL? {
        if let raw = member.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
           raw.isEmpty == false,
           let memberURL = makeURL(from: raw) {
            return memberURL
        }

        return makeURL(from: defaultAvatarURLString)
    }

    private func makeURL(from raw: String) -> URL? {
        if let directURL = URL(string: raw) {
            return directURL
        }

        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: encoded)
        }

        return nil
    }

    private var initialsFallback: some View {
        ZStack {
            Circle()
                .fill(DS.Colors.warning.opacity(0.14))

            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DS.Colors.warning)
            } else {
                Text(initials)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(DS.Colors.warning)
            }
        }
        .frame(width: avatarSize, height: avatarSize)
    }

    private var initials: String {
        member.fullName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
}

struct RescuerAssemblyEventsView: View {
    @StateObject private var vm: RescuerAssemblyEventsViewModel
    @Environment(\.dismiss) private var dismiss

    init(locationManager: LocationManager = .shared) {
        _vm = StateObject(wrappedValue: RescuerAssemblyEventsViewModel(locationManager: locationManager))
    }

    private var checkedInCount: Int {
        vm.events.filter(\.isCheckedIn).count
    }

    private var pendingCount: Int {
        max(vm.events.count - checkedInCount, 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    headerSection
                        .padding(.top, DS.Spacing.md)

                    Text("TẤT CẢ SỰ KIỆN").sectionHeader()

                    contentSection

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, DS.Spacing.md)
            }
            .background(DS.Colors.background)
            .navigationTitle("Điểm tập kết")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.accent)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Làm mới") {
                        vm.refresh()
                    }
                    .foregroundColor(DS.Colors.accent)
                    .disabled(vm.isLoading)
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
        .alert("Thông báo", isPresented: Binding(
            get: { vm.successMessage != nil },
            set: { if !$0 { vm.successMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.successMessage = nil }
        } message: {
            Text(vm.successMessage ?? "")
        }
        .onAppear {
            vm.startLocationTracking()
            if vm.events.isEmpty {
                vm.refresh()
            }
        }
        .onDisappear {
            vm.stopLocationTracking()
        }
        .refreshable {
            vm.refresh()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(DS.Colors.info)
                    .frame(width: 30, height: 30)
                    .background(DS.Colors.info.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

                VStack(alignment: .leading, spacing: 3) {
                    EyebrowLabel(text: "Triệu tập & Xác nhận có mặt", color: DS.Colors.info)
                    Text("Theo dõi sự kiện điểm tập kết và xác nhận có mặt đúng phiên tập trung của bạn.")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if vm.events.isEmpty == false {
                HStack(spacing: DS.Spacing.xs) {
                    summaryPill(
                        title: "Đã xác nhận có mặt",
                        value: "\(checkedInCount)",
                        color: DS.Colors.success
                    )

                    summaryPill(
                        title: "Chờ xác nhận",
                        value: "\(pendingCount)",
                        color: DS.Colors.warning
                    )
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(DS.Colors.info.opacity(0.35), lineWidth: DS.Border.medium))
    }

    private func summaryPill(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)

            Text(value)
                .font(DS.Typography.caption.bold())
                .foregroundColor(color)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .overlay(Rectangle().stroke(color.opacity(0.3), lineWidth: DS.Border.thin))
    }

    @ViewBuilder
    private var contentSection: some View {
        if vm.isLoading && vm.events.isEmpty {
            HStack(spacing: DS.Spacing.sm) {
                ProgressView()
                Text("Đang tải sự kiện...")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, DS.Spacing.lg)
        } else if vm.events.isEmpty {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(DS.Colors.textTertiary)
                Text("Hiện chưa có sự kiện tập kết")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.textSecondary)
                Text("Khi tổng đài tạo phiên tập trung cho đội của bạn, sự kiện sẽ hiển thị tại đây.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Spacing.lg)
        } else {
            VStack(spacing: DS.Spacing.sm) {
                ForEach(vm.events) { event in
                    AssemblyEventRowView(
                        event: event,
                        hasCheckedOut: vm.hasCheckedOut(event: event),
                        isCheckingIn: vm.loadingEventId == event.eventId && vm.loadingAction == .checkIn,
                        isCheckingOut: vm.loadingEventId == event.eventId && vm.loadingAction == .checkOut,
                        allowsCheckOut: vm.isTeamAssignedOrOnMission == false,
                        onCheckIn: { vm.checkIn(event: event) },
                        onCheckOut: { vm.checkOut(event: event) }
                    )
                }
            }
        }
    }
}

private struct AssemblyEventRowView: View {
    let event: AssemblyPointEvent
    let hasCheckedOut: Bool
    let isCheckingIn: Bool
    let isCheckingOut: Bool
    let allowsCheckOut: Bool
    let onCheckIn: () -> Void
    let onCheckOut: () -> Void

    private struct AssemblyPointAnnotation: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }

    private var statusText: String {
        RescuerStatusBadgeText.assemblyEvent(event.eventStatus)
    }

    private var canCheckIn: Bool {
        event.isCheckedIn == false
            && hasCheckedOut == false
            && ["gathering", "ongoing", "planned", "scheduled"].contains(normalizedStatus)
    }

    private var canCheckOut: Bool {
        allowsCheckOut
            && hasCheckedOut == false
            && event.isCheckedIn
            && ["gathering", "ongoing"].contains(normalizedStatus)
    }

    private var normalizedStatus: String {
        RescuerStatusBadgeText.normalized(event.eventStatus)
    }

    private var assemblyCoordinate: CLLocationCoordinate2D? {
        guard let latitude = event.assemblyPointLatitude,
              let longitude = event.assemblyPointLongitude,
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var mapRegion: MKCoordinateRegion {
        let center = assemblyCoordinate ?? CLLocationCoordinate2D(latitude: 16.4637, longitude: 107.5909)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.assemblyPointName ?? "Điểm tập kết #\(event.assemblyPointId)")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)
                    Text(eventLabel)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                Spacer()
                StatusBadge(text: statusText, color: statusColor)
            }

            if let assemblyDateText = formattedDate(event.assemblyDate) {
                Label(assemblyDateText, systemImage: "calendar")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }

            mapSection

            if event.isCheckedIn && hasCheckedOut == false {
                Label(
                    formattedDate(event.checkInTime).map { "Đã xác nhận có mặt lúc \($0)" } ?? "Đã xác nhận có mặt",
                    systemImage: "checkmark.seal.fill"
                )
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.success)
            }

            if hasCheckedOut {
                Label(
                    formattedDate(event.checkOutTime).map { "Đã xác nhận rời đi lúc \($0)" } ?? "Đã xác nhận rời đi",
                    systemImage: "rectangle.portrait.and.arrow.right"
                )
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.warning)
            } else if event.isCheckedIn {
                if allowsCheckOut {
                    Button(action: onCheckOut) {
                        HStack(spacing: DS.Spacing.xs) {
                            if isCheckingOut {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                            }

                            Text(canCheckOut ? "Xác nhận rời đi" : "Không thể xác nhận rời đi")
                                .font(DS.Typography.caption)
                                .tracking(1)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(canCheckOut ? DS.Colors.warning : DS.Colors.textTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .disabled(isCheckingOut || canCheckOut == false)
                }
            } else {
                Button(action: onCheckIn) {
                    HStack(spacing: DS.Spacing.xs) {
                        if isCheckingIn {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "location.fill")
                        }

                        Text("Xác nhận có mặt")
                            .font(DS.Typography.caption)
                            .tracking(1)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.success)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .disabled(isCheckingIn || canCheckIn == false)
            }

        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
    }

    private var eventLabel: String {
        if let assemblyPointCode = event.assemblyPointCode,
           assemblyPointCode.isEmpty == false {
            return assemblyPointCode
        }

        return "Mã sự kiện #\(event.eventId)"
    }

    @ViewBuilder
    private var mapSection: some View {
        if let coordinate = assemblyCoordinate {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Map(
                    coordinateRegion: .constant(mapRegion),
                    annotationItems: [AssemblyPointAnnotation(coordinate: coordinate)]
                ) { item in
                    MapMarker(coordinate: item.coordinate, tint: DS.Colors.accent)
                }
                .frame(height: 168)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(DS.Colors.borderSubtle, lineWidth: DS.Border.thin)
                )

                Button {
                    openInMaps(coordinate: coordinate)
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "map")
                        Text("Mở chỉ đường đến điểm tập kết")
                            .font(DS.Typography.caption)
                            .tracking(0.4)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundColor(DS.Colors.info)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.info.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .stroke(DS.Colors.info.opacity(0.26), lineWidth: DS.Border.thin)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func openInMaps(coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = event.assemblyPointName ?? "Điểm tập kết"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private var statusColor: Color {
        switch normalizedStatus {
        case "gathering":
            return DS.Colors.warning
        case "ongoing":
            return DS.Colors.success
        case "planned", "scheduled":
            return DS.Colors.info
        case "finished", "completed":
            return DS.Colors.textSecondary
        case "cancelled":
            return DS.Colors.accent
        default:
            return DS.Colors.textSecondary
        }
    }

    private func formattedDate(_ rawValue: String?) -> String? {
        guard let rawValue, rawValue.isEmpty == false else { return nil }

        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoNoFraction = ISO8601DateFormatter()
        isoNoFraction.formatOptions = [.withInternetDateTime]

        guard let date = isoWithFraction.date(from: rawValue) ?? isoNoFraction.date(from: rawValue) else {
            return rawValue
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm, dd/MM/yyyy"
        return formatter.string(from: date)
    }
}
