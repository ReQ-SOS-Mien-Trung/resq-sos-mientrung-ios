import SwiftUI

struct MissionDetailView: View {
    let mission: Mission
    @StateObject private var vm = RescuerMissionViewModel()
    @StateObject private var incidentVM = IncidentViewModel()
    @State private var showReportIncident = false

    private var missionTeamId: Int? { mission.missionTeamId }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                missionHeader
                    .padding(.top, DS.Spacing.md)

                Text("DANH SÁCH HOẠT ĐỘNG").sectionHeader()

                activitiesSection

                Text("BAO CAO THUC DIA").sectionHeader()

                reportSection

                incidentSectionHeader

                IncidentTimelineView(incidents: incidentVM.incidents, isLoading: incidentVM.isLoading)

                Spacer(minLength: 80)
            }
            .padding(.horizontal, DS.Spacing.md)
        }
        .background(DS.Colors.background)
        .navigationTitle("Chi tiết nhiệm vụ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    vm.loadActivities(missionId: mission.id)
                    incidentVM.loadIncidents(missionId: mission.id)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .foregroundColor(DS.Colors.warning)
            }
        }
        .sheet(isPresented: $showReportIncident) {
            if let teamId = missionTeamId {
                ReportIncidentView(missionTeamId: teamId, incidentVM: incidentVM, missionId: mission.id)
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
            vm.loadActivities(missionId: mission.id)
            incidentVM.loadIncidents(missionId: mission.id)
        }
    }

    // MARK: - Mission Header
    private var missionHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            StatusBadge(
                text: RescuerStatusBadgeText.mission(mission.status),
                color: missionStatusColor(mission.status)
            )

            Text(mission.title)
                .font(DS.Typography.largeTitle)
                .foregroundColor(DS.Colors.text)

            if let desc = mission.description, !desc.isEmpty {
                Text(desc)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.textSecondary)
            }

            if let start = mission.startDate {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "calendar")
                        .foregroundColor(DS.Colors.textTertiary)
                    Text(start)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                    if let end = mission.endDate {
                        Text("→ \(end)")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
    }

    // MARK: - Activities
    @ViewBuilder
    private var activitiesSection: some View {
        let list = vm.activities.isEmpty ? (mission.activities ?? []) : vm.activities
        if vm.isLoadingActivities && list.isEmpty {
            HStack(spacing: DS.Spacing.sm) {
                ProgressView()
                Text("Đang tải hoạt động...")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .padding()
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
        } else {
            VStack(spacing: DS.Spacing.sm) {
                ForEach(list) { activity in
                    ActivityRowView(activity: activity) { status in
                        vm.updateActivity(missionId: mission.id, activityId: activity.id, status: status)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var reportSection: some View {
        if let teamId = missionTeamId {
            NavigationLink(destination: MissionTeamReportView(
                missionId: mission.id,
                missionTeamId: teamId,
                missionTitle: mission.title
            )) {
                HStack(spacing: DS.Spacing.md) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(DS.Colors.accent)
                            Text("Mo man bao cao doi")
                                .font(DS.Typography.headline)
                                .foregroundColor(DS.Colors.text)
                        }

                        Text("Luu nhap, cap nhat ket qua tung activity va nop bao cao cuoi cho doi.")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)

                        if let teamStatus = mission.teams?.first?.status, teamStatus.isEmpty == false {
                            StatusBadge(text: teamStatus, color: missionStatusColor(teamStatus))
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(DS.Colors.textTertiary)
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.surface)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(DS.Colors.warning)
                Text("Khong tim thay doi duoc gan voi nhiem vu nay de mo bao cao.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.surface)
            .overlay(Rectangle().stroke(DS.Colors.warning.opacity(0.35), lineWidth: DS.Border.medium))
        }
    }

    // MARK: - Incident Section Header
    private var incidentSectionHeader: some View {
        HStack {
            Text("SỰ CỐ TRONG NHIỆM VỤ").sectionHeader()
            Spacer()
            Button { showReportIncident = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Báo sự cố")
                        .font(DS.Typography.caption.bold())
                }
                .foregroundColor(DS.Colors.accent)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.accent.opacity(0.1))
                .overlay(Rectangle().stroke(DS.Colors.accent.opacity(0.4), lineWidth: 1))
            }
        }
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
        RescuerStatusBadgeText.normalized(status)
    }
}
