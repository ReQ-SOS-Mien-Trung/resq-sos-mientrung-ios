import SwiftUI

private enum MissionInventoryStage: String, CaseIterable, Identifiable {
    case plannedPickup
    case pickingUp
    case pickedUp
    case readyForDelivery
    case delivering
    case delivered
    case readyForReturn
    case returning
    case returned
    case plannedUse
    case inUse
    case used
    case released

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plannedPickup: return "Cần lấy"
        case .pickingUp: return "Đang nhận"
        case .pickedUp: return "Đã nhận"
        case .readyForDelivery: return "Sẵn sàng giao"
        case .delivering: return "Đang mang đi giao"
        case .delivered: return "Đã giao"
        case .readyForReturn: return "Sẵn sàng trả"
        case .returning: return "Đang trả kho"
        case .returned: return "Đã trả kho"
        case .plannedUse: return "Đã phân bổ"
        case .inUse: return "Đang dùng"
        case .used: return "Đã dùng"
        case .released: return "Đã giải phóng"
        }
    }

    var color: Color {
        switch self {
        case .plannedPickup, .readyForDelivery, .readyForReturn, .plannedUse:
            return DS.Colors.info
        case .pickingUp, .delivering, .returning, .inUse:
            return DS.Colors.warning
        case .pickedUp:
            return DS.Colors.accent
        case .delivered, .returned, .used:
            return DS.Colors.success
        case .released:
            return DS.Colors.textSecondary
        }
    }
}

private enum MissionInventoryFilter: String, CaseIterable, Identifiable {
    case all
    case pickup
    case inHand
    case delivered
    case returnFlow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Tất cả"
        case .pickup: return "Cần lấy"
        case .inHand: return "Đang giữ"
        case .delivered: return "Đã giao / dùng"
        case .returnFlow: return "Hoàn trả"
        }
    }

    func matches(stage: MissionInventoryStage) -> Bool {
        switch self {
        case .all:
            return true
        case .pickup:
            return [.plannedPickup, .pickingUp].contains(stage)
        case .inHand:
            return [.pickedUp, .readyForDelivery, .delivering, .plannedUse, .inUse].contains(stage)
        case .delivered:
            return [.delivered, .used].contains(stage)
        case .returnFlow:
            return [.readyForReturn, .returning, .returned].contains(stage)
        }
    }
}

private struct MissionInventoryEntry: Identifiable {
    let id: String
    let itemName: String
    let quantity: Int
    let unit: String?
    let activityId: Int
    let activityTitle: String
    let activityType: String?
    let step: Int?
    let depotName: String?
    let stage: MissionInventoryStage
}

private struct MissionInventoryGroup: Identifiable {
    let id: String
    let itemName: String
    let unit: String?
    let totalQuantity: Int
    let entries: [MissionInventoryEntry]
}

private struct MissionInventorySummaryMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let color: Color
}

struct MissionInventoryView: View {
    let missionTitle: String
    let activities: [Activity]

    @State private var selectedFilter: MissionInventoryFilter = .all

    private var inventoryEntries: [MissionInventoryEntry] {
        activities.flatMap { activity in
            let stage = inventoryStage(for: activity)
            return (activity.suppliesToCollect ?? []).map { supply in
                MissionInventoryEntry(
                    id: "\(activity.id)-\(supply.id)",
                    itemName: supply.itemName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Vật tư",
                    quantity: supply.quantity,
                    unit: supply.unit?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    activityId: activity.id,
                    activityTitle: activity.title,
                    activityType: activity.localizedActivityType,
                    step: activity.step,
                    depotName: activity.depotName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    stage: stage
                )
            }
        }
    }

    private var filteredEntries: [MissionInventoryEntry] {
        inventoryEntries.filter { selectedFilter.matches(stage: $0.stage) }
    }

    private var groupedEntries: [MissionInventoryGroup] {
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            "\(entry.itemName)|\(entry.unit ?? "")"
        }

        return grouped.map { key, entries in
            let sortedEntries = entries.sorted { lhs, rhs in
                switch (lhs.step, rhs.step) {
                case let (left?, right?):
                    if left != right { return left < right }
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }
                return lhs.activityId < rhs.activityId
            }

            let first = sortedEntries.first!
            return MissionInventoryGroup(
                id: key,
                itemName: first.itemName,
                unit: first.unit,
                totalQuantity: sortedEntries.reduce(0) { $0 + $1.quantity },
                entries: sortedEntries
            )
        }
        .sorted { lhs, rhs in
            if lhs.totalQuantity != rhs.totalQuantity {
                return lhs.totalQuantity > rhs.totalQuantity
            }
            return lhs.itemName < rhs.itemName
        }
    }

    private var summaryMetrics: [MissionInventorySummaryMetric] {
        [
            MissionInventorySummaryMetric(
                id: "items",
                title: "Loại vật tư",
                value: "\(Set(inventoryEntries.map(\.id)).count == 0 ? 0 : Set(inventoryEntries.map { "\($0.itemName)|\($0.unit ?? "")" }).count)",
                color: DS.Colors.info
            ),
            MissionInventorySummaryMetric(
                id: "quantity",
                title: "Tổng số lượng",
                value: "\(inventoryEntries.reduce(0) { $0 + $1.quantity })",
                color: DS.Colors.accent
            ),
            MissionInventorySummaryMetric(
                id: "pickup",
                title: "Cần lấy",
                value: "\(quantity(for: [.plannedPickup, .pickingUp]))",
                color: DS.Colors.warning
            ),
            MissionInventorySummaryMetric(
                id: "inhand",
                title: "Đang giữ",
                value: "\(quantity(for: [.pickedUp, .readyForDelivery, .delivering, .plannedUse, .inUse]))",
                color: DS.Colors.accent
            ),
            MissionInventorySummaryMetric(
                id: "delivered",
                title: "Đã giao / dùng",
                value: "\(quantity(for: [.delivered, .used]))",
                color: DS.Colors.success
            ),
            MissionInventorySummaryMetric(
                id: "returned",
                title: "Hoàn trả",
                value: "\(quantity(for: [.readyForReturn, .returning, .returned]))",
                color: DS.Colors.textSecondary
            )
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                headerSection

                if inventoryEntries.isEmpty {
                    IncidentFormSection(
                        title: "Chưa có vật tư nào gắn với mission",
                        subtitle: "Backend hiện chỉ trả vật tư qua `activities.suppliesToCollect`. Mission này chưa có activity nào chứa vật tư."
                    ) {
                        IncidentInlineNotice(
                            icon: "shippingbox",
                            text: "Khi mission có bước COLLECT_SUPPLIES, DELIVER_SUPPLIES hoặc activity khác mang `suppliesToCollect`, inventory sẽ hiện tại đây.",
                            tone: DS.Colors.info
                        )
                    }
                } else {
                    summarySection
                    filterSection
                    inventoryListSection
                }
            }
            .padding(DS.Spacing.md)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .navigationTitle("Inventory nhiệm vụ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            EyebrowLabel(text: "MISSION INVENTORY", color: DS.Colors.info)
            Text(missionTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(DS.Colors.text)
            Text("Tổng hợp vật tư từ dữ liệu mission hiện có để đội rescuer theo dõi vật tư cần lấy, đang giữ, đã giao hoặc cần hoàn trả.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Tổng quan nhanh")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(DS.Colors.text)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: DS.Spacing.sm)], spacing: DS.Spacing.sm) {
                ForEach(summaryMetrics) { metric in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(metric.value)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(metric.color)
                        Text(metric.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .padding(DS.Spacing.sm)
                    .sharpCard(
                        borderColor: metric.color.opacity(0.18),
                        borderWidth: DS.Border.thin,
                        shadow: DS.Shadow.none,
                        backgroundColor: DS.Colors.surface,
                        radius: 14
                    )
                }
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Lọc theo vòng đời vật tư")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DS.Colors.text)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(MissionInventoryFilter.allCases) { filter in
                        IncidentChoiceChip(
                            title: filter.title,
                            isSelected: selectedFilter == filter,
                            tone: DS.Colors.info
                        ) {
                            selectedFilter = filter
                        }
                        .frame(width: chipWidth(for: filter))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var inventoryListSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Danh sách vật tư")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(DS.Colors.text)

            ForEach(groupedEntries) { group in
                MissionInventoryGroupCard(group: group)
            }
        }
    }

    private func chipWidth(for filter: MissionInventoryFilter) -> CGFloat {
        switch filter {
        case .all: return 92
        case .pickup: return 108
        case .inHand: return 108
        case .delivered: return 138
        case .returnFlow: return 118
        }
    }

    private func quantity(for stages: Set<MissionInventoryStage>) -> Int {
        inventoryEntries
            .filter { stages.contains($0.stage) }
            .reduce(0) { $0 + $1.quantity }
    }

    private func inventoryStage(for activity: Activity) -> MissionInventoryStage {
        let type = normalizedActivityKey(activity.activityType)
        let status = normalizedStatus(activity.status)

        switch type {
        case "collectsupplies":
            switch status {
            case "ongoing", "inprogress":
                return .pickingUp
            case "succeed", "completed":
                return .pickedUp
            case "failed", "cancelled":
                return .released
            default:
                return .plannedPickup
            }
        case "deliversupplies":
            switch status {
            case "ongoing", "inprogress":
                return .delivering
            case "succeed", "completed":
                return .delivered
            case "failed", "cancelled":
                return .released
            default:
                return .readyForDelivery
            }
        case "returnsupplies":
            switch status {
            case "ongoing", "inprogress", "pendingconfirmation":
                return .returning
            case "succeed", "completed":
                return .returned
            case "failed", "cancelled":
                return .released
            default:
                return .readyForReturn
            }
        default:
            switch status {
            case "ongoing", "inprogress":
                return .inUse
            case "succeed", "completed":
                return .used
            case "failed", "cancelled":
                return .released
            default:
                return .plannedUse
            }
        }
    }

    private func normalizedActivityKey(_ rawValue: String?) -> String {
        (rawValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }

    private func normalizedStatus(_ status: String) -> String {
        RescuerStatusBadgeText.normalized(status)
    }
}

private struct MissionInventoryGroupCard: View {
    let group: MissionInventoryGroup

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.itemName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DS.Colors.text)
                    Text("Tổng: \(group.totalQuantity)\(group.unit.map { " \($0)" } ?? "") • \(group.entries.count) allocation")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DS.Colors.textSecondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ForEach(group.entries) { entry in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(activityTitle(for: entry))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DS.Colors.text)

                            let metadata = [entry.activityType, entry.depotName]
                                .compactMap { $0?.nilIfEmpty }
                                .joined(separator: " • ")
                            if metadata.isEmpty == false {
                                Text(metadata)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 6) {
                            Text("x\(entry.quantity)\(entry.unit.map { " \($0)" } ?? "")")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(DS.Colors.text)

                            StatusBadge(text: entry.stage.title, color: entry.stage.color)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderColor: DS.Colors.borderSubtle,
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 16
        )
    }

    private func activityTitle(for entry: MissionInventoryEntry) -> String {
        if let step = entry.step {
            return "Bước \(step) • \(entry.activityTitle)"
        }
        return entry.activityTitle
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
