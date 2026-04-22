import SwiftUI

struct RelativeProfilePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = RelativeProfileStore.shared

    let initialSelectedProfileIds: Set<String>
    let onApply: ([EmergencyRelativeProfile]) -> Void

    @State private var searchText = ""
    @State private var selectedGroup: RelationGroup?
    @State private var selectedProfileIds: Set<String> = []

    private var filteredProfiles: [EmergencyRelativeProfile] {
        store.filteredProfiles(
            searchText: searchText,
            relationGroup: selectedGroup
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
                } header: {
                    Text("Bộ lọc")
                }

                Section {
                    if filteredProfiles.isEmpty {
                        RelativeProfilePickerEmptyState(
                            title: "Không có hồ sơ phù hợp",
                            systemImage: "person.crop.circle.badge.questionmark",
                            description: "Điều chỉnh bộ lọc hoặc thêm hồ sơ người thân trong phần cài đặt."
                        )
                    } else {
                        ForEach(filteredProfiles) { profile in
                            Button {
                                toggleSelection(for: profile.id)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: selectedProfileIds.contains(profile.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedProfileIds.contains(profile.id) ? DS.Colors.success : DS.Colors.textSecondary)
                                        .padding(.top, 4)

                                    VStack(alignment: .leading, spacing: 8) {
                                        RelativeProfileRow(profile: profile)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Chọn người thân")
                } footer: {
                    Text("Có thể chọn nhiều người để tạo sẵn danh sách nạn nhân cho một lần gửi SOS.")
                }
            }
            .searchable(text: $searchText, prompt: "Tìm theo tên, số điện thoại")
            .navigationTitle("Chọn từ hồ sơ đã lưu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Áp dụng") {
                        applySelection()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedProfileIds.isEmpty)
                }
            }
            .onAppear {
                selectedProfileIds = initialSelectedProfileIds
                store.refreshFromServerIfPossible()
            }
        }
    }

    private func toggleSelection(for profileId: String) {
        if selectedProfileIds.contains(profileId) {
            selectedProfileIds.remove(profileId)
        } else {
            selectedProfileIds.insert(profileId)
        }
    }

    private func applySelection() {
        let selectedProfiles = store.profiles.filter { selectedProfileIds.contains($0.id) }
        onApply(selectedProfiles)
        dismiss()
    }
}

private struct RelativeProfilePickerEmptyState: View {
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

struct SavedRelativeProfilesCard: View {
    @ObservedObject var formData: SOSFormData
    var showsStoredInfo: Bool = true
    var showsPersonDetails: Bool = true
    var onChangeSelection: (() -> Void)? = nil
    var onSwitchToManual: (() -> Void)? = nil

    private var selectedRelativeCount: Int {
        Set(formData.selectedRelativeSnapshots.map(\.profileId)).count
    }

    private var selectedRelativeNames: [String] {
        var seen = Set<String>()
        return formData.selectedRelativeSnapshots.compactMap { snapshot in
            guard seen.insert(snapshot.profileId).inserted else { return nil }
            return formData.person(for: snapshot.personId)?.displayName.nilIfBlank ?? snapshot.displayName.nilIfBlank
        }
    }

    private var manualAdditionalCount: Int {
        max(formData.sharedPeopleCount.total - selectedRelativeCount, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Người thân đã chọn")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)

                    Text(showsPersonDetails
                        ? "Danh sách này được lấy từ hồ sơ đã lưu và có thể chỉnh riêng cho lần SOS hiện tại."
                        : "Danh sách hồ sơ đã áp dụng cho lần SOS hiện tại.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if manualAdditionalCount > 0 {
                        Text("Có thêm \(manualAdditionalCount) người nhập thủ công ngoài danh sách hồ sơ đã lưu.")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                if selectedRelativeCount > 0 {
                    Text("\(selectedRelativeCount) người")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DS.Colors.accent.opacity(0.15))
                        .foregroundColor(DS.Colors.accent)
                        .clipShape(Capsule())
                }
            }

            if !formData.selectedRelativeSnapshots.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if showsPersonDetails {
                        ForEach(formData.selectedRelativeSnapshots, id: \.profileId) { snapshot in
                            SavedRelativeSnapshotRow(snapshot: snapshot, person: formData.person(for: snapshot.personId))
                        }
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(selectedRelativeNames, id: \.self) { name in
                                HStack(spacing: 6) {
                                    Image(systemName: "person.fill")
                                        .font(.caption)
                                    Text(name)
                                        .font(DS.Typography.caption.bold())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .foregroundColor(DS.Colors.text)
                                .background(DS.Colors.background)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            if showsStoredInfo && !formData.savedProfileNoteItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Thông tin đã lưu")
                        .font(.caption.bold())
                        .foregroundColor(DS.Colors.textSecondary)

                    ForEach(formData.savedProfileNoteItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: item.personType.symbolName)
                                    .foregroundColor(DS.Colors.accent)
                                Text(item.displayName)
                                    .font(.subheadline.bold())
                                    .foregroundColor(DS.Colors.text)
                            }

                            ForEach(item.summaryLines, id: \.self) { line in
                                Text(line)
                                    .font(.caption)
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Colors.background)
                        .cornerRadius(10)
                    }
                }
            }

            if onChangeSelection != nil || onSwitchToManual != nil {
                HStack(spacing: 12) {
                    if let onChangeSelection {
                        Button {
                            onChangeSelection()
                        } label: {
                            Label("Đổi danh sách", systemImage: "person.2.badge.gearshape")
                                .font(DS.Typography.caption.bold())
                                .foregroundColor(DS.Colors.text)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(DS.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
                                )
                        }
                    }

                    if let onSwitchToManual {
                        Button {
                            onSwitchToManual()
                        } label: {
                            Label("Nhập thủ công", systemImage: "square.and.pencil")
                                .font(DS.Typography.caption.bold())
                                .foregroundColor(DS.Colors.text)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(DS.Colors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(DS.Colors.borderSubtle, lineWidth: DS.Border.thin)
                                )
                        }
                    }
                }
            }
        }
        .padding()
        .background(DS.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
        )
        .cornerRadius(12)
    }
}

struct SavedRelativeSnapshotRow: View {
    let snapshot: SelectedRelativeSnapshot
    let person: Person?

    private var displayName: String {
        person?.displayName ?? snapshot.displayName
    }

    private var badgeLine: String {
        [snapshot.personType.title, snapshot.relationGroup.title].joined(separator: " • ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: snapshot.personType.symbolName)
                .font(.title3)
                .foregroundColor(DS.Colors.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(DS.Colors.text)

                Text(badgeLine)
                    .font(.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let phoneNumber = snapshot.phoneNumber, !phoneNumber.isEmpty {
                    Text(phoneNumber)
                        .font(.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }

                ForEach(Array(snapshot.storedInfoLines.prefix(3)), id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(DS.Colors.background)
        .cornerRadius(10)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
