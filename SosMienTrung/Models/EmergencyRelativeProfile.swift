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
        if isSenior { titles.append("Người già (>65)") }
        if isYoungChild { titles.append("Trẻ nhỏ (<6)") }
        if hasDisability { titles.append("Người khuyết tật") }
        return titles
    }

    var hasSelection: Bool {
        isPregnant || isSenior || isYoungChild || hasDisability
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
    var tags: [String]
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
        tags: [String] = [],
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
        self.tags = Self.normalizeTags(tags)
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
        case tags
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
        tags = Self.normalizeTags(try container.decodeIfPresent([String].self, forKey: .tags) ?? [])
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

    static func normalizeTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []

        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let lowercased = trimmed.lowercased()
            guard !seen.contains(lowercased) else { continue }

            seen.insert(lowercased)
            normalized.append(trimmed)
        }

        return normalized.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
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
    let tags: [String]
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
        case tags
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
        self.tags = EmergencyRelativeProfile.normalizeTags(profile.tags)
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
        tags = EmergencyRelativeProfile.normalizeTags(try container.decodeIfPresent([String].self, forKey: .tags) ?? [])
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

    private let userDefaults: UserDefaults
    private let activeUserIdProvider: () -> String?
    private var sessionObserver: AnyCancellable?

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

    var availableTags: [String] {
        EmergencyRelativeProfile.normalizeTags(
            profiles.flatMap(\.tags)
        )
    }

    func reloadCurrentUser() {
        guard let userId = activeUserIdProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !userId.isEmpty else {
            profiles = []
            return
        }

        guard let data = userDefaults.data(forKey: storageKey(for: userId)) else {
            profiles = []
            return
        }

        do {
            let decoded = try JSONDecoder().decode([EmergencyRelativeProfile].self, from: data)
            profiles = sortProfiles(decoded)
        } catch {
            print("❌ Failed to load relative profiles: \(error)")
            profiles = []
        }
    }

    func filteredProfiles(
        searchText: String = "",
        relationGroup: RelationGroup? = nil,
        tag: String? = nil
    ) -> [EmergencyRelativeProfile] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines)

        return profiles.filter { profile in
            let matchesGroup = relationGroup == nil || profile.relationGroup == relationGroup
            let matchesTag = trimmedTag == nil || profile.tags.contains {
                $0.localizedCaseInsensitiveCompare(trimmedTag ?? "") == .orderedSame
            }

            let matchesSearch: Bool
            if trimmedSearch.isEmpty {
                matchesSearch = true
            } else {
                let haystacks = [
                    profile.displayName,
                    profile.phoneNumber ?? "",
                    profile.gender?.title ?? "",
                    profile.relationGroup.title,
                    profile.tags.joined(separator: " "),
                    profile.medicalProfile.searchText,
                    profile.storedInfoLines.joined(separator: " ")
                ]
                matchesSearch = haystacks.contains {
                    $0.localizedCaseInsensitiveContains(trimmedSearch)
                }
            }

            return matchesGroup && matchesTag && matchesSearch
        }
    }

    func profile(withId id: String) -> EmergencyRelativeProfile? {
        profiles.first(where: { $0.id == id })
    }

    func save(profile: EmergencyRelativeProfile) {
        var normalized = profile
        normalized = EmergencyRelativeProfile(
            id: normalized.id,
            displayName: normalized.displayName,
            phoneNumber: normalized.phoneNumber,
            personType: normalized.personType,
            gender: normalized.gender,
            relationGroup: normalized.relationGroup,
            tags: normalized.tags,
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
    }

    func delete(profileId: String) {
        profiles.removeAll { $0.id == profileId }
        persist()
    }

    private func persist() {
        guard let userId = activeUserIdProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !userId.isEmpty else {
            profiles = []
            return
        }

        do {
            let data = try JSONEncoder().encode(profiles)
            userDefaults.set(data, forKey: storageKey(for: userId))
        } catch {
            print("❌ Failed to persist relative profiles: \(error)")
        }
    }

    private func storageKey(for userId: String) -> String {
        "saved_relative_profiles_\(userId)"
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
}
