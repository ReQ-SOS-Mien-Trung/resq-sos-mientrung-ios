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
    let inventoryKey: String
    let itemName: String
    let imageUrl: URL?
    let quantity: Int
    let unit: String?
    let activityId: Int
    let activityTitle: String
    let activityType: String?
    let activityStatus: String
    let step: Int?
    let depotName: String?
    let stage: MissionInventoryStage
    let lotAllocations: [MissionSupplyLotAllocation]
}

private struct MissionInventoryGroup: Identifiable {
    let id: String
    let itemName: String
    let imageUrl: URL?
    let unit: String?
    let totalQuantity: Int
    let sharedLots: [MissionInventorySharedLot]
    let entries: [MissionInventoryEntry]
}

private struct MissionInventorySharedLot: Identifiable {
    let id: String
    let lotId: String
    let expiryDisplay: String
    let expirySortDate: Date?
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
                let itemName = supply.itemName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Vật phẩm"
                let unit = supply.unit?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                return MissionInventoryEntry(
                    id: "\(activity.id)-\(supply.id)",
                    inventoryKey: "\(itemName)|\(unit ?? "")",
                    itemName: itemName,
                    imageUrl: inventoryImageURL(from: supply.imageUrl),
                    quantity: inventoryQuantity(for: supply, stage: stage),
                    unit: unit,
                    activityId: activity.id,
                    activityTitle: activity.title,
                    activityType: activity.localizedActivityType,
                    activityStatus: activity.status,
                    step: activity.step,
                    depotName: activity.depotName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    stage: stage,
                    lotAllocations: inventoryLotAllocations(for: supply, stage: stage)
                )
            }
        }
    }

    private var pickedUpInventoryKeys: Set<String> {
        Set(
            inventoryEntries
                .filter { entry in
                    entry.stage == .pickedUp
                }
                .map(\.inventoryKey)
        )
    }

    private var filteredEntries: [MissionInventoryEntry] {
        inventoryEntries.filter(matchesSelectedFilter)
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
                imageUrl: sortedEntries.compactMap(\.imageUrl).first,
                unit: first.unit,
                totalQuantity: sortedEntries.reduce(0) { $0 + $1.quantity },
                sharedLots: sharedLots(from: sortedEntries),
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
                title: "Loại vật phẩm",
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
                value: "\(inHandQuantity)",
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
                        title: "Chưa có vật phẩm nào gắn với nhiệm vụ",
                        subtitle: "Hệ thống hiện chỉ trả vật phẩm qua trường activities.suppliesToCollect. Nhiệm vụ này chưa có hoạt động nào chứa vật phẩm."
                    ) {
                        IncidentInlineNotice(
                            icon: "shippingbox",
                            text: "Khi nhiệm vụ có bước COLLECT_SUPPLIES, DELIVER_SUPPLIES hoặc hoạt động khác có suppliesToCollect, túi đồ sẽ hiển thị tại đây.",
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
        .navigationTitle("Túi đồ vật phẩm")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DS.Colors.info.opacity(0.18),
                                    DS.Colors.info.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(DS.Colors.info)
                }

                VStack(alignment: .leading, spacing: 6) {
                    EyebrowLabel(text: "TÚI ĐỒ NHIỆM VỤ", color: DS.Colors.info)
                    Text(missionTitle)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(DS.Colors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Theo dõi vật phẩm từ các hoạt động của đội để biết món nào cần lấy, đang giữ, đã giao hoặc đang trong luồng hoàn trả.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(totalQuantityCount)")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(DS.Colors.text)

                Text("đơn vị")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DS.Colors.textSecondary)

                Spacer()

                Text("\(itemTypeCount) loại")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DS.Colors.info)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DS.Colors.info.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderColor: DS.Colors.info.opacity(0.18),
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 20
        )
    }

    private var headlineSummaryMetrics: [MissionInventorySummaryMetric] {
        summaryMetrics.filter { ["pickup", "inhand", "delivered"].contains($0.id) }
    }

    private var visibleEntries: [MissionInventoryEntry] {
        selectedFilter == .all ? inventoryEntries : filteredEntries
    }

    private var itemTypeCount: Int {
        Set(visibleEntries.map { "\($0.itemName)|\($0.unit ?? "")" }).count
    }

    private var totalQuantityCount: Int {
        visibleEntries.reduce(0) { $0 + $1.quantity }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Tổng quan nhanh")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(DS.Colors.text)

            HStack(spacing: DS.Spacing.sm) {
                ForEach(headlineSummaryMetrics) { metric in
                    inventorySummaryTile(metric: metric, emphasized: true)
                }
            }

            HStack(spacing: DS.Spacing.sm) {
                infoStripCard(
                    title: "Tổng số lượng",
                    value: "\(totalQuantityCount)",
                    color: DS.Colors.accent,
                    icon: "sum"
                )

                infoStripCard(
                    title: "Hoàn trả",
                    value: "\(quantity(for: [.readyForReturn, .returning, .returned]))",
                    color: DS.Colors.textSecondary,
                    icon: "arrow.uturn.backward.circle"
                )
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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
            Text("Danh sách vật phẩm")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(DS.Colors.text)

            ForEach(groupedEntries) { group in
                MissionInventoryGroupCard(group: group)
            }
        }
    }

    private func inventorySummaryTile(metric: MissionInventorySummaryMetric, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(metric.color.opacity(0.14))
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(metric.color.opacity(0.18), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: iconName(for: metric.id))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(metric.color)
                )

            Text(metric.value)
                .font(.system(size: emphasized ? 26 : 22, weight: .black, design: .rounded))
                .foregroundColor(DS.Colors.text)

            Text(metric.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: emphasized ? 108 : 88, alignment: .leading)
        .padding(DS.Spacing.sm)
        .background(metric.color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(metric.color.opacity(0.2), lineWidth: 1)
        )
    }

    private func infoStripCard(title: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DS.Colors.textSecondary)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.text)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.16), lineWidth: 1)
        )
    }

    private func iconName(for metricId: String) -> String {
        switch metricId {
        case "pickup":
            return "tray.and.arrow.down.fill"
        case "inhand":
            return "shippingbox.circle.fill"
        case "delivered":
            return "checkmark.circle.fill"
        case "returned":
            return "arrow.uturn.backward.circle.fill"
        case "quantity":
            return "sum"
        default:
            return "shippingbox.fill"
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

    private func inventoryQuantity(
        for supply: MissionSupply,
        stage: MissionInventoryStage
    ) -> Int {
        let plannedQuantity = max(supply.quantity, 0)
        let carriedQuantity = inventoryCarriedQuantity(for: supply)

        switch stage {
        case .plannedPickup, .pickingUp, .pickedUp, .readyForDelivery, .delivering, .plannedUse, .inUse:
            return carriedQuantity
        case .delivered, .used:
            let deliveredQuantity = max(
                max(supply.actualDeliveredQuantity ?? 0, 0),
                inventoryLotQuantity(supply.deliveredLotAllocations),
                inventoryReusableQuantity(supply.deliveredReusableUnits)
            )

            if deliveredQuantity > 0 {
                return deliveredQuantity
            }

            return plannedQuantity
        case .readyForReturn, .returning:
            let returnQuantity = max(
                inventoryLotQuantity(supply.expectedReturnLotAllocations),
                inventoryLotQuantity(supply.availableDeliveryLotAllocations),
                inventoryReusableQuantity(supply.expectedReturnUnits),
                inventoryReusableQuantity(supply.availableDeliveryReusableUnits)
            )

            return returnQuantity > 0 ? returnQuantity : carriedQuantity
        case .returned:
            let returnedQuantity = max(
                inventoryLotQuantity(supply.returnedLotAllocations),
                inventoryLotQuantity(supply.expectedReturnLotAllocations),
                inventoryReusableQuantity(supply.returnedReusableUnits),
                inventoryReusableQuantity(supply.expectedReturnUnits)
            )

            return returnedQuantity > 0 ? returnedQuantity : plannedQuantity
        case .released:
            return plannedQuantity
        }
    }

    private func inventoryCarriedQuantity(for supply: MissionSupply) -> Int {
        let plannedQuantity = max(supply.quantity, 0)
        let bufferQuantity: Int
        if let bufferUsedQuantity = supply.bufferUsedQuantity {
            bufferQuantity = max(bufferUsedQuantity, 0)
        } else {
            bufferQuantity = max(supply.bufferQuantity ?? 0, 0)
        }

        return max(
            plannedQuantity + bufferQuantity,
            inventoryLotQuantity(supply.availableDeliveryLotAllocations),
            inventoryLotQuantity(supply.pickupLotAllocations),
            inventoryLotQuantity(supply.plannedPickupLotAllocations),
            inventoryReusableQuantity(supply.availableDeliveryReusableUnits),
            inventoryReusableQuantity(supply.pickedReusableUnits),
            inventoryReusableQuantity(supply.plannedPickupReusableUnits)
        )
    }

    private func inventoryLotQuantity(_ allocations: [MissionSupplyLotAllocation]?) -> Int {
        (allocations ?? []).reduce(0) { partialResult, allocation in
            partialResult + max(0, allocation.quantityTaken ?? 0)
        }
    }

    private func inventoryReusableQuantity(_ units: [MissionSupplyReusableUnit]?) -> Int {
        (units ?? []).filter { unit in
            if let reusableItemId = unit.reusableItemId {
                return reusableItemId > 0
            }

            return false
        }.count
    }

    private func inventoryLotAllocations(
        for supply: MissionSupply,
        stage: MissionInventoryStage
    ) -> [MissionSupplyLotAllocation] {
        switch stage {
        case .plannedPickup, .pickingUp:
            return inventoryNormalizedLotAllocations(supply.plannedPickupLotAllocations)
        case .pickedUp:
            let pickupLots = inventoryNormalizedLotAllocations(supply.pickupLotAllocations)
            if pickupLots.isEmpty == false {
                return pickupLots
            }
            return inventoryNormalizedLotAllocations(supply.plannedPickupLotAllocations)
        case .readyForDelivery, .delivering:
            let availableLots = inventoryNormalizedLotAllocations(supply.availableDeliveryLotAllocations)
            if availableLots.isEmpty == false {
                return availableLots
            }

            let pickupLots = inventoryNormalizedLotAllocations(supply.pickupLotAllocations)
            if pickupLots.isEmpty == false {
                return pickupLots
            }

            return inventoryNormalizedLotAllocations(supply.plannedPickupLotAllocations)
        case .delivered:
            let deliveredLots = inventoryNormalizedLotAllocations(supply.deliveredLotAllocations)
            if deliveredLots.isEmpty == false {
                return deliveredLots
            }
            return inventoryNormalizedLotAllocations(supply.availableDeliveryLotAllocations)
        case .readyForReturn, .returning:
            let expectedReturnLots = inventoryNormalizedLotAllocations(supply.expectedReturnLotAllocations)
            if expectedReturnLots.isEmpty == false {
                return expectedReturnLots
            }

            let deliveredLots = inventoryNormalizedLotAllocations(supply.deliveredLotAllocations)
            if deliveredLots.isEmpty == false {
                return deliveredLots
            }

            return inventoryNormalizedLotAllocations(supply.availableDeliveryLotAllocations)
        case .returned:
            let returnedLots = inventoryNormalizedLotAllocations(supply.returnedLotAllocations)
            if returnedLots.isEmpty == false {
                return returnedLots
            }
            return inventoryNormalizedLotAllocations(supply.expectedReturnLotAllocations)
        case .plannedUse, .inUse:
            let pickupLots = inventoryNormalizedLotAllocations(supply.pickupLotAllocations)
            if pickupLots.isEmpty == false {
                return pickupLots
            }
            return inventoryNormalizedLotAllocations(supply.plannedPickupLotAllocations)
        case .used:
            let deliveredLots = inventoryNormalizedLotAllocations(supply.deliveredLotAllocations)
            if deliveredLots.isEmpty == false {
                return deliveredLots
            }
            return inventoryNormalizedLotAllocations(supply.pickupLotAllocations)
        case .released:
            return []
        }
    }

    private var inHandQuantity: Int {
        inventoryEntries
            .filter(isInHandEntry)
            .reduce(0) { $0 + $1.quantity }
    }

    private func sharedLots(from entries: [MissionInventoryEntry]) -> [MissionInventorySharedLot] {
        var uniqueLotsByKey: [String: MissionInventorySharedLot] = [:]

        for lot in entries.flatMap(\.lotAllocations) {
            let lotId = inventoryLotIdDisplay(lot.lotId)
            let rawExpiry = lot.expiredDate?.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = "\(lotId)|\(rawExpiry ?? "")"

            guard uniqueLotsByKey[key] == nil else { continue }

            uniqueLotsByKey[key] = MissionInventorySharedLot(
                id: key,
                lotId: lotId,
                expiryDisplay: inventoryLotExpiryDisplay(lot.expiredDate),
                expirySortDate: inventoryLotSortDate(lot.expiredDate)
            )
        }

        return uniqueLotsByKey.values.sorted { lhs, rhs in
            switch (lhs.expirySortDate, rhs.expirySortDate) {
            case let (left?, right?):
                if left != right {
                    return left < right
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            if lhs.lotId != rhs.lotId {
                return lhs.lotId < rhs.lotId
            }

            return lhs.id < rhs.id
        }
    }

    private func matchesSelectedFilter(_ entry: MissionInventoryEntry) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .pickup:
            return [.plannedPickup, .pickingUp].contains(entry.stage)
        case .inHand:
            return isInHandEntry(entry)
        case .delivered:
            return [.delivered, .used].contains(entry.stage)
        case .returnFlow:
            return [.readyForReturn, .returning, .returned].contains(entry.stage)
        }
    }

    private func isInHandEntry(_ entry: MissionInventoryEntry) -> Bool {
        switch entry.stage {
        case .pickedUp:
            return true
        case .pickingUp:
            return false
        case .readyForDelivery, .delivering, .plannedUse, .inUse, .readyForReturn, .returning:
            return pickedUpInventoryKeys.contains(entry.inventoryKey)
        case .plannedPickup, .delivered, .returned, .used, .released:
            return false
        }
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

    private func inventoryImageURL(from rawValue: String?) -> URL? {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false,
              let url = URL(string: trimmed) else {
            return nil
        }
        return url
    }
}

private struct MissionInventoryGroupCard: View {
    let group: MissionInventoryGroup

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                MissionInventoryItemThumbnail(imageURL: group.imageUrl, itemName: group.itemName)

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.itemName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(DS.Colors.text)

                    Text("\(group.totalQuantity)\(group.unit.map { " \($0)" } ?? "") • \(group.entries.count) phân bổ")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DS.Colors.textSecondary)

                    if group.sharedLots.isEmpty == false {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Lô và hạn sử dụng")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(DS.Colors.info)

                            ForEach(group.sharedLots) { lot in
                                Text("• Lô \(lot.lotId) • HSD \(lot.expiryDisplay)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                        }
                        .padding(.top, 2)
                    }
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

                            StatusBadge(text: statusBadgeText(for: entry), color: statusBadgeColor(for: entry))
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

    private func statusBadgeText(for entry: MissionInventoryEntry) -> String {
        switch entry.stage {
        case .plannedPickup, .pickingUp:
            return localizedBackendStatus(entry.activityStatus)
        default:
            return entry.stage.title
        }
    }

    private func statusBadgeColor(for entry: MissionInventoryEntry) -> Color {
        switch entry.stage {
        case .plannedPickup, .pickingUp:
            return backendStatusColor(entry.activityStatus)
        default:
            return entry.stage.color
        }
    }

    private func localizedBackendStatus(_ rawStatus: String) -> String {
        switch RescuerStatusBadgeText.normalized(rawStatus) {
        case "planned", "pending", "scheduled":
            return "Đã lên kế hoạch"
        case "ongoing", "inprogress":
            return "Đang thực hiện"
        case "pendingconfirmation":
            return "Chờ xác nhận"
        case "succeed", "succeeded", "success", "completed", "finished", "done":
            return "Hoàn thành"
        case "failed", "fail":
            return "Thất bại"
        case "cancelled", "canceled", "cancel":
            return "Đã hủy"
        default:
            return RescuerStatusBadgeText.activity(ActivityStatus(apiValue: rawStatus) ?? .planned)
        }
    }

    private func backendStatusColor(_ rawStatus: String) -> Color {
        switch RescuerStatusBadgeText.normalized(rawStatus) {
        case "planned", "pending", "scheduled":
            return DS.Colors.info
        case "ongoing", "inprogress", "pendingconfirmation":
            return DS.Colors.warning
        case "succeed", "succeeded", "success", "completed", "finished", "done":
            return DS.Colors.success
        case "failed", "fail", "cancelled", "canceled", "cancel":
            return DS.Colors.accent
        default:
            return DS.Colors.textSecondary
        }
    }
}

private struct MissionInventoryItemThumbnail: View {
    let imageURL: URL?
    let itemName: String

    private let size: CGFloat = 76

    var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallbackView
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(DS.Colors.info.opacity(0.08))

                            ProgressView()
                                .tint(DS.Colors.info)
                        }
                    @unknown default:
                        fallbackView
                    }
                }
            } else {
                fallbackView
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DS.Colors.info.opacity(0.12), lineWidth: 1)
        )
    }

    private var fallbackView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DS.Colors.info.opacity(0.18),
                    DS.Colors.info.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 6) {
                Image(systemName: fallbackIconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(DS.Colors.info)

                Text(shortLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(DS.Colors.info.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(8)
        }
    }

    private var shortLabel: String {
        let words = itemName.split(separator: " ").prefix(2)
        if words.isEmpty {
            return "ITEM"
        }
        return words
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    private var fallbackIconName: String {
        let normalized = itemName
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()

        if normalized.contains("nuoc") {
            return "drop.fill"
        }
        if normalized.contains("mi") || normalized.contains("gao") || normalized.contains("thuc pham") {
            return "fork.knife"
        }
        if normalized.contains("thuoc") || normalized.contains("y te") {
            return "cross.case.fill"
        }
        return "shippingbox.fill"
    }
}

private func inventoryNormalizedLotAllocations(
    _ allocations: [MissionSupplyLotAllocation]?
) -> [MissionSupplyLotAllocation] {
    let filteredAllocations = (allocations ?? []).filter(\.hasDisplayableValue)
    return filteredAllocations.sorted { lhs, rhs in
        let leftDate = inventoryLotSortDate(lhs.expiredDate)
        let rightDate = inventoryLotSortDate(rhs.expiredDate)

        switch (leftDate, rightDate) {
        case let (left?, right?):
            if left != right {
                return left < right
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        return inventoryLotSortKey(lhs.lotId) < inventoryLotSortKey(rhs.lotId)
    }
}

private func inventoryLotIdDisplay(_ lotId: String?) -> String {
    lotId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "?"
}

private func inventoryLotExpiryDisplay(_ rawValue: String?) -> String {
    guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), rawValue.isEmpty == false else {
        return "?"
    }

    let isoWithFractionalSeconds = ISO8601DateFormatter()
    isoWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let isoBasic = ISO8601DateFormatter()
    isoBasic.formatOptions = [.withInternetDateTime]

    guard let date = isoWithFractionalSeconds.date(from: rawValue) ?? isoBasic.date(from: rawValue) else {
        return rawValue
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.dateFormat = "dd/MM/yyyy"
    return formatter.string(from: date)
}

private func inventoryLotSortDate(_ rawValue: String?) -> Date? {
    guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), rawValue.isEmpty == false else {
        return nil
    }

    let isoWithFractionalSeconds = ISO8601DateFormatter()
    isoWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let isoBasic = ISO8601DateFormatter()
    isoBasic.formatOptions = [.withInternetDateTime]

    return isoWithFractionalSeconds.date(from: rawValue) ?? isoBasic.date(from: rawValue)
}

private func inventoryLotSortKey(_ lotId: String?) -> String {
    lotId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
