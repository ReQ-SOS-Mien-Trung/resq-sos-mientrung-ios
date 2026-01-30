//
//  SOSWizardSteps.swift
//  SosMienTrung
//
//  Individual step views cho SOS Wizard
//

import SwiftUI

// MARK: - Step 0: Auto Info (Read-only)

struct Step0AutoInfoView: View {
    @Bindable var formData: SOSFormData
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @ObservedObject var networkMonitor: NetworkMonitor
    
    @State private var batteryLevel: Int? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Thông tin tự động")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Hệ thống đã thu thập các thông tin sau")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 20)
                
                // Info cards
                VStack(spacing: 12) {
                    // Network status
                    InfoCard(
                        icon: networkMonitor.isConnected ? "wifi" : "wifi.slash",
                        iconColor: networkMonitor.isConnected ? .green : .red,
                        title: "Trạng thái mạng",
                        value: networkMonitor.isConnected ? "🟢 Online" : "🔴 Offline (Mesh)"
                    )
                    
                    // Location
                    if let coords = bridgefyManager.locationManager.coordinates {
                        InfoCard(
                            icon: "location.fill",
                            iconColor: .blue,
                            title: "Vị trí GPS",
                            value: String(format: "%.6f, %.6f", coords.latitude, coords.longitude)
                        )
                        
                        if let accuracy = bridgefyManager.locationManager.accuracy {
                            InfoCard(
                                icon: "scope",
                                iconColor: .cyan,
                                title: "Độ chính xác",
                                value: String(format: "± %.0f mét", accuracy)
                            )
                        }
                    } else {
                        InfoCard(
                            icon: "location.slash",
                            iconColor: .orange,
                            title: "Vị trí GPS",
                            value: "Đang lấy vị trí...",
                            isLoading: true
                        )
                    }
                    
                    // Time
                    InfoCard(
                        icon: "clock.fill",
                        iconColor: .purple,
                        title: "Thời gian",
                        value: Date().formatted(date: .abbreviated, time: .shortened)
                    )
                    
                    // User info
                    if let user = UserProfile.shared.currentUser {
                        InfoCard(
                            icon: "person.fill",
                            iconColor: .indigo,
                            title: "Người gửi",
                            value: "\(user.name) • \(user.phoneNumber)"
                        )
                    }
                    
                    // Battery - hiển thị dạng 10 chấm
                    if let battery = batteryLevel {
                        BatteryDotsCard(batteryLevel: battery)
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
        .onAppear {
            refreshBatteryLevel()
        }
    }
    
    private func refreshBatteryLevel() {
        // Đảm bảo monitoring đã enabled
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Delay nhỏ để iOS có thời gian cập nhật giá trị
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let level = UIDevice.current.batteryLevel
            if level >= 0 {
                self.batteryLevel = Int(level * 100)
                print("🔋 Battery refreshed: \(self.batteryLevel ?? -1)%")
            } else {
                print("⚠️ Battery level unavailable")
                self.batteryLevel = nil
            }
        }
    }
    
    private func batteryIcon(for level: Int) -> String {
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }
    
    private func batteryColor(for level: Int) -> Color {
        if level > 50 { return .green }
        if level > 20 { return .yellow }
        return .red
    }
}

// MARK: - Step 1: Select Type

struct Step1SelectTypeView: View {
    @Bindable var formData: SOSFormData
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("🆘")
                        .font(.system(size: 48))
                    
                    Text("Bạn đang cần gì?")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                .padding(.top, 20)
                
                // Quick presets
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chọn nhanh:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(QuickPreset.allCases, id: \.rawValue) { preset in
                                QuickPresetButton(preset: preset, isSelected: formData.appliedPreset == preset) {
                                    formData.applyPreset(preset)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Main selection cards
                VStack(spacing: 16) {
                    SOSTypeCard(
                        type: .rescue,
                        isSelected: formData.sosType == .rescue
                    ) {
                        withAnimation {
                            formData.sosType = .rescue
                        }
                    }
                    
                    SOSTypeCard(
                        type: .relief,
                        isSelected: formData.sosType == .relief
                    ) {
                        withAnimation {
                            formData.sosType = .relief
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - Step 2A: Relief (Cứu trợ)

struct Step2AReliefView: View {
    @Bindable var formData: SOSFormData
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("🎒")
                        .font(.system(size: 48))
                    
                    Text("Chi tiết cứu trợ")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                .padding(.top, 20)
                
                // Supply selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nhu yếu phẩm cần thiết")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(SupplyNeed.allCases) { supply in
                            SupplyCheckbox(
                                supply: supply,
                                isSelected: formData.reliefData.supplies.contains(supply)
                            ) {
                                if formData.reliefData.supplies.contains(supply) {
                                    formData.reliefData.supplies.remove(supply)
                                } else {
                                    formData.reliefData.supplies.insert(supply)
                                }
                            }
                        }
                    }
                    
                    // Other description
                    if formData.reliefData.supplies.contains(.other) {
                        TextField("Mô tả nhu yếu phẩm khác...", text: $formData.reliefData.otherSupplyDescription)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(.ultraThinMaterial)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.horizontal)
                
                // People count
                PeopleCountSection(peopleCount: $formData.reliefData.peopleCount)
                    .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - Step 2B: Rescue (Cứu hộ) - NEW FLOW

struct Step2BRescueView: View {
    @Bindable var formData: SOSFormData
    @State private var selectedPersonForMedical: Person? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("🚨")
                        .font(.system(size: 48))
                    
                    Text("Chi tiết cứu hộ")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                .padding(.top, 20)
                
                // Section 1: Tình trạng hiện tại
                SituationSection(formData: formData)
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.horizontal)
                
                // Section 2: Số người cần hỗ trợ (HỎI TRƯỚC)
                PeopleCountSectionNew(
                    peopleCount: Binding(
                        get: { formData.rescueData.peopleCount },
                        set: { newValue in
                            formData.rescueData.peopleCount = newValue
                            formData.rescueData.generatePeople()
                        }
                    )
                )
                .padding(.horizontal)
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.horizontal)
                
                // Section 3: Có người bị thương không?
                InjuredQuestionSection(formData: formData)
                
                // Section 4: Nếu có → Chọn ai bị thương
                if formData.rescueData.hasInjured && !formData.rescueData.people.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.horizontal)
                    
                    InjuredPersonSelectionSection(
                        formData: formData,
                        selectedPersonForMedical: $selectedPersonForMedical
                    )
                }
                
                Spacer(minLength: 100)
            }
        }
        .onAppear {
            // Tạo danh sách người khi view appear nếu chưa có
            if formData.rescueData.people.isEmpty {
                formData.rescueData.generatePeople()
            }
        }
        .sheet(item: $selectedPersonForMedical) { person in
            PersonMedicalFormSheet(
                person: person,
                formData: formData,
                onDismiss: { selectedPersonForMedical = nil }
            )
        }
    }
}

// MARK: - Sub-sections for Step 2B

struct SituationSection: View {
    @Bindable var formData: SOSFormData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tình trạng hiện tại")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(RescueSituation.allCases) { situation in
                SituationRadio(
                    situation: situation,
                    isSelected: formData.rescueData.situation == situation
                ) {
                    formData.rescueData.situation = situation
                }
            }
            
            // Other description
            if formData.rescueData.situation == .other {
                TextField("Mô tả tình trạng khác...", text: $formData.rescueData.otherSituationDescription)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(.ultraThinMaterial)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
}

struct PeopleCountSectionNew: View {
    @Binding var peopleCount: PeopleCount
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("👥")
                    .font(.title2)
                Text("Số người cần hỗ trợ")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 12) {
                PeopleCountRowNew(
                    icon: "🧑",
                    title: "Người lớn (15-60 tuổi)",
                    count: $peopleCount.adults,
                    minValue: 1
                )
                PeopleCountRowNew(
                    icon: "👶",
                    title: "Trẻ em (< 15 tuổi)",
                    count: $peopleCount.children,
                    minValue: 0
                )
                PeopleCountRowNew(
                    icon: "👴",
                    title: "Người già (> 60 tuổi)",
                    count: $peopleCount.elderly,
                    minValue: 0
                )
            }
            
            // Tổng kết
            HStack {
                Text("Tổng: \(peopleCount.total) người")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Text("💡 Trẻ em & người già được ưu tiên")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 4)
        }
    }
}

struct PeopleCountRowNew: View {
    let icon: String
    let title: String
    @Binding var count: Int
    let minValue: Int
    
    var body: some View {
        HStack {
            Text(icon)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    if count > minValue { count -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(count > minValue ? .white : .white.opacity(0.3))
                }
                .disabled(count <= minValue)
                
                Text("\(count)")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(minWidth: 30)
                
                Button {
                    count += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }
}

struct InjuredQuestionSection: View {
    @Bindable var formData: SOSFormData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🩹")
                    .font(.title2)
                Text("Có người bị thương không?")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 16) {
                InjuredOptionButton(
                    title: "Có",
                    isSelected: formData.rescueData.hasInjured == true
                ) {
                    formData.rescueData.hasInjured = true
                }
                
                InjuredOptionButton(
                    title: "Không",
                    isSelected: formData.rescueData.hasInjured == false
                ) {
                    formData.rescueData.hasInjured = false
                    // Clear injured data
                    formData.rescueData.injuredPersonIds.removeAll()
                    formData.rescueData.medicalInfoByPerson.removeAll()
                }
            }
        }
        .padding(.horizontal)
    }
}

struct InjuredPersonSelectionSection: View {
    @Bindable var formData: SOSFormData
    @Binding var selectedPersonForMedical: Person?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("👆")
                    .font(.title2)
                Text("Ai bị thương?")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text("Chọn người bị thương, sau đó nhập tình trạng y tế")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            // Danh sách người
            ForEach(formData.rescueData.people) { person in
                PersonInjuredRow(
                    person: person,
                    isInjured: formData.rescueData.injuredPersonIds.contains(person.id),
                    hasMedicalInfo: formData.rescueData.medicalInfoByPerson[person.id] != nil,
                    medicalInfo: formData.rescueData.medicalInfoByPerson[person.id],
                    onToggle: {
                        togglePersonInjured(person)
                    },
                    onEditMedical: {
                        selectedPersonForMedical = person
                    }
                )
            }
            
            // Checkbox: những người còn lại ổn định
            if !formData.rescueData.injuredPersonIds.isEmpty {
                Button {
                    formData.rescueData.othersAreStable.toggle()
                } label: {
                    HStack {
                        Image(systemName: formData.rescueData.othersAreStable ? "checkmark.square.fill" : "square")
                            .foregroundColor(formData.rescueData.othersAreStable ? .green : .white.opacity(0.6))
                        
                        Text("Những người còn lại ổn định")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal)
    }
    
    private func togglePersonInjured(_ person: Person) {
        if formData.rescueData.injuredPersonIds.contains(person.id) {
            formData.rescueData.injuredPersonIds.remove(person.id)
            formData.rescueData.medicalInfoByPerson.removeValue(forKey: person.id)
        } else {
            formData.rescueData.injuredPersonIds.insert(person.id)
            // Mở form y tế ngay
            selectedPersonForMedical = person
        }
    }
}

struct PersonInjuredRow: View {
    let person: Person
    let isInjured: Bool
    let hasMedicalInfo: Bool
    let medicalInfo: PersonMedicalInfo?
    let onToggle: () -> Void
    let onEditMedical: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isInjured ? "checkmark.square.fill" : "square")
                        .foregroundColor(isInjured ? .red : .white.opacity(0.6))
                    
                    Text(person.type.icon)
                    Text(person.displayName)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if isInjured && hasMedicalInfo {
                        // Hiển thị badge severity
                        if let info = medicalInfo {
                            SeverityBadge(severity: info.severity)
                        }
                    }
                }
                .padding(12)
                .background(isInjured ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                .cornerRadius(isInjured && hasMedicalInfo ? 10 : 10)
            }
            
            // Medical info summary (if injured and has info)
            if isInjured && hasMedicalInfo, let info = medicalInfo {
                Button(action: onEditMedical) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Issues chips
                        if !info.medicalIssues.isEmpty {
                            FlowLayout(spacing: 4) {
                                ForEach(Array(info.medicalIssues), id: \.self) { issue in
                                    Text("\(issue.icon) \(issue.title)")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.3))
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        
                        HStack {
                            Text("Nhấn để chỉnh sửa")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
            } else if isInjured && !hasMedicalInfo {
                // Prompt to add medical info
                Button(action: onEditMedical) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.orange)
                        Text("Nhập tình trạng y tế")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.orange.opacity(0.6))
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
    }
}

struct SeverityBadge: View {
    let severity: MedicalSeverity
    
    var color: Color {
        switch severity {
        case .critical: return .red
        case .moderate: return .orange
        case .mild: return .yellow
        }
    }
    
    var body: some View {
        Text(severity.title)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.3))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

// MARK: - Medical Form Sheet

struct PersonMedicalFormSheet: View {
    let person: Person
    @Bindable var formData: SOSFormData
    let onDismiss: () -> Void
    
    @State private var localMedicalIssues: Set<MedicalIssue> = []
    @State private var localOtherDescription: String = ""
    @State private var localSeverity: MedicalSeverity = .moderate
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(person.type.icon)
                            .font(.system(size: 48))
                        
                        Text("Tình trạng của \(person.displayName)")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)
                    
                    // Medical issues selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Vấn đề y tế")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(MedicalIssue.allCases) { issue in
                                MedicalIssueCheckboxLight(
                                    issue: issue,
                                    isSelected: localMedicalIssues.contains(issue)
                                ) {
                                    if localMedicalIssues.contains(issue) {
                                        localMedicalIssues.remove(issue)
                                    } else {
                                        localMedicalIssues.insert(issue)
                                    }
                                }
                            }
                        }
                        
                        // Other description
                        if localMedicalIssues.contains(.other) {
                            TextField("Mô tả vấn đề khác...", text: $localOtherDescription)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Severity selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mức độ nghiêm trọng")
                            .font(.headline)
                        
                        ForEach(MedicalSeverity.allCases, id: \.self) { severity in
                            SeverityRadio(
                                severity: severity,
                                isSelected: localSeverity == severity
                            ) {
                                localSeverity = severity
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("Chi tiết y tế")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        saveMedicalInfo()
                        onDismiss()
                    }
                    .bold()
                }
            }
        }
        .onAppear {
            loadExistingData()
        }
    }
    
    private func loadExistingData() {
        if let existing = formData.rescueData.medicalInfoByPerson[person.id] {
            localMedicalIssues = existing.medicalIssues
            localOtherDescription = existing.otherDescription
            localSeverity = existing.severity
        }
    }
    
    private func saveMedicalInfo() {
        let medicalInfo = PersonMedicalInfo(
            personId: person.id,
            medicalIssues: localMedicalIssues,
            otherDescription: localOtherDescription,
            severity: localSeverity
        )
        formData.rescueData.medicalInfoByPerson[person.id] = medicalInfo
        
        // Đảm bảo person được đánh dấu là injured
        formData.rescueData.injuredPersonIds.insert(person.id)
    }
}

struct MedicalIssueCheckboxLight: View {
    let issue: MedicalIssue
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .red : .gray)
                    .font(.body)
                
                Text(issue.icon)
                    .font(.body)
                Text(issue.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

struct SeverityRadio: View {
    let severity: MedicalSeverity
    let isSelected: Bool
    let action: () -> Void
    
    var color: Color {
        switch severity {
        case .critical: return .red
        case .moderate: return .orange
        case .mild: return .yellow
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? color : .gray)
                
                Text(severity.title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Indicator
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
            }
            .padding(12)
            .background(isSelected ? color.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

// MARK: - FlowLayout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + lineHeight
        }
    }
}

// MARK: - Step 3: Additional Info

struct Step3AdditionalInfoView: View {
    @Bindable var formData: SOSFormData
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Mô tả thêm")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Tùy chọn - Chỉ để bổ sung thông tin")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 20)
                
                // Text area
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $formData.additionalDescription)
                        .scrollContentBackground(.hidden)
                        .background(.ultraThinMaterial)
                        .foregroundColor(.white)
                        .frame(minHeight: 150)
                        .cornerRadius(12)
                        .overlay(
                            Group {
                                if formData.additionalDescription.isEmpty {
                                    Text("Ví dụ: Có 1 người lớn bị gãy chân, 2 trẻ em ổn định, đang thiếu nước uống...")
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(12)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                    
                    Text("Không cần nhập lại thông tin đã chọn ở các bước trước")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - Step 4: Review

struct Step4ReviewView: View {
    @Bindable var formData: SOSFormData
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Xác nhận gửi SOS")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                .padding(.top, 20)
                
                // Summary card
                VStack(alignment: .leading, spacing: 16) {
                    // Location
                    if let info = formData.autoInfo, let lat = info.latitude, let long = info.longitude {
                        ReviewRow(icon: "📍", title: "Vị trí", value: String(format: "%.4f, %.4f", lat, long))
                    }
                    
                    // SOS Type
                    if let type = formData.sosType {
                        ReviewRow(icon: type.icon, title: "Loại SOS", value: type.title)
                    }
                    
                    // Type-specific info
                    if formData.sosType == .rescue {
                        if let situation = formData.rescueData.situation {
                            ReviewRow(icon: situation.icon, title: "Tình trạng", value: situation.title)
                        }
                        
                        // Số người
                        ReviewRow(icon: "👥", title: "Số người", value: "\(formData.rescueData.peopleCount.total)")
                        
                        if formData.rescueData.peopleCount.children > 0 {
                            ReviewRow(icon: "👶", title: "Trẻ em", value: "\(formData.rescueData.peopleCount.children)")
                        }
                        if formData.rescueData.peopleCount.elderly > 0 {
                            ReviewRow(icon: "👴", title: "Người già", value: "\(formData.rescueData.peopleCount.elderly)")
                        }
                        
                        // Thông tin y tế từng người bị thương
                        if formData.rescueData.hasInjured && !formData.rescueData.injuredPersonIds.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("🚑 Người bị thương:")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                
                                ForEach(formData.rescueData.people.filter { 
                                    formData.rescueData.injuredPersonIds.contains($0.id) 
                                }) { person in
                                    if let medicalInfo = formData.rescueData.medicalInfoByPerson[person.id] {
                                        InjuredPersonReviewCard(person: person, medicalInfo: medicalInfo)
                                    }
                                }
                            }
                        }
                    } else if formData.sosType == .relief {
                        if !formData.reliefData.supplies.isEmpty {
                            let supplies = formData.reliefData.supplies.map { $0.title }.joined(separator: ", ")
                            ReviewRow(icon: "🎒", title: "Cần", value: supplies)
                        }
                        
                        ReviewRow(icon: "👥", title: "Số người", value: "\(formData.reliefData.peopleCount.total)")
                    }
                    
                    // Additional description
                    if !formData.additionalDescription.isEmpty {
                        ReviewRow(icon: "📝", title: "Ghi chú", value: formData.additionalDescription)
                    }
                    
                    // Time
                    ReviewRow(icon: "🕒", title: "Thời gian", value: Date().formatted(date: .abbreviated, time: .shortened))
                    
                    // Priority score
                    HStack {
                        Text("⚡ Điểm ưu tiên: \(formData.priorityScore)")
                            .font(.subheadline.bold())
                            .foregroundColor(priorityColor)
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
    }
    
    private var priorityColor: Color {
        let score = formData.priorityScore
        if score >= 70 { return .red }
        if score >= 40 { return .orange }
        return .yellow
    }
}

struct InjuredPersonReviewCard: View {
    let person: Person
    let medicalInfo: PersonMedicalInfo
    
    var severityColor: Color {
        switch medicalInfo.severity {
        case .critical: return .red
        case .moderate: return .orange
        case .mild: return .yellow
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(person.type.icon) \(person.displayName)")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(medicalInfo.severity.title)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.3))
                    .foregroundColor(severityColor)
                    .cornerRadius(6)
            }
            
            if !medicalInfo.medicalIssues.isEmpty {
                Text(medicalInfo.medicalIssues.map { "\($0.icon) \($0.title)" }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(10)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Helper Components

struct InfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    var isLoading: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                HStack {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct BatteryDotsCard: View {
    let batteryLevel: Int
    
    private var filledBars: Int {
        // 10 thanh, mỗi thanh = 10%
        return min(10, max(0, Int(ceil(Double(batteryLevel) / 10.0))))
    }
    
    private var barColor: Color {
        if batteryLevel > 50 { return .green }
        if batteryLevel > 20 { return .yellow }
        return .red
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Battery icon dạng hình pin nằm ngang - 10 nấc
            BatteryShape(filledBars: filledBars, barColor: barColor)
                .frame(width: 70, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Pin")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Text(batteryLevelText)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var batteryLevelText: String {
        if batteryLevel > 80 { return "Đầy" }
        if batteryLevel > 50 { return "Tốt" }
        if batteryLevel > 20 { return "Trung bình" }
        return "Yếu"
    }
}

/// Custom battery shape giống cục pin nằm ngang - 10 nấc
struct BatteryShape: View {
    let filledBars: Int
    let barColor: Color
    
    var body: some View {
        HStack(spacing: 0) {
            // Thân pin
            ZStack(alignment: .leading) {
                // Viền ngoài
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: 2)
                
                // 10 thanh bên trong
                HStack(spacing: 1.5) {
                    ForEach(0..<10, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(index < filledBars ? barColor : Color.white.opacity(0.2))
                            .frame(width: 4)
                    }
                }
                .padding(3)
            }
            
            // Đầu pin (cực dương)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white)
                .frame(width: 4, height: 10)
        }
    }
}

struct QuickPresetButton: View {
    let preset: QuickPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(preset.icon)
                Text(preset.title)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.red.opacity(0.6) : Color.white.opacity(0.15))
            .cornerRadius(20)
        }
    }
}

struct SOSTypeCard: View {
    let type: SOSType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(type.icon)
                    .font(.system(size: 40))
                
                Text(type.title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text(type.subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? (type == .rescue ? Color.red.opacity(0.3) : Color.yellow.opacity(0.3)) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? (type == .rescue ? Color.red : Color.yellow) : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

struct SupplyCheckbox: View {
    let supply: SupplyNeed
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .green : .white.opacity(0.6))
                
                Text(supply.icon)
                Text(supply.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

struct SituationRadio: View {
    let situation: RescueSituation
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .red : .white.opacity(0.6))
                
                Text(situation.icon)
                Text(situation.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(12)
            .background(isSelected ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

struct InjuredOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.red.opacity(0.5) : Color.white.opacity(0.1))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
                )
        }
    }
}

struct MedicalIssueCheckbox: View {
    let issue: MedicalIssue
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .red : .white.opacity(0.6))
                    .font(.caption)
                
                Text(issue.icon)
                    .font(.caption)
                Text(issue.title)
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(10)
            .background(isSelected ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct PeopleCountSection: View {
    @Binding var peopleCount: PeopleCount
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Số người cần hỗ trợ")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                PeopleCountRow(title: "Người lớn (15-60 tuổi)", count: $peopleCount.adults, minValue: 1)
                PeopleCountRow(title: "Trẻ em (< 15 tuổi)", count: $peopleCount.children, minValue: 0)
                PeopleCountRow(title: "Người già (> 60 tuổi)", count: $peopleCount.elderly, minValue: 0)
            }
            
            // Tổng kết
            HStack {
                Text("Tổng: \(peopleCount.total) người")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
            }
            
            Text("💡 Trẻ em & người già sẽ được ưu tiên cao hơn")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

struct PeopleCountRow: View {
    let title: String
    @Binding var count: Int
    var minValue: Int = 0
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    if count > minValue { count -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(count > minValue ? .white : .white.opacity(0.3))
                }
                .disabled(count <= minValue)
                
                Text("\(count)")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(minWidth: 30)
                
                Button {
                    count += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
    }
}

struct ReviewRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
    }
}
