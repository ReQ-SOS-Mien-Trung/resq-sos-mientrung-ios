import SwiftUI

struct ReportIncidentView: View {
    private enum IncidentReportRoute: String, Hashable {
        case activity
        case mission
    }

    let mission: Mission
    let activities: [Activity]
    @ObservedObject var incidentVM: IncidentViewModel

    @Environment(\.dismiss) private var dismiss

    private var missionTeamId: Int? {
        mission.missionTeamId
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                headerSection

                if missionTeamId != nil {
                    NavigationLink(value: IncidentReportRoute.activity) {
                        chooserCard(
                            eyebrow: "ACTIVITY",
                            title: "Báo sự cố activity",
                            description: "Dùng khi activity gặp vấn đề cần hỗ trợ, đổi thiết bị, đổi phương tiện hoặc thêm đội.",
                            outcome: "Phù hợp với sự cố cục bộ, có thể ảnh hưởng một hoặc nhiều activity nhưng chưa làm toàn đội mất khả năng tiếp tục mission.",
                            icon: "figure.run.square.stack.fill",
                            tone: DS.Colors.warning
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: IncidentReportRoute.mission) {
                        chooserCard(
                            eyebrow: "MISSION",
                            title: "Báo sự cố mission",
                            description: "Dùng khi toàn đội không thể tiếp tục nhiệm vụ hoặc cần giải cứu khẩn.",
                            outcome: "Phù hợp với tình huống ảnh hưởng toàn nhiệm vụ: mắc kẹt, nhiều người bị thương, mất phương tiện chính hoặc buộc dừng / bàn giao mission.",
                            icon: "shield.lefthalf.filled.trianglebadge.exclamationmark",
                            tone: DS.Colors.danger
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    IncidentFormSection(
                        title: "Không tìm thấy thông tin team",
                        subtitle: "Mission hiện tại chưa có `missionTeamId`, nên chưa thể mở form báo sự cố mới."
                    ) {
                        IncidentInlineNotice(
                            icon: "exclamationmark.triangle.fill",
                            text: "Hãy thử tải lại mission hoặc kiểm tra dữ liệu team được gán từ backend.",
                            tone: DS.Colors.danger
                        )
                    }
                }
            }
            .padding(DS.Spacing.md)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .navigationTitle("Báo sự cố")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: IncidentReportRoute.self) { route in
            if let missionTeamId {
                switch route {
                case .activity:
                    ActivityIncidentReportFormView(
                        mission: mission,
                        missionTeamId: missionTeamId,
                        activities: activities,
                        incidentVM: incidentVM
                    )
                case .mission:
                    MissionIncidentReportFormView(
                        mission: mission,
                        missionTeamId: missionTeamId,
                        activities: activities,
                        incidentVM: incidentVM
                    )
                }
            }
        }
        .alert("Lỗi", isPresented: Binding(
            get: { incidentVM.errorMessage != nil },
            set: { if !$0 { incidentVM.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { incidentVM.errorMessage = nil }
        } message: {
            Text(incidentVM.errorMessage ?? "")
        }
        .onChange(of: incidentVM.successMessage) { message in
            guard message != nil else { return }
            incidentVM.loadIncidents(missionId: mission.id)
            dismiss()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            EyebrowLabel(text: "CHỌN LOẠI BÁO CÁO")
            Text("Đừng để user phải tự suy luận mình đang báo loại nào.")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(DS.Colors.text)

            Text("Chọn đúng entry point ngay từ đầu để form mở đúng logic điều phối phía sau.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
        }
    }

    private func chooserCard(
        eyebrow: String,
        title: String,
        description: String,
        outcome: String,
        icon: String,
        tone: Color
    ) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tone.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(tone)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                EyebrowLabel(text: eyebrow, color: tone)
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(DS.Colors.text)
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(outcome)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DS.Colors.textTertiary)
                .padding(.top, 6)
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderColor: tone.opacity(0.22),
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 18
        )
    }
}
