import SwiftUI

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
                StatusBadge(text: mission.status, color: missionStatusColor(mission.status))

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
        case "ongoing":
            return DS.Colors.success
        case "planned":
            return DS.Colors.warning
        case "completed":
            return DS.Colors.info
        case "incompleted":
            return DS.Colors.accent
        default:
            return DS.Colors.textSecondary
        }
    }

    private func normalizedStatus(_ status: String) -> String {
        status
            .replacingOccurrences(of: "_", with: "")
            .lowercased()
    }
}

// MARK: - Rescuer Dashboard
struct RescuerDashboardView: View {
    @StateObject private var vm = RescuerMissionViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var isMembersExpanded = false
    @State private var showAssemblyEvents = false

    private var currentUserId: String? {
        AuthSessionStore.shared.session?.userId
    }

    private var currentMember: RescueTeamMember? {
        guard let currentUserId else { return nil }
        return vm.team?.members?.first(where: { $0.userId == currentUserId })
    }

    private var hasCheckedIn: Bool {
        currentMember?.checkedIn == true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
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
                        vm.refreshDashboard()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .foregroundColor(DS.Colors.warning)
                    .disabled(vm.isLoading)
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
            .sheet(isPresented: $showAssemblyEvents) {
                NavigationStack {
                    RescuerAssemblyEventsView()
                }
            }
        }
        .onAppear {
            vm.refreshDashboard()
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
                    StatusBadge(text: status, color: teamStatusColor(status))
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

                Button {
                    showAssemblyEvents = true
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "calendar.badge.clock")
                        Text("SỰ KIỆN ĐIỂM TẬP KẾT")
                            .font(DS.Typography.subheadline).tracking(1)
                    }
                    .foregroundColor(DS.Colors.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.background)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                }
                .padding(.top, DS.Spacing.xs)

                Button { vm.checkIn() } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: hasCheckedIn ? "checkmark.circle.fill" : "checkmark.circle")
                        Text(hasCheckedIn ? "ĐÃ CHECK-IN" : "CHECK-IN NHANH")
                            .font(DS.Typography.subheadline).tracking(1)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(hasCheckedIn ? DS.Colors.textTertiary : DS.Colors.success)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
                .padding(.top, DS.Spacing.xs)
                .disabled(vm.isLoading || hasCheckedIn)
            } else {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                    Text("Đang tải thông tin team...")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(DS.Colors.warning.opacity(0.5), lineWidth: DS.Border.medium))
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
        status
            .replacingOccurrences(of: "_", with: "")
            .lowercased()
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
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: member.isLeader ? "crown.fill" : "person.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(member.isLeader ? DS.Colors.warning : DS.Colors.textSecondary)
                                .frame(width: 14)

                            Text(member.fullName)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text)

                            Spacer()

                            Text(member.isLeader ? "Đội trưởng" : "Thành viên")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(DS.Colors.background)
                        .overlay(Rectangle().stroke(DS.Colors.border.opacity(0.8), lineWidth: DS.Border.thin))
                    }
                }
            }
        }
    }
}

struct RescuerAssemblyEventsView: View {
    @StateObject private var vm = RescuerAssemblyEventsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                    .padding(.top, DS.Spacing.md)

                Text("SỰ KIỆN CỦA BẠN").sectionHeader()

                contentSection

                Spacer(minLength: 80)
            }
            .padding(.horizontal, DS.Spacing.md)
        }
        .background(DS.Colors.background)
        .navigationTitle("Điểm Tập Kết")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Đóng") { dismiss() }
                    .foregroundColor(DS.Colors.accent)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    vm.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .foregroundColor(DS.Colors.warning)
                .disabled(vm.isLoading)
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
            EyebrowLabel(text: "CHECK-IN SỰ KIỆN")
            Text("Theo dõi sự kiện điểm tập kết và check-in đúng phiên tập trung của bạn.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(DS.Colors.warning.opacity(0.5), lineWidth: DS.Border.medium))
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

    private var statusText: String {
        event.eventStatus ?? "Unknown"
    }

    private var canCheckIn: Bool {
        event.isCheckedIn == false && ["gathering", "ongoing", "planned"].contains(normalizedStatus)
    }

    private var normalizedStatus: String {
        (event.eventStatus ?? "")
            .replacingOccurrences(of: "_", with: "")
            .lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.assemblyPointName ?? "Điểm tập kết #\(event.assemblyPointId)")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)
                    Text("Mã sự kiện #\(event.eventId)")
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

                    Text(event.isCheckedIn ? "ĐÃ CHECK-IN" : "CHECK-IN SỰ KIỆN")
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

    private var statusColor: Color {
        switch normalizedStatus {
        case "gathering":
            return DS.Colors.warning
        case "ongoing":
            return DS.Colors.success
        case "planned":
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

        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
