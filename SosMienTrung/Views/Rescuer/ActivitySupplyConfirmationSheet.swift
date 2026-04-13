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

                        IncidentInlineNotice(
                            icon: "info.circle.fill",
                            text: hasBufferedItems
                                ? "Chỉ nhập số vật phẩm dự trù thực tế đã dùng. Nếu không dùng vật phẩm dự trù, để 0 và xác nhận."
                                : "Bước này không có vật phẩm dự trù. Bạn chỉ cần xác nhận để hệ thống trừ đúng số lượng kế hoạch."
                        )
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
                                    value: quantityText(drafts[index].bufferAvailable, unit: drafts[index].unit),
                                    tone: DS.Colors.warning
                                )
                            }

                            if drafts[index].bufferAvailable > 0 {
                                HStack(spacing: DS.Spacing.xs) {
                                    quickActionChip(
                                        title: "Không dùng dự trù",
                                        isSelected: parsedBufferQuantity(at: index) == 0
                                    ) {
                                        drafts[index].usedBufferText = "0"
                                        drafts[index].reason = ""
                                    }

                                    quickActionChip(
                                        title: "Dùng hết dự trù",
                                        isSelected: parsedBufferQuantity(at: index) == drafts[index].bufferAvailable
                                    ) {
                                        drafts[index].usedBufferText = String(drafts[index].bufferAvailable)
                                    }
                                }

                                IncidentTextInputField(
                                    title: "Vật phẩm dự trù đã dùng",
                                    placeholder: "0",
                                    text: bindingForPickupQuantity(at: index),
                                    keyboardType: .numberPad
                                )

                                if let validationMessage = pickupValidationMessage(for: drafts[index]) {
                                    validationText(validationMessage)
                                }

                                if parsedBufferQuantity(at: index) > 0 {
                                    IncidentTextInputField(
                                        title: "Lý do dùng vật phẩm dự trù",
                                        placeholder: "Ví dụ: tăng số hộ dân thực tế, phát sinh thêm nhu cầu tại hiện trường...",
                                        text: bindingForPickupReason(at: index),
                                        axis: .vertical
                                    )
                                }
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
        drafts.contains { $0.bufferAvailable > 0 }
    }

    private var canSubmit: Bool {
        drafts.allSatisfy { pickupValidationMessage(for: $0) == nil }
    }

    private var isSubmissionLocked: Bool {
        isSubmitting || isSubmittingLocal
    }

    private var submitPayload: [MissionPickupBufferUsageRequest] {
        drafts.compactMap { draft in
            guard draft.bufferAvailable > 0, let used = parsedBufferQuantity(for: draft), used > 0 else {
                return nil
            }

            return MissionPickupBufferUsageRequest(
                itemId: draft.itemId,
                bufferQuantityUsed: used,
                bufferUsedReason: draft.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private var submitSummaryText: String {
        let usedBufferTotal = submitPayload.reduce(0) { $0 + $1.bufferQuantityUsed }
        if usedBufferTotal > 0 {
            return "Hệ thống sẽ ghi nhận \(usedBufferTotal) đơn vị vật phẩm dự trù đã dùng trước khi hoàn tất bước tiếp nhận."
        }

        return "Chưa dùng vật phẩm dự trù. Hệ thống sẽ chỉ trừ số lượng theo kế hoạch."
    }

    private func pickupCardSubtitle(for draft: PickupBufferDraft) -> String {
        if draft.bufferAvailable > 0 {
            return "Kế hoạch \(quantityText(draft.plannedQuantity, unit: draft.unit)) • Có thể dùng thêm tối đa \(quantityText(draft.bufferAvailable, unit: draft.unit)) vật phẩm dự trù"
        }

        return "Kế hoạch \(quantityText(draft.plannedQuantity, unit: draft.unit))"
    }

    private func bindingForPickupQuantity(at index: Int) -> Binding<String> {
        Binding(
            get: { drafts[index].usedBufferText },
            set: { drafts[index].usedBufferText = sanitizedIntegerInput($0) }
        )
    }

    private func bindingForPickupReason(at index: Int) -> Binding<String> {
        Binding(
            get: { drafts[index].reason },
            set: { drafts[index].reason = $0 }
        )
    }

    private func parsedBufferQuantity(at index: Int) -> Int {
        parsedBufferQuantity(for: drafts[index]) ?? 0
    }

    private func parsedBufferQuantity(for draft: PickupBufferDraft) -> Int? {
        Int(draft.usedBufferText.isEmpty ? "0" : draft.usedBufferText)
    }

    private func pickupValidationMessage(for draft: PickupBufferDraft) -> String? {
        guard draft.bufferAvailable > 0 else { return nil }
        guard let usedBuffer = parsedBufferQuantity(for: draft) else {
            return "Vui lòng nhập số nguyên hợp lệ."
        }
        if usedBuffer < 0 {
            return "Số lượng vật phẩm dự trù không được nhỏ hơn 0."
        }
        if usedBuffer > draft.bufferAvailable {
            return "Số lượng vật phẩm dự trù đã dùng không được vượt quá mức dự trù."
        }
        if usedBuffer > 0 && draft.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Cần nhập lý do khi có dùng vật phẩm dự trù."
        }
        return nil
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
                IncidentFormSection(
                    title: "Xác nhận phân phát vật phẩm",
                    subtitle: "Nhập số lượng thực tế từng vật phẩm trước khi hoàn tất bước phân phát."
                ) {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        IncidentInlineNotice(
                            icon: "arrowshape.turn.up.right.circle.fill",
                            text: hasDiscrepancy
                                ? "Bạn đang nhập số lượng khác với kế hoạch. Phần vật phẩm chưa phân phát sẽ được chuyển sang bước hoàn trả."
                                : "Giữ nguyên số lượng kế hoạch nếu đội đã phân phát đủ như dự kiến."
                        )

                        HStack(spacing: DS.Spacing.sm) {
                            metricChip(
                                title: "Tổng kế hoạch",
                                value: quantityText(totalPlannedQuantity, unit: nil),
                                tone: DS.Colors.info
                            )

                            metricChip(
                                title: "Tổng thực tế",
                                value: quantityText(totalActualQuantity, unit: nil),
                                tone: hasDiscrepancy ? DS.Colors.warning : DS.Colors.success
                            )
                        }
                    }
                }

                ForEach(drafts.indices, id: \.self) { index in
                    IncidentFormSection(
                        title: drafts[index].itemName,
                        subtitle: "Kế hoạch \(quantityText(drafts[index].plannedQuantity, unit: drafts[index].unit))"
                    ) {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack(spacing: DS.Spacing.xs) {
                                quickActionChip(
                                    title: "Đủ kế hoạch",
                                    isSelected: parsedActualQuantity(at: index) == drafts[index].plannedQuantity
                                ) {
                                    drafts[index].actualQuantityText = String(drafts[index].plannedQuantity)
                                }

                                quickActionChip(
                                    title: "Chưa phát",
                                    isSelected: parsedActualQuantity(at: index) == 0
                                ) {
                                    drafts[index].actualQuantityText = "0"
                                }
                            }

                            IncidentTextInputField(
                                title: "Số lượng đã giao thực tế",
                                placeholder: String(drafts[index].plannedQuantity),
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
                                    tone: parsedActualQuantity(at: index) < drafts[index].plannedQuantity ? DS.Colors.warning : DS.Colors.info
                                )
                            }
                        }
                    }
                }

                IncidentFormSection(
                    title: hasDiscrepancy ? "Ghi chú chênh lệch" : "Ghi chú phân phát",
                    subtitle: hasDiscrepancy
                        ? "Nên ghi rõ lý do nếu số lượng phân phát khác với kế hoạch."
                        : "Có thể để trống nếu đội đã phân phát đúng theo kế hoạch."
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
            return MissionActualDeliveredItemRequest(
                itemId: draft.itemId,
                actualQuantity: actualQuantity
            )
        }
    }

    private var hasDiscrepancy: Bool {
        drafts.contains { draft in
            guard let actualQuantity = parsedActualQuantity(for: draft) else { return false }
            return actualQuantity != draft.plannedQuantity
        }
    }

    private var totalPlannedQuantity: Int {
        drafts.reduce(0) { $0 + $1.plannedQuantity }
    }

    private var totalActualQuantity: Int {
        drafts.reduce(0) { partial, draft in
            partial + (parsedActualQuantity(for: draft) ?? 0)
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
        return nil
    }

    private func deliveryDeltaDescription(for draft: DeliveryDraft) -> String? {
        guard let actualQuantity = parsedActualQuantity(for: draft) else { return nil }
        let delta = actualQuantity - draft.plannedQuantity
        if delta == 0 {
            return nil
        }
        if delta < 0 {
            return "Còn thiếu \(quantityText(abs(delta), unit: draft.unit)) so với kế hoạch."
        }
        return "Nhiều hơn kế hoạch \(quantityText(delta, unit: draft.unit))."
    }
}

private struct PickupBufferDraft: Identifiable {
    let itemId: Int
    let itemName: String
    let unit: String?
    let plannedQuantity: Int
    let bufferAvailable: Int
    var usedBufferText: String
    var reason: String

    var id: String { "\(itemId)" }

    init(supply: MissionSupply) {
        itemId = supply.itemId ?? -1
        itemName = supply.itemName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Vật phẩm"
        unit = supply.unit
        plannedQuantity = supply.quantity
        bufferAvailable = supply.bufferQuantity ?? 0
        usedBufferText = String(supply.bufferUsedQuantity ?? 0)
        reason = supply.bufferUsedReason ?? ""
    }
}

private struct DeliveryDraft: Identifiable {
    let itemId: Int
    let itemName: String
    let unit: String?
    let plannedQuantity: Int
    var actualQuantityText: String

    var id: String { "\(itemId)" }

    init(supply: MissionSupply) {
        itemId = supply.itemId ?? -1
        itemName = supply.itemName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Vật phẩm"
        unit = supply.unit
        plannedQuantity = supply.quantity
        actualQuantityText = String(supply.actualDeliveredQuantity ?? supply.quantity)
    }
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
