import SwiftUI

struct IncidentTimelineView: View {
    let incidents: [Incident]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if isLoading {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                    Text("Đang tải sự cố...")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding()
            } else if incidents.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(DS.Colors.success)
                    Text("Chưa có sự cố nào được ghi nhận")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.surface)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
            } else {
                ForEach(incidents) { incident in
                    IncidentRowView(incident: incident)
                }
            }
        }
    }
}

// MARK: - Incident Row
struct IncidentRowView: View {
    let incident: Incident

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(statusColor)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        StatusBadge(text: incident.status, color: statusColor)
                        Spacer()
                        if let raw = incident.createdAt {
                            Text(formattedDate(raw))
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textTertiary)
                        }
                    }

                    if let desc = incident.description, !desc.isEmpty {
                        Text(desc)
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text)
                    }

                    // Flags
                    HStack(spacing: DS.Spacing.sm) {
                        if incident.needsAssistance == true {
                            Label("Cần hỗ trợ", systemImage: "hand.raised.fill")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.warning)
                        }
                        if incident.hasInjuredMember == true {
                            Label("Có thương vong", systemImage: "cross.fill")
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.accent)
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(statusColor.opacity(0.3), lineWidth: DS.Border.medium))
    }

    private var statusColor: Color {
        switch incident.status.lowercased() {
        case "reported":    return DS.Colors.warning
        case "acknowledged":return DS.Colors.info
        case "inprogress":  return DS.Colors.warning
        case "resolved":    return DS.Colors.success
        case "closed":      return DS.Colors.textTertiary
        default:            return DS.Colors.textSecondary
        }
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
