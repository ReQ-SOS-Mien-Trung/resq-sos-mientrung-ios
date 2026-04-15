import SwiftUI

struct NotificationCenterView: View {
    @ObservedObject var notificationHub: NotificationHubService
    @ObservedObject private var navigationCoordinator = AppNavigationCoordinator.shared
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
            .navigationTitle("Thông báo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                }

                if notificationHub.unreadCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Đọc hết") {
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

            Text("Chưa có thông báo")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)

            Text("Danh sách thông báo từ server và broadcast FCM sẽ hiển thị tại đây.")
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
                navigationCoordinator.handleNotificationTap(notification)
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
                        ResQBadge(text: displayTypeLabel(for: type), color: iconColor(for: notification))
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
        case "team_assigned", "team_invitation", "coordinator_join", "coordinator_leave":
            return "person.2.fill"
        case "supply_request", "supply_request_urgent", "supply_request_high_escalation", "supply_request_urgent_escalation", "supply_accepted", "supply_preparing", "supply_shipped", "supply_completed", "supply_rejected", "supply_request_auto_rejected", "fund_allocation":
            return "shippingbox.fill"
        default:
            return "bell.fill"
        }
    }

    private func iconColor(for notification: RealtimeNotification) -> Color {
        switch notification.type?.lowercased() {
        case "flood_alert", "supply_rejected", "supply_request_auto_rejected", "supply_request_urgent", "supply_request_urgent_escalation":
            return DS.Colors.danger
        case "supply_accepted", "supply_preparing", "supply_shipped", "supply_completed", "fund_allocation":
            return DS.Colors.success
        case "chat_message":
            return DS.Colors.info
        case "supply_request", "supply_request_high_escalation":
            return DS.Colors.warning
        default:
            return DS.Colors.warning
        }
    }

    private func displayTypeLabel(for rawType: String) -> String {
        switch rawType.lowercased() {
        case "assembly_gathering":
            return "Thông báo triệu tập"
        case "assembly_point_assignment":
            return "Cập nhật điểm tập kết"
        case "team_assigned", "team_invitation":
            return "Thông báo đội cứu hộ"
        case "chat_message":
            return "Tin nhắn mới"
        case "fund_allocation":
            return "Quỹ kho được cấp mới"
        case "flood_alert":
            return "Cảnh báo lũ"
        case "coordinator_join":
            return "Người điều phối đã tham gia"
        case "coordinator_leave":
            return "Người điều phối đã rời"
        case "supply_request":
            return "Yêu cầu cung cấp vật tư mới"
        case "supply_request_urgent":
            return "Yêu cầu tiếp tế khẩn cấp"
        case "supply_accepted":
            return "Yêu cầu tiếp tế được chấp nhận"
        case "supply_request_auto_rejected":
            return "Hệ thống tự động từ chối yêu cầu"
        case "supply_request_high_escalation":
            return "Yêu cầu vào ngưỡng gấp"
        case "supply_request_urgent_escalation":
            return "Yêu cầu vào ngưỡng khẩn cấp"
        case "supply_preparing":
            return "Kho nguồn đang chuẩn bị hàng"
        case "supply_shipped":
            return "Vật tư đang được vận chuyển"
        case "supply_completed":
            return "Kho nguồn đã hoàn tất giao hàng"
        case "supply_rejected":
            return "Yêu cầu tiếp tế bị từ chối"
        case "general":
            return "Thông báo"
        default:
            return "Thông báo"
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm, dd/MM"
        return formatter
    }()
}
