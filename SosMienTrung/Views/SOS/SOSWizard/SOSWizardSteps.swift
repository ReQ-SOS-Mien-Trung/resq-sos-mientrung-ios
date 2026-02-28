//
//  SOSWizardSteps.swift
//  SosMienTrung
//
//  Individual step views cho SOS Wizard
//

import SwiftUI
import CoreLocation

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
                        .foregroundColor(DS.Colors.accent)
                    
                    Text("Thông tin tự động")
                        .font(.title2.bold())
                        .foregroundColor(DS.Colors.text)
                    
                    Text("Hệ thống đã thu thập các thông tin sau")
                        .font(DS.Typography.subheadline)
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
                    } else if bridgefyManager.locationManager.authorizationStatus == .denied ||
                                bridgefyManager.locationManager.authorizationStatus == .restricted {
                        InfoCard(
                            icon: "location.slash",
                            iconColor: .red,
                            title: "Vị trí GPS",
                            value: "Không có quyền truy cập vị trí",
                            isLoading: false
                        )
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
                        .foregroundColor(DS.Colors.text)
                    
                    Text("Có thể chọn 1 hoặc cả 2")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 20)
                
                // Quick presets
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chọn nhanh:")
                        .font(DS.Typography.subheadline)
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
                
                // Main selection cards - now checkboxes
                VStack(spacing: 16) {
                    SOSTypeCheckbox(
                        type: .rescue,
                        isSelected: formData.selectedTypes.contains(.rescue)
                    ) {
                        withAnimation {
                            if formData.selectedTypes.contains(.rescue) {
                                formData.selectedTypes.remove(.rescue)
                            } else {
                                formData.selectedTypes.insert(.rescue)
                            }
                        }
                    }
                    
                    SOSTypeCheckbox(
                        type: .relief,
                        isSelected: formData.selectedTypes.contains(.relief)
                    ) {
                        withAnimation {
                            if formData.selectedTypes.contains(.relief) {
                                formData.selectedTypes.remove(.relief)
                            } else {
                                formData.selectedTypes.insert(.relief)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // People count section - hiển thị ngay khi chọn loại SOS
                if !formData.selectedTypes.isEmpty {
                    Divider()
                        .background(DS.Colors.surface)
                        .padding(.horizontal)
                    
                    SharedPeopleCountSection(peopleCount: $formData.sharedPeopleCount)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - Shared People Count Section (hiển thị ở Step 1)

struct SharedPeopleCountSection: View {
    @Binding var peopleCount: PeopleCount
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("👥")
                    .font(.title2)
                Text("Số người cần hỗ trợ")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
            }
            
            Text("Xác định ngay số người để ưu tiên xử lý")
                .font(DS.Typography.caption)
                .foregroundColor(.white.opacity(0.6))
            
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
                    .foregroundColor(DS.Colors.text)
                Spacer()
                Text("💡 Trẻ em & người già được ưu tiên")
                    .font(DS.Typography.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - SOSTypeCheckbox (thay thế SOSTypeCard để có thể chọn nhiều)

struct SOSTypeCheckbox: View {
    let type: SOSType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundColor(isSelected ? (type == .rescue ? .red : .yellow) : .white.opacity(0.6))
                
                // Icon
                Text(type.icon)
                    .font(.system(size: 32))
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)
                    
                    Text(type.subtitle)
                        .font(DS.Typography.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DS.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? (type == .rescue ? Color.red.opacity(0.25) : Color.yellow.opacity(0.25)) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? (type == .rescue ? Color.red : Color.yellow) : DS.Colors.surface, lineWidth: isSelected ? 2 : 1)
                    )
            )
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
                        .foregroundColor(DS.Colors.text)
                    
                    // Show people count summary
                    Text("Hỗ trợ cho \(formData.sharedPeopleCount.total) người")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 20)
                
                // Supply selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nhu yếu phẩm cần thiết")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)
                    
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
                            .background(DS.Colors.surface)
                            .foregroundColor(DS.Colors.text)
                            
                    }
                }
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
                        .foregroundColor(DS.Colors.text)
                    
                    // Show injured count (số người được chọn bị thương)
                    let injuredCount = formData.rescueData.injuredPersonIds.count
                    if injuredCount > 0 {
                        Text("Cứu hộ cho \(injuredCount) người bị thương")
                            .font(DS.Typography.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("Chọn người cần cứu hộ bên dưới")
                            .font(DS.Typography.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.top, 20)
                
                // Section 1: Ai bị thương? (hiển thị sẵn)
                if !formData.rescueData.people.isEmpty {
                    InjuredPersonSelectionSection(
                        formData: formData,
                        selectedPersonForMedical: $selectedPersonForMedical
                    )
                }
                
                Divider()
                    .background(DS.Colors.surface)
                    .padding(.horizontal)
                
                // Section 2: Tình trạng hiện tại
                SituationSection(formData: formData)
                
                Spacer(minLength: 100)
            }
        }
        .onAppear {
            // Sync shared people count và generate people list khi view appear
            formData.rescueData.peopleCount = formData.sharedPeopleCount
            if formData.rescueData.people.isEmpty {
                formData.rescueData.generatePeople()
            }
            // Mặc định set hasInjured = true để hiển thị danh sách người
            formData.rescueData.hasInjured = true
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
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
            
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
                    .background(DS.Colors.surface)
                    .foregroundColor(DS.Colors.text)
                    
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
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
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
                    .foregroundColor(DS.Colors.text)
                Spacer()
                Text("💡 Trẻ em & người già được ưu tiên")
                    .font(DS.Typography.caption)
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
                .font(DS.Typography.subheadline)
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
                    .foregroundColor(DS.Colors.text)
                    .frame(minWidth: 30)
                
                Button {
                    count += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(DS.Colors.text)
                }
            }
        }
        .padding(12)
        .background(DS.Colors.surface)
        
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
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
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
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
            }
            
            Text("Chọn người bị thương, sau đó nhập tình trạng y tế")
                .font(DS.Typography.caption)
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
                            .font(DS.Typography.caption)
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
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.text)
                    
                    Spacer()
                    
                    if isInjured && hasMedicalInfo {
                        // Hiển thị badge severity
                        if let info = medicalInfo {
                            SeverityBadge(severity: info.severity)
                        }
                    }
                }
                .padding(12)
                .background(DS.Colors.surface)
                
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isInjured ? Color.red.opacity(0.2) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isInjured ? Color.red : DS.Colors.surface, lineWidth: isInjured ? 2 : 1)
                )
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
                                        .foregroundColor(DS.Colors.text)
                                        
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
                    .background(DS.Colors.surface)
                    
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red.opacity(0.6), lineWidth: 1)
                    )
                }
            } else if isInjured && !hasMedicalInfo {
                // Prompt to add medical info
                Button(action: onEditMedical) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(DS.Colors.warning)
                        Text("Nhập tình trạng y tế")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.warning)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.caption)
                            .foregroundColor(.orange.opacity(0.6))
                    }
                    .padding(12)
                    .background(DS.Colors.surface)
                    
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange.opacity(0.6), lineWidth: 1)
                    )
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
                            .font(DS.Typography.headline)
                        
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
                            .font(DS.Typography.headline)
                        
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
                    .font(DS.Typography.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(12)
            .background(DS.Colors.surface)
            
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.red.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.red : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
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
                    .font(DS.Typography.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Indicator
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
            }
            .padding(12)
            .background(DS.Colors.surface)
            
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
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
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 48))
                        .foregroundColor(DS.Colors.accent)
                    
                    Text("Mô tả thêm")
                        .font(.title2.bold())
                        .foregroundColor(DS.Colors.text)
                    
                    Text("Tùy chọn - Chỉ để bổ sung thông tin")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 20)
                
                // Text area
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $formData.additionalDescription)
                        .scrollContentBackground(.hidden)
                        .background(DS.Colors.surface)
                        .foregroundColor(DS.Colors.text)
                        .frame(minHeight: 150)
                        
                        .focused($isTextEditorFocused)
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
                        .font(DS.Typography.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
        .onTapGesture {
            isTextEditorFocused = false
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
                        .foregroundColor(DS.Colors.success)
                    
                    Text("Xác nhận gửi SOS")
                        .font(.title2.bold())
                        .foregroundColor(DS.Colors.text)
                }
                .padding(.top, 20)
                
                // Summary card
                VStack(alignment: .leading, spacing: 16) {
                    // Location
                    if let info = formData.autoInfo, let lat = info.latitude, let long = info.longitude {
                        ReviewRow(icon: "📍", title: "Vị trí", value: String(format: "%.4f, %.4f", lat, long))
                    }
                    
                    // SOS Types - hiển thị tất cả loại đã chọn
                    if !formData.selectedTypes.isEmpty {
                        let typesText = formData.selectedTypes.map { $0.title }.joined(separator: " + ")
                        let icon = formData.needsBothSteps ? "🆘" : (formData.sosType?.icon ?? "🆘")
                        ReviewRow(icon: icon, title: "Loại SOS", value: typesText)
                    }
                    
                    // Số người (shared)
                    ReviewRow(icon: "👥", title: "Tổng số người", value: "\(formData.sharedPeopleCount.total)")
                    
                    if formData.sharedPeopleCount.children > 0 {
                        ReviewRow(icon: "👶", title: "Trẻ em", value: "\(formData.sharedPeopleCount.children)")
                    }
                    if formData.sharedPeopleCount.elderly > 0 {
                        ReviewRow(icon: "👴", title: "Người già", value: "\(formData.sharedPeopleCount.elderly)")
                    }
                    
                    // RESCUE info
                    if formData.needsRescueStep {
                        Divider()
                            .background(DS.Colors.surface)
                        
                        Text("🚨 Thông tin cứu hộ")
                            .font(.subheadline.bold())
                            .foregroundColor(DS.Colors.danger)
                        
                        if let situation = formData.rescueData.situation {
                            ReviewRow(icon: situation.icon, title: "Tình trạng", value: situation.title)
                        }
                        
                        // Thông tin y tế từng người bị thương
                        if formData.rescueData.hasInjured && !formData.rescueData.injuredPersonIds.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("🚑 Người bị thương:")
                                    .font(.caption.bold())
                                    .foregroundColor(.white.opacity(0.8))
                                
                                ForEach(formData.rescueData.people.filter { 
                                    formData.rescueData.injuredPersonIds.contains($0.id) 
                                }) { person in
                                    if let medicalInfo = formData.rescueData.medicalInfoByPerson[person.id] {
                                        InjuredPersonReviewCard(person: person, medicalInfo: medicalInfo)
                                    }
                                }
                            }
                        }
                    }
                    
                    // RELIEF info
                    if formData.needsReliefStep {
                        Divider()
                            .background(DS.Colors.surface)
                        
                        Text("🎒 Thông tin cứu trợ")
                            .font(.subheadline.bold())
                            .foregroundColor(.yellow)
                        
                        if !formData.reliefData.supplies.isEmpty {
                            let supplies = formData.reliefData.supplies.map { $0.title }.joined(separator: ", ")
                            ReviewRow(icon: "📦", title: "Cần", value: supplies)
                        }
                        
                        if !formData.reliefData.otherSupplyDescription.isEmpty {
                            ReviewRow(icon: "📝", title: "Khác", value: formData.reliefData.otherSupplyDescription)
                        }
                    }
                    
                    // Additional description
                    if !formData.additionalDescription.isEmpty {
                        Divider()
                            .background(DS.Colors.surface)
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
                .background(DS.Colors.surface)
                
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
                    .foregroundColor(DS.Colors.text)
                
                Spacer()
                
                Text(medicalInfo.severity.title)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.3))
                    .foregroundColor(severityColor)
                    
            }
            
            if !medicalInfo.medicalIssues.isEmpty {
                Text(medicalInfo.medicalIssues.map { "\($0.icon) \($0.title)" }.joined(separator: ", "))
                    .font(DS.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(10)
        .background(Color.red.opacity(0.1))
        
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
                    .font(DS.Typography.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                HStack {
                    Text(value)
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.text)
                    
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
        .background(DS.Colors.surface)
        
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
                    .font(DS.Typography.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Text(batteryLevelText)
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)
            }
            
            Spacer()
        }
        .padding()
        .background(DS.Colors.surface)
        
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
                            .fill(index < filledBars ? barColor : DS.Colors.surface)
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
                    .font(DS.Typography.caption)
            }
            .foregroundColor(DS.Colors.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DS.Colors.surface)
            
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.red.opacity(0.25) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.red : DS.Colors.surface, lineWidth: isSelected ? 2 : 1)
            )
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
                    .foregroundColor(DS.Colors.text)
                
                Text(type.subtitle)
                    .font(DS.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DS.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? (type == .rescue ? Color.red.opacity(0.25) : Color.yellow.opacity(0.25)) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? (type == .rescue ? Color.red : Color.yellow) : DS.Colors.surface, lineWidth: isSelected ? 2 : 1)
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
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)
                
                Spacer()
            }
            .padding(12)
            .background(DS.Colors.surface)
            
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.green.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.green : DS.Colors.surface, lineWidth: isSelected ? 2 : 1)
            )
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
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)
                
                Spacer()
            }
            .padding(12)
            .background(DS.Colors.surface)
            
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.red.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.red : DS.Colors.surface, lineWidth: isSelected ? 2 : 1)
            )
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
                .foregroundColor(DS.Colors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DS.Colors.surface)
                
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.red.opacity(0.25) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.red : DS.Colors.surface, lineWidth: isSelected ? 2 : 1)
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
                    .font(DS.Typography.caption)
                
                Text(issue.icon)
                    .font(DS.Typography.caption)
                Text(issue.title)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text)
                
                Spacer()
            }
            .padding(10)
            .background(DS.Colors.surface)
            
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.red.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.red : DS.Colors.surface, lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

struct PeopleCountSection: View {
    @Binding var peopleCount: PeopleCount
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Số người cần hỗ trợ")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
            
            VStack(spacing: 12) {
                PeopleCountRow(title: "Người lớn (15-60 tuổi)", count: $peopleCount.adults, minValue: 1)
                PeopleCountRow(title: "Trẻ em (< 15 tuổi)", count: $peopleCount.children, minValue: 0)
                PeopleCountRow(title: "Người già (> 60 tuổi)", count: $peopleCount.elderly, minValue: 0)
            }
            
            // Tổng kết
            HStack {
                Text("Tổng: \(peopleCount.total) người")
                    .font(.subheadline.bold())
                    .foregroundColor(DS.Colors.text)
                Spacer()
            }
            
            Text("💡 Trẻ em & người già sẽ được ưu tiên cao hơn")
                .font(DS.Typography.caption)
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
                .font(DS.Typography.subheadline)
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
                    .foregroundColor(DS.Colors.text)
                    .frame(minWidth: 30)
                
                Button {
                    count += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(DS.Colors.text)
                }
            }
        }
        .padding(12)
        .background(DS.Colors.surface)
        
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
                    .font(DS.Typography.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Text(value)
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)
            }
            
            Spacer()
        }
    }
}
