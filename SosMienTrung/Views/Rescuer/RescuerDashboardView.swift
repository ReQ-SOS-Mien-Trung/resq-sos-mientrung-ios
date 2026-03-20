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

                Button { vm.checkIn() } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: hasCheckedIn ? "checkmark.circle.fill" : "checkmark.circle")
                        Text(hasCheckedIn ? "ĐÃ XÁC NHẬN CÓ MẶT" : "XÁC NHẬN CÓ MẶT")
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
}
