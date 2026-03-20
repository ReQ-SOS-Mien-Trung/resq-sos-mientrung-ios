import SwiftUI

struct ActivityRowView: View {
    let activity: Activity
    let onStatusChange: (String) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header row
            HStack(spacing: DS.Spacing.sm) {
                statusIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.title)
                        .font(DS.Typography.subheadline.bold())
                        .foregroundColor(DS.Colors.text)
                    if let desc = activity.description, !desc.isEmpty {
                        Text(desc)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(isExpanded ? nil : 1)
                    }
                }
                Spacer()
                StatusBadge(text: activity.status, color: activityStatusColor(activity.activityStatus))
            }

            // Action buttons — only when activity can still progress
            if availableActions.isEmpty == false {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(availableActions) { action in
                            actionButton(action)
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        ForEach(availableActions) { action in
                            actionButton(action)
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(borderColor, lineWidth: DS.Border.medium))
        .onTapGesture { isExpanded.toggle() }
    }

    // MARK: - Status Icon
    private var statusIcon: some View {
        Group {
            switch activity.activityStatus {
            case .succeed:   Image(systemName: "checkmark.circle.fill").foregroundColor(DS.Colors.success)
            case .onGoing:   Image(systemName: "arrow.triangle.2.circlepath.circle.fill").foregroundColor(DS.Colors.warning)
            case .failed:    Image(systemName: "xmark.circle.fill").foregroundColor(DS.Colors.accent)
            case .cancelled: Image(systemName: "minus.circle.fill").foregroundColor(DS.Colors.textTertiary)
            case .planned:   Image(systemName: "circle").foregroundColor(DS.Colors.textSecondary)
            }
        }
        .font(.system(size: 20))
    }

    // MARK: - Border Color
    private var borderColor: Color {
        switch activity.activityStatus {
        case .succeed:   return DS.Colors.success.opacity(0.5)
        case .onGoing:   return DS.Colors.warning.opacity(0.5)
        case .failed:    return DS.Colors.accent.opacity(0.5)
        default:         return DS.Colors.border
        }
    }

    // MARK: - Action Button
    private var availableActions: [ActivityAction] {
        switch activity.activityStatus {
        case .planned:
            return [
                ActivityAction(label: "Bắt đầu", icon: "play.fill", color: DS.Colors.warning, status: "OnGoing"),
                ActivityAction(label: "Hủy", icon: "minus.circle.fill", color: DS.Colors.textTertiary, status: "Cancelled")
            ]
        case .onGoing:
            return [
                ActivityAction(label: "Hoàn thành", icon: "checkmark.circle.fill", color: DS.Colors.success, status: "Succeed"),
                ActivityAction(label: "Thất bại", icon: "xmark.circle.fill", color: DS.Colors.accent, status: "Failed"),
                ActivityAction(label: "Hủy", icon: "minus.circle.fill", color: DS.Colors.textTertiary, status: "Cancelled")
            ]
        default:
            return []
        }
    }

    private func actionButton(_ action: ActivityAction) -> some View {
        Button { onStatusChange(action.status) } label: {
            HStack(spacing: 4) {
                Image(systemName: action.icon)
                Text(action.label)
                    .font(DS.Typography.caption.bold())
            }
            .foregroundColor(action.color)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(action.color.opacity(0.1))
            .overlay(Rectangle().stroke(action.color.opacity(0.4), lineWidth: 1))
        }
    }

    private func activityStatusColor(_ status: ActivityStatus) -> Color {
        switch status {
        case .succeed:   return DS.Colors.success
        case .onGoing:   return DS.Colors.warning
        case .failed:    return DS.Colors.accent
        case .cancelled: return DS.Colors.textTertiary
        case .planned:   return DS.Colors.textSecondary
        }
    }
}

private struct ActivityAction: Identifiable {
    let id: String
    let label: String
    let icon: String
    let color: Color
    let status: String

    init(label: String, icon: String, color: Color, status: String) {
        self.id = status
        self.label = label
        self.icon = icon
        self.color = color
        self.status = status
    }
}
