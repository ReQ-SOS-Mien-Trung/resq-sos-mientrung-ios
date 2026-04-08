import SwiftUI
import CoreLocation

struct ReportIncidentView: View {
    enum IncidentReportTarget: String, CaseIterable, Identifiable {
        case activity = "Theo hoạt động"
        case mission = "Toàn đội"

        var id: String { rawValue }
    }

    let missionTeamId: Int
    let activities: [Activity]
    @ObservedObject var incidentVM: IncidentViewModel
    let missionId: Int

    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @State private var description = ""
    @State private var selectedTarget: IncidentReportTarget = .activity
    @State private var selectedActivityId: Int?
    @State private var needsRescueAssistance = false
    @State private var assistanceSosType: SOSType = .rescue
    @State private var assistanceSituation: RescueSituation = .trapped
    @State private var assistanceHasInjured = false
    @State private var assistancePeopleCount = PeopleCount(adults: 1, children: 0, elderly: 0)
    @State private var assistanceMedicalIssues: Set<MedicalIssue> = []
    @State private var assistanceAddress = ""
    @State private var assistanceAdditionalDescription = ""
    @FocusState private var isDescriptionFocused: Bool

    private var currentLocation: CLLocationCoordinate2D? {
        locationManager.currentLocation?.coordinate
    }

    private var reportableActivities: [Activity] {
        activities
            .filter { activity in
                let normalized = normalizedStatus(activity.status)
                return normalized != "succeed"
                    && normalized != "completed"
                    && normalized != "failed"
                    && normalized != "cancelled"
            }
            .sorted { lhs, rhs in
                switch (lhs.step, rhs.step) {
                case let (l?, r?):
                    if l != r { return l < r }
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

    private var preferredActivityId: Int? {
        if let onGoing = reportableActivities.first(where: { normalizedStatus($0.status) == "ongoing" }) {
            return onGoing.id
        }

        return reportableActivities.first?.id
    }

    private var selectedActivity: Activity? {
        guard let selectedActivityId else { return nil }
        return reportableActivities.first(where: { $0.id == selectedActivityId })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(DS.Colors.accent)
                                .font(.system(size: 24))
                            VStack(alignment: .leading) {
                                EyebrowLabel(text: "BÁO SỰ CỐ")
                                Text("Ghi nhận sự cố trong nhiệm vụ")
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                        }
                        EditorialDivider(height: DS.Border.thin)
                    }

                    // Target
                    targetSection

                    // Location
                    locationSection

                    // Description
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("MÔ TẢ SỰ CỐ")
                            .font(DS.Typography.caption).tracking(1)
                            .foregroundColor(DS.Colors.textSecondary)

                        TextEditor(text: $description)
                            .foregroundColor(DS.Colors.text)
                            .scrollContentBackground(.hidden)
                            .background(DS.Colors.surface)
                            .frame(minHeight: 120, maxHeight: 200)
                            .padding(DS.Spacing.sm)
                            .overlay(Rectangle().stroke(
                                description.isEmpty ? DS.Colors.border : DS.Colors.warning,
                                lineWidth: DS.Border.medium
                            ))
                            .focused($isDescriptionFocused)
                            .onChange(of: description) { val in
                                if val.count > 500 { description = String(val.prefix(500)) }
                            }

                        Text("\(description.count)/500 ký tự")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textTertiary)
                    }

                    if selectedTarget == .mission {
                        missionAssistanceSection
                    }

                    // Submit
                    Button { submitIncident() } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            if incidentVM.isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                            Text("GỬI BÁO CÁO")
                                .font(DS.Typography.headline).tracking(2)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(isFormValid && !incidentVM.isSubmitting ? DS.Colors.accent : DS.Colors.textTertiary)
                        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
                        .shadow(color: .black.opacity(0.2), radius: 0, x: 3, y: 3)
                    }
                    .disabled(!isFormValid || incidentVM.isSubmitting)

                    Spacer()
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Báo Sự Cố")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                        .foregroundColor(DS.Colors.accent)
                }
            }
            .alert("Lỗi", isPresented: Binding(
                get: { incidentVM.errorMessage != nil },
                set: { if !$0 { incidentVM.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { incidentVM.errorMessage = nil }
            } message: {
                Text(incidentVM.errorMessage ?? "")
            }
            .onChange(of: incidentVM.successMessage) { msg in
                if msg != nil {
                    incidentVM.loadIncidents(missionId: missionId)
                    dismiss()
                }
            }
            .onChange(of: selectedTarget) { target in
                guard target == .activity else { return }

                if selectedActivity == nil {
                    selectedActivityId = preferredActivityId
                }

                if selectedActivityId == nil {
                    selectedTarget = .mission
                }
            }
            .onAppear {
                configureInitialTargetSelection()
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Target Section
    @ViewBuilder
    private var targetSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("PHẠM VI SỰ CỐ")
                .font(DS.Typography.caption).tracking(1)
                .foregroundColor(DS.Colors.textSecondary)

            Picker("Phạm vi", selection: $selectedTarget) {
                ForEach(IncidentReportTarget.allCases) { target in
                    Text(target.rawValue).tag(target)
                }
            }
            .pickerStyle(.segmented)

            if selectedTarget == .activity {
                if reportableActivities.isEmpty {
                    Text("Không còn hoạt động dang dở để báo sự cố theo Activity. Vui lòng chọn phạm vi Toàn đội.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.accent)
                        .padding(.top, 4)
                } else {
                    Picker("Hoạt động", selection: Binding(
                        get: { selectedActivityId ?? reportableActivities.first?.id ?? 0 },
                        set: { selectedActivityId = $0 }
                    )) {
                        ForEach(reportableActivities) { activity in
                            Text(activityLabel(activity)).tag(activity.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.surface)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))

                    Text("Activity được chọn sẽ bị đánh dấu Failed và hệ thống có thể tự chuyển sang activity tiếp theo.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            } else {
                Text("Toàn bộ hoạt động dang dở của đội sẽ bị chuyển Failed và đội chuyển sang chờ nộp báo cáo.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var missionAssistanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("CẦN HỖ TRỢ CỨU NẠN")
                .font(DS.Typography.caption).tracking(1)
                .foregroundColor(DS.Colors.textSecondary)

            Toggle(isOn: $needsRescueAssistance) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tạo kèm yêu cầu SOS hỗ trợ")
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundColor(DS.Colors.text)

                    Text("Chỉ áp dụng cho sự cố phạm vi toàn đội và sẽ gửi kèm thông tin hỗ trợ mới lên backend.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            .tint(DS.Colors.accent)

            if needsRescueAssistance {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Picker("Loại SOS", selection: $assistanceSosType) {
                        ForEach(SOSType.allCases, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Tình huống", selection: $assistanceSituation) {
                        ForEach(RescueSituation.allCases) { situation in
                            Text(situation.title).tag(situation)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.Colors.surface)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))

                    Toggle("Có người bị thương", isOn: $assistanceHasInjured)
                        .tint(DS.Colors.accent)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("SỐ NGƯỜI CẦN HỖ TRỢ")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)

                        Stepper("Người lớn: \(assistancePeopleCount.adults)", value: $assistancePeopleCount.adults, in: 0...20)
                        Stepper("Trẻ em: \(assistancePeopleCount.children)", value: $assistancePeopleCount.children, in: 0...20)
                        Stepper("Người già: \(assistancePeopleCount.elderly)", value: $assistancePeopleCount.elderly, in: 0...20)
                    }
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.surface)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("VẤN ĐỀ Y TẾ")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: DS.Spacing.xs)], spacing: DS.Spacing.xs) {
                            ForEach(MedicalIssue.allCases, id: \.self) { issue in
                                Button {
                                    toggleMedicalIssue(issue)
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(issue.icon)
                                        Text(issue.title)
                                            .font(DS.Typography.caption)
                                            .multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                    }
                                    .foregroundColor(assistanceMedicalIssues.contains(issue) ? .white : DS.Colors.text)
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, DS.Spacing.xs)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(assistanceMedicalIssues.contains(issue) ? DS.Colors.accent : DS.Colors.surface)
                                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("ĐỊA CHỈ THAM CHIẾU")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)

                        TextField("Thôn/xã/khu vực có thể tiếp cận", text: $assistanceAddress)
                            .textInputAutocapitalization(.words)
                            .padding(DS.Spacing.sm)
                            .background(DS.Colors.surface)
                            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("GHI CHÚ HỖ TRỢ")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)

                        TextEditor(text: $assistanceAdditionalDescription)
                            .foregroundColor(DS.Colors.text)
                            .scrollContentBackground(.hidden)
                            .background(DS.Colors.surface)
                            .frame(minHeight: 90, maxHeight: 160)
                            .padding(DS.Spacing.sm)
                            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
                            .onChange(of: assistanceAdditionalDescription) { value in
                                if value.count > 300 {
                                    assistanceAdditionalDescription = String(value.prefix(300))
                                }
                            }

                        Text("\(assistanceAdditionalDescription.count)/300 ký tự")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                }
                .padding(DS.Spacing.sm)
                .background(DS.Colors.surface.opacity(0.45))
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
            }
        }
    }

    // MARK: - Location Section
    @ViewBuilder
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("VỊ TRÍ HIỆN TẠI")
                .font(DS.Typography.caption).tracking(1)
                .foregroundColor(DS.Colors.textSecondary)

            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "location.fill")
                    .foregroundColor(currentLocation != nil ? DS.Colors.success : DS.Colors.textTertiary)

                if let loc = currentLocation {
                    Text(String(format: "%.5f, %.5f", loc.latitude, loc.longitude))
                        .font(DS.Typography.body.monospacedDigit())
                        .foregroundColor(DS.Colors.text)
                } else {
                    Text("Đang lấy vị trí...")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.surface)
            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
        }
    }

    // MARK: - Helpers
    private var isFormValid: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && currentLocation != nil
            && isTargetSelectionValid
            && (
                selectedTarget != .mission
                || !needsRescueAssistance
                || assistancePeopleCount.total > 0
            )
    }

    private var isTargetSelectionValid: Bool {
        switch selectedTarget {
        case .mission:
            return true
        case .activity:
            return selectedActivity != nil
        }
    }

    private func submitIncident() {
        guard let loc = currentLocation else { return }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch selectedTarget {
        case .mission:
            incidentVM.reportMissionIncident(
                missionId: missionId,
                missionTeamId: missionTeamId,
                description: trimmed,
                lat: loc.latitude,
                lng: loc.longitude,
                needsRescueAssistance: needsRescueAssistance,
                assistanceSos: missionAssistancePayload(
                    description: trimmed,
                    location: loc
                )
            )
        case .activity:
            guard let activityId = selectedActivityId else { return }
            incidentVM.reportActivityIncident(
                missionId: missionId,
                activityId: activityId,
                description: trimmed,
                lat: loc.latitude,
                lng: loc.longitude
            )
        }
    }

    private func configureInitialTargetSelection() {
        if selectedActivityId == nil {
            selectedActivityId = preferredActivityId
        }

        if selectedActivityId == nil {
            selectedTarget = .mission
        }
    }

    private func activityLabel(_ activity: Activity) -> String {
        if let step = activity.step {
            return "#\(step) - \(activity.title)"
        }

        return activity.title
    }

    private func toggleMedicalIssue(_ issue: MedicalIssue) {
        if assistanceMedicalIssues.contains(issue) {
            assistanceMedicalIssues.remove(issue)
        } else {
            assistanceMedicalIssues.insert(issue)
        }
    }

    private func missionAssistancePayload(
        description: String,
        location: CLLocationCoordinate2D
    ) -> IncidentAssistanceSosRequestData? {
        guard selectedTarget == .mission, needsRescueAssistance else { return nil }

        let trimmedAddress = assistanceAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAdditionalDescription = assistanceAdditionalDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawMessage = [
            "Sự cố nhiệm vụ: \(description)",
            trimmedAdditionalDescription
        ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return IncidentAssistanceSosRequestData(
            rawMessage: rawMessage.isEmpty ? nil : rawMessage,
            latitude: location.latitude,
            longitude: location.longitude,
            sosType: assistanceSosType.rawValue,
            situation: assistanceSituation.rawValue,
            hasInjured: assistanceHasInjured,
            adultCount: assistancePeopleCount.adults,
            childCount: assistancePeopleCount.children,
            elderlyCount: assistancePeopleCount.elderly,
            medicalIssues: MedicalIssue.allCases
                .filter { assistanceMedicalIssues.contains($0) }
                .map(\.rawValue),
            address: trimmedAddress.isEmpty ? nil : trimmedAddress,
            additionalDescription: trimmedAdditionalDescription.isEmpty ? nil : trimmedAdditionalDescription
        )
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
