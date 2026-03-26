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
    @ObservedObject var formData: SOSFormData
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
                        .foregroundColor(DS.Colors.textSecondary)
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
    @ObservedObject var formData: SOSFormData
    
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
                        .foregroundColor(DS.Colors.textSecondary)
                }
                .padding(.top, 20)
                
                // Quick presets
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chọn nhanh:")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.textSecondary)
                    
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
                .foregroundColor(DS.Colors.textSecondary)
            
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
                    .foregroundColor(DS.Colors.textMuted)
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
                    .foregroundColor(isSelected ? (type == .rescue ? .red : .yellow) : DS.Colors.textSecondary)
                
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
                        .foregroundColor(DS.Colors.textSecondary)
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
    @ObservedObject var formData: SOSFormData
    @State private var activeEditor: ReliefPersonEditorTarget?
    
    private var peopleCount: Int { formData.sharedPeopleCount.total }

    private struct ReliefPersonEditorTarget: Identifiable {
        enum Mode: String {
            case specialDiet
            case clothing
        }

        let person: Person
        let mode: Mode

        var id: String { "\(mode.rawValue)_\(person.id)" }
    }
    
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
                    Text("Hỗ trợ cho \(peopleCount) người")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.textSecondary)
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
                                    formData.reliefData.clearFollowUp(for: supply)
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
                
                // MARK: - Follow-up Questions
                
                VStack(spacing: 16) {
                    // 💧 Nước uống
                    if formData.reliefData.supplies.contains(.water) {
                        waterFollowUpSection
                    }
                    
                    // 🍚 Thực phẩm
                    if formData.reliefData.supplies.contains(.food) {
                        foodFollowUpSection
                    }
                    
                    // 💊 Thuốc men
                    if formData.reliefData.supplies.contains(.medicine) {
                        medicineFollowUpSection
                    }
                    
                    // 🛏 Chăn / Giữ ấm
                    if formData.reliefData.supplies.contains(.blanket) {
                        blanketFollowUpSection
                    }
                    
                    // 👕 Quần áo
                    if formData.reliefData.supplies.contains(.clothes) {
                        clothesFollowUpSection
                    }
                }
                .padding(.horizontal)
                .animation(.easeInOut(duration: 0.3), value: formData.reliefData.supplies)
                
                Spacer(minLength: 100)
            }
        }
        .onAppear {
            formData.syncPeopleCount()
        }
        .sheet(item: $activeEditor) { target in
            switch target.mode {
            case .specialDiet:
                SpecialDietFormSheet(
                    person: target.person,
                    formData: formData,
                    onDismiss: { activeEditor = nil }
                )
            case .clothing:
                ClothingPersonFormSheet(
                    person: target.person,
                    formData: formData,
                    onDismiss: { activeEditor = nil }
                )
            }
        }
    }
    
    // MARK: - 💧 Water Follow-up
    
    private var waterFollowUpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nước uống", systemImage: "drop.fill")
                .font(DS.Typography.headline)
                .foregroundColor(.blue)
            
            Text("Lượng nước uống hiện tại có thể duy trì thêm bao lâu với \(peopleCount) người?")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.text)
            
            ForEach(WaterDuration.allCases) { option in
                ReliefRadioRow(
                    title: option.title,
                    isSelected: formData.reliefData.waterDuration == option
                ) {
                    formData.reliefData.waterDuration = option
                }
            }
            
            Divider().padding(.vertical, 4)
            
            Text("Bạn còn khoảng bao nhiêu nước uống?")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.text)
            
            ForEach(WaterRemaining.allCases) { option in
                ReliefRadioRow(
                    title: option.title,
                    isSelected: formData.reliefData.waterRemaining == option
                ) {
                    formData.reliefData.waterRemaining = option
                }
            }
        }
        .padding()
        .background(DS.Colors.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - 🍚 Food Follow-up
    
    private var foodFollowUpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Thực phẩm", systemImage: "fork.knife")
                .font(DS.Typography.headline)
                .foregroundColor(.orange)
            
            Text("Lượng thực phẩm hiện tại có thể duy trì thêm bao lâu với \(peopleCount) người?")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.text)
            
            ForEach(FoodDuration.allCases) { option in
                ReliefRadioRow(
                    title: option.title,
                    isSelected: formData.reliefData.foodDuration == option
                ) {
                    formData.reliefData.foodDuration = option
                }
            }
            
            Divider().padding(.vertical, 4)
            
            SharedPersonSelectionSection(
                icon: "🍽",
                title: "Ai cần chế độ ăn đặc biệt?",
                subtitle: "Chọn người rồi nhập tên và mô tả chế độ ăn đặc biệt của họ",
                people: formData.sharedPeople
            ) { person in
                PersonRequirementRow(
                    person: person,
                    isSelected: formData.reliefData.specialDietPersonIds.contains(person.id),
                    accentColor: .orange,
                    badgeText: formData.reliefData.specialDietInfoByPerson[person.id] == nil ? nil : "Đã chọn",
                    detailText: specialDietSummary(for: person.id),
                    emptyDetailText: "Nhập tên và mô tả chế độ ăn đặc biệt",
                    onToggle: {
                        toggleSpecialDiet(person)
                    },
                    onEdit: {
                        openSpecialDietEditor(for: person)
                    }
                )
            }
        }
        .padding()
        .background(DS.Colors.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - 💊 Medicine Follow-up
    
    private var medicineFollowUpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Y tế", systemImage: "cross.case.fill")
                .font(DS.Typography.headline)
                .foregroundColor(.red)
            
            Text("Chọn loại hỗ trợ y tế đang cần:")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.text)
            
            ForEach(MedicalSupportNeed.allCases) { need in
                ReliefCheckboxRow(
                    title: need.title,
                    isSelected: formData.reliefData.medicalNeeds.contains(need)
                ) {
                    if formData.reliefData.medicalNeeds.contains(need) {
                        formData.reliefData.medicalNeeds.remove(need)
                    } else {
                        formData.reliefData.medicalNeeds.insert(need)
                    }
                }
            }

            TextField("Mô tả rõ hơn về tình trạng y tế...", text: $formData.reliefData.medicalDescription)
                .textFieldStyle(.plain)
                .padding(10)
                .background(DS.Colors.background)
                .cornerRadius(8)
                .foregroundColor(DS.Colors.text)
        }
        .padding()
        .background(DS.Colors.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - 🛏 Blanket Follow-up
    
    private var blanketFollowUpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Chăn / Giữ ấm", systemImage: "bed.double.fill")
                .font(DS.Typography.headline)
                .foregroundColor(.purple)
            
            Text("Chăn mền của bạn còn đủ không?")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.text)
            
            HStack(spacing: 12) {
                ReliefRadioRow(
                    title: "Có",
                    isSelected: formData.reliefData.areBlanketsEnough == true
                ) {
                    formData.reliefData.areBlanketsEnough = true
                    formData.reliefData.blanketRequestCount = nil
                }
                
                ReliefRadioRow(
                    title: "Không",
                    isSelected: formData.reliefData.areBlanketsEnough == false
                ) {
                    formData.reliefData.areBlanketsEnough = false
                    if formData.reliefData.blanketRequestCount == nil {
                        formData.reliefData.blanketRequestCount = 1
                    }
                }
            }
            
            if formData.reliefData.areBlanketsEnough == false {
                Divider().padding(.vertical, 4)

                Text("Số lượng chăn mền cần thêm")
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)

                QuantityStepperRow(
                    title: "Chăn mền",
                    value: Binding(
                        get: { formData.reliefData.blanketRequestCount ?? 1 },
                        set: { newValue in
                            formData.reliefData.blanketRequestCount = min(max(newValue, 1), peopleCount)
                        }
                    ),
                    minValue: 1,
                    maxValue: max(1, peopleCount)
                )

                Text("Tối đa \(peopleCount) chăn mền theo số người cần hỗ trợ")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
        .padding()
        .background(DS.Colors.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - 👕 Clothes Follow-up
    
    private var clothesFollowUpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quần áo", systemImage: "tshirt.fill")
                .font(DS.Typography.headline)
                .foregroundColor(.teal)
            
            SharedPersonSelectionSection(
                icon: "👕",
                title: "Ai cần quần áo?",
                subtitle: "Chọn người rồi nhập tên và giới tính của họ",
                people: formData.sharedPeople
            ) { person in
                PersonRequirementRow(
                    person: person,
                    isSelected: formData.reliefData.clothingPersonIds.contains(person.id),
                    accentColor: .teal,
                    badgeText: formData.reliefData.clothingInfoByPerson[person.id]?.gender?.title,
                    detailText: clothingSummary(for: person.id),
                    emptyDetailText: "Nhập tên và giới tính người cần quần áo",
                    onToggle: {
                        toggleClothingPerson(person)
                    },
                    onEdit: {
                        openClothingEditor(for: person)
                    }
                )
            }
        }
        .padding()
        .background(DS.Colors.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.teal.opacity(0.3), lineWidth: 1)
        )
    }

    private func toggleSpecialDiet(_ person: Person) {
        if formData.reliefData.specialDietPersonIds.contains(person.id) {
            formData.reliefData.specialDietPersonIds.remove(person.id)
            formData.reliefData.specialDietInfoByPerson.removeValue(forKey: person.id)
        } else {
            formData.reliefData.specialDietPersonIds.insert(person.id)
            if formData.reliefData.specialDietInfoByPerson[person.id] == nil {
                formData.reliefData.specialDietInfoByPerson[person.id] = PersonSpecialDietInfo(personId: person.id)
            }
            openSpecialDietEditor(for: person)
        }
    }

    private func openSpecialDietEditor(for person: Person) {
        activeEditor = ReliefPersonEditorTarget(
            person: formData.person(for: person.id) ?? person,
            mode: .specialDiet
        )
    }

    private func toggleClothingPerson(_ person: Person) {
        if formData.reliefData.clothingPersonIds.contains(person.id) {
            formData.reliefData.clothingPersonIds.remove(person.id)
            formData.reliefData.clothingInfoByPerson.removeValue(forKey: person.id)
        } else {
            formData.reliefData.clothingPersonIds.insert(person.id)
            if formData.reliefData.clothingInfoByPerson[person.id] == nil {
                formData.reliefData.clothingInfoByPerson[person.id] = ClothingPersonInfo(personId: person.id)
            }
            openClothingEditor(for: person)
        }
    }

    private func openClothingEditor(for person: Person) {
        activeEditor = ReliefPersonEditorTarget(
            person: formData.person(for: person.id) ?? person,
            mode: .clothing
        )
    }

    private func specialDietSummary(for personId: String) -> String? {
        guard let info = formData.reliefData.specialDietInfoByPerson[personId] else { return nil }
        let description = info.dietDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? nil : description
    }

    private func clothingSummary(for personId: String) -> String? {
        guard let info = formData.reliefData.clothingInfoByPerson[personId],
              let gender = info.gender else { return nil }
        return "Giới tính: \(gender.title)"
    }
}

// MARK: - Step 2B: Rescue (Cứu hộ) - NEW FLOW

struct Step2BRescueView: View {
    @ObservedObject var formData: SOSFormData
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
                            .foregroundColor(DS.Colors.textSecondary)
                    } else {
                        Text("Chọn người cần cứu hộ bên dưới")
                            .font(DS.Typography.subheadline)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }
                .padding(.top, 20)
                
                // Section 1: Ai bị thương? (hiển thị sẵn)
                if !formData.sharedPeople.isEmpty {
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
            // Sync shared people list khi view appear
            formData.syncPeopleCount()
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
    @ObservedObject var formData: SOSFormData
    
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
                    .foregroundColor(DS.Colors.textMuted)
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
                .foregroundColor(DS.Colors.text)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    if count > minValue { count -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(count > minValue ? DS.Colors.text : DS.Colors.textMuted)
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
    @ObservedObject var formData: SOSFormData
    
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
    @ObservedObject var formData: SOSFormData
    @Binding var selectedPersonForMedical: Person?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SharedPersonSelectionSection(
                icon: "👆",
                title: "Ai bị thương?",
                subtitle: "Chọn người bị thương, sau đó nhập tình trạng y tế",
                people: formData.sharedPeople
            ) { person in
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

            if !formData.rescueData.injuredPersonIds.isEmpty &&
               formData.rescueData.injuredPersonIds.count < formData.sharedPeople.count {
                Button {
                    formData.rescueData.othersAreStable.toggle()
                } label: {
                    HStack {
                        Image(systemName: formData.rescueData.othersAreStable ? "checkmark.square.fill" : "square")
                            .foregroundColor(formData.rescueData.othersAreStable ? .green : DS.Colors.textSecondary)

                        Text("Những người còn lại ổn định")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text)
                    }
                }
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
        // Reset nếu tất cả đều bị thương
        if formData.rescueData.injuredPersonIds.count >= formData.sharedPeople.count {
            formData.rescueData.othersAreStable = false
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
                        .foregroundColor(isInjured ? .red : DS.Colors.textSecondary)
                    
                    Text(person.type.icon)
                    Text(person.displayName)
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.text)
                    
                    Spacer()
                    
                    if isInjured && hasMedicalInfo {
                        // Hiển thị số issues đã chọn
                        if let info = medicalInfo, !info.medicalIssues.isEmpty {
                            Text("\(info.medicalIssues.count) vấn đề")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.3))
                                .foregroundColor(.red)
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
                                .foregroundColor(DS.Colors.textMuted)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(DS.Colors.textMuted)
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

struct SharedPersonSelectionSection<RowContent: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let people: [Person]
    let rowContent: (Person) -> RowContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(icon)
                    .font(.title2)
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
            }

            Text(subtitle)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)

            ForEach(people) { person in
                rowContent(person)
            }
        }
    }
}

struct PersonRequirementRow: View {
    let person: Person
    let isSelected: Bool
    let accentColor: Color
    let badgeText: String?
    let detailText: String?
    let emptyDetailText: String
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? accentColor : DS.Colors.textSecondary)

                    Text(person.type.icon)
                    Text(person.displayName)
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.text)

                    Spacer()

                    if isSelected, let badgeText, !badgeText.isEmpty {
                        Text(badgeText)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accentColor.opacity(0.18))
                            .foregroundColor(accentColor)
                    }
                }
                .padding(12)
                .background(DS.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? accentColor.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? accentColor : DS.Colors.surface, lineWidth: isSelected ? 2 : 1)
                )
            }

            if isSelected {
                Button(action: onEdit) {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.circle.fill")
                            .foregroundColor(accentColor)

                        Text(detailText ?? emptyDetailText)
                            .font(DS.Typography.caption)
                            .foregroundColor(detailText == nil ? DS.Colors.textSecondary : DS.Colors.text)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(DS.Colors.textMuted)
                    }
                    .padding(12)
                    .background(DS.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(accentColor.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(accentColor.opacity(0.35), lineWidth: 1)
                    )
                }
            }
        }
    }
}

struct QuantityStepperRow: View {
    let title: String
    @Binding var value: Int
    let minValue: Int
    let maxValue: Int

    var body: some View {
        HStack {
            Text(title)
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.text)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    if value > minValue { value -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value > minValue ? DS.Colors.text : DS.Colors.textMuted)
                }
                .disabled(value <= minValue)

                Text("\(value)")
                    .font(.title3.bold())
                    .foregroundColor(DS.Colors.text)
                    .frame(minWidth: 30)

                Button {
                    if value < maxValue { value += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(value < maxValue ? DS.Colors.text : DS.Colors.textMuted)
                }
                .disabled(value >= maxValue)
            }
        }
        .padding(12)
        .background(DS.Colors.background)
        .cornerRadius(8)
    }
}

struct SeverityBadge: View {
    let issueCount: Int
    
    var body: some View {
        Text("\(issueCount) vấn đề")
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.3))
            .foregroundColor(.red)
    }
}

struct SpecialDietFormSheet: View {
    let person: Person
    @ObservedObject var formData: SOSFormData
    let onDismiss: () -> Void

    @State private var localName: String = ""
    @State private var localDietDescription: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("🍽")
                            .font(.system(size: 48))

                        Text("Chế độ ăn của")
                            .font(.title3.bold())
                            .foregroundColor(.primary)

                        TextField(person.displayName, text: $localName)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mô tả chế độ ăn đặc biệt")
                            .font(DS.Typography.headline)

                        TextField("Ví dụ: ăn lỏng, cần sữa, dị ứng hải sản...", text: $localDietDescription, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("Chi tiết thực phẩm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        saveSpecialDietInfo()
                        onDismiss()
                    }
                    .bold()
                }
            }
        }
        .onAppear {
            localName = formData.person(for: person.id)?.customName ?? person.customName
            localDietDescription = formData.reliefData.specialDietInfoByPerson[person.id]?.dietDescription ?? ""
        }
    }

    private func saveSpecialDietInfo() {
        formData.updatePersonName(localName, for: person.id)
        formData.reliefData.specialDietPersonIds.insert(person.id)
        formData.reliefData.specialDietInfoByPerson[person.id] = PersonSpecialDietInfo(
            personId: person.id,
            dietDescription: localDietDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

struct ClothingPersonFormSheet: View {
    let person: Person
    @ObservedObject var formData: SOSFormData
    let onDismiss: () -> Void

    @State private var localName: String = ""
    @State private var localGender: ClothingGender = .male

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("👕")
                            .font(.system(size: 48))

                        Text("Thông tin người cần quần áo")
                            .font(.title3.bold())
                            .foregroundColor(.primary)

                        TextField(person.displayName, text: $localName)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Giới tính")
                            .font(DS.Typography.headline)

                        ForEach(ClothingGender.allCases) { gender in
                            ReliefRadioRow(
                                title: gender.title,
                                isSelected: localGender == gender
                            ) {
                                localGender = gender
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 50)
                }
            }
            .navigationTitle("Chi tiết quần áo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        saveClothingInfo()
                        onDismiss()
                    }
                    .bold()
                }
            }
        }
        .onAppear {
            localName = formData.person(for: person.id)?.customName ?? person.customName
            localGender = formData.reliefData.clothingInfoByPerson[person.id]?.gender ?? .male
        }
    }

    private func saveClothingInfo() {
        formData.updatePersonName(localName, for: person.id)
        formData.reliefData.clothingPersonIds.insert(person.id)
        formData.reliefData.clothingInfoByPerson[person.id] = ClothingPersonInfo(
            personId: person.id,
            gender: localGender
        )
    }
}

// MARK: - Medical Form Sheet

struct PersonMedicalFormSheet: View {
    let person: Person
    @ObservedObject var formData: SOSFormData
    let onDismiss: () -> Void
    
    @State private var localName: String = ""
    @State private var localMedicalIssues: Set<MedicalIssue> = []
    @State private var localOtherDescription: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(person.type.icon)
                            .font(.system(size: 48))
                        
                        Text("Tình trạng của")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                        
                        TextField(person.displayName, text: $localName)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 20)
                    
                    // Medical issues selection — grouped by category
                    let grouped = MedicalIssue.groupedIssues(for: person.type)
                    ForEach(grouped, id: \.category) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.category.title)
                                .font(DS.Typography.headline)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(group.issues) { issue in
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
                            
                            // Other description — chỉ hiện ở nhóm "Khác"
                            if group.category == .other && localMedicalIssues.contains(.other) {
                                TextField("Mô tả vấn đề khác...", text: $localOtherDescription)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
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
        // Load custom name from person
        localName = person.customName
        
        if let existing = formData.rescueData.medicalInfoByPerson[person.id] {
            localMedicalIssues = existing.medicalIssues
            localOtherDescription = existing.otherDescription
        }
    }
    
    private func saveMedicalInfo() {
        // Lưu tên tùy chỉnh vào person
        let trimmedName = localName.trimmingCharacters(in: .whitespacesAndNewlines)
        formData.updatePersonName(trimmedName, for: person.id)
        
        let medicalInfo = PersonMedicalInfo(
            personId: person.id,
            medicalIssues: localMedicalIssues,
            otherDescription: localOtherDescription
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
    let issueCount: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .red : .gray)
                
                Text("\(issueCount) vấn đề y tế")
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
    @ObservedObject var formData: SOSFormData
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
                        .foregroundColor(DS.Colors.textSecondary)
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
                                        .foregroundColor(DS.Colors.textMuted)
                                        .padding(12)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                    
                    Text("Không cần nhập lại thông tin đã chọn ở các bước trước")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textMuted)
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
    @ObservedObject var formData: SOSFormData
    
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
                    
                    PeopleCountSummaryGrid(
                        peopleCount: formData.sharedPeopleCount,
                        layoutStyle: .inline
                    )
                    
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
                                    .foregroundColor(DS.Colors.text)

                                LazyVGrid(columns: summaryGridColumns, spacing: 10) {
                                    ForEach(formData.sharedPeople.filter {
                                        formData.rescueData.injuredPersonIds.contains($0.id)
                                    }) { person in
                                        if let medicalInfo = formData.rescueData.medicalInfoByPerson[person.id] {
                                            InjuredPersonReviewCard(person: person, medicalInfo: medicalInfo)
                                        }
                                    }
                                }
                                
                                // Những người còn lại ổn định
                                if formData.rescueData.othersAreStable &&
                                   formData.rescueData.injuredPersonIds.count < formData.sharedPeople.count {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Những người còn lại ổn định")
                                            .font(DS.Typography.caption)
                                            .foregroundColor(DS.Colors.textSecondary)
                                    }
                                    .padding(.top, 4)
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

                        ReliefSummaryGridContent(
                            relief: formData.reliefData,
                            people: formData.sharedPeople
                        )
                    }
                    
                    // Additional description
                    if !formData.additionalDescription.isEmpty {
                        Divider()
                            .background(DS.Colors.surface)
                        ReviewRow(icon: "📝", title: "Ghi chú", value: formData.additionalDescription)
                    }
                    
                    // Time
                    ReviewRow(icon: "🕒", title: "Thời gian", value: Date().formatted(date: .abbreviated, time: .shortened))
                    
                    // Priority level
                    HStack {
                        Text("⚡ Mức ưu tiên: \(formData.priorityLevel.title)")
                            .font(.subheadline.bold())
                            .foregroundColor(formData.priorityLevel.color)
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
    
}

struct InjuredPersonReviewCard: View {
    let person: Person
    let medicalInfo: PersonMedicalInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(person.type.icon) \(person.displayName)")
                    .font(.subheadline.bold())
                    .foregroundColor(DS.Colors.text)
                
                Spacer()
                
                if !medicalInfo.medicalIssues.isEmpty {
                    Text("\(medicalInfo.medicalIssues.count) vấn đề")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.3))
                        .foregroundColor(.red)
                }
            }
            
            if !medicalInfo.medicalIssues.isEmpty {
                Text(medicalInfo.medicalIssues.map { "\($0.icon) \($0.title)" }.joined(separator: ", "))
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(Color.red.opacity(0.1))
        .cornerRadius(DS.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(Color.red.opacity(0.18), lineWidth: DS.Border.thin)
        )
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
                    .foregroundColor(DS.Colors.textSecondary)
                
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
                    .foregroundColor(DS.Colors.textSecondary)
                
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
                    .foregroundColor(DS.Colors.textSecondary)
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
                    .foregroundColor(isSelected ? .green : DS.Colors.textSecondary)
                
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
                    .foregroundColor(isSelected ? .red : DS.Colors.textSecondary)
                
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
                    .foregroundColor(isSelected ? .red : DS.Colors.textSecondary)
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
                .foregroundColor(DS.Colors.textMuted)
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
                .foregroundColor(DS.Colors.text)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    if count > minValue { count -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(count > minValue ? DS.Colors.text : DS.Colors.textMuted)
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
                    .foregroundColor(DS.Colors.textSecondary)
                
                Text(value)
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)
            }
            
            Spacer()
        }
    }
}

let summaryGridColumns: [GridItem] = [
    GridItem(.flexible(), spacing: 12, alignment: .top),
    GridItem(.flexible(), spacing: 12, alignment: .top)
]

struct PeopleCountMetric: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: String
}

struct ReliefSupplyCardLine: Identifiable {
    let id: String
    let label: String
    let value: String
}

struct ReliefSupplyCardModel: Identifiable {
    let id: String
    let icon: String
    let title: String
    let accentColor: Color
    let lines: [ReliefSupplyCardLine]
}

struct PersonRequirementSummaryModel: Identifiable {
    let id: String
    let name: String
    let typeIcon: String
    let needsClothing: Bool
    let hasSpecialDiet: Bool
    let dietDescription: String?
    let genderTag: String?
}

func peopleCountMetrics(from peopleCount: PeopleCount) -> [PeopleCountMetric] {
    [
        PeopleCountMetric(id: "total", icon: "👥", title: "Tổng người", value: "\(peopleCount.total)"),
        PeopleCountMetric(id: "adults", icon: "🧑", title: "Người lớn", value: "\(peopleCount.adults)"),
        PeopleCountMetric(id: "children", icon: "👶", title: "Trẻ em", value: "\(peopleCount.children)"),
        PeopleCountMetric(id: "elderly", icon: "👴", title: "Người già", value: "\(peopleCount.elderly)")
    ]
}

func reliefSupplyCardModels(from relief: ReliefData) -> [ReliefSupplyCardModel] {
    func line(_ id: String, _ label: String, _ value: String) -> ReliefSupplyCardLine {
        ReliefSupplyCardLine(id: id, label: label, value: value)
    }

    func fallbackLine() -> [ReliefSupplyCardLine] {
        [line("requested", "Trạng thái", "Đã yêu cầu")]
    }

    let trimmedMedicalDescription = relief.medicalDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedOtherDescription = relief.otherSupplyDescription.trimmingCharacters(in: .whitespacesAndNewlines)

    var cards: [ReliefSupplyCardModel] = []

    if relief.supplies.contains(.water) {
        var lines: [ReliefSupplyCardLine] = []
        if let duration = relief.waterDuration {
            lines.append(line("water_duration", "Còn duy trì", duration.title))
        }
        if let remaining = relief.waterRemaining {
            lines.append(line("water_remaining", "Lượng còn lại", remaining.title))
        }
        cards.append(
            ReliefSupplyCardModel(
                id: SupplyNeed.water.rawValue,
                icon: SupplyNeed.water.icon,
                title: SupplyNeed.water.title,
                accentColor: .blue,
                lines: lines.isEmpty ? fallbackLine() : lines
            )
        )
    }

    if relief.supplies.contains(.food) {
        var lines: [ReliefSupplyCardLine] = []
        if let duration = relief.foodDuration {
            lines.append(line("food_duration", "Còn duy trì", duration.title))
        }
        cards.append(
            ReliefSupplyCardModel(
                id: SupplyNeed.food.rawValue,
                icon: SupplyNeed.food.icon,
                title: SupplyNeed.food.title,
                accentColor: .orange,
                lines: lines.isEmpty ? fallbackLine() : lines
            )
        )
    }

    if relief.supplies.contains(.medicine) {
        var lines: [ReliefSupplyCardLine] = []
        if !relief.medicalNeeds.isEmpty {
            lines.append(line("medical_needs", "Hạng mục", relief.medicalNeeds.map(\.title).joined(separator: ", ")))
        }
        if !trimmedMedicalDescription.isEmpty {
            lines.append(line("medical_description", "Mô tả", trimmedMedicalDescription))
        }
        cards.append(
            ReliefSupplyCardModel(
                id: SupplyNeed.medicine.rawValue,
                icon: SupplyNeed.medicine.icon,
                title: SupplyNeed.medicine.title,
                accentColor: .red,
                lines: lines.isEmpty ? fallbackLine() : lines
            )
        )
    }

    if relief.supplies.contains(.blanket) {
        var lines: [ReliefSupplyCardLine] = []
        if let areBlanketsEnough = relief.areBlanketsEnough {
            lines.append(line("blanket_status", "Tình trạng", areBlanketsEnough ? "Còn đủ" : "Không đủ"))
        }
        if let blanketRequestCount = relief.blanketRequestCount {
            lines.append(line("blanket_count", "Cần thêm", "\(blanketRequestCount)"))
        }
        cards.append(
            ReliefSupplyCardModel(
                id: SupplyNeed.blanket.rawValue,
                icon: "🛏️",
                title: "Chăn mền",
                accentColor: .purple,
                lines: lines.isEmpty ? fallbackLine() : lines
            )
        )
    }

    if relief.supplies.contains(.clothes) {
        let lines = relief.clothingPersonIds.isEmpty
            ? fallbackLine()
            : [line("clothing_count", "Số người", "\(relief.clothingPersonIds.count) người")]
        cards.append(
            ReliefSupplyCardModel(
                id: SupplyNeed.clothes.rawValue,
                icon: SupplyNeed.clothes.icon,
                title: SupplyNeed.clothes.title,
                accentColor: .teal,
                lines: lines
            )
        )
    }

    if relief.supplies.contains(.other) {
        let lines = trimmedOtherDescription.isEmpty
            ? fallbackLine()
            : [line("other_description", "Chi tiết", trimmedOtherDescription)]
        cards.append(
            ReliefSupplyCardModel(
                id: SupplyNeed.other.rawValue,
                icon: SupplyNeed.other.icon,
                title: SupplyNeed.other.title,
                accentColor: DS.Colors.accent,
                lines: lines
            )
        )
    }

    return cards
}

func personRequirementSummaryModels(from relief: ReliefData, people: [Person]) -> [PersonRequirementSummaryModel] {
    let requestedPersonIds = relief.specialDietPersonIds.union(relief.clothingPersonIds)

    return people.compactMap { person in
        guard requestedPersonIds.contains(person.id) else { return nil }

        let hasClothing = relief.clothingPersonIds.contains(person.id)
        let hasSpecialDiet = relief.specialDietPersonIds.contains(person.id)
        let dietDescription = relief.specialDietInfoByPerson[person.id]?.dietDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let genderTag = relief.clothingInfoByPerson[person.id]?.gender?.title

        return PersonRequirementSummaryModel(
            id: person.id,
            name: person.displayName,
            typeIcon: person.type.icon,
            needsClothing: hasClothing,
            hasSpecialDiet: hasSpecialDiet,
            dietDescription: dietDescription?.isEmpty == false ? dietDescription : nil,
            genderTag: genderTag
        )
    }
}

enum PeopleCountMetricLayoutStyle {
    case stacked
    case inline
}

struct PeopleCountSummaryGrid: View {
    let peopleCount: PeopleCount
    var layoutStyle: PeopleCountMetricLayoutStyle = .stacked

    var body: some View {
        LazyVGrid(columns: summaryGridColumns, spacing: 12) {
            ForEach(peopleCountMetrics(from: peopleCount)) { metric in
                PeopleCountMetricCard(metric: metric, layoutStyle: layoutStyle)
            }
        }
    }
}

struct PeopleCountMetricCard: View {
    let metric: PeopleCountMetric
    var layoutStyle: PeopleCountMetricLayoutStyle = .stacked

    var body: some View {
        Group {
            if layoutStyle == .inline {
                HStack(alignment: .center, spacing: 8) {
                    Text(metric.icon)
                        .font(.title3)

                    Text("\(metric.title):")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)

                    Text(metric.value)
                        .font(.title2.bold())
                        .foregroundColor(DS.Colors.text)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(metric.icon)
                        .font(.title3)

                    Text(metric.title)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)

                    Text(metric.value)
                        .font(.title3.bold())
                        .foregroundColor(DS.Colors.text)
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: layoutStyle == .inline ? 56 : 88,
            alignment: layoutStyle == .inline ? .leading : .topLeading
        )
        .padding(.horizontal, 12)
        .padding(.vertical, layoutStyle == .inline ? 8 : 12)
        .background(DS.Colors.background)
        .cornerRadius(DS.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.borderSubtle, lineWidth: DS.Border.thin)
        )
    }
}

struct ReliefSummaryGridContent: View {
    let relief: ReliefData
    let people: [Person]

    private var supplyCards: [ReliefSupplyCardModel] {
        reliefSupplyCardModels(from: relief)
    }

    private var personCards: [PersonRequirementSummaryModel] {
        personRequirementSummaryModels(from: relief, people: people)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !supplyCards.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Các nhu yếu phẩm được yêu cầu")
                        .font(.caption.bold())
                        .foregroundColor(DS.Colors.textSecondary)

                    LazyVGrid(columns: summaryGridColumns, spacing: 12) {
                        ForEach(supplyCards) { card in
                            ReliefSupplySummaryCard(card: card)
                        }
                    }
                }
            }

            if !personCards.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Yêu cầu theo người")
                        .font(.caption.bold())
                        .foregroundColor(DS.Colors.textSecondary)

                    LazyVGrid(columns: summaryGridColumns, spacing: 12) {
                        ForEach(personCards) { card in
                            PersonRequirementSummaryCard(card: card)
                        }
                    }
                }
            }
        }
    }
}

struct ReliefSupplySummaryCard: View {
    let card: ReliefSupplyCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(card.icon)
                    .font(.headline)

                Text(card.title)
                    .font(.subheadline.bold())
                    .foregroundColor(DS.Colors.text)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }

            ForEach(card.lines) { line in
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.label)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)

                    Text(line.value)
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(card.accentColor.opacity(0.10))
        .cornerRadius(DS.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(card.accentColor.opacity(0.28), lineWidth: DS.Border.thin)
        )
    }
}

struct PersonRequirementSummaryCard: View {
    let card: PersonRequirementSummaryModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(card.typeIcon)
                    .font(.headline)

                Text(card.name)
                    .font(.subheadline.bold())
                    .foregroundColor(DS.Colors.text)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                if let genderTag = card.genderTag {
                    SummaryTag(text: genderTag)
                }
            }

            if card.needsClothing {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Yêu cầu")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)

                    Text("Quần áo")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if card.hasSpecialDiet {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chế độ ăn đặc biệt")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)

                    Text(card.dietDescription ?? "Có")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(DS.Colors.background)
        .cornerRadius(DS.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.borderSubtle, lineWidth: DS.Border.thin)
        )
    }
}

struct SummaryTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(DS.Colors.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(DS.Colors.accent.opacity(0.14))
            .cornerRadius(999)
    }
}

// MARK: - Relief Radio Row (single-select)

struct ReliefRadioRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? DS.Colors.accent : DS.Colors.textSecondary)
                    .font(.body)
                
                Text(title)
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)
                
                Spacer()
            }
            .padding(10)
            .background(isSelected ? DS.Colors.accent.opacity(0.1) : DS.Colors.background)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? DS.Colors.accent : DS.Colors.border, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
    }
}

// MARK: - Relief Checkbox Row (multi-select)

struct ReliefCheckboxRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? DS.Colors.accent : DS.Colors.textSecondary)
                    .font(.body)
                
                Text(title)
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)
                
                Spacer()
            }
            .padding(10)
            .background(isSelected ? DS.Colors.accent.opacity(0.1) : DS.Colors.background)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? DS.Colors.accent : DS.Colors.border, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
    }
}
