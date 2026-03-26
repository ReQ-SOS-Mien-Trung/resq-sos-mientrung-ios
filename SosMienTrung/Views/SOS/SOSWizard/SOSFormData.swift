//
//  SOSFormData.swift
//  SosMienTrung
//
//  Data models cho SOS Wizard Form
//

import Foundation
import Combine
import CoreLocation
import SwiftUI

// MARK: - Priority Level

/// Mức ưu tiên P1–P4 theo triage rule
enum PriorityLevel: String, Codable {
    case p1 = "P1"
    case p2 = "P2"
    case p3 = "P3"
    case p4 = "P4"
    
    var title: String {
        switch self {
        case .p1: return "P1 – Nguy kịch"
        case .p2: return "P2 – Cao"
        case .p3: return "P3 – Trung bình"
        case .p4: return "P4 – Thấp"
        }
    }
    
    var color: Color {
        switch self {
        case .p1: return .red
        case .p2: return .orange
        case .p3: return .yellow
        case .p4: return .green
        }
    }
}

// MARK: - Enums

/// Loại SOS chính
enum SOSType: String, Codable, CaseIterable {
    case rescue = "RESCUE"      // Cứu hộ - giải cứu, y tế, di chuyển khẩn cấp
    case relief = "RELIEF"      // Cứu trợ - nhu yếu phẩm, hỗ trợ sinh hoạt
    
    var title: String {
        switch self {
        case .rescue: return "CỨU HỘ"
        case .relief: return "CỨU TRỢ"
        }
    }
    
    var subtitle: String {
        switch self {
        case .rescue: return "Giải cứu – Cấp cứu – Y tế – Di chuyển khẩn cấp"
        case .relief: return "Nhu yếu phẩm – Hỗ trợ sinh hoạt"
        }
    }
    
    var icon: String {
        switch self {
        case .rescue: return "🚨"
        case .relief: return "🎒"
        }
    }
    
    var color: String {
        switch self {
        case .rescue: return "red"
        case .relief: return "yellow"
        }
    }
}

/// Nhu yếu phẩm cần thiết (Cứu trợ)
enum SupplyNeed: String, Codable, CaseIterable, Identifiable {
    case water = "WATER"
    case food = "FOOD"
    case clothes = "CLOTHES"
    case blanket = "BLANKET"
    case medicine = "MEDICINE"
    case other = "OTHER"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .water: return "Nước uống"
        case .food: return "Thực phẩm"
        case .clothes: return "Quần áo"
        case .blanket: return "Chăn / Giữ ấm"
        case .medicine: return "Y tế"
        case .other: return "Khác"
        }
    }
    
    var icon: String {
        switch self {
        case .water: return "💧"
        case .food: return "🍚"
        case .clothes: return "👕"
        case .blanket: return "🛏️"
        case .medicine: return "💊"
        case .other: return "📦"
        }
    }
}

// MARK: - Relief Follow-up Enums

/// Thời gian nước uống có thể duy trì
enum WaterDuration: String, Codable, CaseIterable, Identifiable {
    case under6h = "UNDER_6H"
    case from6to12h = "6_TO_12H"
    case from12to24h = "12_TO_24H"
    case from1to2days = "1_TO_2_DAYS"
    case over2days = "OVER_2_DAYS"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .under6h: return "Dưới 6 giờ"
        case .from6to12h: return "6 – 12 giờ"
        case .from12to24h: return "12 – 24 giờ"
        case .from1to2days: return "1 – 2 ngày"
        case .over2days: return "Trên 2 ngày"
        }
    }
}

/// Lượng nước uống còn lại
enum WaterRemaining: String, Codable, CaseIterable, Identifiable {
    case none = "NONE"
    case under2L = "UNDER_2L"
    case from2to5L = "2_TO_5L"
    case over5L = "OVER_5L"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .none: return "Không còn"
        case .under2L: return "< 2 lít"
        case .from2to5L: return "2 – 5 lít"
        case .over5L: return "> 5 lít"
        }
    }
}

/// Thời gian thực phẩm có thể duy trì
enum FoodDuration: String, Codable, CaseIterable, Identifiable {
    case under12h = "UNDER_12H"
    case from12to24h = "12_TO_24H"
    case from1to2days = "1_TO_2_DAYS"
    case from2to3days = "2_TO_3_DAYS"
    case over3days = "OVER_3_DAYS"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .under12h: return "Dưới 12 giờ"
        case .from12to24h: return "12 – 24 giờ"
        case .from1to2days: return "1 – 2 ngày"
        case .from2to3days: return "2 – 3 ngày"
        case .over3days: return "Trên 3 ngày"
        }
    }
}

/// Nhu cầu chế độ ăn đặc biệt
enum SpecialDietNeed: String, Codable, CaseIterable, Identifiable {
    case none = "NONE"
    case children = "CHILDREN"
    case elderly = "ELDERLY"
    case both = "BOTH"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .none: return "Không"
        case .children: return "Trẻ em"
        case .elderly: return "Người già"
        case .both: return "Cả hai"
        }
    }
}

/// Loại tình trạng y tế cần thuốc
enum MedicineCondition: String, Codable, CaseIterable, Identifiable {
    case highFever = "HIGH_FEVER"
    case chronicDisease = "CHRONIC_DISEASE"
    case injured = "INJURED"
    case other = "OTHER"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .highFever: return "Sốt cao"
        case .chronicDisease: return "Bệnh mãn tính"
        case .injured: return "Bị thương"
        case .other: return "Khác"
        }
    }
}

/// Tình trạng chăn / giữ ấm
enum BlanketAvailability: String, Codable, CaseIterable, Identifiable {
    case none = "NONE"
    case notEnough = "NOT_ENOUGH"
    case enough = "ENOUGH"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .none: return "Không có"
        case .notEnough: return "Có nhưng không đủ"
        case .enough: return "Có đủ"
        }
    }
}

/// Tình trạng quần áo
enum ClothingStatus: String, Codable, CaseIterable, Identifiable {
    case completelyLacking = "COMPLETELY_LACKING"
    case partiallyLacking = "PARTIALLY_LACKING"
    case sufficient = "SUFFICIENT"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .completelyLacking: return "Thiếu hoàn toàn"
        case .partiallyLacking: return "Thiếu một phần"
        case .sufficient: return "Đủ"
        }
    }
}

enum MedicalSupportNeed: String, Codable, CaseIterable, Identifiable {
    case commonMedicine = "COMMON_MEDICINE"
    case firstAid = "FIRST_AID"
    case chronicMaintenance = "CHRONIC_MAINTENANCE"
    case minorInjury = "MINOR_INJURY"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commonMedicine:
            return "Thuốc thông dụng (hạ sốt, đau đầu, tiêu hóa...)"
        case .firstAid:
            return "Vật tư sơ cứu (băng gạc, oxy già, thuốc đỏ...)"
        case .chronicMaintenance:
            return "Người có bệnh nền cần thuốc duy trì"
        case .minorInjury:
            return "Người bị thương nhẹ (cần xử lý tại chỗ)"
        }
    }
}

enum ClothingGender: String, Codable, CaseIterable, Identifiable {
    case male = "MALE"
    case female = "FEMALE"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: return "Nam"
        case .female: return "Nữ"
        }
    }
}

/// Tình trạng hiện tại (Cứu hộ)
enum RescueSituation: String, Codable, CaseIterable, Identifiable {
    case trapped = "TRAPPED"
    case collapsed = "COLLAPSED"
    case dangerZone = "DANGER_ZONE"
    case cannotMove = "CANNOT_MOVE"
    case flooding = "FLOODING"
    case other = "OTHER"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .trapped: return "Bị mắc kẹt"
        case .collapsed: return "Nhà sập"
        case .dangerZone: return "Kẹt trong khu vực nguy hiểm"
        case .cannotMove: return "Không thể di chuyển"
        case .flooding: return "Nước dâng cao"
        case .other: return "Khác"
        }
    }
    
    var icon: String {
        switch self {
        case .trapped: return "🚧"
        case .collapsed: return "🏚️"
        case .dangerZone: return "⚠️"
        case .cannotMove: return "🦽"
        case .flooding: return "🌊"
        case .other: return "❓"
        }
    }
    
    /// Hệ số nhân tình huống (dùng cho priority)
    var situationMultiplier: Double {
        switch self {
        case .flooding: return 1.5
        case .collapsed: return 1.5
        case .trapped: return 1.3
        case .dangerZone: return 1.3
        case .cannotMove: return 1.2
        case .other: return 1.0
        }
    }
    
    /// Situation Severe Flag
    var isSevere: Bool {
        switch self {
        case .flooding, .collapsed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Nhóm vấn đề y tế

enum MedicalIssueCategory: String, CaseIterable, Identifiable {
    case injury = "INJURY"
    case danger = "DANGER"
    case special = "SPECIAL"
    case other = "OTHER"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .injury: return "Chấn thương"
        case .danger: return "Tình trạng nguy hiểm"
        case .special: return "Tình trạng đặc thù"
        case .other: return "Khác"
        }
    }
}

/// Vấn đề y tế — phân loại theo độ tuổi
enum MedicalIssue: String, Codable, CaseIterable, Identifiable {
    // --- Chấn thương (chung) ---
    case bleeding          = "BLEEDING"
    case severelyBleeding  = "SEVERELY_BLEEDING"
    case fracture          = "FRACTURE"
    case headInjury        = "HEAD_INJURY"
    case burns             = "BURNS"
    
    // --- Tình trạng nguy hiểm (chung) ---
    case unconscious       = "UNCONSCIOUS"
    case breathingDifficulty = "BREATHING_DIFFICULTY"
    case chestPainStroke   = "CHEST_PAIN_STROKE"
    case cannotMove        = "CANNOT_MOVE"
    case drowning          = "DROWNING"
    
    // --- Trẻ em đặc thù ---
    case highFever         = "HIGH_FEVER"
    case dehydration       = "DEHYDRATION"
    case infantNeedsMilk   = "INFANT_NEEDS_MILK"
    case lostParent        = "LOST_PARENT"
    
    // --- Người già đặc thù ---
    case chronicDisease    = "CHRONIC_DISEASE"
    case confusion         = "CONFUSION"
    case needsMedicalDevice = "NEEDS_MEDICAL_DEVICE"
    
    // --- Khác ---
    case other             = "OTHER"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .bleeding:            return "Chảy máu"
        case .severelyBleeding:    return "Chảy máu nặng"
        case .fracture:            return "Gãy xương"
        case .headInjury:          return "Chấn thương đầu"
        case .burns:               return "Bỏng"
        case .unconscious:         return "Bất tỉnh"
        case .breathingDifficulty: return "Khó thở"
        case .chestPainStroke:     return "Đau ngực / nghi đột quỵ"
        case .cannotMove:          return "Không thể di chuyển"
        case .drowning:            return "Đuối nước"
        case .highFever:           return "Sốt cao"
        case .dehydration:         return "Mất nước"
        case .infantNeedsMilk:     return "Trẻ sơ sinh cần sữa"
        case .lostParent:          return "Lạc cha mẹ"
        case .chronicDisease:      return "Cần thuốc bệnh nền"
        case .confusion:           return "Lú lẫn / mất phương hướng"
        case .needsMedicalDevice:  return "Cần thiết bị y tế"
        case .other:               return "Khác"
        }
    }
    
    var icon: String {
        switch self {
        case .bleeding:            return "🩸"
        case .severelyBleeding:    return "🩸"
        case .fracture:            return "🦴"
        case .headInjury:          return "🤕"
        case .burns:               return "🔥"
        case .unconscious:         return "😵"
        case .breathingDifficulty: return "😮‍💨"
        case .chestPainStroke:     return "💔"
        case .cannotMove:          return "🚶"
        case .drowning:            return "🌊"
        case .highFever:           return "🤒"
        case .dehydration:         return "💧"
        case .infantNeedsMilk:     return "🍼"
        case .lostParent:          return "🧸"
        case .chronicDisease:      return "💊"
        case .confusion:           return "🧠"
        case .needsMedicalDevice:  return "🩺"
        case .other:               return "🏥"
        }
    }
    
    /// Trọng số (dùng cho priority score)
    var severity: Int {
        switch self {
        case .unconscious:          return 5
        case .breathingDifficulty:  return 5
        case .chestPainStroke:      return 5
        case .drowning:             return 5
        case .severelyBleeding:     return 4
        case .bleeding:             return 4
        case .burns:                return 4
        case .headInjury:           return 4
        case .cannotMove:           return 4
        case .highFever:            return 3
        case .dehydration:          return 3
        case .fracture:             return 3
        case .infantNeedsMilk:      return 3
        case .lostParent:           return 3
        case .chronicDisease:       return 2
        case .confusion:            return 2
        case .needsMedicalDevice:   return 2
        case .other:                return 1
        }
    }
    
    /// Medical Severe Flag: issue có severity >= 4 (SEVERE)
    var isSevere: Bool {
        switch self {
        case .unconscious, .drowning, .breathingDifficulty,
             .chestPainStroke, .severelyBleeding:
            return true
        default:
            return false
        }
    }
    
    /// Nhóm (category) của issue
    var category: MedicalIssueCategory {
        switch self {
        case .bleeding, .severelyBleeding, .fracture, .headInjury, .burns:
            return .injury
        case .unconscious, .breathingDifficulty, .chestPainStroke, .cannotMove, .drowning:
            return .danger
        case .highFever, .dehydration, .infantNeedsMilk, .lostParent,
             .chronicDisease, .confusion, .needsMedicalDevice:
            return .special
        case .other:
            return .other
        }
    }
    
    // MARK: Issues theo loại người
    
    /// Trả về danh sách issue phù hợp theo PersonType, gom theo category
    static func groupedIssues(for personType: Person.PersonType) -> [(category: MedicalIssueCategory, issues: [MedicalIssue])] {
        let flat = issuesForPersonType(personType)
        // Giữ thứ tự category: injury → danger → special → other
        var result: [(category: MedicalIssueCategory, issues: [MedicalIssue])] = []
        for cat in MedicalIssueCategory.allCases {
            let matching = flat.filter { $0.category == cat }
            if !matching.isEmpty {
                result.append((category: cat, issues: matching))
            }
        }
        return result
    }
    
    /// Danh sách phẳng issue cho mỗi PersonType
    static func issuesForPersonType(_ type: Person.PersonType) -> [MedicalIssue] {
        switch type {
        case .adult:
            return [
                // Chấn thương
                .severelyBleeding, .fracture, .headInjury,
                // Nguy hiểm
                .unconscious, .breathingDifficulty, .chestPainStroke, .cannotMove, .drowning,
                // Khác
                .chronicDisease, .other
            ]
        case .child:
            return [
                // Chấn thương
                .bleeding, .fracture,
                // Nguy hiểm
                .unconscious, .breathingDifficulty, .highFever, .dehydration, .drowning,
                // Đặc thù
                .infantNeedsMilk, .lostParent,
                // Khác
                .other
            ]
        case .elderly:
            return [
                // Chấn thương
                .fracture, .bleeding, .burns,
                // Nguy hiểm
                .unconscious, .breathingDifficulty, .chestPainStroke, .cannotMove, .drowning,
                // Đặc thù
                .chronicDisease, .confusion, .needsMedicalDevice,
                // Khác
                .other
            ]
        }
    }
}

// MARK: - Data Models

/// Thông tin số người
struct PeopleCount: Codable, Equatable {
    var adults: Int = 1        // Người lớn (15-60)
    var children: Int = 0      // Trẻ em (< 15 tuổi)
    var elderly: Int = 0       // Người già (> 60 tuổi)
    
    var total: Int {
        adults + children + elderly
    }
    
}

/// Đại diện cho một người trong nhóm cần cứu hộ
struct Person: Codable, Equatable, Identifiable, Hashable {
    let id: String
    let type: PersonType
    let index: Int
    var customName: String = ""
    
    var displayName: String {
        customName.isEmpty ? "\(type.title) \(index)" : customName
    }
    
    enum PersonType: String, Codable {
        case adult = "ADULT"
        case child = "CHILD"
        case elderly = "ELDERLY"
        
        var title: String {
            switch self {
            case .adult: return "Người lớn"
            case .child: return "Trẻ em"
            case .elderly: return "Người già"
            }
        }
        
        var icon: String {
            switch self {
            case .adult: return "🧑"
            case .child: return "👶"
            case .elderly: return "👴"
            }
        }
        
        /// Trọng số theo độ tuổi (dùng cho priority)
        var ageWeight: Double {
            switch self {
            case .adult: return 1.0
            case .child: return 1.4
            case .elderly: return 1.3
            }
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Thông tin y tế của một người bị thương
struct PersonMedicalInfo: Codable, Equatable, Identifiable {
    let personId: String
    var medicalIssues: Set<MedicalIssue> = []
    var otherDescription: String = ""
    
    var id: String { personId }
    
    /// Tổng trọng số các vấn đề y tế
    var issueWeightSum: Int {
        medicalIssues.reduce(0) { $0 + $1.severity }
    }
}

struct PersonSpecialDietInfo: Codable, Equatable, Identifiable {
    let personId: String
    var dietDescription: String = ""

    var id: String { personId }
}

struct ClothingPersonInfo: Codable, Equatable, Identifiable {
    let personId: String
    var gender: ClothingGender? = nil

    var id: String { personId }
}

/// Thông tin auto-collected
struct AutoCollectedInfo: Codable {
    let deviceId: String
    let userId: String?
    let userName: String?
    let userPhone: String?
    let timestamp: Date
    let latitude: Double?
    let longitude: Double?
    let accuracy: Double?       // GPS accuracy in meters
    let isOnline: Bool
    let batteryLevel: Int?
    
    init(
        deviceId: String,
        userId: String? = nil,
        userName: String? = nil,
        userPhone: String? = nil,
        timestamp: Date = Date(),
        latitude: Double? = nil,
        longitude: Double? = nil,
        accuracy: Double? = nil,
        isOnline: Bool = false,
        batteryLevel: Int? = nil
    ) {
        self.deviceId = deviceId
        self.userId = userId
        self.userName = userName
        self.userPhone = userPhone
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.isOnline = isOnline
        self.batteryLevel = batteryLevel
    }
}

/// Dữ liệu cứu trợ (relief)
struct ReliefData: Codable, Equatable {
    var supplies: Set<SupplyNeed> = []
    var otherSupplyDescription: String = ""
    var peopleCount: PeopleCount = PeopleCount()
    
    // Follow-up: Nước uống
    var waterDuration: WaterDuration?
    var waterRemaining: WaterRemaining?
    
    // Follow-up: Thực phẩm
    var foodDuration: FoodDuration?
    var specialDietNeed: SpecialDietNeed?
    var specialDietPersonIds: Set<String> = []
    var specialDietInfoByPerson: [String: PersonSpecialDietInfo] = [:]

    // Follow-up: Y tế
    var needsUrgentMedicine: Bool?
    var medicineConditions: Set<MedicineCondition> = []
    var medicineOtherDescription: String = ""
    var medicalNeeds: Set<MedicalSupportNeed> = []
    var medicalDescription: String = ""

    // Follow-up: Chăn / giữ ấm
    var isColdOrWet: Bool?
    var blanketAvailability: BlanketAvailability?
    var areBlanketsEnough: Bool?
    var blanketRequestCount: Int?

    // Follow-up: Quần áo
    var clothingStatus: ClothingStatus?
    var clothingPersonIds: Set<String> = []
    var clothingInfoByPerson: [String: ClothingPersonInfo] = [:]

    /// Xóa dữ liệu follow-up khi bỏ chọn nhu yếu phẩm
    mutating func clearFollowUp(for supply: SupplyNeed) {
        switch supply {
        case .water:
            waterDuration = nil
            waterRemaining = nil
        case .food:
            foodDuration = nil
            specialDietNeed = nil
            specialDietPersonIds = []
            specialDietInfoByPerson = [:]
        case .medicine:
            needsUrgentMedicine = nil
            medicineConditions = []
            medicineOtherDescription = ""
            medicalNeeds = []
            medicalDescription = ""
        case .blanket:
            isColdOrWet = nil
            blanketAvailability = nil
            areBlanketsEnough = nil
            blanketRequestCount = nil
        case .clothes:
            clothingStatus = nil
            clothingPersonIds = []
            clothingInfoByPerson = [:]
        case .other:
            break
        }
    }

    mutating func syncToValidPeople(validIds: Set<String>, maxPeopleCount: Int) {
        specialDietPersonIds = specialDietPersonIds.intersection(validIds)
        specialDietInfoByPerson = specialDietInfoByPerson.filter { validIds.contains($0.key) }

        clothingPersonIds = clothingPersonIds.intersection(validIds)
        clothingInfoByPerson = clothingInfoByPerson.filter { validIds.contains($0.key) }

        guard let blanketRequestCount else { return }
        if maxPeopleCount <= 0 {
            self.blanketRequestCount = nil
        } else {
            self.blanketRequestCount = min(max(blanketRequestCount, 1), maxPeopleCount)
        }
    }
}

/// Dữ liệu cứu hộ (rescue)
struct RescueData: Codable, Equatable {
    var situation: RescueSituation?
    var otherSituationDescription: String = ""
    var peopleCount: PeopleCount = PeopleCount()
    
    // Legacy mirrored people list for local persistence/detail view
    var people: [Person] = []
    
    // Người bị thương được chọn
    var hasInjured: Bool = false
    var injuredPersonIds: Set<String> = []
    
    // Thông tin y tế cho từng người bị thương
    var medicalInfoByPerson: [String: PersonMedicalInfo] = [:]
    
    // Để lại cho backwards compatibility
    var medicalIssues: Set<MedicalIssue> = []
    var otherMedicalDescription: String = ""
    var othersAreStable: Bool = false
    
    /// Tạo danh sách người từ peopleCount
    mutating func generatePeople() {
        // Lưu customName hiện có để khôi phục sau khi tạo lại
        let existingNames = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0.customName) })
        
        var newPeople: [Person] = []
        
        // Tạo người lớn (luôn ít nhất 1)
        let adultCount = max(1, peopleCount.adults)
        for i in 1...adultCount {
            var person = Person(id: "adult_\(i)", type: .adult, index: i)
            person.customName = existingNames[person.id] ?? ""
            newPeople.append(person)
        }
        
        // Tạo trẻ em
        if peopleCount.children > 0 {
            for i in 1...peopleCount.children {
                var person = Person(id: "child_\(i)", type: .child, index: i)
                person.customName = existingNames[person.id] ?? ""
                newPeople.append(person)
            }
        }
        
        // Tạo người già
        if peopleCount.elderly > 0 {
            for i in 1...peopleCount.elderly {
                var person = Person(id: "elderly_\(i)", type: .elderly, index: i)
                person.customName = existingNames[person.id] ?? ""
                newPeople.append(person)
            }
        }
        
        // Xóa người bị thương không còn trong danh sách
        let validIds = Set(newPeople.map { $0.id })
        injuredPersonIds = injuredPersonIds.intersection(validIds)
        medicalInfoByPerson = medicalInfoByPerson.filter { validIds.contains($0.key) }
        
        people = newPeople
    }

    mutating func syncToValidPeople(validIds: Set<String>) {
        injuredPersonIds = injuredPersonIds.intersection(validIds)
        medicalInfoByPerson = medicalInfoByPerson.filter { validIds.contains($0.key) }
    }
    
    /// personMedicalScore = Σ(issueWeight) × ageWeight cho mỗi người
    /// Tổng: Σ(personMedicalScore)
    var weightedMedicalScore: Double {
        var total = 0.0
        for personId in injuredPersonIds {
            guard let info = medicalInfoByPerson[personId],
                  let person = people.first(where: { $0.id == personId }) else { continue }
            total += Double(info.issueWeightSum) * person.type.ageWeight
        }
        return total
    }
    
    /// Medical Severe Flag: có bất kỳ issue nào isSevere
    var medicalSevere: Bool {
        medicalInfoByPerson.values.contains { info in
            info.medicalIssues.contains { $0.isSevere }
        }
    }
    
    /// Situation Severe Flag
    var situationSevere: Bool {
        situation?.isSevere ?? false
    }
}

// MARK: - Main Form Data

/// Form data chính cho SOS Wizard
class SOSFormData: ObservableObject {
    // Step tracking
    @Published var currentStep: SOSWizardStep = .autoInfo
    @Published var completedSteps: Set<SOSWizardStep> = []
    
    // Auto-collected (Step 0)
    @Published var autoInfo: AutoCollectedInfo?
    
    // Step 1: Loại SOS - có thể chọn 1 hoặc cả 2
    @Published var selectedTypes: Set<SOSType> = []
    
    // Computed property cho backward compatibility
    var sosType: SOSType? {
        // Ưu tiên rescue nếu chọn cả 2
        if selectedTypes.contains(.rescue) { return .rescue }
        if selectedTypes.contains(.relief) { return .relief }
        return nil
    }
    
    // Số người cần hỗ trợ (shared giữa rescue và relief)
    @Published var sharedPeopleCount: PeopleCount = PeopleCount() {
        didSet {
            syncPeopleCount()
        }
    }
    @Published var sharedPeople: [Person] = []
    
    // Step 2A: Cứu trợ
    @Published var reliefData: ReliefData = ReliefData()
    
    // Step 2B: Cứu hộ
    @Published var rescueData: RescueData = RescueData()
    
    // Step 3: Mô tả thêm
    @Published var additionalDescription: String = ""
    
    // Quick preset applied
    @Published var appliedPreset: QuickPreset?

    init() {
        syncPeopleCount()
    }
    
    // MARK: - Computed Properties
    
    var canSendMinimalSOS: Bool {
        // Có thể gửi SOS tối thiểu nếu có vị trí
        autoInfo?.latitude != nil && autoInfo?.longitude != nil
    }
    
    var canProceedToNextStep: Bool {
        switch currentStep {
        case .autoInfo:
            return autoInfo != nil
        case .selectType:
            return !selectedTypes.isEmpty && sharedPeopleCount.total > 0
        case .relief:
            return !reliefData.supplies.isEmpty || !reliefData.otherSupplyDescription.isEmpty
        case .rescue:
            return rescueData.situation != nil
        case .additionalInfo:
            return true // Optional step
        case .review:
            return true
        }
    }
    
    var isComplete: Bool {
        !selectedTypes.isEmpty
    }
    
    // Check nếu chọn cả 2 loại
    var needsBothSteps: Bool {
        selectedTypes.contains(.rescue) && selectedTypes.contains(.relief)
    }
    
    var needsRescueStep: Bool {
        selectedTypes.contains(.rescue)
    }
    
    var needsReliefStep: Bool {
        selectedTypes.contains(.relief)
    }
    
    /// PriorityScore = (Σ(requestTypeScore) + Σ(personMedicalScore)) × situationMultiplier, capped at 100
    var priorityScore: Int {
        let requestTypeScore: Double
        switch sosType {
        case .rescue:  requestTypeScore = 30
        case .relief:  requestTypeScore = 20
        case .none:    requestTypeScore = 0
        }
        
        let medicalScore = needsRescueStep ? rescueData.weightedMedicalScore : 0
        let situationMultiplier = rescueData.situation?.situationMultiplier ?? 1.0
        
        let raw = (requestTypeScore + medicalScore) * situationMultiplier
        return min(100, Int(raw.rounded()))
    }
    
    // MARK: - Priority Level (P1–P4)
    
    /// Ngưỡng điểm cho từng mức ưu tiên (thang 0–100)
    private static let p1Threshold = 70
    private static let p2Threshold = 45
    private static let p3Threshold = 25
    
    /// Flags tổng hợp
    var hasSevereFlag: Bool {
        (needsRescueStep && rescueData.medicalSevere) || (needsRescueStep && rescueData.situationSevere)
    }
    
    /// Mức ưu tiên theo triage rule
    var priorityLevel: PriorityLevel {
        let score = priorityScore
        if score >= Self.p1Threshold && hasSevereFlag { return .p1 }
        if score >= Self.p2Threshold && hasSevereFlag { return .p2 }
        if score >= Self.p3Threshold                  { return .p3 }
        return .p4
    }
    
    // MARK: - Methods
    
    func reset() {
        currentStep = .autoInfo
        completedSteps = []
        selectedTypes = []
        reliefData = ReliefData()
        rescueData = RescueData()
        additionalDescription = ""
        appliedPreset = nil
        sharedPeople = []
        sharedPeopleCount = PeopleCount()
    }
    
    func markStepCompleted(_ step: SOSWizardStep) {
        completedSteps.insert(step)
    }
    
    func goToNextStep() {
        markStepCompleted(currentStep)
        
        // Sync shared people count vào relief/rescue data
        syncPeopleCount()
        
        switch currentStep {
        case .autoInfo:
            currentStep = .selectType
        case .selectType:
            // Ưu tiên relief trước, sau đó mới rescue
            if needsReliefStep {
                currentStep = .relief
            } else if needsRescueStep {
                currentStep = .rescue
            } else {
                currentStep = .additionalInfo
            }
        case .relief:
            // Sau relief, nếu cần rescue thì qua rescue, nếu không thì additionalInfo
            if needsRescueStep {
                currentStep = .rescue
            } else {
                currentStep = .additionalInfo
            }
        case .rescue:
            currentStep = .additionalInfo
        case .additionalInfo:
            currentStep = .review
        case .review:
            break // Stay on review
        }
    }
    
    func goToPreviousStep() {
        switch currentStep {
        case .autoInfo:
            break
        case .selectType:
            currentStep = .autoInfo
        case .relief:
            currentStep = .selectType
        case .rescue:
            // Nếu đã qua relief trước đó, quay lại relief
            if needsReliefStep {
                currentStep = .relief
            } else {
                currentStep = .selectType
            }
        case .additionalInfo:
            // Quay lại rescue nếu có, nếu không thì relief, nếu không thì selectType
            if needsRescueStep {
                currentStep = .rescue
            } else if needsReliefStep {
                currentStep = .relief
            } else {
                currentStep = .selectType
            }
        case .review:
            currentStep = .additionalInfo
        }
    }
    
    /// Sync shared people count vào rescue và relief data
    func syncPeopleCount() {
        let existingNames = Dictionary(uniqueKeysWithValues: sharedPeople.map { ($0.id, $0.customName) })
        var newPeople: [Person] = []

        let adultCount = max(1, sharedPeopleCount.adults)
        for index in 1...adultCount {
            var person = Person(id: "adult_\(index)", type: .adult, index: index)
            person.customName = existingNames[person.id] ?? ""
            newPeople.append(person)
        }

        if sharedPeopleCount.children > 0 {
            for index in 1...sharedPeopleCount.children {
                var person = Person(id: "child_\(index)", type: .child, index: index)
                person.customName = existingNames[person.id] ?? ""
                newPeople.append(person)
            }
        }

        if sharedPeopleCount.elderly > 0 {
            for index in 1...sharedPeopleCount.elderly {
                var person = Person(id: "elderly_\(index)", type: .elderly, index: index)
                person.customName = existingNames[person.id] ?? ""
                newPeople.append(person)
            }
        }

        let validIds = Set(newPeople.map(\.id))
        sharedPeople = newPeople
        reliefData.peopleCount = sharedPeopleCount
        rescueData.peopleCount = sharedPeopleCount
        rescueData.people = newPeople
        rescueData.syncToValidPeople(validIds: validIds)
        reliefData.syncToValidPeople(validIds: validIds, maxPeopleCount: sharedPeopleCount.total)
    }

    func restoreSharedPeople(_ people: [Person]) {
        sharedPeople = people
        syncPeopleCount()
    }

    func updatePersonName(_ name: String, for personId: String) {
        guard let index = sharedPeople.firstIndex(where: { $0.id == personId }) else { return }
        var updatedPeople = sharedPeople
        updatedPeople[index].customName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        sharedPeople = updatedPeople
        rescueData.people = updatedPeople
    }

    func person(for personId: String) -> Person? {
        sharedPeople.first(where: { $0.id == personId }) ??
            rescueData.people.first(where: { $0.id == personId })
    }

    func orderedPeople(for personIds: Set<String>) -> [Person] {
        sharedPeople.filter { personIds.contains($0.id) }
    }
    
    /// Apply quick preset
    func applyPreset(_ preset: QuickPreset) {
        appliedPreset = preset
        selectedTypes.insert(preset.sosType)
        
        switch preset {
        case .needWaterFood:
            reliefData.supplies = [.water, .food]
        case .hasInjured:
            rescueData.hasInjured = true
        case .trapped:
            rescueData.situation = .trapped
        case .flooding:
            rescueData.situation = .flooding
        case .collapsed:
            rescueData.situation = .collapsed
        }
    }
    
    /// Convert to SOSPacket message format
    func toSOSMessage() -> String {
        var parts: [String] = []
        
        // Loại SOS
        if let type = sosType {
            parts.append("[\(type.title)]")
        }
        
        // Chi tiết cứu hộ
        if needsRescueStep {
            if let situation = rescueData.situation {
                parts.append("Tình trạng: \(situation.title)")
            }
            
            // Số người
            parts.append("Số người: \(rescueData.peopleCount.total)")
            if rescueData.peopleCount.children > 0 {
                parts.append("Trẻ em: \(rescueData.peopleCount.children)")
            }
            if rescueData.peopleCount.elderly > 0 {
                parts.append("Người già: \(rescueData.peopleCount.elderly)")
            }
            
            // Thông tin y tế từng người bị thương
            if rescueData.hasInjured && !rescueData.injuredPersonIds.isEmpty {
                var injuredInfo: [String] = []
                for personId in rescueData.injuredPersonIds {
                    if let person = person(for: personId),
                       let medicalInfo = rescueData.medicalInfoByPerson[personId] {
                        let issues = medicalInfo.medicalIssues.map { $0.title }.joined(separator: ", ")
                        let nameLabel: String
                        if person.customName.isEmpty {
                            nameLabel = person.displayName
                        } else {
                            nameLabel = "\(person.type.title) \(person.index): \(person.customName)"
                        }
                        injuredInfo.append("\(nameLabel) - \(issues)")
                    }
                }
                if !injuredInfo.isEmpty {
                    parts.append("Bị thương: \(injuredInfo.joined(separator: "; "))")
                }
            }
        }

        // Chi tiết cứu trợ
        if needsReliefStep {
            if !reliefData.supplies.isEmpty {
                let supplies = reliefData.supplies.map { $0.title }.joined(separator: ", ")
                parts.append("Cần: \(supplies)")
            }
            
            parts.append("Số người: \(reliefData.peopleCount.total)")

            if let waterDuration = reliefData.waterDuration {
                parts.append("Nước: \(waterDuration.title)")
            }

            if let waterRemaining = reliefData.waterRemaining {
                parts.append("Nước còn: \(waterRemaining.title)")
            }

            if let foodDuration = reliefData.foodDuration {
                parts.append("Thực phẩm: \(foodDuration.title)")
            }

            let specialDietSummaries = orderedPeople(for: reliefData.specialDietPersonIds).compactMap { person -> String? in
                guard let info = reliefData.specialDietInfoByPerson[person.id] else { return nil }
                let description = info.dietDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                return description.isEmpty ? person.displayName : "\(person.displayName) (\(description))"
            }
            if !specialDietSummaries.isEmpty {
                parts.append("Ăn đặc biệt: \(specialDietSummaries.joined(separator: "; "))")
            }

            if !reliefData.medicalNeeds.isEmpty {
                parts.append("Y tế: \(reliefData.medicalNeeds.map(\.title).joined(separator: ", "))")
            }

            if !reliefData.medicalDescription.isEmpty {
                parts.append("Mô tả y tế: \(reliefData.medicalDescription)")
            }

            if let areBlanketsEnough = reliefData.areBlanketsEnough {
                if areBlanketsEnough {
                    parts.append("Chăn mền: đủ")
                } else if let blanketRequestCount = reliefData.blanketRequestCount {
                    parts.append("Chăn mền: cần thêm \(blanketRequestCount)")
                } else {
                    parts.append("Chăn mền: không đủ")
                }
            }

            let clothingSummaries = orderedPeople(for: reliefData.clothingPersonIds).compactMap { person -> String? in
                guard let info = reliefData.clothingInfoByPerson[person.id] else { return nil }
                let genderTitle = info.gender?.title ?? "Chưa rõ"
                return "\(person.displayName) (\(genderTitle))"
            }
            if !clothingSummaries.isEmpty {
                parts.append("Quần áo: \(clothingSummaries.joined(separator: "; "))")
            }
        }
        
        // Mô tả thêm
        if !additionalDescription.isEmpty {
            parts.append("Ghi chú: \(additionalDescription)")
        }
        
        return parts.joined(separator: " | ")
    }
    
    /// Convert to structured JSON for server
    func toStructuredPayload() -> SOSStructuredPayload {
        SOSStructuredPayload(
            sosType: sosType?.rawValue,
            reliefData: needsReliefStep ? reliefData : nil,
            rescueData: needsRescueStep ? rescueData : nil,
            additionalDescription: additionalDescription.isEmpty ? nil : additionalDescription,
            priorityScore: priorityScore,
            autoInfo: autoInfo
        )
    }
}

// MARK: - Wizard Steps

enum SOSWizardStep: Int, CaseIterable, Comparable {
    case autoInfo = 0
    case selectType = 1
    case relief = 2     // 2A
    case rescue = 3     // 2B (same step number conceptually)
    case additionalInfo = 4
    case review = 5
    
    static func < (lhs: SOSWizardStep, rhs: SOSWizardStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var title: String {
        switch self {
        case .autoInfo: return "Thông tin tự động"
        case .selectType: return "Loại SOS"
        case .relief: return "Chi tiết cứu trợ"
        case .rescue: return "Chi tiết cứu hộ"
        case .additionalInfo: return "Mô tả thêm"
        case .review: return "Xác nhận"
        }
    }
    
    var stepNumber: Int {
        switch self {
        case .autoInfo: return 0
        case .selectType: return 1
        case .relief, .rescue: return 2
        case .additionalInfo: return 3
        case .review: return 4
        }
    }
}

// MARK: - Quick Presets

enum QuickPreset: String, CaseIterable {
    case needWaterFood = "NEED_WATER_FOOD"
    case hasInjured = "HAS_INJURED"
    case trapped = "TRAPPED"
    case flooding = "FLOODING"
    case collapsed = "COLLAPSED"
    
    var title: String {
        switch self {
        case .needWaterFood: return "Cần nước và thực phẩm"
        case .hasInjured: return "Có người bị thương"
        case .trapped: return "Bị mắc kẹt"
        case .flooding: return "Nước dâng cao"
        case .collapsed: return "Nhà sập"
        }
    }
    
    var icon: String {
        switch self {
        case .needWaterFood: return "🍚"
        case .hasInjured: return "🩹"
        case .trapped: return "🚧"
        case .flooding: return "🌊"
        case .collapsed: return "🏚️"
        }
    }
    
    var sosType: SOSType {
        switch self {
        case .needWaterFood: return .relief
        case .hasInjured, .trapped, .flooding, .collapsed: return .rescue
        }
    }
}

// MARK: - Structured Payload for Server

struct SOSStructuredPayload: Codable {
    let sosType: String?
    let reliefData: ReliefData?
    let rescueData: RescueData?
    let additionalDescription: String?
    let priorityScore: Int
    let autoInfo: AutoCollectedInfo?
    
    enum CodingKeys: String, CodingKey {
        case sosType = "sos_type"
        case reliefData = "relief_data"
        case rescueData = "rescue_data"
        case additionalDescription = "additional_description"
        case priorityScore = "priority_score"
        case autoInfo = "auto_info"
    }
}

// MARK: - SOSFormData Extension for SOSPacket conversion

extension SOSFormData {
    /// Convert to unified SOSPacket for server upload
    func toSOSPacket() -> SOSPacket {
        let latitude = autoInfo?.latitude ?? 0
        let longitude = autoInfo?.longitude ?? 0
        let accuracy = autoInfo?.accuracy
        
        // Determine SOS type string
        let sosTypeString: String
        if needsBothSteps {
            sosTypeString = "BOTH"
        } else if needsRescueStep {
            sosTypeString = "RESCUE"
        } else if needsReliefStep {
            sosTypeString = "RELIEF"
        } else {
            sosTypeString = "UNKNOWN"
        }
        
        // Build unified structured data
        let structuredData = SOSStructuredData(
            // Rescue fields
            situation: needsRescueStep ? rescueData.situation?.rawValue : nil,
            otherSituationDescription: needsRescueStep && !rescueData.otherSituationDescription.isEmpty 
                ? rescueData.otherSituationDescription 
                : nil,
            hasInjured: needsRescueStep ? rescueData.hasInjured : nil,
            medicalIssues: needsRescueStep ? {
                let perPerson = rescueData.medicalInfoByPerson.values
                    .flatMap { $0.medicalIssues }
                    .map { $0.rawValue }
                return perPerson.isEmpty ? nil : Array(Set(perPerson))
            }() : nil,
            otherMedicalDescription: needsRescueStep && !rescueData.otherMedicalDescription.isEmpty 
                ? rescueData.otherMedicalDescription 
                : nil,
            othersAreStable: needsRescueStep ? rescueData.othersAreStable : nil,
            canMove: needsRescueStep ? (rescueData.situation != .cannotMove) : nil,
            needMedical: needsRescueStep ? rescueData.hasInjured : nil,
            injuredPersons: needsRescueStep && !rescueData.injuredPersonIds.isEmpty ? {
                var persons: [SOSInjuredPerson] = []
                for personId in rescueData.injuredPersonIds {
                    if let person = person(for: personId),
                       let info = rescueData.medicalInfoByPerson[personId] {
                        persons.append(SOSInjuredPerson(
                            personType: person.type.rawValue,
                            index: person.index,
                            name: person.displayName,
                            customName: person.customName.isEmpty ? nil : person.customName,
                            medicalIssues: info.medicalIssues.map { $0.rawValue },
                            severity: "NONE"
                        ))
                    }
                }
                return persons.isEmpty ? nil : persons
            }() : nil,
            
            // Relief fields
            supplies: needsReliefStep && !reliefData.supplies.isEmpty 
                ? reliefData.supplies.map { $0.rawValue } 
                : nil,
            otherSupplyDescription: needsReliefStep && !reliefData.otherSupplyDescription.isEmpty 
                ? reliefData.otherSupplyDescription 
                : nil,
            supplyDetails: needsReliefStep ? {
                let specialDietPersons = orderedPeople(for: reliefData.specialDietPersonIds).compactMap { person -> SOSSpecialDietPerson? in
                    guard let info = reliefData.specialDietInfoByPerson[person.id] else { return nil }
                    return SOSSpecialDietPerson(
                        personType: person.type.rawValue,
                        index: person.index,
                        name: person.displayName,
                        customName: person.customName.isEmpty ? nil : person.customName,
                        dietDescription: info.dietDescription.isEmpty ? nil : info.dietDescription
                    )
                }

                let clothingPersons = orderedPeople(for: reliefData.clothingPersonIds).compactMap { person -> SOSClothingPerson? in
                    guard let info = reliefData.clothingInfoByPerson[person.id],
                          let gender = info.gender else { return nil }
                    return SOSClothingPerson(
                        personType: person.type.rawValue,
                        index: person.index,
                        name: person.displayName,
                        customName: person.customName.isEmpty ? nil : person.customName,
                        gender: gender.rawValue
                    )
                }

                let hasSomeDetail =
                    reliefData.waterDuration != nil ||
                    reliefData.waterRemaining != nil ||
                    reliefData.foodDuration != nil ||
                    !specialDietPersons.isEmpty ||
                    !reliefData.medicalNeeds.isEmpty ||
                    !reliefData.medicalDescription.isEmpty ||
                    reliefData.areBlanketsEnough != nil ||
                    reliefData.blanketRequestCount != nil ||
                    !clothingPersons.isEmpty

                guard hasSomeDetail else { return nil }

                return SOSSupplyDetailData(
                    waterDuration: reliefData.waterDuration?.rawValue,
                    waterRemaining: reliefData.waterRemaining?.rawValue,
                    foodDuration: reliefData.foodDuration?.rawValue,
                    specialDietNeed: reliefData.specialDietNeed?.rawValue,
                    specialDietPersons: specialDietPersons.isEmpty ? nil : specialDietPersons,
                    needsUrgentMedicine: reliefData.needsUrgentMedicine,
                    medicineConditions: reliefData.medicineConditions.isEmpty ? nil : reliefData.medicineConditions.map { $0.rawValue },
                    medicineOtherDescription: reliefData.medicineOtherDescription.isEmpty ? nil : reliefData.medicineOtherDescription,
                    medicalNeeds: reliefData.medicalNeeds.isEmpty ? nil : reliefData.medicalNeeds.map { $0.rawValue },
                    medicalDescription: reliefData.medicalDescription.isEmpty ? nil : reliefData.medicalDescription,
                    isColdOrWet: reliefData.isColdOrWet,
                    blanketAvailability: reliefData.blanketAvailability?.rawValue,
                    areBlanketsEnough: reliefData.areBlanketsEnough,
                    blanketRequestCount: reliefData.blanketRequestCount,
                    clothingStatus: reliefData.clothingStatus?.rawValue,
                    clothingPersons: clothingPersons.isEmpty ? nil : clothingPersons
                )
            }() : nil,
            
            // Common fields
            peopleCount: SOSPeopleCount(
                adult: sharedPeopleCount.adults,
                child: sharedPeopleCount.children,
                elderly: sharedPeopleCount.elderly
            ),
            additionalDescription: additionalDescription.isEmpty ? nil : additionalDescription
        )
        
        // Build sender info from auto collected data
        let senderInfo: SOSSenderInfo?
        if let info = autoInfo {
            senderInfo = SOSSenderInfo(
                deviceId: info.deviceId,
                userId: info.userId,
                userName: info.userName,
                userPhone: info.userPhone,
                batteryLevel: info.batteryLevel,
                isOnline: info.isOnline
            )
        } else {
            senderInfo = nil
        }
        
        // Use deviceId as originId for mesh routing
        let originId = autoInfo?.deviceId ?? UUID().uuidString
        
        return SOSPacket(
            originId: originId,
            timestamp: Date(),
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            sosType: sosTypeString,
            message: toSOSMessage(),
            structuredData: structuredData,
            senderInfo: senderInfo,
            hopCount: 0,
            path: []
        )
    }
}
