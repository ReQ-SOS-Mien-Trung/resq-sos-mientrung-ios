import SwiftUI

struct NotificationCenterView: View {
    @ObservedObject var notificationHub: NotificationHubService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    if notificationHub.notifications.isEmpty && notificationHub.isSyncing == false {
                        emptyState
                    } else {
                        ForEach(notificationHub.notifications) { notification in
                            notificationCard(notification)
                        }
                    }
                }
                .padding(DS.Spacing.md)
            }
            .refreshable {
                await notificationHub.syncNotifications()
            }
            .background(DS.Colors.background)
            .navigationTitle("Thong bao")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Dong") {
                        dismiss()
                    }
                }

                if notificationHub.unreadCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Doc het") {
                            Task {
                                await notificationHub.markAllAsRead()
                            }
                        }
                    }
                }
            }
        }
        .task {
            await notificationHub.syncNotifications()
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)

            Text("Chua co thong bao")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)

            Text("Danh sach thong bao tu server va broadcast FCM se hien thi tai day.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxxl)
        .sharpCard(
            shadow: DS.Shadow.small,
            backgroundColor: DS.Colors.surface
        )
    }

    private func notificationCard(_ notification: RealtimeNotification) -> some View {
        Button {
            Task {
                await notificationHub.markAsRead(notification)
            }
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: iconName(for: notification))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(iconColor(for: notification))
                        .frame(width: 28, height: 28)
                        .background(iconColor(for: notification).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(notification.displayTitle)
                                .font(DS.Typography.headline)
                                .foregroundColor(DS.Colors.text)

                            if notification.isRead == false {
                                Circle()
                                    .fill(DS.Colors.danger)
                                    .frame(width: 8, height: 8)
                            }
                        }

                        Text(notification.displayMessage)
                            .font(DS.Typography.subheadline)
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                HStack {
                    if let type = notification.type, !type.isEmpty {
                        ResQBadge(text: type.uppercased(), color: iconColor(for: notification))
                    }

                    Spacer()

                    if let createdAt = notification.createdAt {
                        Text(Self.timestampFormatter.string(from: createdAt))
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textMuted)
                    }
                }
            }
            .padding(DS.Spacing.md)
            .sharpCard(
                borderColor: notification.isRead ? DS.Colors.border : iconColor(for: notification).opacity(0.5),
                borderWidth: DS.Border.thin,
                shadow: DS.Shadow.small,
                backgroundColor: notification.isRead ? DS.Colors.surface : DS.Colors.surface.opacity(0.98)
            )
        }
        .buttonStyle(.plain)
    }

    private func iconName(for notification: RealtimeNotification) -> String {
        switch notification.type?.lowercased() {
        case "flood_alert":
            return "exclamationmark.triangle.fill"
        case "chat_message":
            return "message.fill"
        case "team_invitation", "coordinator_join", "coordinator_leave":
            return "person.2.fill"
        case "supply_accepted", "supply_preparing", "supply_shipped", "supply_completed", "supply_request", "supply_rejected":
            return "shippingbox.fill"
        default:
            return "bell.fill"
        }
    }

    private func iconColor(for notification: RealtimeNotification) -> Color {
        switch notification.type?.lowercased() {
        case "flood_alert", "supply_rejected":
            return DS.Colors.danger
        case "supply_accepted", "supply_preparing", "supply_shipped", "supply_completed":
            return DS.Colors.success
        case "chat_message":
            return DS.Colors.info
        default:
            return DS.Colors.warning
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm, dd/MM"
        return formatter
    }()
}
