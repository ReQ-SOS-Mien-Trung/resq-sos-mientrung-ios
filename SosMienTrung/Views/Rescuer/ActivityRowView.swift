import SwiftUI

struct ActivityRowView: View {
    let activity: Activity
    let executionContext: MissionActivityExecutionContext?
    let assignmentLabel: String?
    let isStatusEditable: Bool
    let pendingSyncState: MissionActivitySyncState?
    let onStatusChange: (String) -> Void
    let onNavigateTap: (() -> Void)?
    let allowsCompletionActions: Bool
    let isNavigateLoading: Bool

    @State private var isExpanded = false

    init(
        activity: Activity,
        executionContext: MissionActivityExecutionContext? = nil,
        assignmentLabel: String? = nil,
        isStatusEditable: Bool = true,
        pendingSyncState: MissionActivitySyncState? = nil,
        onStatusChange: @escaping (String) -> Void,
        allowsCompletionActions: Bool = true,
        isNavigateLoading: Bool = false,
        onNavigateTap: (() -> Void)? = nil
    ) {
        self.activity = activity
        self.executionContext = executionContext
        self.assignmentLabel = assignmentLabel
        self.isStatusEditable = isStatusEditable
        self.pendingSyncState = pendingSyncState
        self.onStatusChange = onStatusChange
        self.allowsCompletionActions = allowsCompletionActions
        self.isNavigateLoading = isNavigateLoading
        self.onNavigateTap = onNavigateTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    statusIcon

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: DS.Spacing.xs) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    if let step = activity.step {
                                        stepBadge(step)
                                    }

                                    Text(displayTitle)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(DS.Colors.text)
                                        .multilineTextAlignment(.leading)
                                }

                                if let subtitle = subtitleText {
                                    Text(subtitle)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(DS.Colors.textSecondary)
                                        .multilineTextAlignment(.leading)
                                }

                                if let executionContext {
                                    executionContextView(executionContext)
                                }
                            }

                            Spacer(minLength: DS.Spacing.xs)

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(DS.Colors.textTertiary)
                                .padding(.top, 4)
                        }

                        if let desc = activity.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DS.Colors.textSecondary)
                                .lineLimit(isExpanded ? nil : 1)
                                .multilineTextAlignment(.leading)
                        }

                        if isExpanded, let activityImageURL {
                            activityProofThumbnail(activityImageURL)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            if supplyItems.isEmpty == false {
                supplyOverviewSection
            }

            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                activityStatusBadge

                if let pendingSyncState {
                    pendingSyncBadge(pendingSyncState)
                }

                if let estimatedTime = activity.estimatedTime, estimatedTime > 0 {
                    Label("~\(estimatedTime) phút", systemImage: "timer")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DS.Colors.textSecondary)
                }

                Spacer()
            }

            if onNavigateTap != nil {
                Button {
                    onNavigateTap?()
                } label: {
                    HStack(spacing: 8) {
                        if isNavigateLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "location.viewfinder")
                                .font(.system(size: 14, weight: .semibold))
                        }

                        Text(isNavigateLoading ? "Đang tải lộ trình..." : "Xem lộ trình bước này")
                            .font(.system(size: 13, weight: .semibold))

                        Spacer()

                        if isNavigateLoading == false {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .foregroundColor(DS.Colors.info)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DS.Colors.info.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DS.Colors.info.opacity(0.28), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isNavigateLoading)
            }

            if availableActions.isEmpty == false {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Divider()
                        .overlay(DS.Colors.divider)

                    Text("Thao tác")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DS.Colors.textSecondary)

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

            if isExpanded, detailItems.isEmpty == false {
                Divider()
                    .overlay(DS.Colors.divider)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(detailItems) { item in
                        HStack(alignment: .top, spacing: DS.Spacing.sm) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DS.Colors.textSecondary)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DS.Colors.textSecondary)

                                Text(item.value)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(DS.Colors.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderColor: borderColor,
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 16
        )
    }

    private var activityStatusBadge: some View {
        let badgeColor = activityStatusBadgeColor(activity.status, fallback: activity.activityStatus)

        return HStack(spacing: 6) {
            Image(systemName: activityStatusBadgeSymbol(activity.status, fallback: activity.activityStatus))
                .font(.system(size: 11, weight: .bold))

            Text(RescuerStatusBadgeText.activity(activity.status, fallback: activity.activityStatus))
                .font(.system(size: 13, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(badgeColor.opacity(0.14))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(badgeColor.opacity(0.45), lineWidth: 1.2)
        )
        .shadow(color: badgeColor.opacity(0.12), radius: 4, x: 0, y: 2)
    }

    private func pendingSyncBadge(_ state: MissionActivitySyncState) -> some View {
        let color = pendingSyncBadgeColor(state)

        return HStack(spacing: 6) {
            Image(systemName: pendingSyncBadgeSymbol(state))
                .font(.system(size: 11, weight: .bold))

            Text(pendingSyncBadgeLabel(state))
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(activityStatusColor(activity.status, fallback: activity.activityStatus).opacity(0.12))
                .frame(width: 42, height: 42)

            switch normalizedActivityDisplayStatus(activity.status) {
            case "pendingconfirmation":
                Image(systemName: "clock.badge.questionmark").foregroundColor(DS.Colors.info)
            case "succeed", "completed":
                Image(systemName: "checkmark.circle.fill").foregroundColor(DS.Colors.success)
            case "ongoing", "inprogress":
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill").foregroundColor(DS.Colors.warning)
            case "failed", "fail":
                Image(systemName: "xmark.circle.fill").foregroundColor(DS.Colors.accent)
            case "cancelled", "canceled", "cancel":
                Image(systemName: "minus.circle.fill").foregroundColor(DS.Colors.textTertiary)
            default:
                Image(systemName: "clock").foregroundColor(DS.Colors.textSecondary)
            }
        }
        .font(.system(size: 20))
    }

    private var borderColor: Color {
        switch normalizedActivityDisplayStatus(activity.status) {
        case "pendingconfirmation":
            return DS.Colors.info.opacity(0.2)
        case "succeed", "completed":
            return DS.Colors.success.opacity(0.18)
        case "ongoing", "inprogress":
            return DS.Colors.warning.opacity(0.22)
        case "failed", "fail":
            return DS.Colors.accent.opacity(0.18)
        default:
            return DS.Colors.borderSubtle
        }
    }

    private var availableActions: [ActivityAction] {
        guard isStatusEditable else { return [] }

        switch activity.activityStatus {
        case .onGoing:
            guard allowsCompletionActions else { return [] }
            return [
                ActivityAction(
                    label: primaryCompleteActionLabel,
                    icon: primaryCompleteActionIcon,
                    color: DS.Colors.success,
                    status: "Succeed"
                ),
                ActivityAction(label: "Thất bại", icon: "xmark.circle.fill", color: DS.Colors.accent, status: "Failed")
            ]
        default:
            return []
        }
    }

    private var displayTitle: String {
        let cleaned = activity.title
            .replacingOccurrences(of: "\\s*#\\d+$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? activity.title : cleaned
    }

    private var subtitleText: String? {
        let parts = [
            localizedPriorityText(activity.priority).map { "Ưu tiên \($0)" },
            assignmentLabel
        ].compactMap { $0 }

        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func stepBadge(_ step: Int) -> some View {
        HStack(spacing: 5) {
            Text("Bước")
                .font(.system(size: 11, weight: .semibold))

            Text("\(step)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundColor(DS.Colors.accent)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(DS.Colors.accent.opacity(0.1))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(DS.Colors.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private var supplyOverviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: supplyOverviewIcon)
                    .font(.system(size: 13, weight: .semibold))

                Text(supplyOverviewTitle)
                    .font(.system(size: 13, weight: .bold))

                Spacer()

                Text("\(supplyItems.count) mục")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .foregroundColor(supplyOverviewColor)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(supplyOverviewRows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 7) {
                        Circle()
                            .fill(supplyOverviewColor.opacity(0.8))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)

                        Text(row)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DS.Colors.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(supplyOverviewColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(supplyOverviewColor.opacity(0.28), lineWidth: 1)
        )
    }

    private func executionContextView(_ context: MissionActivityExecutionContext) -> some View {
        let color = executionContextColor(context)

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: executionContextSymbol(context))
                    .font(.system(size: 11, weight: .bold))

                Text(context.badgeText)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )

            if isExpanded, let detailText = context.detailText {
                Text(detailText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var supplyItems: [MissionSupply] {
        activity.suppliesToCollect ?? []
    }

    private var activityImageURL: URL? {
        guard let rawValue = activity.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              rawValue.isEmpty == false,
              let url = URL(string: rawValue) else {
            return nil
        }

        return url
    }

    private func activityProofThumbnail(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ảnh báo cáo")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DS.Colors.textSecondary)

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DS.Colors.background)

                        Image(systemName: "photo")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DS.Colors.background)

                        ProgressView()
                            .controlSize(.small)
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 120, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 1)
            )
        }
    }

    private var supplyOverviewRows: [String] {
        let rows = supplyItems.map { supply in
            let quantity = "x\(supply.quantity)"
            let unit = supply.unit?.trimmingCharacters(in: .whitespacesAndNewlines)
            let itemName = supply.itemName?.trimmingCharacters(in: .whitespacesAndNewlines)

            let itemLabel = itemName?.isEmpty == false ? itemName! : "Vật phẩm"
            let unitLabel = (unit?.isEmpty == false ? " \(unit!)" : "")
            return "\(itemLabel) \(quantity)\(unitLabel)"
        }

        if isExpanded || rows.count <= 2 {
            return rows
        }

        return Array(rows.prefix(2)) + ["+\(rows.count - 2) vật phẩm khác"]
    }

    private var normalizedActivityTypeKey: String {
        activity.normalizedActivityTypeKey
    }

    private var primaryCompleteActionLabel: String {
        switch normalizedActivityTypeKey {
        case "collectsupplies":
            return "Xác nhận tiếp nhận"
        case "deliversupplies":
            return "Xác nhận phân phát"
        case "returnsupplies":
            return "Xác nhận hoàn trả"
        default:
            return "Hoàn thành"
        }
    }

    private var primaryCompleteActionIcon: String {
        switch normalizedActivityTypeKey {
        case "collectsupplies":
            return "shippingbox.fill"
        case "deliversupplies":
            return "arrowshape.turn.up.right.circle.fill"
        case "returnsupplies":
            return "arrow.uturn.backward.circle.fill"
        default:
            return "checkmark.circle.fill"
        }
    }

    private var supplyOverviewTitle: String {
        switch normalizedActivityTypeKey {
        case "collectsupplies":
            return "Cần tiếp nhận ở bước này"
        case "deliversupplies":
            return "Cần phân phát ở bước này"
        case "returnsupplies":
            return "Cần hoàn trả ở bước này"
        case "medicalaid", "medicalsupport", "medical":
            return "Vật phẩm sử dụng ở bước này"
        default:
            return "Vật phẩm liên quan"
        }
    }

    private var supplyOverviewIcon: String {
        switch normalizedActivityTypeKey {
        case "collectsupplies":
            return "shippingbox.fill"
        case "deliversupplies":
            return "arrowshape.turn.up.right.circle.fill"
        case "returnsupplies":
            return "arrow.uturn.backward.circle.fill"
        case "medicalaid", "medicalsupport", "medical":
            return "cross.case.fill"
        default:
            return "cube.box.fill"
        }
    }

    private var supplyOverviewColor: Color {
        switch normalizedActivityTypeKey {
        case "collectsupplies":
            return DS.Colors.warning
        case "deliversupplies":
            return DS.Colors.success
        case "returnsupplies":
            return DS.Colors.info
        case "medicalaid", "medicalsupport", "medical":
            return DS.Colors.accent
        default:
            return DS.Colors.info
        }
    }

    private var detailItems: [ActivityDetailItem] {
        [
            detailItem("Loại bước thực hiện", activity.localizedActivityType, icon: "tag"),
            detailItem("Công việc", localizedCodeDetailValue, icon: "number"),
            detailItem("Đội phụ trách", assignmentLabel, icon: "person.3"),
            detailItem("Kho tiếp tế", activity.depotName, icon: "shippingbox"),
            detailItem("Địa chỉ kho", activity.depotAddress, icon: "mappin.and.ellipse"),
            detailItem("Thời gian phân công", formattedDisplayDate(activity.assignedAt), icon: "calendar.badge.clock"),
            detailItem("Hoàn tất lúc", formattedDisplayDate(activity.completedAt), icon: "checkmark.circle")
        ]
        .compactMap { $0 }
    }

    private func actionButton(_ action: ActivityAction) -> some View {
        Button {
            onStatusChange(action.status)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.system(size: 16, weight: .semibold))

                Text(action.label)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
            }
            .foregroundColor(action.foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 22)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, 12)
            .background(action.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(action.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.label)
    }

    private var localizedCodeDetailValue: String? {
        guard let localizedCode = activity.localizedActivityCode else {
            return nil
        }

        if localizedCode == activity.localizedActivityType {
            return nil
        }

        return localizedCode
    }

    private func executionContextColor(_ context: MissionActivityExecutionContext) -> Color {
        if context.sosRequestId != nil {
            return DS.Colors.accent
        }

        return DS.Colors.info
    }

    private func executionContextSymbol(_ context: MissionActivityExecutionContext) -> String {
        if context.sosRequestId != nil {
            return "dot.radiowaves.left.and.right"
        }

        return "location.circle.fill"
    }

    private func activityStatusColor(_ rawStatus: String, fallback status: ActivityStatus) -> Color {
        switch normalizedActivityDisplayStatus(rawStatus) {
        case "pendingconfirmation":
            return DS.Colors.info
        default:
            return activityStatusColor(status)
        }
    }

    private func activityStatusColor(_ status: ActivityStatus) -> Color {
        switch status {
        case .succeed:
            return DS.Colors.success
        case .onGoing:
            return DS.Colors.warning
        case .failed:
            return DS.Colors.accent
        case .cancelled:
            return DS.Colors.textTertiary
        case .planned:
            return DS.Colors.textSecondary
        }
    }

    private func activityStatusBadgeColor(_ rawStatus: String, fallback status: ActivityStatus) -> Color {
        switch normalizedActivityDisplayStatus(rawStatus) {
        case "pendingconfirmation":
            return DS.Colors.info
        default:
            return activityStatusBadgeColor(status)
        }
    }

    private func activityStatusBadgeColor(_ status: ActivityStatus) -> Color {
        switch status {
        case .planned:
            return DS.Colors.info
        case .onGoing:
            return DS.Colors.warning
        case .succeed:
            return DS.Colors.success
        case .failed:
            return DS.Colors.accent
        case .cancelled:
            return DS.Colors.textSecondary
        }
    }

    private func activityStatusBadgeSymbol(_ rawStatus: String, fallback status: ActivityStatus) -> String {
        switch normalizedActivityDisplayStatus(rawStatus) {
        case "pendingconfirmation":
            return "clock.badge.questionmark"
        default:
            return activityStatusBadgeSymbol(status)
        }
    }

    private func activityStatusBadgeSymbol(_ status: ActivityStatus) -> String {
        switch status {
        case .planned:
            return "calendar.badge.clock"
        case .onGoing:
            return "bolt.fill"
        case .succeed:
            return "checkmark.seal.fill"
        case .failed:
            return "xmark.octagon.fill"
        case .cancelled:
            return "slash.circle.fill"
        }
    }

    private func normalizedActivityDisplayStatus(_ rawStatus: String) -> String {
        RescuerStatusBadgeText.normalized(rawStatus)
    }

    private func pendingSyncBadgeLabel(_ state: MissionActivitySyncState) -> String {
        switch state {
        case .queued:
            return "Chưa đồng bộ"
        case .syncing:
            return "Đang đồng bộ"
        case .failed:
            return "Lỗi đồng bộ"
        case .synced:
            return "Đã đồng bộ"
        }
    }

    private func pendingSyncBadgeColor(_ state: MissionActivitySyncState) -> Color {
        switch state {
        case .queued:
            return DS.Colors.info
        case .syncing:
            return DS.Colors.warning
        case .failed:
            return DS.Colors.accent
        case .synced:
            return DS.Colors.success
        }
    }

    private func pendingSyncBadgeSymbol(_ state: MissionActivitySyncState) -> String {
        switch state {
        case .queued:
            return "arrow.triangle.2.circlepath.circle"
        case .syncing:
            return "icloud.and.arrow.up"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .synced:
            return "checkmark.icloud.fill"
        }
    }

    private func detailItem(_ title: String, _ value: String?, icon: String) -> ActivityDetailItem? {
        guard let value, value.isEmpty == false else { return nil }
        return ActivityDetailItem(title: title, value: value, icon: icon)
    }

    private func formattedDisplayDate(_ raw: String?) -> String? {
        guard let raw, raw.isEmpty == false else { return nil }

        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]

        guard let date = isoFull.date(from: raw) ?? isoBasic.date(from: raw) else {
            return raw
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm, dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private func localizedPriorityText(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.isEmpty == false else {
            return nil
        }

        switch value.lowercased() {
        case "critical":
            return "Khẩn cấp"
        case "high":
            return "Cao"
        case "medium":
            return "Trung bình"
        case "low":
            return "Thấp"
        default:
            return value
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

    var foregroundColor: Color {
        switch status {
        case "OnGoing":
            return .white
        default:
            return color
        }
    }

    var backgroundColor: Color {
        switch status {
        case "OnGoing":
            return color
        default:
            return color.opacity(0.08)
        }
    }

    var borderColor: Color {
        color.opacity(0.25)
    }
}

private struct ActivityDetailItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
}
