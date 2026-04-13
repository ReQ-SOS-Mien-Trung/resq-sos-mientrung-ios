import SwiftUI
import CoreLocation

struct MissionIncidentReportFormView: View {
    let mission: Mission
    let missionTeamId: Int
    let activities: [Activity]
    @ObservedObject var incidentVM: IncidentViewModel

    @ObservedObject private var authSession = AuthSessionStore.shared
    @StateObject private var locationManager = LocationManager()
    @State private var draft = MissionIncidentDraft()
    @State private var recordedAt = Date()

    private let gridColumns = [GridItem(.adaptive(minimum: 150), spacing: DS.Spacing.xs)]

    private var currentLocation: CLLocationCoordinate2D? {
        locationManager.currentLocation?.coordinate
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

    private var unresolvedActivitiesCount: Int {
        activities.filter {
            let normalized = normalizedStatus($0.status)
            return normalized != "succeed"
                && normalized != "completed"
                && normalized != "failed"
                && normalized != "cancelled"
        }.count
    }

    private var requiresRescueRequest: Bool {
        draft.missionDecision == .rescueWholeTeamImmediately || draft.retreatCapability == .urgentRescueNeeded
    }

    private var requiresHandover: Bool {
        draft.missionDecision == .handOverMission
    }

    private var isFormValid: Bool {
        draft.isValid && currentLocation != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                headerSection
                contextSection
                incidentTypeSection
                missionDecisionSection
                teamStatusSection
                vehicleSection
                hazardsSection
                rescueSection
                handoverSection
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
        .navigationTitle("Sự cố mission")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            configureDefaults()
            applyMissionRules()
        }
        .onChange(of: draft.missionDecision) { _ in
            applyMissionRules()
        }
        .onChange(of: draft.retreatCapability) { _ in
            applyMissionRules()
        }
        .onChange(of: draft.needsRescueSOS) { _ in
            applyMissionRules()
        }
        .onChange(of: draft.needsMissionHandover) { _ in
            applyMissionRules()
        }
        .onChange(of: draft.note) { value in
            if value.count > 1000 {
                draft.note = String(value.prefix(1000))
            }
        }
        .onChange(of: draft.evidencePlaceholderNote) { value in
            if value.count > 240 {
                draft.evidencePlaceholderNote = String(value.prefix(240))
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            EyebrowLabel(text: "BÁO SỰ CỐ MISSION", color: DS.Colors.danger)

            Text("Dùng khi toàn bộ team đang làm mission rơi vào tình huống không thể tiếp tục nhiệm vụ.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DS.Colors.text)

            IncidentInlineNotice(
                icon: "shield.lefthalf.filled.badge.exclamationmark",
                text: "Form này nghiêm trọng hơn activity incident: có thể phải dừng mission, bàn giao cho team khác hoặc giải cứu chính đội cứu hộ hiện tại.",
                tone: DS.Colors.danger
            )
        }
    }

    private var contextSection: some View {
        IncidentFormSection(
            title: "Thông tin mission",
            subtitle: "Context tự động từ mission hiện tại, cộng thêm trạng thái nạn nhân / người dân đang đi cùng."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                IncidentContextRow(icon: "flag.fill", title: "Mission", value: mission.title)
                IncidentContextRow(icon: "person.3.fill", title: "Team", value: teamName ?? "Chưa có thông tin")
                IncidentContextRow(icon: "person.fill", title: "Người báo cáo", value: reporterName)
                IncidentContextRow(icon: "clock.fill", title: "Thời gian ghi nhận", value: formattedDisplayDate(recordedAt))
                IncidentContextRow(icon: "checklist", title: "Số activity chưa hoàn thành", value: "\(unresolvedActivitiesCount)")
                IncidentLocationSummaryCard(coordinate: currentLocation)

                IncidentBooleanField(
                    title: "Có nạn nhân / người dân đang đi cùng không?",
                    subtitle: "Dùng khi team đang chở hoặc đang giữ an toàn cho người dân / nạn nhân.",
                    value: $draft.hasCiviliansWithTeam
                )

                if draft.hasCiviliansWithTeam == true {
                    IncidentTextInputField(
                        title: "Số nạn nhân / người dân đang đi cùng",
                        placeholder: "Nhập số người đang đi cùng team",
                        text: $draft.civilianCount,
                        keyboardType: .numberPad
                    )
                    IncidentTextInputField(
                        title: "Tình trạng nạn nhân / người dân",
                        placeholder: "Ví dụ: 2 nạn nhân còn tỉnh, 1 người già kiệt sức",
                        text: $draft.civilianCondition,
                        axis: .vertical
                    )
                }
            }
        }
    }

    private var incidentTypeSection: some View {
        IncidentFormSection(
            title: "Loại sự cố mission",
            subtitle: "Chỉ dùng cho sự cố ảnh hưởng cấp toàn nhiệm vụ, không phải lỗi cục bộ của một activity."
        ) {
            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.xs) {
                ForEach(RescuerMissionIncidentType.allCases) { type in
                    IncidentChoiceChip(
                        title: type.title,
                        isSelected: draft.incidentType == type,
                        tone: DS.Colors.danger
                    ) {
                        draft.incidentType = type
                    }
                }
            }
        }
    }

    private var missionDecisionSection: some View {
        IncidentFormSection(
            title: "Quyết định với mission",
            subtitle: "Đây là block bắt buộc vì nó quyết định mission tiếp tục, dừng, bàn giao hay chuyển sang giải cứu đội."
        ) {
            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.xs) {
                ForEach(MissionDecision.allCases) { decision in
                    IncidentChoiceChip(
                        title: decision.title,
                        isSelected: draft.missionDecision == decision,
                        tone: DS.Colors.warning
                    ) {
                        draft.missionDecision = decision
                    }
                }
            }
        }
    }

    private var teamStatusSection: some View {
        IncidentFormSection(
            title: "Tình trạng đội cứu hộ",
            subtitle: "Phần trọng tâm để hệ thống biết chính team rescuer hiện đang an toàn đến đâu."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                IncidentTextInputField(
                    title: "Tổng số thành viên team",
                    placeholder: "Nhập tổng số thành viên",
                    text: $draft.totalMembers,
                    keyboardType: .numberPad
                )
                IncidentTextInputField(
                    title: "Số người an toàn",
                    placeholder: "Nhập số người còn an toàn",
                    text: $draft.safeMembers,
                    keyboardType: .numberPad
                )
                IncidentTextInputField(
                    title: "Số người bị thương nhẹ",
                    placeholder: "Nhập số người bị thương nhẹ",
                    text: $draft.lightlyInjuredMembers,
                    keyboardType: .numberPad
                )
                IncidentTextInputField(
                    title: "Số người bị thương nặng",
                    placeholder: "Nhập số người bị thương nặng",
                    text: $draft.severelyInjuredMembers,
                    keyboardType: .numberPad
                )
                IncidentTextInputField(
                    title: "Số người không thể di chuyển",
                    placeholder: "Nhập số người không thể di chuyển",
                    text: $draft.immobileMembers,
                    keyboardType: .numberPad
                )
                IncidentTextInputField(
                    title: "Số người mất liên lạc",
                    placeholder: "Nhập số người mất liên lạc",
                    text: $draft.missingContactMembers,
                    keyboardType: .numberPad
                )

                IncidentBooleanField(
                    title: "Có người cần cấp cứu ngay không?",
                    subtitle: "Giữ lại logic SOS y tế nhưng đối tượng là rescuer team.",
                    value: $draft.needsImmediateEmergencyCare
                )

                if draft.needsImmediateEmergencyCare == true {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Tình trạng cấp cứu")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DS.Colors.text)

                        LazyVGrid(columns: gridColumns, spacing: DS.Spacing.xs) {
                            ForEach(RescuerEmergencyType.allCases) { emergency in
                                IncidentChoiceChip(
                                    title: emergency.title,
                                    isSelected: draft.emergencyTypes.contains(emergency),
                                    tone: DS.Colors.danger
                                ) {
                                    toggleOption(emergency, in: &draft.emergencyTypes)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var vehicleSection: some View {
        IncidentFormSection(
            title: "Tình trạng phương tiện và khả năng rút lui",
            subtitle: "Phần này giúp hệ thống quyết định team còn tự rút được hay cần giải cứu."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                selectGrid(
                    title: "Loại phương tiện chính",
                    options: MissionPrimaryVehicleType.allCases,
                    selection: draft.primaryVehicleType,
                    tone: DS.Colors.info
                ) { draft.primaryVehicleType = $0 }

                selectGrid(
                    title: "Tình trạng phương tiện",
                    options: MissionVehicleStatus.allCases,
                    selection: draft.vehicleStatus,
                    tone: DS.Colors.warning
                ) { draft.vehicleStatus = $0 }

                selectGrid(
                    title: "Khả năng rút lui",
                    options: MissionRetreatCapability.allCases,
                    selection: draft.retreatCapability,
                    tone: DS.Colors.accent
                ) { draft.retreatCapability = $0 }
            }
        }
    }

    private var hazardsSection: some View {
        IncidentFormSection(
            title: "Mức nguy hiểm hiện trường",
            subtitle: "Chọn nhiều khi hiện trường có đồng thời nhiều yếu tố nguy hiểm."
        ) {
            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.xs) {
                ForEach(MissionHazard.allCases) { hazard in
                    IncidentChoiceChip(
                        title: hazard.title,
                        isSelected: draft.hazards.contains(hazard),
                        tone: DS.Colors.warning
                    ) {
                        toggleOption(hazard, in: &draft.hazards)
                    }
                }
            }
        }
    }

    private var rescueSection: some View {
        IncidentFormSection(
            title: "Yêu cầu giải cứu team",
            subtitle: "Dùng khi team hiện tại không thể tiếp tục mission và cần lực lượng khác tới giải cứu / sơ tán."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Toggle(isOn: rescueToggleBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tạo yêu cầu giải cứu đội cứu hộ")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DS.Colors.text)
                        Text("Nếu bật, form sẽ gửi kèm nhu cầu giải cứu, sơ tán, y tế hoặc tiếp quản mission.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }
                .tint(DS.Colors.danger)

                if requiresRescueRequest {
                    IncidentInlineNotice(
                        icon: "bolt.fill",
                        text: "Yêu cầu giải cứu đã được bật bắt buộc vì mission cần giải cứu toàn đội ngay hoặc team không thể tự rút.",
                        tone: DS.Colors.danger
                    )
                }

                if draft.needsRescueSOS {
                    LazyVGrid(columns: gridColumns, spacing: DS.Spacing.xs) {
                        ForEach(MissionRescueSupportType.allCases) { supportType in
                            IncidentChoiceChip(
                                title: supportType.title,
                                isSelected: draft.rescueSupportTypes.contains(supportType),
                                tone: DS.Colors.danger
                            ) {
                                toggleOption(supportType, in: &draft.rescueSupportTypes)
                            }
                        }
                    }

                    selectGrid(
                        title: "Mức khẩn cấp",
                        options: MissionRescuePriority.allCases,
                        selection: draft.rescuePriority,
                        tone: DS.Colors.danger
                    ) { draft.rescuePriority = $0 }

                    selectGrid(
                        title: "Ưu tiên sơ tán",
                        options: MissionEvacuationPriority.allCases,
                        selection: draft.evacuationPriority,
                        tone: DS.Colors.warning
                    ) { draft.evacuationPriority = $0 }
                }
            }
        }
    }

    private var handoverSection: some View {
        IncidentFormSection(
            title: "Bàn giao mission",
            subtitle: "Mission-level incident cần xác định rõ có phải chuyển giao phần việc dang dở cho team khác không."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if requiresHandover {
                    IncidentInlineNotice(
                        icon: "arrow.triangle.branch",
                        text: "Block bàn giao đang ở trạng thái bắt buộc vì bạn chọn quyết định cần bàn giao mission cho team khác.",
                        tone: DS.Colors.warning
                    )
                } else {
                    IncidentBooleanField(
                        title: "Có cần team khác tiếp quản mission không?",
                        value: $draft.needsMissionHandover
                    )
                }

                if draft.needsMissionHandover == true {
                    IncidentTextInputField(
                        title: "Phần việc dang dở",
                        placeholder: "Mô tả những gì mission chưa thể hoàn tất",
                        text: $draft.unfinishedWork,
                        axis: .vertical
                    )
                    IncidentTextInputField(
                        title: "Số activity chưa hoàn thành",
                        placeholder: "Mặc định theo mission hiện tại",
                        text: $draft.unfinishedActivityCount,
                        keyboardType: .numberPad
                    )
                    IncidentTextInputField(
                        title: "Nạn nhân / hàng hóa / thiết bị cần bàn giao",
                        placeholder: "Mô tả người, hàng hoặc thiết bị cần chuyển tiếp",
                        text: $draft.transferItems,
                        axis: .vertical
                    )
                    IncidentTextInputField(
                        title: "Lưu ý cho team tiếp quản",
                        placeholder: "Cảnh báo hiện trường, tuyến vào, trạng thái nạn nhân, thiết bị còn lại...",
                        text: $draft.notesForTakeoverTeam,
                        axis: .vertical
                    )
                    IncidentTextInputField(
                        title: "Điểm bàn giao an toàn",
                        placeholder: "Mô tả điểm bàn giao hoặc mốc hẹn an toàn",
                        text: $draft.safeHandoverPoint,
                        axis: .vertical
                    )
                }
            }
        }
    }

    private var notesSection: some View {
        IncidentFormSection(
            title: "Ghi chú",
            subtitle: "Mô tả ngắn nguyên nhân, mức nguy hiểm với team hiện tại và hành động đã thử trước khi gửi báo cáo."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                TextEditor(text: $draft.note)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(DS.Colors.text)
                    .frame(minHeight: 160)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DS.Colors.border, lineWidth: 1)
                    )

                Text("\(draft.note.count)/1000 ký tự")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
    }

    private var evidenceSection: some View {
        IncidentFormSection(
            title: "Ảnh / video / bằng chứng",
            subtitle: "Shell UI để giữ chỗ cho media trong request model của phase sau."
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                IncidentInlineNotice(
                    icon: "camera.macro",
                    text: "Hiện chưa upload ảnh/video thật. Phần này chỉ giữ chỗ trong giao diện và model để backend/media hook vào sau.",
                    tone: DS.Colors.info
                )
                IncidentTextInputField(
                    title: "Ghi chú bằng chứng",
                    placeholder: "Ví dụ: có video xuồng mắc kẹt và ảnh sạt lở gần điểm rút lui",
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

    private var rescueToggleBinding: Binding<Bool> {
        Binding(
            get: { draft.needsRescueSOS || requiresRescueRequest },
            set: { newValue in
                if requiresRescueRequest {
                    draft.needsRescueSOS = true
                } else {
                    draft.needsRescueSOS = newValue
                }
            }
        )
    }

    private func titleForOption<Option>(_ option: Option) -> String {
        switch option {
        case let option as MissionPrimaryVehicleType:
            return option.title
        case let option as MissionVehicleStatus:
            return option.title
        case let option as MissionRetreatCapability:
            return option.title
        case let option as MissionRescuePriority:
            return option.title
        case let option as MissionEvacuationPriority:
            return option.title
        default:
            return ""
        }
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
            draft.safeMembers = String(memberCount)
            draft.lightlyInjuredMembers = "0"
            draft.severelyInjuredMembers = "0"
            draft.immobileMembers = "0"
            draft.missingContactMembers = "0"
        }
    }

    private func applyMissionRules() {
        draft.enforceRules(defaultUnfinishedActivityCount: unresolvedActivitiesCount)

        if requiresHandover {
            draft.needsMissionHandover = true
        }

        if requiresRescueRequest {
            draft.needsRescueSOS = true
        }
    }

    private func submitIncident() {
        guard
            let currentLocation,
            let request = draft.toRequest(
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
                unfinishedActivityCount: unresolvedActivitiesCount
            )
        else {
            return
        }

        incidentVM.reportMissionIncident(
            missionId: mission.id,
            missionTeamId: missionTeamId,
            request: request
        )
    }

    private func formattedDisplayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "HH:mm, dd/MM/yyyy"
        return formatter.string(from: date)
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
