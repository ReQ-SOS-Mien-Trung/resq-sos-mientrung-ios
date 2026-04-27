import SwiftUI
import CoreLocation

struct ActivityIncidentReportFormView: View {
    let mission: Mission
    let missionTeamId: Int
    let activities: [Activity]
    @ObservedObject var incidentVM: IncidentViewModel

    @ObservedObject private var authSession = AuthSessionStore.shared
    @StateObject private var locationManager = LocationManager()
    @State private var draft = ActivityIncidentDraft()
    @State private var recordedAt = Date()
    @Environment(\.dismiss) private var dismiss

    private let gridColumns = [GridItem(.adaptive(minimum: 150), spacing: DS.Spacing.xs)]

    private var currentLocation: CLLocationCoordinate2D? {
        locationManager.currentLocation?.coordinate
    }

    private var reportableActivities: [Activity] {
        activities
            .filter {
                let normalized = normalizedStatus($0.status)
                return normalized != "succeed"
                    && normalized != "completed"
                    && normalized != "failed"
                    && normalized != "cancelled"
            }
            .sorted { lhs, rhs in
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

                return lhs.id < rhs.id
            }
    }

    private var selectedActivities: [Activity] {
        activities.filter { draft.selectedActivityIds.contains($0.id) }
    }

    private var reporterName: String {
        authSession.session?.fullName
            ?? authSession.session?.username
            ?? authSession.session?.email
            ?? "Thành viên cứu hộ"
    }

    private var teamName: String? {
        mission.teams?.first?.teamName
    }

    private var activityTypeSummary: String {
        let labels = selectedActivities
            .compactMap(\.localizedActivityType)
            .reduce(into: [String]()) { partialResult, value in
                if partialResult.contains(value) == false {
                    partialResult.append(value)
                }
            }

        if labels.isEmpty {
            return "Chọn hoạt động để xem loại hoạt động"
        }

        return labels.joined(separator: ", ")
    }

    private var isFormValid: Bool {
        draft.isValid && currentLocation != nil && !selectedActivities.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                headerSection
                contextSection
                activitySelectionSection
                incidentTypeSection
                impactSection
                affectedResourcesSection
                activitySpecificDetailsSection
                supportRequestSection
                teamStatusSection
                notesSection
                evidenceSection
                IncidentSubmitButton(
                    title: draft.submitButtonTitle,
                    isEnabled: isFormValid,
                    isLoading: incidentVM.isSubmitting
                ) {
                    submitIncident()
                }
                Spacer(minLength: 40)
            }
            .padding(DS.Spacing.md)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .navigationTitle("Sự cố hoạt động")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            configureDefaults()
            locationManager.startContinuousUpdates()
        }
        .onDisappear {
            locationManager.stopContinuousUpdates()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    fillDemoData()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "magicmouse.fill")
                        Text("Demo")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(DS.Colors.accent)
                }
            }
        }
        .onChange(of: draft.needSupportSOS) { _ in
            applyDraftRules()
        }
        .onChange(of: draft.needReassignActivity) { _ in
            applyDraftRules()
        }
        .onChange(of: draft.incidentType) { _ in
            applyDraftRules()
        }
        .onChange(of: draft.note) { value in
            if value.count > 900 {
                draft.note = String(value.prefix(900))
            }
        }
        .onChange(of: draft.evidencePlaceholderNote) { value in
            if value.count > 240 {
                draft.evidencePlaceholderNote = String(value.prefix(240))
            }
        }
        .alert("Thông báo", isPresented: Binding(
            get: { incidentVM.errorMessage != nil || incidentVM.successMessage != nil },
            set: { _ in
                if incidentVM.successMessage != nil {
                    dismiss()
                }
                incidentVM.errorMessage = nil
                incidentVM.successMessage = nil
            }
        )) {
            Button("OK") { }
        } message: {
            if let error = incidentVM.errorMessage {
                Text(error)
            } else if let success = incidentVM.successMessage {
                Text(success)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            EyebrowLabel(text: "BÁO SỰ CỐ HOẠT ĐỘNG")

            Text("Dùng khi một hoặc nhiều hoạt động gặp vấn đề nhưng đội vẫn còn khả năng hoạt động ở mức nào đó.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DS.Colors.text)

            IncidentInlineNotice(
                icon: "point.bottomleft.forward.to.arrowtriangle.uturn.scurvepath",
                text: "Biểu mẫu này dành cho sự cố cục bộ: đổi thiết bị, đổi phương tiện, bổ sung người hoặc điều đội khác tới hỗ trợ / tiếp quản hoạt động.",
                tone: DS.Colors.warning
            )
        }
    }

    private var contextSection: some View {
        IncidentFormSection(
            title: "Thông tin ngữ cảnh",
            subtitle: "Thông tin chung được lấy từ nhiệm vụ hiện tại và vị trí thiết bị."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                IncidentContextRow(icon: "flag.fill", title: "Nhiệm vụ", value: mission.title)
                IncidentContextRow(icon: "person.3.fill", title: "Đội đang thực hiện", value: teamName ?? "Chưa có thông tin")
                IncidentContextRow(icon: "person.fill", title: "Người báo cáo", value: reporterName)
                IncidentContextRow(icon: "clock.fill", title: "Thời gian ghi nhận", value: formattedDisplayDate(recordedAt))
                IncidentContextRow(icon: "square.stack.3d.up.fill", title: "Loại hoạt động", value: activityTypeSummary)
                IncidentLocationSummaryCard(coordinate: currentLocation)
            }
        }
    }

    private var activitySelectionSection: some View {
        IncidentFormSection(
            title: "Hoạt động bị ảnh hưởng",
            subtitle: "Có thể chọn nhiều hoạt động nếu cùng chịu tác động từ một sự cố."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if reportableActivities.isEmpty {
                    IncidentInlineNotice(
                        icon: "exclamationmark.triangle.fill",
                        text: "Không còn hoạt động dang dở để chọn. Hãy dùng báo sự cố nhiệm vụ nếu toàn đội không thể tiếp tục.",
                        tone: DS.Colors.danger
                    )
                } else {
                    LazyVGrid(columns: gridColumns, spacing: DS.Spacing.xs) {
                        ForEach(reportableActivities) { activity in
                            IncidentChoiceChip(
                                title: activitySelectionTitle(activity),
                                subtitle: activity.localizedActivityType ?? RescuerStatusBadgeText.activity(activity.activityStatus),
                                isSelected: draft.selectedActivityIds.contains(activity.id),
                                tone: DS.Colors.accent
                            ) {
                                toggleActivitySelection(activity.id)
                            }
                        }
                    }
                }

                if draft.selectedActivityIds.isEmpty {
                    Text("Chọn ít nhất 1 hoạt động để gửi báo cáo.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DS.Colors.danger)
                }
            }
        }
    }

    private var incidentTypeSection: some View {
        IncidentFormSection(
            title: "Loại sự cố hoạt động",
            subtitle: "Chọn loại chính để biểu mẫu mở đúng nhóm trường nghiệp vụ."
        ) {
            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.xs) {
                ForEach(RescuerActivityIncidentType.allCases) { type in
                    IncidentChoiceChip(
                        title: type.title,
                        isSelected: draft.incidentType == type,
                        tone: DS.Colors.warning
                    ) {
                        draft.incidentType = type
                    }
                }
            }
        }
    }

    private var impactSection: some View {
        IncidentFormSection(
            title: "Mức độ ảnh hưởng tới hoạt động",
            subtitle: "Ba trường này quyết định chỉ ghi nhận sự cố hay mở hỗ trợ / điều phối lại hoạt động."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                IncidentBooleanField(
                    title: "Đội hiện tại còn làm tiếp được hoạt động này không?",
                    subtitle: "Nếu không, điều phối viên cần xem xét hỗ trợ hoặc giao lại hoạt động.",
                    value: $draft.canContinueActivity
                )

                Toggle(isOn: $draft.needSupportSOS) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tạo yêu cầu hỗ trợ cho hoạt động này")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DS.Colors.text)
                        Text("Dùng khi cần thêm đội, phương tiện hoặc thiết bị để tiếp tục / hoàn thành.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }
                .tint(DS.Colors.accent)

                Toggle(isOn: $draft.needReassignActivity) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hoạt động cần điều phối viên giao lại cho đội khác")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DS.Colors.text)
                        Text("Khi bật, biểu mẫu sẽ tự thêm nội dung tiếp quản hoạt động trong yêu cầu hỗ trợ.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }
                .tint(DS.Colors.warning)
            }
        }
    }

    private var affectedResourcesSection: some View {
        IncidentFormSection(
            title: "Đối tượng bị ảnh hưởng",
            subtitle: "Chọn nhiều nếu sự cố tác động đồng thời tới nhiều nguồn lực."
        ) {
            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.xs) {
                ForEach(ActivityAffectedResource.allCases) { resource in
                    IncidentChoiceChip(
                        title: resource.title,
                        isSelected: draft.affectedResources.contains(resource),
                        tone: DS.Colors.info
                    ) {
                        toggleOption(resource, in: &draft.affectedResources)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var activitySpecificDetailsSection: some View {
        IncidentFormSection(
            title: "Chi tiết sự cố",
            subtitle: "Phần này thay đổi theo loại sự cố đã chọn."
        ) {
            switch draft.incidentType {
            case .equipmentDamage:
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    IncidentTextInputField(title: "Loại thiết bị", placeholder: "Ví dụ: máy đàm, máy bơm, cáng cứu thương", text: $draft.equipmentType)
                    selectGrid(
                        title: "Mức độ hư hỏng",
                        options: ActivityDamageSeverity.allCases,
                        selection: draft.equipmentDamageSeverity,
                        tone: DS.Colors.warning
                    ) { draft.equipmentDamageSeverity = $0 }
                    IncidentBooleanField(title: "Có thiết bị thay thế không?", value: $draft.hasReplacementEquipment)
                }
            case .vehicleDamage:
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    IncidentTextInputField(title: "Loại phương tiện", placeholder: "Ví dụ: xuồng máy, ca nô, xe bán tải", text: $draft.vehicleType)
                    selectGrid(
                        title: "Tình trạng phương tiện",
                        options: ActivityVehicleCondition.allCases,
                        selection: draft.vehicleCondition,
                        tone: DS.Colors.warning
                    ) { draft.vehicleCondition = $0 }
                    IncidentBooleanField(title: "Có người bị ảnh hưởng do hỏng phương tiện không?", value: $draft.vehicleAffectedMembers)
                }
            case .lostSupplies:
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    IncidentTextInputField(title: "Đồ / vật phẩm bị mất", placeholder: "Ví dụ: dây cứu hộ, túi y tế, bộ đàm", text: $draft.lostSupplyName)
                    IncidentTextInputField(
                        title: "Số lượng",
                        placeholder: "Nhập số lượng nếu có",
                        text: $draft.lostSupplyQuantity,
                        keyboardType: .numberPad
                    )
                    IncidentBooleanField(title: "Có ảnh hưởng trực tiếp đến hoạt động không?", value: $draft.lostSupplyDirectImpact)
                }
            case .insufficientStaff:
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    IncidentTextInputField(
                        title: "Hiện có bao nhiêu người",
                        placeholder: "Nhập số người đang tham gia",
                        text: $draft.currentPeopleCount,
                        keyboardType: .numberPad
                    )
                    IncidentTextInputField(
                        title: "Cần thêm bao nhiêu người",
                        placeholder: "Nhập số người cần bổ sung",
                        text: $draft.additionalPeopleNeeded,
                        keyboardType: .numberPad
                    )

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Kỹ năng cần bổ sung")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DS.Colors.text)

                        LazyVGrid(columns: gridColumns, spacing: DS.Spacing.xs) {
                            ForEach(ActivityRequiredSkill.allCases) { skill in
                                IncidentChoiceChip(
                                    title: skill.title,
                                    isSelected: draft.requiredSkills.contains(skill),
                                    tone: DS.Colors.info
                                ) {
                                    toggleOption(skill, in: &draft.requiredSkills)
                                }
                            }
                        }
                    }
                }
            case .missingEquipment:
                IncidentInlineNotice(
                    icon: "shippingbox.fill",
                    text: "Phần báo cáo vật phẩm / thiết bị của nhiệm vụ sẽ được gắn API sau. Hiện tại hãy mô tả rõ loại thiết bị còn thiếu và tác động ở phần ghi chú.",
                    tone: DS.Colors.info
                )
            case .accessRouteBlocked, .sceneMoreDangerous, .beyondCurrentCapability, .handOverToAnotherTeam, .other, .none:
                IncidentInlineNotice(
                    icon: "text.bubble.fill",
                    text: "Loại sự cố này dùng ghi chú nghiệp vụ bên dưới để mô tả nguyên nhân, phần hoạt động bị ảnh hưởng và hỗ trợ cần nhất.",
                    tone: DS.Colors.info
                )
            }
        }
    }

    @ViewBuilder
    private var supportRequestSection: some View {
        if draft.needSupportSOS {
            IncidentFormSection(
                title: "Yêu cầu hỗ trợ hoạt động",
                subtitle: "Gửi kèm hỗ trợ điều phối khi hoạt động cần thêm người, thiết bị, phương tiện hoặc đội tiếp quản."
            ) {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    LazyVGrid(columns: gridColumns, spacing: DS.Spacing.xs) {
                        ForEach(ActivitySupportType.allCases) { supportType in
                            IncidentChoiceChip(
                                title: supportType.title,
                                isSelected: draft.supportTypes.contains(supportType),
                                tone: DS.Colors.accent,
                                isDisabled: draft.needReassignActivity && supportType == .takeOverActivity
                            ) {
                                toggleSupportType(supportType)
                            }
                        }
                    }

                    selectGrid(
                        title: "Mức ưu tiên",
                        options: ActivitySupportPriority.allCases,
                        selection: draft.supportPriority,
                        tone: DS.Colors.accent
                    ) { draft.supportPriority = $0 }

                    IncidentTextInputField(
                        title: "Số đội cần thêm",
                        placeholder: "Có thể để trống nếu chưa xác định",
                        text: $draft.supportTeamCount,
                        keyboardType: .numberPad
                    )
                    IncidentTextInputField(
                        title: "Số người cần thêm",
                        placeholder: "Có thể để trống nếu chưa xác định",
                        text: $draft.supportPeopleCount,
                        keyboardType: .numberPad
                    )
                    IncidentTextInputField(
                        title: "Số phương tiện cần thêm",
                        placeholder: "Có thể để trống nếu chưa xác định",
                        text: $draft.supportVehicleCount,
                        keyboardType: .numberPad
                    )
                    IncidentTextInputField(
                        title: "Điểm tiếp cận / điểm hẹn hỗ trợ",
                        placeholder: "Mô tả điểm gặp an toàn hoặc mốc nhận bàn giao",
                        text: $draft.supportMeetupPoint,
                        axis: .vertical
                    )

                    if draft.needReassignActivity {
                        IncidentInlineNotice(
                            icon: "arrow.triangle.swap",
                            text: "Tiếp quản hoạt động đã được khóa trong yêu cầu hỗ trợ vì bạn đánh dấu cần giao lại hoạt động.",
                            tone: DS.Colors.warning
                        )
                    }
                }
            }
        }
    }

    private var teamStatusSection: some View {
        IncidentFormSection(
            title: "Tình trạng đội hiện tại",
            subtitle: "Sự cố hoạt động có thể có người bị thương nhẹ nhưng chưa đến mức giải cứu toàn đội."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                IncidentTextInputField(
                    title: "Tổng số thành viên đang tham gia hoạt động",
                    placeholder: "Nhập tổng số người",
                    text: $draft.totalMembers,
                    keyboardType: .numberPad
                )
                IncidentTextInputField(
                    title: "Số người còn làm việc bình thường",
                    placeholder: "Nhập số người còn hoạt động",
                    text: $draft.availableMembers,
                    keyboardType: .numberPad
                )
                IncidentTextInputField(
                    title: "Số người bị thương nhẹ",
                    placeholder: "Nhập số người bị thương nhẹ",
                    text: $draft.lightlyInjuredMembers,
                    keyboardType: .numberPad
                )
                IncidentTextInputField(
                    title: "Số người tạm thời không thể tham gia hoạt động",
                    placeholder: "Nhập số người phải rút khỏi hoạt động",
                    text: $draft.unavailableMembers,
                    keyboardType: .numberPad
                )
                IncidentBooleanField(title: "Có cần sơ tán thành viên nào không?", value: $draft.needsMemberEvacuation)
            }
        }
    }

    private var notesSection: some View {
        IncidentFormSection(
            title: "Ghi chú",
            subtitle: "Mô tả nguyên nhân, phần hoạt động bị ảnh hưởng, những gì đội đã thử xử lý và hỗ trợ cần nhất."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                TextEditor(text: $draft.note)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(DS.Colors.text)
                    .frame(minHeight: 140)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DS.Colors.border, lineWidth: 1)
                    )

                Text("\(draft.note.count)/900 ký tự")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
    }

    private var evidenceSection: some View {
        IncidentFormSection(
            title: "Ảnh / video / bằng chứng",
            subtitle: "Giao diện tạm cho giai đoạn này. Tải media thật sẽ được gắn ở bước máy chủ / media tiếp theo."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                IncidentInlineNotice(
                    icon: "camera.fill",
                    text: "Có thể dùng cho ảnh phương tiện hỏng, đường bị chặn, thiết bị hư hoặc hiện trường. Hiện tại mới giữ chỗ ở giao diện và mô hình yêu cầu.",
                    tone: DS.Colors.info
                )
                IncidentTextInputField(
                    title: "Ghi chú bằng chứng",
                    placeholder: "Ví dụ: đã chụp ảnh xuồng hỏng và điểm đường bị sạt lở",
                    text: $draft.evidencePlaceholderNote,
                    axis: .vertical
                )
            }
        }
    }

    @ViewBuilder
    private func selectGrid<Option: Identifiable & Hashable>(
        title: String,
        options: [Option],
        selection: Option?,
        tone: Color,
        onSelect: @escaping (Option) -> Void
    ) -> some View where Option.ID == String {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(DS.Colors.text)

            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.xs) {
                ForEach(options) { option in
                    IncidentChoiceChip(
                        title: titleForOption(option),
                        isSelected: selection == option,
                        tone: tone
                    ) {
                        onSelect(option)
                    }
                }
            }
        }
    }

    private func titleForOption<Option>(_ option: Option) -> String {
        switch option {
        case let option as ActivityDamageSeverity:
            return option.title
        case let option as ActivityVehicleCondition:
            return option.title
        case let option as ActivitySupportPriority:
            return option.title
        default:
            return ""
        }
    }

    private func toggleActivitySelection(_ activityId: Int) {
        if draft.selectedActivityIds.contains(activityId) {
            draft.selectedActivityIds.remove(activityId)
        } else {
            draft.selectedActivityIds.insert(activityId)
        }
    }

    private func toggleSupportType(_ supportType: ActivitySupportType) {
        if draft.needReassignActivity && supportType == .takeOverActivity {
            return
        }

        toggleOption(supportType, in: &draft.supportTypes)
    }

    private func toggleOption<Option: Hashable>(_ option: Option, in set: inout Set<Option>) {
        if set.contains(option) {
            set.remove(option)
        } else {
            set.insert(option)
        }
    }

    private func configureDefaults() {
        guard draft.totalMembers.isEmpty else { return }

        let memberCount = mission.teams?.first?.memberCount ?? mission.teams?.first?.members?.count
        if let memberCount {
            draft.totalMembers = String(memberCount)
            draft.availableMembers = String(memberCount)
            draft.lightlyInjuredMembers = "0"
            draft.unavailableMembers = "0"
        }
    }

    private func applyDraftRules() {
        if draft.incidentType == .handOverToAnotherTeam {
            draft.needReassignActivity = true
        }
        draft.enforceRules()
    }

    private func submitIncident() {
        guard let currentLocation else {
            print("⚠️ [ActivityIncidentReportFormView] submitIncident failed: currentLocation is nil")
            return
        }
        
        guard let request = draft.toRequest(
            missionId: mission.id,
            missionTeamId: missionTeamId,
            missionTitle: mission.title,
            teamName: teamName,
            reporterId: authSession.session?.userId,
            reporterName: reporterName,
            location: IncidentLocationSnapshot(
                latitude: currentLocation.latitude,
                longitude: currentLocation.longitude
            ),
            selectedActivities: selectedActivities
        ) else {
            print("⚠️ [ActivityIncidentReportFormView] submitIncident failed: draft.toRequest returned nil. isFormValid=\(isFormValid)")
            return
        }

        print("🚀 [ActivityIncidentReportFormView] Submitting incident report for mission \(mission.id)...")
        incidentVM.reportActivityIncident(
            missionId: mission.id,
            missionTeamId: missionTeamId,
            request: request
        )
    }

    private func activitySelectionTitle(_ activity: Activity) -> String {
        if let step = activity.step {
            return "Bước \(step) • \(activity.title)"
        }
        return activity.title
    }

    private func formattedDisplayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm, dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private func fillDemoData() {
        if let firstActivity = reportableActivities.first {
            draft.selectedActivityIds = [firstActivity.id]
        } else if let firstRaw = activities.first {
            draft.selectedActivityIds = [firstRaw.id]
        }
        
        draft.incidentType = .equipmentDamage
        draft.equipmentType = "Xuồng máy"
        draft.equipmentDamageSeverity = .unusable
        draft.hasReplacementEquipment = false
        
        draft.canContinueActivity = false
        draft.needSupportSOS = true
        draft.supportTypes = [.replacementVehicle]
        draft.supportPriority = .immediate
        draft.supportMeetupPoint = "Cạnh trạm y tế xã"
        
        draft.needsMemberEvacuation = false
        
        draft.affectedResources = [.equipment]
        
        draft.totalMembers = "4"
        draft.availableMembers = "4"
        draft.lightlyInjuredMembers = "0"
        draft.unavailableMembers = "0"
        
        draft.note = "Xuồng bị thủng không thể tiếp tục di chuyển, cần hỗ trợ phương tiện thay thế."
    }

    private func normalizedStatus(_ status: String) -> String {
        status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}
