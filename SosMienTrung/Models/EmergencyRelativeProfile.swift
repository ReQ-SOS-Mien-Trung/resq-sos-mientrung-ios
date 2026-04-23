import Foundation
import Combine

enum RelationGroup: String, Codable, CaseIterable, Identifiable {
    case giaDinh = "gia_dinh"
    case nhaNoi = "nha_noi"
    case nhaNgoai = "nha_ngoai"
    case hangXom = "hang_xom"
    case banBe = "ban_be"
    case khac = "khac"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .giaDinh: return "Gia đình"
        case .nhaNoi: return "Nhà nội"
        case .nhaNgoai: return "Nhà ngoại"
        case .hangXom: return "Hàng xóm"
        case .banBe: return "Bạn bè"
        case .khac: return "Khác"
        }
    }

    var shortTitle: String {
        switch self {
        case .giaDinh: return "Gia đình"
        case .nhaNoi: return "Nội"
        case .nhaNgoai: return "Ngoại"
        case .hangXom: return "Hàng xóm"
        case .banBe: return "Bạn bè"
        case .khac: return "Khác"
        }
    }
}

enum ChronicConditionOption: String, Codable, CaseIterable, Identifiable, Hashable {
    case cardiovascular = "CARDIOVASCULAR"
    case hypertension = "HYPERTENSION"
    case hypotension = "HYPOTENSION"
    case diabetes = "DIABETES"
    case asthma = "ASTHMA"
    case lungDisease = "LUNG_DISEASE"
    case kidneyDisease = "KIDNEY_DISEASE"
    case liverDisease = "LIVER_DISEASE"
    case epilepsy = "EPILEPSY"
    case clottingDisorder = "CLOTTING_DISORDER"
    case cancer = "CANCER"
    case immunocompromised = "IMMUNOCOMPROMISED"
    case neurological = "NEUROLOGICAL"
    case mentalHealth = "MENTAL_HEALTH"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cardiovascular: return "Tim mạch"
        case .hypertension: return "Huyết áp cao"
        case .hypotension: return "Huyết áp thấp"
        case .diabetes: return "Tiểu đường"
        case .asthma: return "Hen suyễn"
        case .lungDisease: return "Bệnh phổi"
        case .kidneyDisease: return "Bệnh thận"
        case .liverDisease: return "Bệnh gan"
        case .epilepsy: return "Động kinh"
        case .clottingDisorder: return "Rối loạn đông máu"
        case .cancer: return "Ung thư"
        case .immunocompromised: return "Suy giảm miễn dịch"
        case .neurological: return "Bệnh thần kinh"
        case .mentalHealth: return "Bệnh tâm thần"
        }
    }
}

enum AllergyOption: String, Codable, CaseIterable, Identifiable, Hashable {
    case medication = "MEDICATION"
    case food = "FOOD"
    case insect = "INSECT"
    case environment = "ENVIRONMENT"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .medication: return "Dị ứng thuốc"
        case .food: return "Dị ứng thực phẩm"
        case .insect: return "Dị ứng côn trùng"
        case .environment: return "Dị ứng môi trường"
        }
    }
}

enum MobilityStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case normal = "NORMAL"
    case limitedWalking = "LIMITED_WALKING"
    case needsSupport = "NEEDS_SUPPORT"
    case immobile = "IMMOBILE"
    case wheelchair = "WHEELCHAIR"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return "Bình thường"
        case .limitedWalking: return "Đi lại khó khăn"
        case .needsSupport: return "Cần hỗ trợ (gậy / người đỡ)"
        case .immobile: return "Không thể tự di chuyển"
        case .wheelchair: return "Dùng xe lăn"
        }
    }
}

enum MedicalDeviceOption: String, Codable, CaseIterable, Identifiable, Hashable {
    case oxygen = "OXYGEN"
    case ventilator = "VENTILATOR"
    case glucoseMonitor = "GLUCOSE_MONITOR"
    case pacemaker = "PACEMAKER"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .oxygen: return "Bình oxy"
        case .ventilator: return "Máy trợ thở"
        case .glucoseMonitor: return "Máy đo đường huyết"
        case .pacemaker: return "Máy trợ tim (pacemaker)"
        }
    }
}

enum MedicalHistoryOption: String, Codable, CaseIterable, Identifiable, Hashable {
    case boneFracture = "BONE_FRACTURE"
    case priorHeadInjury = "PRIOR_HEAD_INJURY"
    case majorSurgery = "MAJOR_SURGERY"
    case implant = "IMPLANT"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .boneFracture: return "Đã từng gãy xương"
        case .priorHeadInjury: return "Chấn thương đầu trước đó"
        case .majorSurgery: return "Phẫu thuật lớn"
        case .implant: return "Có cấy ghép / nẹp / vít"
        }
    }
}

enum BloodTypeOption: String, Codable, CaseIterable, Identifiable, Hashable {
    case aPositive = "A+"
    case aNegative = "A-"
    case bPositive = "B+"
    case bNegative = "B-"
    case abPositive = "AB+"
    case abNegative = "AB-"
    case oPositive = "O+"
    case oNegative = "O-"
    case unknown = "UNKNOWN"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aPositive: return "A+"
        case .aNegative: return "A-"
        case .bPositive: return "B+"
        case .bNegative: return "B-"
        case .abPositive: return "AB+"
        case .abNegative: return "AB-"
        case .oPositive: return "O+"
        case .oNegative: return "O-"
        case .unknown: return "Không biết"
        }
    }
}

struct LongTermMedicationEntry: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var frequency: String
    var note: String

    init(
        id: String = UUID().uuidString,
        name: String = "",
        frequency: String = "",
        note: String = ""
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.frequency = frequency.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isMeaningful: Bool {
        name.nilIfBlank != nil || frequency.nilIfBlank != nil || note.nilIfBlank != nil
    }

    var summary: String? {
        guard isMeaningful else { return nil }
        var parts: [String] = []
        if let name = name.nilIfBlank {
            parts.append(name)
        }
        if let frequency = frequency.nilIfBlank {
            parts.append("tần suất: \(frequency)")
        }
        if let note = note.nilIfBlank {
            parts.append(note)
        }
        return parts.joined(separator: ", ")
    }
}

struct SpecialMedicalSituation: Codable, Equatable, Hashable {
    var isPregnant: Bool = false
    var isSenior: Bool = false
    var isYoungChild: Bool = false
    var hasDisability: Bool = false

    var selectedTitles: [String] {
        var titles: [String] = []
        if isPregnant { titles.append("Đang mang thai") }
        if hasDisability { titles.append("Người khuyết tật") }
        return titles
    }

    var hasSelection: Bool {
        isPregnant || hasDisability
    }

    var sanitizedForProfileEditor: SpecialMedicalSituation {
        SpecialMedicalSituation(
            isPregnant: isPregnant,
            isSenior: false,
            isYoungChild: false,
            hasDisability: hasDisability
        )
    }
}

struct RelativeMedicalProfile: Codable, Equatable, Hashable {
    var chronicConditions: [ChronicConditionOption] = []
    var otherChronicCondition: String = ""
    var allergyOptions: [AllergyOption] = []
    var allergyDetails: String = ""
    var hasLongTermMedication: Bool = false
    var longTermMedications: [LongTermMedicationEntry] = []
    var mobilityStatus: MobilityStatus = .normal
    var medicalDevices: [MedicalDeviceOption] = []
    var otherMedicalDevice: String = ""
    var specialSituation: SpecialMedicalSituation = SpecialMedicalSituation()
    var medicalHistory: [MedicalHistoryOption] = []
    var medicalHistoryDetails: String = ""
    var bloodType: BloodTypeOption = .unknown

    init(
        chronicConditions: [ChronicConditionOption] = [],
        otherChronicCondition: String = "",
        allergyOptions: [AllergyOption] = [],
        allergyDetails: String = "",
        hasLongTermMedication: Bool = false,
        longTermMedications: [LongTermMedicationEntry] = [],
        mobilityStatus: MobilityStatus = .normal,
        medicalDevices: [MedicalDeviceOption] = [],
        otherMedicalDevice: String = "",
        specialSituation: SpecialMedicalSituation = SpecialMedicalSituation(),
        medicalHistory: [MedicalHistoryOption] = [],
        medicalHistoryDetails: String = "",
        bloodType: BloodTypeOption = .unknown
    ) {
        self.chronicConditions = normalizeSelection(chronicConditions)
        self.otherChronicCondition = otherChronicCondition.trimmingCharacters(in: .whitespacesAndNewlines)
        self.allergyOptions = normalizeSelection(allergyOptions)
        self.allergyDetails = allergyDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hasLongTermMedication = hasLongTermMedication
        self.longTermMedications = hasLongTermMedication
            ? longTermMedications
                .map { LongTermMedicationEntry(id: $0.id, name: $0.name, frequency: $0.frequency, note: $0.note) }
                .filter(\.isMeaningful)
            : []
        self.mobilityStatus = mobilityStatus
        self.medicalDevices = normalizeSelection(medicalDevices)
        self.otherMedicalDevice = otherMedicalDevice.trimmingCharacters(in: .whitespacesAndNewlines)
        self.specialSituation = specialSituation
        self.medicalHistory = normalizeSelection(medicalHistory)
        self.medicalHistoryDetails = medicalHistoryDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bloodType = bloodType
    }

    var summaryLines: [String] {
        var lines: [String] = []

        var conditionTitles = chronicConditions.map(\.title)
        if let otherCondition = otherChronicCondition.nilIfBlank {
            conditionTitles.append("Khác: \(otherCondition)")
        }
        if !conditionTitles.isEmpty {
            lines.append("Bệnh nền: \(conditionTitles.joined(separator: ", "))")
        }

        if !allergyOptions.isEmpty || allergyDetails.nilIfBlank != nil {
            var parts = allergyOptions.map(\.title)
            if let allergyDetails = allergyDetails.nilIfBlank {
                if parts.isEmpty {
                    parts.append(allergyDetails)
                } else {
                    parts.append("ghi chú: \(allergyDetails)")
                }
            }
            lines.append("Dị ứng: \(parts.joined(separator: ", "))")
        }

        if hasLongTermMedication {
            let medications = longTermMedications.compactMap(\.summary)
            if medications.isEmpty {
                lines.append("Thuốc đang dùng: Có dùng thuốc dài hạn")
            } else {
                lines.append("Thuốc đang dùng: \(medications.joined(separator: "; "))")
            }
        }

        if mobilityStatus != .normal {
            lines.append("Khả năng vận động: \(mobilityStatus.title)")
        }

        var deviceTitles = medicalDevices.map(\.title)
        if let otherDevice = otherMedicalDevice.nilIfBlank {
            deviceTitles.append("Khác: \(otherDevice)")
        }
        if !deviceTitles.isEmpty {
            lines.append("Thiết bị hỗ trợ: \(deviceTitles.joined(separator: ", "))")
        }

        if specialSituation.hasSelection {
            lines.append("Tình trạng đặc biệt: \(specialSituation.selectedTitles.joined(separator: ", "))")
        }

        var historyTitles = medicalHistory.map(\.title)
        if let historyDetails = medicalHistoryDetails.nilIfBlank {
            historyTitles.append("ghi chú: \(historyDetails)")
        }
        if !historyTitles.isEmpty {
            lines.append("Tiền sử chấn thương / phẫu thuật: \(historyTitles.joined(separator: ", "))")
        }

        if bloodType != .unknown {
            lines.append("Nhóm máu: \(bloodType.title)")
        }

        return lines
    }

    var searchText: String {
        let medicationText = longTermMedications.compactMap(\.summary).joined(separator: " ")
        return (
            summaryLines.joined(separator: " ") + " " +
            medicationText + " " +
            specialSituation.selectedTitles.joined(separator: " ")
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasContent: Bool {
        !summaryLines.isEmpty
    }
}

struct EmergencyRelativeProfile: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var displayName: String
    var phoneNumber: String?
    var personType: Person.PersonType
    var gender: ClothingGender?
    var relationGroup: RelationGroup
    var medicalProfile: RelativeMedicalProfile
    var medicalBaselineNote: String
    var specialNeedsNote: String
    var specialDietNote: String
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        displayName: String,
        phoneNumber: String? = nil,
        personType: Person.PersonType,
        gender: ClothingGender? = nil,
        relationGroup: RelationGroup,
        medicalProfile: RelativeMedicalProfile = RelativeMedicalProfile(),
        medicalBaselineNote: String = "",
        specialNeedsNote: String = "",
        specialDietNote: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.phoneNumber = phoneNumber?.trimmedNilIfEmpty
        self.personType = personType
        self.gender = gender
        self.relationGroup = relationGroup
        self.medicalProfile = medicalProfile
        self.medicalBaselineNote = medicalBaselineNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.specialNeedsNote = specialNeedsNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.specialDietNote = specialDietNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case phoneNumber
        case personType
        case gender
        case relationGroup
        case medicalProfile
        case medicalBaselineNote
        case specialNeedsNote
        case specialDietNote
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)?.trimmedNilIfEmpty
        personType = try container.decode(Person.PersonType.self, forKey: .personType)
        gender = try container.decodeIfPresent(ClothingGender.self, forKey: .gender)
        relationGroup = try container.decode(RelationGroup.self, forKey: .relationGroup)
        medicalProfile = try container.decodeIfPresent(RelativeMedicalProfile.self, forKey: .medicalProfile) ?? RelativeMedicalProfile()
        medicalBaselineNote = try container.decodeIfPresent(String.self, forKey: .medicalBaselineNote)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        specialNeedsNote = try container.decodeIfPresent(String.self, forKey: .specialNeedsNote)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        specialDietNote = try container.decodeIfPresent(String.self, forKey: .specialDietNote)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    var personId: String {
        "relative_\(id)"
    }

    var medicalSummaryLines: [String] {
        var lines = medicalProfile.summaryLines
        if let medicalBaselineNote = medicalBaselineNote.nilIfBlank {
            lines.append("Ghi chú y tế bổ sung: \(medicalBaselineNote)")
        }
        return lines
    }

    var storedInfoLines: [String] {
        var lines = medicalSummaryLines
        if let specialNeedsNote = specialNeedsNote.nilIfBlank {
            lines.append("Yêu cầu đặc biệt: \(specialNeedsNote)")
        }
        if let specialDietNote = specialDietNote.nilIfBlank {
            lines.append("Ăn uống: \(specialDietNote)")
        }
        return lines
    }
}

struct SelectedRelativeSnapshot: Codable, Identifiable, Equatable, Hashable {
    let profileId: String
    let personId: String
    let personType: Person.PersonType
    let personIndex: Int
    let displayName: String
    let phoneNumber: String?
    let gender: ClothingGender?
    let relationGroup: RelationGroup
    let medicalProfile: RelativeMedicalProfile
    let medicalBaselineNote: String
    let specialNeedsNote: String
    let specialDietNote: String
    let updatedAt: Date

    var id: String { personId }

    enum CodingKeys: String, CodingKey {
        case profileId
        case personId
        case personType
        case personIndex
        case displayName
        case phoneNumber
        case gender
        case relationGroup
        case medicalProfile
        case medicalBaselineNote
        case specialNeedsNote
        case specialDietNote
        case updatedAt
    }

    init(profile: EmergencyRelativeProfile, personIndex: Int) {
        self.profileId = profile.id
        self.personId = profile.personId
        self.personType = profile.personType
        self.personIndex = personIndex
        self.displayName = profile.displayName
        self.phoneNumber = profile.phoneNumber?.trimmedNilIfEmpty
        self.gender = profile.gender
        self.relationGroup = profile.relationGroup
        self.medicalProfile = profile.medicalProfile
        self.medicalBaselineNote = profile.medicalBaselineNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.specialNeedsNote = profile.specialNeedsNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.specialDietNote = profile.specialDietNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedAt = profile.updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileId = try container.decode(String.self, forKey: .profileId)
        personId = try container.decode(String.self, forKey: .personId)
        personType = try container.decode(Person.PersonType.self, forKey: .personType)
        personIndex = try container.decode(Int.self, forKey: .personIndex)
        displayName = try container.decode(String.self, forKey: .displayName)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)?.trimmedNilIfEmpty
        gender = try container.decodeIfPresent(ClothingGender.self, forKey: .gender)
        relationGroup = try container.decode(RelationGroup.self, forKey: .relationGroup)
        medicalProfile = try container.decodeIfPresent(RelativeMedicalProfile.self, forKey: .medicalProfile) ?? RelativeMedicalProfile()
        medicalBaselineNote = try container.decodeIfPresent(String.self, forKey: .medicalBaselineNote)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        specialNeedsNote = try container.decodeIfPresent(String.self, forKey: .specialNeedsNote)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        specialDietNote = try container.decodeIfPresent(String.self, forKey: .specialDietNote)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    var medicalSummaryLines: [String] {
        var lines = medicalProfile.summaryLines
        if let medicalBaselineNote = medicalBaselineNote.nilIfBlank {
            lines.append("Ghi chú y tế bổ sung: \(medicalBaselineNote)")
        }
        return lines
    }

    var storedInfoLines: [String] {
        var lines = medicalSummaryLines
        if let specialNeedsNote = specialNeedsNote.nilIfBlank {
            lines.append("Yêu cầu đặc biệt: \(specialNeedsNote)")
        }
        if let specialDietNote = specialDietNote.nilIfBlank {
            lines.append("Ăn uống: \(specialDietNote)")
        }
        return lines
    }
}

enum SOSPersonSourceMode: String, Codable {
    case manual = "MANUAL"
    case savedProfiles = "SAVED_PROFILES"
    case mixed = "MIXED"
}

@MainActor
final class RelativeProfileStore: ObservableObject {
    static let shared = RelativeProfileStore()

    @Published private(set) var profiles: [EmergencyRelativeProfile] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var isServerSyncEnabled = false

    var canSyncToServer: Bool {
        currentUserId() != nil && AuthSessionStore.shared.session?.accessToken.nilIfBlank != nil
    }

    private let userDefaults: UserDefaults
    private let activeUserIdProvider: () -> String?
    private var sessionObserver: AnyCancellable?
    private var syncTask: Task<Void, Never>?
    private var remoteProfilesById: [String: EmergencyRelativeProfile] = [:]
    private var hasLoadedRemoteSnapshot = false
    private var activeSyncOperations = 0

    init(
        userDefaults: UserDefaults = .standard,
        activeUserIdProvider: (() -> String?)? = nil,
        sessionPublisher: AnyPublisher<AuthSession?, Never>? = nil
    ) {
        self.userDefaults = userDefaults
        self.activeUserIdProvider = activeUserIdProvider ?? {
            AuthSessionStore.shared.session?.userId
        }

        reloadCurrentUser()
        let resolvedSessionPublisher = sessionPublisher ?? AuthSessionStore.shared.$session.eraseToAnyPublisher()
        sessionObserver = resolvedSessionPublisher.sink { [weak self] _ in
            self?.reloadCurrentUser()
        }
    }

    func reloadCurrentUser() {
        syncTask?.cancel()
        remoteProfilesById = [:]
        hasLoadedRemoteSnapshot = false
        activeSyncOperations = 0
        isSyncing = false

        guard let userId = currentUserId(),
              !userId.isEmpty else {
            profiles = []
            isServerSyncEnabled = false
            return
        }

        isServerSyncEnabled = loadServerSyncPreference(for: userId)
        profiles = loadLocalProfiles(for: userId)

        if isServerSyncEnabled {
            scheduleServerBootstrap(for: userId)
        }
    }

    func filteredProfiles(
        searchText: String = "",
        relationGroup: RelationGroup? = nil
    ) -> [EmergencyRelativeProfile] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return profiles.filter { profile in
            let matchesGroup = relationGroup == nil || profile.relationGroup == relationGroup

            let matchesSearch: Bool
            if trimmedSearch.isEmpty {
                matchesSearch = true
            } else {
                let haystacks = [
                    profile.displayName,
                    profile.phoneNumber ?? "",
                    profile.gender?.title ?? "",
                    profile.relationGroup.title,
                    profile.medicalProfile.searchText,
                    profile.storedInfoLines.joined(separator: " ")
                ]
                matchesSearch = haystacks.contains {
                    $0.localizedCaseInsensitiveContains(trimmedSearch)
                }
            }

            return matchesGroup && matchesSearch
        }
    }

    func profile(withId id: String) -> EmergencyRelativeProfile? {
        profiles.first(where: { $0.id == id })
    }

    func save(profile: EmergencyRelativeProfile) {
        var normalized = profile
        let normalizedPhoneNumber = normalized.phoneNumber
            .flatMap(VietnamPhoneNumber.editableInput)
            .flatMap { digits in
                digits.isEmpty ? nil : VietnamPhoneNumber.normalizedE164(digits)
            }
        normalized = EmergencyRelativeProfile(
            id: normalized.id,
            displayName: normalized.displayName,
            phoneNumber: normalizedPhoneNumber,
            personType: normalized.personType,
            gender: normalized.gender,
            relationGroup: normalized.relationGroup,
            medicalProfile: normalized.medicalProfile,
            medicalBaselineNote: normalized.medicalBaselineNote,
            specialNeedsNote: normalized.specialNeedsNote,
            specialDietNote: normalized.specialDietNote,
            updatedAt: Date()
        )

        if let index = profiles.firstIndex(where: { $0.id == normalized.id }) {
            profiles[index] = normalized
        } else {
            profiles.append(normalized)
        }

        profiles = sortProfiles(profiles)
        persist()

        if isServerSyncEnabled {
            scheduleRemoteFlushForCurrentUser()
        }
    }

    func delete(profileId: String) {
        profiles.removeAll { $0.id == profileId }
        persist()

        if isServerSyncEnabled {
            scheduleRemoteFlushForCurrentUser()
        }
    }

    func setServerSyncEnabled(_ enabled: Bool) {
        guard let userId = currentUserId(),
              !userId.isEmpty else {
            isServerSyncEnabled = false
            return
        }

        guard isServerSyncEnabled != enabled else { return }

        persistServerSyncPreference(enabled, for: userId)
        isServerSyncEnabled = enabled
        syncTask?.cancel()

        if enabled {
            scheduleServerBootstrap(for: userId)
            return
        }

        remoteProfilesById = [:]
        hasLoadedRemoteSnapshot = false
    }

    func clearServerDataFromCurrentUser() {
        guard let userId = currentUserId(),
              !userId.isEmpty,
              isServerSyncEnabled == false,
              canSyncToServer else {
            return
        }

        syncTask?.cancel()
        syncTask = Task { [weak self] in
            await self?.purgeServerProfiles(for: userId)
        }
    }

    func refreshFromServerIfPossible(force: Bool = false) {
        guard let userId = currentUserId(),
              !userId.isEmpty,
              isServerSyncEnabled,
              canSyncToServer,
              isSyncing == false else {
            return
        }

        guard force || hasLoadedRemoteSnapshot == false || profiles.isEmpty else {
            return
        }

        scheduleServerBootstrap(for: userId)
    }

    private func persist() {
        guard let userId = currentUserId(),
              !userId.isEmpty else {
            profiles = []
            return
        }

        persist(profiles, for: userId)
    }

    private func currentUserId() -> String? {
        activeUserIdProvider()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfBlank
    }

    private func loadLocalProfiles(for userId: String) -> [EmergencyRelativeProfile] {
        guard let data = userDefaults.data(forKey: storageKey(for: userId)) else {
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([EmergencyRelativeProfile].self, from: data)
            return sortProfiles(decoded)
        } catch {
            print("❌ Failed to load relative profiles: \(error)")
            return []
        }
    }

    private func persist(_ profiles: [EmergencyRelativeProfile], for userId: String) {
        do {
            let data = try JSONEncoder().encode(profiles)
            userDefaults.set(data, forKey: storageKey(for: userId))
        } catch {
            print("❌ Failed to persist relative profiles: \(error)")
        }
    }

    private func loadServerSyncPreference(for userId: String) -> Bool {
        userDefaults.object(forKey: serverSyncPreferenceKey(for: userId)) as? Bool ?? false
    }

    private func persistServerSyncPreference(_ enabled: Bool, for userId: String) {
        userDefaults.set(enabled, forKey: serverSyncPreferenceKey(for: userId))
    }

    private func scheduleServerBootstrap(for userId: String) {
        guard isServerSyncEnabled, canSyncToServer else { return }

        let localSnapshot = sortProfiles(profiles)

        syncTask?.cancel()
        syncTask = Task { [weak self] in
            await self?.bootstrapServerSync(for: userId, localSnapshot: localSnapshot)
        }
    }

    private func scheduleRemoteFlushForCurrentUser() {
        guard let userId = currentUserId(),
              isServerSyncEnabled,
              canSyncToServer else {
            return
        }

        let localSnapshot = sortProfiles(profiles)

        syncTask?.cancel()
        syncTask = Task { [weak self] in
            await self?.flushLocalChangesToServer(for: userId, localSnapshot: localSnapshot)
        }
    }

    private func bootstrapServerSync(
        for userId: String,
        localSnapshot: [EmergencyRelativeProfile]
    ) async {
        beginSync()
        defer { endSync() }

        do {
            guard currentUserId() == userId,
                  isServerSyncEnabled,
                  canSyncToServer else {
                return
            }

            let remoteProfiles = try await RelativeProfileAPIService.shared.fetchRelativeProfiles()
            guard currentUserId() == userId,
                  isServerSyncEnabled,
                  Task.isCancelled == false else {
                return
            }

            let sortedRemoteProfiles = sortProfiles(remoteProfiles)
            hasLoadedRemoteSnapshot = true
            remoteProfilesById = dictionary(from: sortedRemoteProfiles)

            let mergedProfiles = mergeProfiles(local: localSnapshot, remote: sortedRemoteProfiles)
            if profilesEqual(mergedProfiles, profiles) == false {
                profiles = mergedProfiles
                persist(mergedProfiles, for: userId)
            }

            guard profilesEqual(mergedProfiles, sortedRemoteProfiles) == false else { return }

            try await fallbackToFullSync(for: userId, localSnapshot: mergedProfiles)
        } catch RelativeProfileAPIError.notAuthenticated {
            return
        } catch is CancellationError {
            return
        } catch {
            print("❌ Failed to sync relative profiles: \(error.localizedDescription)")
        }
    }

    private func flushLocalChangesToServer(
        for userId: String,
        localSnapshot: [EmergencyRelativeProfile]
    ) async {
        beginSync()
        defer { endSync() }

        do {
            guard currentUserId() == userId,
                  isServerSyncEnabled,
                  canSyncToServer else {
                return
            }

            if hasLoadedRemoteSnapshot == false {
                await bootstrapServerSync(for: userId, localSnapshot: localSnapshot)
                return
            }

            let localById = dictionary(from: localSnapshot)
            var remoteById = remoteProfilesById

            let deletedIds = remoteById.keys
                .filter { localById[$0] == nil }
                .sorted()

            for id in deletedIds {
                try Task.checkCancellation()
                do {
                    try await RelativeProfileAPIService.shared.deleteRelativeProfile(id: id)
                } catch let error as RelativeProfileAPIError where error.statusCode == 404 {
                    // Hồ sơ đã bị xoá trên server trước đó, coi như đã đồng bộ.
                }
                remoteById.removeValue(forKey: id)
            }

            let createdIds = localById.keys
                .filter { remoteById[$0] == nil }
                .sorted()

            for id in createdIds {
                guard let profile = localById[id] else { continue }
                try Task.checkCancellation()
                let createdProfile = try await RelativeProfileAPIService.shared.createRelativeProfile(profile)
                remoteById[canonicalProfileId(createdProfile.id)] = createdProfile
            }

            let updatedIds = localById.keys
                .filter { remoteById[$0] != nil }
                .sorted()

            for id in updatedIds {
                guard let localProfile = localById[id],
                      let remoteProfile = remoteById[id],
                      profilesEqual([localProfile], [remoteProfile]) == false else {
                    continue
                }

                try Task.checkCancellation()
                let updatedProfile = try await RelativeProfileAPIService.shared.updateRelativeProfile(localProfile)
                remoteById[canonicalProfileId(updatedProfile.id)] = updatedProfile
            }

            guard currentUserId() == userId,
                  isServerSyncEnabled,
                  Task.isCancelled == false else {
                return
            }

            applyRemoteSnapshot(Array(remoteById.values), for: userId)
        } catch RelativeProfileAPIError.notAuthenticated {
            return
        } catch is CancellationError {
            return
        } catch let error as RelativeProfileAPIError where shouldFallbackToFullSync(for: error) {
            do {
                try await fallbackToFullSync(for: userId, localSnapshot: localSnapshot)
            } catch RelativeProfileAPIError.notAuthenticated {
                return
            } catch is CancellationError {
                return
            } catch {
                print("❌ Failed to sync relative profiles: \(error.localizedDescription)")
            }
        } catch {
            print("❌ Failed to sync relative profiles: \(error.localizedDescription)")
        }
    }

    private func fallbackToFullSync(
        for userId: String,
        localSnapshot: [EmergencyRelativeProfile]
    ) async throws {
        let reconciledProfiles = try await RelativeProfileAPIService.shared.syncRelativeProfiles(localSnapshot)
        guard currentUserId() == userId,
              isServerSyncEnabled,
              Task.isCancelled == false else {
            return
        }

        applyRemoteSnapshot(reconciledProfiles, for: userId)
    }

    private func purgeServerProfiles(for userId: String) async {
        beginSync()
        defer { endSync() }

        do {
            guard currentUserId() == userId,
                  isServerSyncEnabled == false,
                  canSyncToServer else {
                return
            }

            try await RelativeProfileAPIService.shared.clearRelativeProfilesFromServer()
            guard currentUserId() == userId,
                  isServerSyncEnabled == false,
                  Task.isCancelled == false else {
                return
            }

            remoteProfilesById = [:]
            hasLoadedRemoteSnapshot = false
        } catch RelativeProfileAPIError.notAuthenticated {
            return
        } catch is CancellationError {
            return
        } catch {
            print("❌ Failed to remove relative profiles from server: \(error.localizedDescription)")
        }
    }

    private func mergeProfiles(
        local: [EmergencyRelativeProfile],
        remote: [EmergencyRelativeProfile]
    ) -> [EmergencyRelativeProfile] {
        var mergedById: [String: EmergencyRelativeProfile] = [:]

        for profile in remote {
            mergedById[canonicalProfileId(profile.id)] = profile
        }

        for profile in local {
            let canonicalId = canonicalProfileId(profile.id)
            if let existing = mergedById[canonicalId] {
                mergedById[canonicalId] = profile.updatedAt >= existing.updatedAt ? profile : existing
            } else {
                mergedById[canonicalId] = profile
            }
        }

        return sortProfiles(Array(mergedById.values))
    }

    private func profilesEqual(_ lhs: [EmergencyRelativeProfile], _ rhs: [EmergencyRelativeProfile]) -> Bool {
        canonicalizedForComparison(lhs) == canonicalizedForComparison(rhs)
    }

    private func canonicalizedForComparison(_ profiles: [EmergencyRelativeProfile]) -> [EmergencyRelativeProfile] {
        sortProfiles(
            profiles.map { profile in
                EmergencyRelativeProfile(
                    id: canonicalProfileId(profile.id),
                    displayName: profile.displayName,
                    phoneNumber: profile.phoneNumber,
                    personType: profile.personType,
                    gender: profile.gender,
                    relationGroup: profile.relationGroup,
                    medicalProfile: profile.medicalProfile,
                    medicalBaselineNote: profile.medicalBaselineNote,
                    specialNeedsNote: profile.specialNeedsNote,
                    specialDietNote: profile.specialDietNote,
                    updatedAt: profile.updatedAt
                )
            }
        )
    }

    private func canonicalProfileId(_ id: String) -> String {
        UUID(uuidString: id)?.uuidString ?? id
    }

    private func dictionary(from profiles: [EmergencyRelativeProfile]) -> [String: EmergencyRelativeProfile] {
        var result: [String: EmergencyRelativeProfile] = [:]

        for profile in profiles {
            result[canonicalProfileId(profile.id)] = profile
        }

        return result
    }

    private func applyRemoteSnapshot(_ remoteProfiles: [EmergencyRelativeProfile], for userId: String) {
        let sortedProfiles = sortProfiles(remoteProfiles)
        remoteProfilesById = dictionary(from: sortedProfiles)
        hasLoadedRemoteSnapshot = true

        guard currentUserId() == userId else { return }

        profiles = sortedProfiles
        persist(sortedProfiles, for: userId)
    }

    private func shouldFallbackToFullSync(for error: RelativeProfileAPIError) -> Bool {
        guard let statusCode = error.statusCode else {
            return false
        }

        return [400, 404, 409].contains(statusCode)
    }

    private func beginSync() {
        activeSyncOperations += 1
        isSyncing = activeSyncOperations > 0
    }

    private func endSync() {
        activeSyncOperations = max(0, activeSyncOperations - 1)
        isSyncing = activeSyncOperations > 0
    }

    private func storageKey(for userId: String) -> String {
        "saved_relative_profiles_\(userId)"
    }

    private func serverSyncPreferenceKey(for userId: String) -> String {
        "saved_relative_profiles_sync_enabled_\(userId)"
    }

    private func sortProfiles(_ profiles: [EmergencyRelativeProfile]) -> [EmergencyRelativeProfile] {
        profiles.sorted { lhs, rhs in
            let nameOrder = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            if nameOrder == .orderedSame {
                return lhs.updatedAt > rhs.updatedAt
            }
            return nameOrder == .orderedAscending
        }
    }
}

private func normalizeSelection<Option: CaseIterable & Hashable>(_ values: [Option]) -> [Option]
where Option.AllCases: Collection {
    let selected = Set(values)
    return Array(Option.allCases).filter { selected.contains($0) }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmedNilIfEmpty: String? {
        nilIfBlank
    }
}

private extension Optional where Wrapped == String {
    var trimmedNilIfEmpty: String? {
        switch self {
        case .some(let value):
            return value.trimmedNilIfEmpty
        case .none:
            return nil
        }
    }

    var nilIfBlank: String? {
        switch self {
        case .some(let value):
            return value.nilIfBlank
        case .none:
            return nil
        }
    }
}

private extension RelativeProfileAPIError {
    var statusCode: Int? {
        switch self {
        case .httpError(let code, _):
            return code
        default:
            return nil
        }
    }
}
