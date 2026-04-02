import SwiftUI

struct RelativeProfilesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = RelativeProfileStore.shared

    @State private var searchText = ""
    @State private var selectedGroup: RelationGroup?
    @State private var selectedTag: String?
    @State private var editingProfile: EmergencyRelativeProfile?
    @State private var isCreatingProfile = false

    private var filteredProfiles: [EmergencyRelativeProfile] {
        store.filteredProfiles(
            searchText: searchText,
            relationGroup: selectedGroup,
            tag: selectedTag
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Nhóm", selection: $selectedGroup) {
                        Text("Tất cả nhóm").tag(RelationGroup?.none)
                        ForEach(RelationGroup.allCases) { group in
                            Text(group.title).tag(RelationGroup?.some(group))
                        }
                    }

                    Picker("Tag", selection: $selectedTag) {
                        Text("Tất cả tag").tag(String?.none)
                        ForEach(store.availableTags, id: \.self) { tag in
                            Text(tag).tag(String?.some(tag))
                        }
                    }
                    .disabled(store.availableTags.isEmpty)
                } header: {
                    Text("Bộ lọc")
                }

                Section {
                    if filteredProfiles.isEmpty {
                        RelativeProfilesEmptyState(
                            title: "Chưa có hồ sơ phù hợp",
                            systemImage: "person.3.sequence.fill",
                            description: "Thêm người thân để chọn nhanh khi gửi SOS."
                        )
                    } else {
                        ForEach(filteredProfiles) { profile in
                            Button {
                                editingProfile = profile
                            } label: {
                                RelativeProfileRow(profile: profile)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.delete(profileId: profile.id)
                                } label: {
                                    Label("Xóa", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Danh sách hồ sơ")
                } footer: {
                    Text("Dữ liệu được lưu cục bộ theo tài khoản hiện tại để dùng lại trong các lần gửi SOS.")
                }
            }
            .searchable(text: $searchText, prompt: "Tìm theo tên, tag, số điện thoại, bệnh nền")
            .navigationTitle("Người thân & hồ sơ SOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isCreatingProfile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isCreatingProfile) {
            RelativeProfileEditorView { profile in
                store.save(profile: profile)
            }
        }
        .sheet(item: $editingProfile) { profile in
            RelativeProfileEditorView(existingProfile: profile) { updatedProfile in
                store.save(profile: updatedProfile)
            }
        }
    }
}

struct RelativeProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let existingProfile: EmergencyRelativeProfile?
    let onSave: (EmergencyRelativeProfile) -> Void

    @State private var displayName = ""
    @State private var phoneNumber = ""
    @State private var personType: Person.PersonType = .adult
    @State private var gender: ClothingGender?
    @State private var relationGroup: RelationGroup = .giaDinh
    @State private var tagsText = ""
    @State private var medicalProfile = RelativeMedicalProfile()
    @State private var medicalBaselineNote = ""
    @State private var specialNeedsNote = ""
    @State private var specialDietNote = ""
    @State private var showError = false
    @State private var errorMessage = ""

    init(
        existingProfile: EmergencyRelativeProfile? = nil,
        onSave: @escaping (EmergencyRelativeProfile) -> Void
    ) {
        self.existingProfile = existingProfile
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin chính") {
                    TextField("Tên người thân", text: $displayName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)

                    TextField("Số điện thoại (tuỳ chọn)", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    Picker("Nhóm tuổi", selection: $personType) {
                        ForEach(Person.PersonType.allCasesForProfileEditor, id: \.rawValue) { type in
                            Text(type.title).tag(type)
                        }
                    }

                    Picker("Nhóm quan hệ", selection: $relationGroup) {
                        ForEach(RelationGroup.allCases) { group in
                            Text(group.title).tag(group)
                        }
                    }
                }

                Section("Thông tin nền từ SOS") {
                    Picker("Giới tính cho hỗ trợ quần áo", selection: $gender) {
                        Text("Chưa thiết lập").tag(ClothingGender?.none)
                        ForEach(ClothingGender.allCases) { gender in
                            Text(gender.title).tag(ClothingGender?.some(gender))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("🫀 Bệnh nền")

                        SelectableChipGrid(
                            options: ChronicConditionOption.allCases,
                            selectedOptions: Set(medicalProfile.chronicConditions),
                            title: \.title
                        ) { option in
                            medicalProfile.chronicConditions = toggledSelection(option, in: medicalProfile.chronicConditions)
                        }

                        TextField("Khác (nếu có)", text: $medicalProfile.otherChronicCondition)
                            .textInputAutocapitalization(.sentences)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("💊 Dị ứng")

                        SelectableChipGrid(
                            options: AllergyOption.allCases,
                            selectedOptions: Set(medicalProfile.allergyOptions),
                            title: \.title
                        ) { option in
                            medicalProfile.allergyOptions = toggledSelection(option, in: medicalProfile.allergyOptions)
                        }

                        if !medicalProfile.allergyOptions.isEmpty {
                            TextField("Ghi rõ dị ứng penicillin, hải sản...", text: $medicalProfile.allergyDetails)
                                .textInputAutocapitalization(.sentences)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("💉 Thuốc đang sử dụng")

                        Toggle("Có đang dùng thuốc điều trị dài hạn", isOn: $medicalProfile.hasLongTermMedication)

                        if medicalProfile.hasLongTermMedication {
                            ForEach(Array(medicalProfile.longTermMedications.indices), id: \.self) { index in
                                MedicationEntryEditor(
                                    entry: $medicalProfile.longTermMedications[index],
                                    removeAction: {
                                        medicalProfile.longTermMedications.remove(at: index)
                                    }
                                )
                            }

                            Button {
                                medicalProfile.longTermMedications.append(LongTermMedicationEntry())
                            } label: {
                                Label("Thêm thuốc", systemImage: "plus.circle.fill")
                            }
                        }
                    }

                    Picker("🦽 Khả năng vận động", selection: $medicalProfile.mobilityStatus) {
                        ForEach(MobilityStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("🫁 Thiết bị hỗ trợ")

                        SelectableChipGrid(
                            options: MedicalDeviceOption.allCases,
                            selectedOptions: Set(medicalProfile.medicalDevices),
                            title: \.title
                        ) { option in
                            medicalProfile.medicalDevices = toggledSelection(option, in: medicalProfile.medicalDevices)
                        }

                        TextField("Thiết bị khác (nếu có)", text: $medicalProfile.otherMedicalDevice)
                            .textInputAutocapitalization(.sentences)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("🤰 Tình trạng đặc biệt")

                        Toggle("Đang mang thai", isOn: $medicalProfile.specialSituation.isPregnant)
                        Toggle("Người già (>65)", isOn: $medicalProfile.specialSituation.isSenior)
                        Toggle("Trẻ nhỏ (<6)", isOn: $medicalProfile.specialSituation.isYoungChild)
                        Toggle("Người khuyết tật", isOn: $medicalProfile.specialSituation.hasDisability)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("🩹 Tiền sử chấn thương / phẫu thuật")

                        SelectableChipGrid(
                            options: MedicalHistoryOption.allCases,
                            selectedOptions: Set(medicalProfile.medicalHistory),
                            title: \.title
                        ) { option in
                            medicalProfile.medicalHistory = toggledSelection(option, in: medicalProfile.medicalHistory)
                        }

                        notesEditor(
                            title: "Mô tả thêm (tuỳ chọn)",
                            text: $medicalProfile.medicalHistoryDetails,
                            placeholder: "Ví dụ: phẫu thuật tim 2022, nẹp xương đùi..."
                        )
                    }

                    Picker("🩸 Nhóm máu", selection: $medicalProfile.bloodType) {
                        ForEach(BloodTypeOption.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }

                    notesEditor(
                        title: "Chế độ ăn đặc biệt",
                        text: $specialDietNote,
                        placeholder: "Ví dụ: ăn lỏng, cần sữa, kiêng đường, dị ứng hải sản..."
                    )

                    notesEditor(
                        title: "Yêu cầu hỗ trợ đặc biệt",
                        text: $specialNeedsNote,
                        placeholder: "Ví dụ: cần người dìu, cần chỗ ngồi cố định, cần liên hệ người giám hộ..."
                    )

                    notesEditor(
                        title: "Ghi chú y tế bổ sung",
                        text: $medicalBaselineNote,
                        placeholder: "Thông tin thêm chưa nằm trong các mục trên"
                    )
                }

                Section("Phân loại") {
                    TextField("Tag, cách nhau bởi dấu phẩy", text: $tagsText)
                        .textInputAutocapitalization(.never)

                    Text("Ví dụ: tiểu đường, xe lăn, trẻ sơ sinh")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(existingProfile == nil ? "Thêm hồ sơ" : "Sửa hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        saveProfile()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadExistingProfile()
            }
            .onChange(of: medicalProfile.hasLongTermMedication) { isEnabled in
                guard isEnabled else { return }
                if medicalProfile.longTermMedications.isEmpty {
                    medicalProfile.longTermMedications = [LongTermMedicationEntry()]
                }
            }
            .alert("Không thể lưu hồ sơ", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    @ViewBuilder
    private func notesEditor(
        title: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)

            TextEditor(text: text)
                .frame(minHeight: 90)
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(placeholder)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                }
        }
    }

    @ViewBuilder
    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.bold())
            .foregroundColor(.primary)
    }

    private func loadExistingProfile() {
        guard let existingProfile else { return }
        displayName = existingProfile.displayName
        phoneNumber = existingProfile.phoneNumber ?? ""
        personType = existingProfile.personType
        gender = existingProfile.gender
        relationGroup = existingProfile.relationGroup
        tagsText = existingProfile.tags.joined(separator: ", ")
        medicalProfile = existingProfile.medicalProfile
        medicalBaselineNote = existingProfile.medicalBaselineNote
        specialNeedsNote = existingProfile.specialNeedsNote
        specialDietNote = existingProfile.specialDietNote
    }

    private func saveProfile() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Tên người thân là bắt buộc."
            showError = true
            return
        }

        let tags = tagsText
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let profile = EmergencyRelativeProfile(
            id: existingProfile?.id ?? UUID().uuidString,
            displayName: trimmedName,
            phoneNumber: phoneNumber,
            personType: personType,
            gender: gender,
            relationGroup: relationGroup,
            tags: tags,
            medicalProfile: RelativeMedicalProfile(
                chronicConditions: medicalProfile.chronicConditions,
                otherChronicCondition: medicalProfile.otherChronicCondition,
                allergyOptions: medicalProfile.allergyOptions,
                allergyDetails: medicalProfile.allergyDetails,
                hasLongTermMedication: medicalProfile.hasLongTermMedication,
                longTermMedications: medicalProfile.longTermMedications,
                mobilityStatus: medicalProfile.mobilityStatus,
                medicalDevices: medicalProfile.medicalDevices,
                otherMedicalDevice: medicalProfile.otherMedicalDevice,
                specialSituation: medicalProfile.specialSituation,
                medicalHistory: medicalProfile.medicalHistory,
                medicalHistoryDetails: medicalProfile.medicalHistoryDetails,
                bloodType: medicalProfile.bloodType
            ),
            medicalBaselineNote: medicalBaselineNote,
            specialNeedsNote: specialNeedsNote,
            specialDietNote: specialDietNote,
            updatedAt: Date()
        )

        onSave(profile)
        dismiss()
    }

    private func toggledSelection<Option: CaseIterable & Hashable>(_ option: Option, in options: [Option]) -> [Option]
    where Option.AllCases: Collection {
        var selected = Set(options)
        if selected.contains(option) {
            selected.remove(option)
        } else {
            selected.insert(option)
        }
        return Array(Option.allCases).filter { selected.contains($0) }
    }
}

struct RelativeProfileRow: View {
    let profile: EmergencyRelativeProfile

    private var subtitleParts: [String] {
        var parts = [profile.personType.title, profile.relationGroup.title]
        if let gender = profile.gender {
            parts.append(gender.title)
        }
        if let phoneNumber = profile.phoneNumber, !phoneNumber.isEmpty {
            parts.append(phoneNumber)
        }
        return parts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(profile.personType.icon)")
                    .font(.title3)

                Text(profile.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text(profile.relationGroup.shortTitle)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }

            Text(subtitleParts.joined(separator: " • "))
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !profile.tags.isEmpty {
                Text(profile.tags.map { "#\($0)" }.joined(separator: "  "))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let notes = Array(profile.storedInfoLines.prefix(5))
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(notes, id: \.self) { note in
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct SelectableChipGrid<Option: Identifiable & Hashable>: View {
    let options: [Option]
    let selectedOptions: Set<Option>
    let title: KeyPath<Option, String>
    let action: (Option) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(options) { option in
                Button {
                    action(option)
                } label: {
                    Text(option[keyPath: title])
                        .font(.caption.bold())
                        .foregroundColor(selectedOptions.contains(option) ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedOptions.contains(option) ? Color.accentColor : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedOptions.contains(option) ? Color.accentColor : Color(.systemGray4),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MedicationEntryEditor: View {
    @Binding var entry: LongTermMedicationEntry
    let removeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Thuốc")
                    .font(.subheadline.bold())
                Spacer()
                Button(role: .destructive, action: removeAction) {
                    Image(systemName: "trash")
                }
            }

            TextField("Tên thuốc", text: $entry.name)
            TextField("Tần suất", text: $entry.frequency)
            TextField("Ghi chú", text: $entry.note, axis: .vertical)
                .lineLimit(2...4)
        }
        .padding(.vertical, 4)
    }
}

private struct RelativeProfilesEmptyState: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

private extension Person.PersonType {
    static var allCasesForProfileEditor: [Person.PersonType] {
        [.adult, .child, .elderly]
    }
}
