import SwiftUI

struct IncidentTimelineView: View {
    let incidents: [Incident]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if isLoading {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .tint(DS.Colors.accent)
                    Text("Đang tải sự cố...")
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
            } else if incidents.isEmpty {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DS.Colors.accent)
                        .frame(width: 42, height: 42)
                        .background(DS.Colors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chưa có sự cố nào được ghi nhận")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(DS.Colors.text)

                        Text("Mọi hoạt động trong nhiệm vụ hiện đang ổn định.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DS.Colors.textSecondary)
                    }
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
            } else {
                ForEach(incidents) { incident in
                    IncidentRowView(incident: incident)
                }
            }
        }
    }
}

struct IncidentRowView: View {
    let incident: Incident

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(statusColor)
                        .font(.system(size: 16, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        StatusBadge(text: RescuerStatusBadgeText.incident(incident.status), color: statusColor)
                        Spacer()
                        if let raw = incident.createdAt {
                            Text(formattedDate(raw))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DS.Colors.textTertiary)
                        }
                    }

                    if let desc = incident.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(DS.Colors.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: DS.Spacing.xs) {
                        if incident.needsAssistance == true {
                            incidentFlag(
                                title: "Cần hỗ trợ",
                                icon: "hand.raised.fill",
                                tint: DS.Colors.accent
                            )
                        }
                        if incident.hasInjuredMember == true {
                            incidentFlag(
                                title: "Có thương vong",
                                icon: "cross.fill",
                                tint: DS.Colors.accent
                            )
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderColor: statusColor.opacity(0.18),
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 16
        )
    }

    private var statusColor: Color {
        switch RescuerStatusBadgeText.normalized(incident.status) {
        case "reported":
            return DS.Colors.accent
        case "acknowledged":
            return DS.Colors.info
        case "inprogress":
            return DS.Colors.accent
        case "resolved":
            return DS.Colors.success
        case "closed":
            return DS.Colors.textTertiary
        default:
            return DS.Colors.textSecondary
        }
    }

    private func incidentFlag(title: String, icon: String, tint: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.1))
            .clipShape(Capsule())
    }

    private func formattedDate(_ raw: String) -> String {
        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]
        let date = isoFull.date(from: raw) ?? isoBasic.date(from: raw)
        guard let date else { return raw }

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm dd/MM"
        return fmt.string(from: date)
    }
}
