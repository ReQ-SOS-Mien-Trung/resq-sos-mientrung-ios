import SwiftUI

struct SosSelectionView: View {
    @ObservedObject var vm: VictimChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            header

            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        if vm.sosRequests.isEmpty {
                            emptyState
                        }

                        ForEach(vm.sosRequests) { sos in
                            Button {
                                Task { await vm.linkSosRequest(sos.id) }
                            } label: {
                                sosCard(for: sos)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.xl)
                }
            }
        }
        .background(DS.Colors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            EyebrowLabel(text: "YÊU CẦU CỦA BẠN")
            Text("Chọn SOS\nCần Hỗ Trợ")
                .font(DS.Typography.title)
                .foregroundColor(DS.Colors.text)

            Text("Chạm vào một yêu cầu để kết nối nhanh với điều phối viên.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)

            EditorialDivider(height: DS.Border.thick)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(DS.Colors.textTertiary)

            Text("Chưa có yêu cầu SOS")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)

            Text("Hãy tạo yêu cầu mới để bắt đầu nhận hỗ trợ.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .sharpCard(shadow: DS.Shadow.small, backgroundColor: DS.Colors.surface, radius: DS.Radius.md)
    }

    @ViewBuilder
    private func sosCard(for sos: SosRequestDto) -> some View {
        let localizedStatus = SosDisplayFormatter.localizedStatus(sos.status)
        let statusTint = statusColor(for: sos.status)

        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxxs) {
                    Text("SOS #\(sos.id)")
                        .font(DS.Typography.headline.monospacedDigit())
                        .foregroundColor(DS.Colors.text)

                    Text("Nhấn để chọn yêu cầu")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textTertiary)
                }

                Spacer(minLength: DS.Spacing.sm)

                statusBadge(title: localizedStatus, tint: statusTint)
            }

            if let localizedType = SosDisplayFormatter.localizedType(sos.sosType) {
                HStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.caption2)
                    Text(localizedType)
                        .font(DS.Typography.subheadline)
                        .lineLimit(1)
                }
                .foregroundColor(DS.Colors.textSecondary)
            }

            Text(condensedMessage(sos.msg))
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .lineLimit(3)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: DS.Spacing.xs) {
                if let localizedPriority = SosDisplayFormatter.localizedPriority(sos.priorityLevel) {
                    metadataChip(
                        icon: "flag.fill",
                        text: localizedPriority,
                        tint: priorityColor(for: sos.priorityLevel)
                    )
                }

                if let wait = sos.waitTimeMinutes {
                    metadataChip(icon: "clock.fill", text: "~\(wait) phút", tint: DS.Colors.warning)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(statusTint.opacity(0.22), lineWidth: DS.Border.thin)
        )
        .shadow(
            color: DS.Shadow.small.color,
            radius: DS.Shadow.small.radius,
            x: DS.Shadow.small.x,
            y: DS.Shadow.small.y
        )
    }

    private func statusBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(DS.Typography.caption)
            .foregroundColor(tint)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }

    private func metadataChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: DS.Spacing.xxxs) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(DS.Typography.caption)
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.xxs)
        .background(tint.opacity(0.13))
        .clipShape(Capsule())
    }

    private func condensedMessage(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func priorityColor(for rawPriority: String?) -> Color {
        switch SosDisplayFormatter.normalizedKey(rawPriority) {
        case "critical", "urgent":
            return DS.Colors.danger
        case "high":
            return DS.Colors.warning
        case "medium", "normal":
            return DS.Colors.info
        case "low":
            return DS.Colors.success
        default:
            return DS.Colors.textSecondary
        }
    }

    private func statusColor(for rawStatus: String) -> Color {
        switch SosDisplayFormatter.normalizedKey(rawStatus) {
        case "pending", "waiting", "queued", "new":
            return DS.Colors.warning
        case "approved", "accepted", "assigned", "inprogress", "ongoing", "processing":
            return DS.Colors.info
        case "resolved", "closed", "completed", "done":
            return DS.Colors.success
        case "rejected", "declined", "cancelled", "canceled", "cancel":
            return DS.Colors.danger
        default:
            return DS.Colors.textSecondary
        }
    }
}
