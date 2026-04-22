import SwiftUI
import UIKit

struct PickupConfirmationSheet: View {
    let activity: Activity
    let isSubmitting: Bool
    let onSubmit: ([MissionPickupBufferUsageRequest], UIImage?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [PickupBufferDraft]
    @State private var proofImage: UIImage?
    @State private var isSubmittingLocal = false

    init(
        activity: Activity,
        isSubmitting: Bool,
        onSubmit: @escaping ([MissionPickupBufferUsageRequest], UIImage?) async -> Bool
    ) {
        self.activity = activity
        self.isSubmitting = isSubmitting
        self.onSubmit = onSubmit
        _drafts = State(initialValue: (activity.suppliesToCollect ?? []).map(PickupBufferDraft.init))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                IncidentFormSection(
                    title: "Xác nhận tiếp nhận vật phẩm",
                ) {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        if let depotName = activity.depotName, depotName.isEmpty == false {
                            IncidentContextRow(
                                icon: "shippingbox.fill",
                                title: "Kho tiếp tế",
                                value: depotName
                            )
                        }

                        if let description = activity.description, description.isEmpty == false {
                            IncidentContextRow(
                                icon: "list.bullet.rectangle",
                                title: "Công việc",
                                value: description
                            )
                        }
                    }
                }

                ForEach(drafts.indices, id: \.self) { index in
                    IncidentFormSection(
                        title: drafts[index].itemName,
                        subtitle: pickupCardSubtitle(for: drafts[index])
                    ) {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack(spacing: DS.Spacing.sm) {
                                metricChip(
                                    title: "Kế hoạch",
                                    value: quantityText(drafts[index].plannedQuantity, unit: drafts[index].unit),
                                    tone: DS.Colors.info
                                )

                                metricChip(
                                    title: "Vật phẩm dự trù",
                                    value: quantityText(drafts[index].bufferQuantityToReceive, unit: drafts[index].unit),
                                    tone: DS.Colors.warning
                                )
                            }

                            if drafts[index].lotAllocations.isEmpty == false {
                                supplyLotSummarySection(
                                    title: "Chi tiết lô tiếp nhận",
                                    allocations: drafts[index].lotAllocations,
                                    unit: drafts[index].unit
                                )
                            }

                            if drafts[index].bufferQuantityToReceive > 0 {
                                metricChip(
                                    title: "Tổng tiếp nhận",
                                    value: quantityText(drafts[index].totalPickupQuantity, unit: drafts[index].unit),
                                    tone: DS.Colors.accent
                                )

                                IncidentInlineNotice(
                                    icon: "checkmark.seal.fill",
                                    text: "Đội cứu hộ sẽ tiếp nhận toàn bộ phần dự trù khi xác nhận.",
                                    tone: DS.Colors.warning
                                )
                            } else {
                                IncidentInlineNotice(
                                    icon: "checkmark.circle.fill",
                                    text: "Vật phẩm này không có phần dự trù. Hệ thống sẽ trừ đúng số lượng kế hoạch khi bạn xác nhận."
                                )
                            }
                        }
                    }
                }

                ActivityProofCaptureSection(
                    proofImage: $proofImage,
                    subtitle: "Bạn có thể chụp ảnh nhanh tại kho để làm minh chứng tiếp nhận vật phẩm."
                )
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Colors.background)
        .navigationTitle("Xác nhận tiếp nhận")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Đóng") {
                    dismiss()
                }
                .disabled(isSubmissionLocked)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DS.Spacing.sm) {
                if hasBufferedItems {
                    IncidentInlineNotice(
                        icon: "shippingbox",
                        text: submitSummaryText,
                        tone: DS.Colors.warning
                    )
                }

                IncidentSubmitButton(
                    title: "Xác nhận đã tiếp nhận",
                    isEnabled: canSubmit,
                    isLoading: isSubmissionLocked
                ) {
                    guard isSubmissionLocked == false else { return }
                    isSubmittingLocal = true

                    Task { @MainActor in
                        let didSucceed = await onSubmit(submitPayload, proofImage)
                        if didSucceed {
                            dismiss()
                        } else {
                            isSubmittingLocal = false
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.md)
            .background(.ultraThinMaterial)
        }
    }

    private var hasBufferedItems: Bool {
        drafts.contains { $0.bufferQuantityToReceive > 0 }
    }

    private var canSubmit: Bool {
        true
    }

    private var isSubmissionLocked: Bool {
        isSubmitting || isSubmittingLocal
    }

    private var submitPayload: [MissionPickupBufferUsageRequest] {
        drafts.compactMap { draft in
            let bufferQuantity = draft.bufferQuantityToReceive
            guard bufferQuantity > 0 else {
                return nil
            }

            return MissionPickupBufferUsageRequest(
                itemId: draft.itemId,
                bufferQuantityUsed: bufferQuantity,
                bufferUsedReason: automaticBufferReceiptReason
            )
        }
    }

    private var submitSummaryText: String {
        "Hệ thống sẽ trừ toàn bộ vật phẩm dự trù cùng với số lượng kế hoạch."
    }

    private func pickupCardSubtitle(for draft: PickupBufferDraft) -> String {
        if draft.bufferQuantityToReceive > 0 {
            return "Kế hoạch \(quantityText(draft.plannedQuantity, unit: draft.unit)) • Dự trù \(quantityText(draft.bufferQuantityToReceive, unit: draft.unit)) • Tổng \(quantityText(draft.totalPickupQuantity, unit: draft.unit))"
        }

        return "Kế hoạch \(quantityText(draft.plannedQuantity, unit: draft.unit))"
    }

    private var automaticBufferReceiptReason: String {
        "Đội cứu hộ tiếp nhận toàn bộ vật phẩm dự trù theo kế hoạch."
    }
}

struct DeliveryConfirmationSheet: View {
    let activity: Activity
    let isSubmitting: Bool
    let onSubmit: ([MissionActualDeliveredItemRequest], String?, UIImage?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [DeliveryDraft]
    @State private var deliveryNote = ""
    @State private var proofImage: UIImage?
    @State private var isSubmittingLocal = false

    init(
        activity: Activity,
        isSubmitting: Bool,
        onSubmit: @escaping ([MissionActualDeliveredItemRequest], String?, UIImage?) async -> Bool
    ) {
        self.activity = activity
        self.isSubmitting = isSubmitting
        self.onSubmit = onSubmit
        _drafts = State(initialValue: (activity.suppliesToCollect ?? []).map(DeliveryDraft.init))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                ForEach(drafts.indices, id: \.self) { index in
                    IncidentFormSection(
                        title: drafts[index].itemName,
                        subtitle: deliveryCardSubtitle(for: drafts[index])
                    ) {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            if drafts[index].bufferQuantityToDeliver > 0 {
                                HStack(spacing: DS.Spacing.sm) {
                                    metricChip(
                                        title: "Kế hoạch",
                                        value: quantityText(drafts[index].plannedQuantity, unit: drafts[index].unit),
                                        tone: DS.Colors.info
                                    )

                                    metricChip(
                                        title: "Dự trù đã nhận",
                                        value: quantityText(drafts[index].bufferQuantityToDeliver, unit: drafts[index].unit),
                                        tone: DS.Colors.warning
                                    )
                                }

                                metricChip(
                                    title: "Tối đa có thể phát",
                                    value: quantityText(drafts[index].deliverableQuantity, unit: drafts[index].unit),
                                    tone: DS.Colors.accent
                                )
                            }

                            IncidentTextInputField(
                                title: "Số lượng đã giao thực tế",
                                placeholder: String(drafts[index].deliverableQuantity),
                                text: bindingForDeliveryQuantity(at: index),
                                keyboardType: .numberPad
                            )

                            if let validationMessage = deliveryValidationMessage(for: drafts[index]) {
                                validationText(validationMessage)
                            }

                            if let deltaDescription = deliveryDeltaDescription(for: drafts[index]) {
                                IncidentInlineNotice(
                                    icon: "chart.bar.doc.horizontal",
                                    text: deltaDescription,
                                    tone: deliveryDeltaTone(for: drafts[index], actualQuantity: parsedActualQuantity(at: index))
                                )
                            }
                        }
                    }
                }

                IncidentFormSection(
                    title: hasDiscrepancy ? "Ghi chú chênh lệch" : "Ghi chú phân phát",
                    subtitle: hasDiscrepancy
                        ? "Có thể ghi lý do còn vật phẩm chưa phát hết; nếu để trống thì bước báo cáo đội sẽ yêu cầu bổ sung."
                        : "Có thể để trống nếu đội đã phân phát đúng số lượng đang giữ."
                ) {
                    IncidentTextInputField(
                        title: "Ghi chú",
                        placeholder: "Ví dụ: một phần vật phẩm chưa phát hết và sẽ chuyển sang hoàn trả về kho...",
                        text: $deliveryNote,
                        axis: .vertical
                    )
                }

                ActivityProofCaptureSection(
                    proofImage: $proofImage,
                    subtitle: "Bạn có thể chụp ảnh hiện trường giao vật phẩm để lưu minh chứng phân phát."
                )
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Colors.background)
        .navigationTitle("Xác nhận phân phát")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Đóng") {
                    dismiss()
                }
                .disabled(isSubmissionLocked)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DS.Spacing.sm) {
                if hasDiscrepancy {
                    IncidentInlineNotice(
                        icon: "shippingbox.circle.fill",
                        text: "Nếu còn vật phẩm chưa phân phát hết, hệ thống sẽ tạo bước hoàn trả cho phần còn lại.",
                        tone: DS.Colors.warning
                    )
                }

                IncidentSubmitButton(
                    title: "Xác nhận đã phân phát",
                    isEnabled: canSubmit,
                    isLoading: isSubmissionLocked
                ) {
                    guard isSubmissionLocked == false else { return }
                    isSubmittingLocal = true

                    Task { @MainActor in
                        let didSucceed = await onSubmit(submitPayload, deliveryNote, proofImage)
                        if didSucceed {
                            dismiss()
                        } else {
                            isSubmittingLocal = false
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.md)
            .background(.ultraThinMaterial)
        }
    }

    private var canSubmit: Bool {
        drafts.allSatisfy { deliveryValidationMessage(for: $0) == nil }
    }

    private var isSubmissionLocked: Bool {
        isSubmitting || isSubmittingLocal
    }

    private var submitPayload: [MissionActualDeliveredItemRequest] {
        drafts.compactMap { draft in
            guard let actualQuantity = parsedActualQuantity(for: draft) else { return nil }
            let lotAllocations = builtLotAllocations(for: draft, actualQuantity: actualQuantity)
            let reusableUnits = builtReusableUnits(for: draft, actualQuantity: actualQuantity)

            return MissionActualDeliveredItemRequest(
                itemId: draft.itemId,
                actualQuantity: actualQuantity,
                lotAllocations: lotAllocations.isEmpty ? nil : lotAllocations,
                reusableUnits: reusableUnits.isEmpty ? nil : reusableUnits
            )
        }
    }

    private var hasDiscrepancy: Bool {
        drafts.contains { draft in
            guard let actualQuantity = parsedActualQuantity(for: draft) else { return false }
            return actualQuantity != draft.deliverableQuantity
        }
    }

    private func bindingForDeliveryQuantity(at index: Int) -> Binding<String> {
        Binding(
            get: { drafts[index].actualQuantityText },
            set: { drafts[index].actualQuantityText = sanitizedIntegerInput($0) }
        )
    }

    private func parsedActualQuantity(at index: Int) -> Int {
        parsedActualQuantity(for: drafts[index]) ?? 0
    }

    private func parsedActualQuantity(for draft: DeliveryDraft) -> Int? {
        Int(draft.actualQuantityText.isEmpty ? "0" : draft.actualQuantityText)
    }

    private func deliveryValidationMessage(for draft: DeliveryDraft) -> String? {
        guard let actualQuantity = parsedActualQuantity(for: draft) else {
            return "Vui lòng nhập số nguyên hợp lệ."
        }
        if actualQuantity < 0 {
            return "Số lượng thực tế không được nhỏ hơn 0."
        }
        if actualQuantity > draft.deliverableQuantity {
            return "Số lượng thực tế không được lớn hơn số lượng đội đang giữ."
        }
        if draft.hasLotTracking && draft.hasReusableTracking {
            return "Vật phẩm này có dữ liệu giao theo cả lô và reusable unit. Vui lòng tải lại nhiệm vụ."
        }
        if draft.hasLotTracking && actualQuantity > draft.availableLotQuantity {
            return "Số lượng thực tế vượt quá số lượng theo lô mà đội đang mang theo."
        }
        if draft.hasReusableTracking && actualQuantity > draft.availableReusableQuantity {
            return "Số lượng thực tế vượt quá số reusable unit mà đội đang mang theo."
        }
        if draft.hasLotTracking && actualQuantity > 0 && builtLotAllocations(for: draft, actualQuantity: actualQuantity).isEmpty {
            return "Không thể tự phân bổ số lượng theo lô cho vật phẩm này."
        }
        if draft.hasReusableTracking && actualQuantity > 0 && builtReusableUnits(for: draft, actualQuantity: actualQuantity).count != actualQuantity {
            return "Không thể xác định đủ reusable unit để xác nhận phân phát."
        }
        return nil
    }

    private func deliveryDeltaDescription(for draft: DeliveryDraft) -> String? {
        guard let actualQuantity = parsedActualQuantity(for: draft) else { return nil }
        let delta = actualQuantity - draft.plannedQuantity
        if delta == 0, actualQuantity == draft.deliverableQuantity {
            return nil
        }
        if delta < 0 {
            return "Còn thiếu \(quantityText(abs(delta), unit: draft.unit)) so với kế hoạch."
        }
        if delta > 0 {
            return "Đã phát thêm \(quantityText(delta, unit: draft.unit)) từ vật phẩm dự trù."
        }

        let remaining = draft.deliverableQuantity - actualQuantity
        if remaining > 0 {
            return "Còn \(quantityText(remaining, unit: draft.unit)) vật phẩm dự trù chưa phân phát."
        }

        return nil
    }

    private func deliveryDeltaTone(for draft: DeliveryDraft, actualQuantity: Int) -> Color {
        actualQuantity < draft.deliverableQuantity ? DS.Colors.warning : DS.Colors.info
    }

    private func deliveryCardSubtitle(for draft: DeliveryDraft) -> String {
        if draft.bufferQuantityToDeliver > 0 {
            return "Kế hoạch \(quantityText(draft.plannedQuantity, unit: draft.unit)) • Dự trù \(quantityText(draft.bufferQuantityToDeliver, unit: draft.unit)) • Tối đa \(quantityText(draft.deliverableQuantity, unit: draft.unit))"
        }

        return "Kế hoạch \(quantityText(draft.plannedQuantity, unit: draft.unit))"
    }

    private func builtLotAllocations(
        for draft: DeliveryDraft,
        actualQuantity: Int
    ) -> [MissionDeliveryLotAllocationRequest] {
        guard actualQuantity > 0, draft.hasLotTracking else {
            return []
        }

        var remaining = actualQuantity
        var allocations: [MissionDeliveryLotAllocationRequest] = []

        for lot in draft.deliveryLotAllocations {
            guard remaining > 0 else { break }
            guard
                let lotId = lot.numericLotId,
                let availableQuantity = lot.quantityTaken,
                availableQuantity > 0
            else {
                continue
            }

            let quantityTaken = min(availableQuantity, remaining)
            allocations.append(
                MissionDeliveryLotAllocationRequest(
                    lotId: lotId,
                    quantityTaken: quantityTaken,
                    receivedDate: lot.receivedDate,
                    expiredDate: lot.expiredDate,
                    remainingQuantityAfterExecution: max(0, availableQuantity - quantityTaken)
                )
            )
            remaining -= quantityTaken
        }

        return remaining == 0 ? allocations : []
    }

    private func builtReusableUnits(
        for draft: DeliveryDraft,
        actualQuantity: Int
    ) -> [MissionDeliveryReusableUnitRequest] {
        guard actualQuantity > 0, draft.hasReusableTracking else {
            return []
        }

        return Array(draft.deliveryReusableUnits.prefix(actualQuantity)).compactMap { unit in
            guard let reusableItemId = unit.reusableItemId, reusableItemId > 0 else {
                return nil
            }

            return MissionDeliveryReusableUnitRequest(
                reusableItemId: reusableItemId,
                itemModelId: unit.itemModelId ?? draft.itemId,
                itemName: unit.itemName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? draft.itemName,
                serialNumber: unit.serialNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                condition: unit.condition,
                note: unit.note
            )
        }
    }
}

struct ReturnSuppliesConfirmationSheet: View {
    let activity: Activity
    let isSubmitting: Bool
    let onSubmit: (UIImage?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [ReturnSupplyDraft]
    @State private var proofImage: UIImage?
    @State private var isSubmittingLocal = false

    init(
        activity: Activity,
        isSubmitting: Bool,
        onSubmit: @escaping (UIImage?) async -> Bool
    ) {
        self.activity = activity
        self.isSubmitting = isSubmitting
        self.onSubmit = onSubmit
        _drafts = State(initialValue: (activity.suppliesToCollect ?? []).map(ReturnSupplyDraft.init))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                IncidentFormSection(
                    title: "Xác nhận hoàn trả vật phẩm"
                ) {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        if let depotName = activity.depotName, depotName.isEmpty == false {
                            IncidentContextRow(
                                icon: "shippingbox.fill",
                                title: "Kho tiếp tế",
                                value: depotName
                            )
                        }

                        if let description = activity.description, description.isEmpty == false {
                            IncidentContextRow(
                                icon: "list.bullet.rectangle",
                                title: "Công việc",
                                value: description
                            )
                        }

                        IncidentInlineNotice(
                            icon: "arrow.uturn.backward.circle.fill",
                            text: "Hệ thống hiển thị chi tiết các lô cần hoàn trả để đội đối chiếu trước khi xác nhận.",
                            tone: DS.Colors.info
                        )
                    }
                }

                ForEach(drafts.indices, id: \.self) { index in
                    IncidentFormSection(
                        title: drafts[index].itemName,
                        subtitle: returnCardSubtitle(for: drafts[index])
                    ) {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack(spacing: DS.Spacing.sm) {
                                metricChip(
                                    title: "Kế hoạch",
                                    value: quantityText(drafts[index].plannedQuantity, unit: drafts[index].unit),
                                    tone: DS.Colors.info
                                )

                                metricChip(
                                    title: "Theo lô",
                                    value: "\(drafts[index].lotCount) lô",
                                    tone: DS.Colors.warning
                                )
                            }

                            if drafts[index].primaryLots.isEmpty {
                                IncidentInlineNotice(
                                    icon: "shippingbox",
                                    text: "Vật phẩm này chưa có thông tin lô hoàn trả chi tiết.",
                                    tone: DS.Colors.warning
                                )
                            } else {
                                supplyLotSummarySection(
                                    title: drafts[index].primaryLotsTitle,
                                    allocations: drafts[index].primaryLots,
                                    unit: drafts[index].unit
                                )
                            }

                            if let referenceTitle = drafts[index].referenceLotsTitle,
                               drafts[index].referenceLots.isEmpty == false {
                                supplyLotSummarySection(
                                    title: referenceTitle,
                                    allocations: drafts[index].referenceLots,
                                    unit: drafts[index].unit
                                )
                            }
                        }
                    }
                }

                ActivityProofCaptureSection(
                    proofImage: $proofImage,
                    subtitle: "Bạn có thể chụp ảnh tại kho để lưu minh chứng hoàn trả vật phẩm."
                )
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Colors.background)
        .navigationTitle("Xác nhận hoàn trả")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Đóng") {
                    dismiss()
                }
                .disabled(isSubmissionLocked)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DS.Spacing.sm) {
                if hasMissingLotDetails {
                    IncidentInlineNotice(
                        icon: "exclamationmark.triangle.fill",
                        text: "Một số vật phẩm chưa có thông tin lô chi tiết từ hệ thống. Bạn vẫn có thể xác nhận hoàn trả.",
                        tone: DS.Colors.warning
                    )
                }

                IncidentSubmitButton(
                    title: "Xác nhận đã hoàn trả",
                    isEnabled: true,
                    isLoading: isSubmissionLocked
                ) {
                    guard isSubmissionLocked == false else { return }
                    isSubmittingLocal = true

                    Task { @MainActor in
                        let didSucceed = await onSubmit(proofImage)
                        if didSucceed {
                            dismiss()
                        } else {
                            isSubmittingLocal = false
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.md)
            .background(.ultraThinMaterial)
        }
    }

    private var hasMissingLotDetails: Bool {
        drafts.contains { $0.primaryLots.isEmpty }
    }

    private var isSubmissionLocked: Bool {
        isSubmitting || isSubmittingLocal
    }

    private func returnCardSubtitle(for draft: ReturnSupplyDraft) -> String {
        if draft.lotCount > 0 {
            return "Kế hoạch \(quantityText(draft.plannedQuantity, unit: draft.unit)) • Theo dõi \(draft.lotCount) lô"
        }

        return "Kế hoạch \(quantityText(draft.plannedQuantity, unit: draft.unit))"
    }
}

private struct PickupBufferDraft: Identifiable {
    let itemId: Int
    let itemName: String
    let unit: String?
    let plannedQuantity: Int
    let bufferAvailable: Int
    let lotAllocations: [MissionSupplyLotAllocation]

    var id: String { "\(itemId)" }
    var bufferQuantityToReceive: Int { max(0, bufferAvailable) }
    var totalPickupQuantity: Int { plannedQuantity + bufferQuantityToReceive }

    init(supply: MissionSupply) {
        itemId = supply.itemId ?? -1
        itemName = supply.itemName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Vật phẩm"
        unit = supply.unit
        plannedQuantity = supply.quantity
        bufferAvailable = supply.bufferQuantity ?? 0
        lotAllocations = PickupBufferDraft.normalizedLotAllocations(from: supply)
    }

    private static func normalizedLotAllocations(from supply: MissionSupply) -> [MissionSupplyLotAllocation] {
        let pickupLots = normalizedDisplayableLotAllocations(supply.pickupLotAllocations)
        if pickupLots.isEmpty == false {
            return pickupLots
        }

        return normalizedDisplayableLotAllocations(supply.plannedPickupLotAllocations)
    }
}

private struct DeliveryDraft: Identifiable {
    let itemId: Int
    let itemName: String
    let unit: String?
    let plannedQuantity: Int
    let deliverableQuantity: Int
    let deliveryLotAllocations: [MissionSupplyLotAllocation]
    let deliveryReusableUnits: [MissionSupplyReusableUnit]
    var actualQuantityText: String

    var id: String { "\(itemId)" }
    var bufferQuantityToDeliver: Int { max(0, deliverableQuantity - plannedQuantity) }

    var hasLotTracking: Bool { deliveryLotAllocations.isEmpty == false }
    var hasReusableTracking: Bool { deliveryReusableUnits.isEmpty == false }
    var availableLotQuantity: Int {
        deliveryLotAllocations.reduce(0) { partialResult, lot in
            partialResult + max(0, lot.quantityTaken ?? 0)
        }
    }
    var availableReusableQuantity: Int { deliveryReusableUnits.count }

    init(supply: MissionSupply) {
        itemId = supply.itemId ?? -1
        itemName = supply.itemName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Vật phẩm"
        unit = supply.unit
        let resolvedPlannedQuantity = max(supply.quantity, 0)
        let normalizedLotAllocations = DeliveryDraft.normalizedLotAllocations(from: supply)
        let normalizedReusableUnits = DeliveryDraft.normalizedReusableUnits(from: supply)
        let resolvedDeliverableQuantity = DeliveryDraft.deliverableQuantity(
            plannedQuantity: resolvedPlannedQuantity,
            supply: supply,
            lotAllocations: normalizedLotAllocations,
            reusableUnits: normalizedReusableUnits
        )
        plannedQuantity = resolvedPlannedQuantity
        deliveryLotAllocations = normalizedLotAllocations
        deliveryReusableUnits = normalizedReusableUnits
        deliverableQuantity = resolvedDeliverableQuantity
        actualQuantityText = String(supply.actualDeliveredQuantity ?? resolvedDeliverableQuantity)
    }

    private static func deliverableQuantity(
        plannedQuantity: Int,
        supply: MissionSupply,
        lotAllocations: [MissionSupplyLotAllocation],
        reusableUnits: [MissionSupplyReusableUnit]
    ) -> Int {
        let bufferQuantity: Int
        if let bufferUsedQuantity = supply.bufferUsedQuantity {
            bufferQuantity = max(bufferUsedQuantity, 0)
        } else {
            bufferQuantity = max(supply.bufferQuantity ?? 0, 0)
        }

        let lotQuantity = lotAllocations.reduce(0) { partialResult, lot in
            partialResult + max(0, lot.quantityTaken ?? 0)
        }

        return max(plannedQuantity + bufferQuantity, lotQuantity, reusableUnits.count)
    }

    private static func normalizedLotAllocations(from supply: MissionSupply) -> [MissionSupplyLotAllocation] {
        let availableDeliveryLots = nonEmptyLotAllocations(supply.availableDeliveryLotAllocations)
        if availableDeliveryLots.isEmpty == false {
            return availableDeliveryLots
        }

        let pickupLots = nonEmptyLotAllocations(supply.pickupLotAllocations)
        if pickupLots.isEmpty == false {
            return pickupLots
        }

        return nonEmptyLotAllocations(supply.plannedPickupLotAllocations)
    }

    private static func nonEmptyLotAllocations(
        _ allocations: [MissionSupplyLotAllocation]?
    ) -> [MissionSupplyLotAllocation] {
        (allocations ?? []).filter(\.hasDisplayableValue)
    }

    private static func normalizedReusableUnits(from supply: MissionSupply) -> [MissionSupplyReusableUnit] {
        let availableDeliveryUnits = nonEmptyReusableUnits(supply.availableDeliveryReusableUnits)
        if availableDeliveryUnits.isEmpty == false {
            return availableDeliveryUnits
        }

        let pickedUnits = nonEmptyReusableUnits(supply.pickedReusableUnits)
        if pickedUnits.isEmpty == false {
            return pickedUnits
        }

        return nonEmptyReusableUnits(supply.plannedPickupReusableUnits)
    }

    private static func nonEmptyReusableUnits(
        _ units: [MissionSupplyReusableUnit]?
    ) -> [MissionSupplyReusableUnit] {
        (units ?? []).filter { unit in
            if let reusableItemId = unit.reusableItemId {
                return reusableItemId > 0
            }

            return false
        }
    }
}

private struct ReturnSupplyDraft: Identifiable {
    let itemId: Int
    let itemName: String
    let unit: String?
    let plannedQuantity: Int
    let primaryLotsTitle: String
    let primaryLots: [MissionSupplyLotAllocation]
    let referenceLotsTitle: String?
    let referenceLots: [MissionSupplyLotAllocation]

    var id: String { "\(itemId)" }
    var lotCount: Int { primaryLots.count }

    init(supply: MissionSupply) {
        itemId = supply.itemId ?? -1
        itemName = supply.itemName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Vật phẩm"
        unit = supply.unit
        plannedQuantity = supply.quantity

        let expectedLots = normalizedDisplayableLotAllocations(supply.expectedReturnLotAllocations)
        let returnedLots = normalizedDisplayableLotAllocations(supply.returnedLotAllocations)
        let deliveredLots = normalizedDisplayableLotAllocations(supply.deliveredLotAllocations)
        let availableLots = normalizedDisplayableLotAllocations(supply.availableDeliveryLotAllocations)

        if returnedLots.isEmpty == false {
            primaryLotsTitle = "Lô đã hoàn trả"
            primaryLots = returnedLots
            referenceLotsTitle = expectedLots.isEmpty == false ? "Lô dự kiến ban đầu" : nil
            referenceLots = expectedLots
        } else if expectedLots.isEmpty == false {
            primaryLotsTitle = "Lô dự kiến hoàn trả"
            primaryLots = expectedLots
            referenceLotsTitle = nil
            referenceLots = []
        } else if deliveredLots.isEmpty == false {
            primaryLotsTitle = "Lô đang giữ để hoàn trả"
            primaryLots = deliveredLots
            referenceLotsTitle = nil
            referenceLots = []
        } else {
            primaryLotsTitle = "Lô liên quan"
            primaryLots = availableLots
            referenceLotsTitle = nil
            referenceLots = []
        }
    }
}

private func supplyLotSummarySection(
    title: String,
    allocations: [MissionSupplyLotAllocation],
    unit: String?
) -> some View {
    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(DS.Colors.textSecondary)

        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ForEach(Array(allocations.enumerated()), id: \.offset) { _, allocation in
                VStack(alignment: .leading, spacing: 7) {
                    Text("Lô \(lotIdDisplay(allocation.lotId))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DS.Colors.text)

                    HStack(spacing: DS.Spacing.xs) {
                        lotInfoChip(
                            title: "SL",
                            value: lotQuantityDisplay(allocation.quantityTaken, unit: unit),
                            tone: DS.Colors.info
                        )

                        lotInfoChip(
                            title: "HSD",
                            value: lotExpiryDisplay(allocation.expiredDate),
                            tone: DS.Colors.warning
                        )
                    }
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, DS.Spacing.sm)
    .padding(.vertical, 10)
    .background(DS.Colors.info.opacity(0.07))
    .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(DS.Colors.info.opacity(0.24), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
}

private func lotInfoChip(title: String, value: String, tone: Color) -> some View {
    HStack(spacing: 6) {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DS.Colors.textSecondary)

        Text(value)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(DS.Colors.text)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(tone.opacity(0.12))
    .overlay(
        Capsule(style: .continuous)
            .stroke(tone.opacity(0.3), lineWidth: 1)
    )
    .clipShape(Capsule(style: .continuous))
}

private func normalizedDisplayableLotAllocations(
    _ allocations: [MissionSupplyLotAllocation]?
) -> [MissionSupplyLotAllocation] {
    let filteredAllocations = (allocations ?? []).filter(\.hasDisplayableValue)
    return filteredAllocations.sorted { lhs, rhs in
        let leftDate = lotSortDate(lhs.expiredDate)
        let rightDate = lotSortDate(rhs.expiredDate)

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

        return lotSortKey(lhs.lotId) < lotSortKey(rhs.lotId)
    }
}

private func lotIdDisplay(_ lotId: String?) -> String {
    lotId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "?"
}

private func lotQuantityDisplay(_ quantity: Int?, unit: String?) -> String {
    guard let quantity else { return "?" }

    if let unit, unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
        return "\(quantity) \(unit)"
    }

    return "\(quantity)"
}

private func lotExpiryDisplay(_ rawValue: String?) -> String {
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

private func lotSortDate(_ rawValue: String?) -> Date? {
    guard let rawValue = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), rawValue.isEmpty == false else {
        return nil
    }

    let isoWithFractionalSeconds = ISO8601DateFormatter()
    isoWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let isoBasic = ISO8601DateFormatter()
    isoBasic.formatOptions = [.withInternetDateTime]

    return isoWithFractionalSeconds.date(from: rawValue) ?? isoBasic.date(from: rawValue)
}

private func lotSortKey(_ lotId: String?) -> String {
    lotId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
}

private func metricChip(title: String, value: String, tone: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DS.Colors.textSecondary)
            .textCase(.uppercase)

        Text(value)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(DS.Colors.text)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, DS.Spacing.sm)
    .padding(.vertical, 10)
    .background(tone.opacity(0.1))
    .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(tone.opacity(0.25), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
}

private func quickActionChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    IncidentChoiceChip(
        title: title,
        isSelected: isSelected,
        tone: isSelected ? DS.Colors.accent : DS.Colors.textSecondary,
        action: action
    )
}

private func validationText(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(DS.Colors.accent)
        .fixedSize(horizontal: false, vertical: true)
}

private func sanitizedIntegerInput(_ value: String) -> String {
    value.filter(\.isNumber)
}

private func quantityText(_ quantity: Int, unit: String?) -> String {
    if let unit, unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
        return "\(quantity) \(unit)"
    }
    return "\(quantity)"
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
