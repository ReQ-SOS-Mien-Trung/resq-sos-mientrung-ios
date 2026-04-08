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
            return "Đang thực hiện"
        case "planned", "pending", "scheduled":
            return "Đã lên kế hoạch"
        case "completed", "finished":
            return "Đã hoàn thành"
        case "incompleted", "incomplete":
            return "Chưa hoàn thành"
        case "cancelled":
            return "Đã hủy"
        default:
            return fallbackLabel(from: status)
        }
    }

    static func team(_ status: String) -> String {
        switch normalized(status) {
        case "ready", "available":
            return "Sẵn sàng"
        case "gathering":
            return "Tập kết"
        case "assigned":
            return "Đã phân công"
        case "onmission":
            return "Đang làm nhiệm vụ"
        case "stuck":
            return "Gặp sự cố"
        case "awaitingacceptance":
            return "Chờ xác nhận"
        case "unavailable":
            return "Không sẵn sàng"
        case "disbanded":
            return "Đã giải tán"
        default:
            return fallbackLabel(from: status)
        }
    }

    static func activity(_ status: ActivityStatus) -> String {
        switch status {
        case .planned:
            return "Đã lên kế hoạch"
        case .onGoing:
            return "Đang thực hiện"
        case .succeed:
            return "Hoàn thành"
        case .failed:
            return "Thất bại"
        case .cancelled:
            return "Đã hủy"
        }
    }

    static func assemblyEvent(_ status: String?) -> String {
        switch normalized(status) {
        case "scheduled", "planned":
            return "Đã lên lịch"
        case "gathering", "ongoing":
            return "Đang tập trung"
        case "completed", "finished":
            return "Đã hoàn tất"
        case "cancelled":
            return "Đã hủy"
        default:
            return fallbackLabel(from: status)
        }
    }

    static func incident(_ status: String) -> String {
        switch normalized(status) {
        case "reported":
            return "Đã báo cáo"
        case "inprogress":
            return "Đang xử lý"
        case "resolved":
            return "Đã xử lý"
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
            return "Không xác định"
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
                    Label("\(mission.activityCount) hoạt động", systemImage: "checklist")
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
    @StateObject private var vm = RescuerMissionViewModel()
    @StateObject private var assemblyVM = RescuerAssemblyEventsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var isMembersExpanded = false
    @State private var showAssemblyEventsSheet = false

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

    private var assemblyEventsSummary: String {
        if assemblyVM.isLoading && assemblyVM.events.isEmpty {
            return "Đang tải sự kiện tập kết..."
        }

        let totalCount = assemblyVM.events.count
        let checkedInCount = assemblyVM.events.filter(\.isCheckedIn).count

        guard totalCount > 0 else {
            return "Xem lịch triệu tập và check-in của bạn"
        }

        if checkedInCount == totalCount {
            return "Bạn đã check-in đầy đủ \(totalCount) sự kiện"
        }

        if checkedInCount > 0 {
            return "Bạn đã check-in \(checkedInCount)/\(totalCount) sự kiện"
        }

        return "Có \(totalCount) sự kiện đang chờ check-in"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if isMissionAccessUnlocked {
                        teamCard
                            .padding(.top, DS.Spacing.md)

                        Text("NHIỆM VỤ CỦA TEAM").sectionHeader()

                        if vm.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, DS.Spacing.lg)
                        } else if vm.missions.isEmpty {
                            emptyMissionsView
                        } else {
                            missionsList
                        }
                    } else {
                        Text("TRIỆU TẬP").sectionHeader()
                            .padding(.top, DS.Spacing.md)

                        assemblyEventsSection

                        checkInGateMessage
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if isMissionAccessUnlocked {
                            vm.refreshDashboard()
                        } else {
                            assemblyVM.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .foregroundColor(DS.Colors.warning)
                    .disabled(vm.isLoading || assemblyVM.isLoading)
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
            .alert("Lỗi check-in", isPresented: Binding(
                get: { assemblyVM.errorMessage != nil },
                set: { if !$0 { assemblyVM.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { assemblyVM.errorMessage = nil }
            } message: {
                Text(assemblyVM.errorMessage ?? "")
            }
            .alert("Thông báo check-in", isPresented: Binding(
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
            if assemblyVM.events.isEmpty {
                assemblyVM.refresh()
            }

            if isMissionAccessUnlocked {
                vm.refreshDashboard()
            }
        }
        .onChange(of: isMissionAccessUnlocked) { unlocked in
            if unlocked {
                vm.refreshDashboard()
            }
        }
    }

    // MARK: Team Card
    @ViewBuilder
    private var teamCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(DS.Colors.warning)
                EyebrowLabel(text: "TEAM CỦA BẠN")
                Spacer()

                if let status = vm.team?.status {
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

                assemblyEventsTriggerButton

                if isCurrentUserLeader {
                    teamAvailabilityButton
                    .padding(.top, DS.Spacing.xs)
                } else {
                    Label("Chỉ đội trưởng có thể đổi trạng thái sẵn sàng của team", systemImage: "lock.fill")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                        .padding(.top, DS.Spacing.xs)
                }
            } else if vm.isLoadingTeam {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                    Text("Đang tải thông tin team...")
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
                        Text("Bạn chưa có team")
                            .font(DS.Typography.subheadline.bold())
                            .foregroundColor(DS.Colors.text)

                        Text(vm.noTeamMessage ?? "Hiện tại bạn chưa được phân vào đội cứu hộ. Vui lòng chờ điều phối viên phân công.")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
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
            Text("Team của bạn chưa được giao nhiệm vụ")
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

                Text("Sau khi bạn bấm Xác nhận có mặt ở phần Triệu tập & Check-in, thông tin Team của bạn và Nhiệm vụ của team sẽ hiển thị.")
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
                Text("Khi tổng đài tạo phiên tập trung, bạn sẽ thấy lịch triệu tập và có thể check-in ngay tại đây.")
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
                        isCheckingIn: assemblyVM.loadingEventId == event.eventId,
                        onCheckIn: { assemblyVM.checkIn(event: event) }
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
    @StateObject private var vm = RescuerAssemblyEventsViewModel()
    @Environment(\.dismiss) private var dismiss

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
            if vm.events.isEmpty {
                vm.refresh()
            }
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
                    EyebrowLabel(text: "Triệu tập & Check-in", color: DS.Colors.info)
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
                        title: "Đã check-in",
                        value: "\(checkedInCount)",
                        color: DS.Colors.success
                    )

                    summaryPill(
                        title: "Chờ check-in",
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
                        isCheckingIn: vm.loadingEventId == event.eventId,
                        onCheckIn: { vm.checkIn(event: event) }
                    )
                }
            }
        }
    }
}

private struct AssemblyEventRowView: View {
    let event: AssemblyPointEvent
    let isCheckingIn: Bool
    let onCheckIn: () -> Void

    private struct AssemblyPointAnnotation: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }

    private var statusText: String {
        RescuerStatusBadgeText.assemblyEvent(event.eventStatus)
    }

    private var canCheckIn: Bool {
        event.isCheckedIn == false && ["gathering", "ongoing", "planned", "scheduled"].contains(normalizedStatus)
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

            if event.isCheckedIn {
                Label(
                    formattedDate(event.checkInTime).map { "Đã check-in lúc \($0)" } ?? "Đã check-in",
                    systemImage: "checkmark.seal.fill"
                )
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.success)
            }

            Button(action: onCheckIn) {
                HStack(spacing: DS.Spacing.xs) {
                    if isCheckingIn {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: event.isCheckedIn ? "checkmark.circle.fill" : "location.fill")
                    }

                    Text(event.isCheckedIn ? "ĐÃ CHECK-IN" : "Xác nhận có mặt")
                        .font(DS.Typography.caption)
                        .tracking(1)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .background(event.isCheckedIn ? DS.Colors.textTertiary : DS.Colors.success)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .disabled(isCheckingIn || canCheckIn == false)
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
