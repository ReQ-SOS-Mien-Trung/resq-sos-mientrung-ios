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

fileprivate extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

fileprivate extension Optional where Wrapped == String {
    var nilIfBlank: String? {
        switch self {
        case .some(let value):
            return value.nilIfBlank
        case .none:
            return nil
        }
    }
}

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

enum SOSReportingTarget: String, Codable, CaseIterable, Identifiable {
    case `self` = "SELF"
    case other = "OTHER"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .self: return "Tôi đang cần cứu"
        case .other: return "Tôi báo hộ người khác"
        }
    }

    var optionLabel: String {
        switch self {
        case .self: return "Lựa chọn A"
        case .other: return "Lựa chọn B"
        }
    }

    var description: String {
        switch self {
        case .self:
            return "Tạo 1 yêu cầu SOS cho bản thân bạn hoặc nhóm người đang ở cùng bạn."
        case .other:
            return "Tạo 1 yêu cầu SOS cho 1 hoặc nhiều người khác đang cần cứu nhưng không thể tự gửi."
        }
    }

    var systemImage: String {
        switch self {
        case .self: return "person.crop.circle.badge.exclamationmark"
        case .other: return "person.2.wave.2.fill"
        }
    }
}

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

    var symbolName: String {
        switch self {
        case .rescue: return "cross.case.fill"
        case .relief: return "shippingbox.fill"
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

    var symbolName: String {
        switch self {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .clothes: return "tshirt.fill"
        case .blanket: return "bed.double.fill"
        case .medicine: return "cross.case.fill"
        case .other: return "shippingbox.fill"
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

    var symbolName: String {
        switch self {
        case .trapped: return "exclamationmark.triangle.fill"
        case .collapsed: return "house.fill"
        case .dangerZone: return "exclamationmark.octagon.fill"
        case .cannotMove: return "figure.roll"
        case .flooding: return "drop.fill"
        case .other: return "questionmark.circle.fill"
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

    var symbolName: String {
        switch self {
        case .bleeding:            return "drop.fill"
        case .severelyBleeding:    return "drop.triangle.fill"
        case .fracture:            return "figure.fall"
        case .headInjury:          return "brain.head.profile"
        case .burns:               return "flame.fill"
        case .unconscious:         return "bed.double.fill"
        case .breathingDifficulty: return "lungs.fill"
        case .chestPainStroke:     return "heart.fill"
        case .cannotMove:          return "figure.roll"
        case .drowning:            return "water.waves"
        case .highFever:           return "thermometer.high"
        case .dehydration:         return "drop.fill"
        case .infantNeedsMilk:     return "figure.child"
        case .lostParent:          return "person.2.slash.fill"
        case .chronicDisease:      return "pills.fill"
        case .confusion:           return "brain.head.profile"
        case .needsMedicalDevice:  return "stethoscope"
        case .other:               return "cross.case.fill"
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
                .unconscious, .breathingDifficulty, .cannotMove, .highFever, .dehydration, .drowning,
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
    var adults: Int = 0        // Người lớn (15-60)
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
    
    enum PersonType: String, Codable, Hashable {
        case adult = "ADULT"
        case child = "CHILD"
        case elderly = "ELDERLY"

        var idPrefix: String {
            switch self {
            case .adult: return "adult"
            case .child: return "child"
            case .elderly: return "elderly"
            }
        }
        
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

        var symbolName: String {
            switch self {
            case .adult: return "person.fill"
            case .child: return "figure.child"
            case .elderly: return "figure.seated.side"
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
    var medicalIssues: Set<String> = []
    var otherDescription: String = ""
    
    var id: String { personId }
    
    func issueWeightSum(using config: SOSRuleConfig) -> Double {
        medicalIssues.reduce(0) { partialResult, issueKey in
            partialResult + config.medicalIssueWeight(for: issueKey)
        }
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

private enum SOSQuickFillSample {
    static let adultId = "adult_1"
    static let childId = "child_1"
    static let elderlyId = "elderly_1"
    static let demoLatitude = 16.469621
    static let demoLongitude = 107.592778
    static let demoAddress = "2 Trần Hưng Đạo, Phú Hòa, Thành phố Huế"

    static let additionalDescription = "Bà già Chu đang bị mất nhiệt. Cần cứu gấp!!!!!!!!!!!!!!"

    static let medicalContextItems: [SavedRelativeProfileNoteItem] = [
        SavedRelativeProfileNoteItem(
            id: childId,
            displayName: "Khoa",
            personType: .child,
            summaryLines: [
                "Bệnh nền: Tim mạch, Tiểu đường, Bệnh thận",
                "Dị ứng: Dị ứng thuốc",
                "Thiết bị hỗ trợ: Bình oxy",
                "Tiền sử chấn thương / phẫu thuật: Đã từng gãy xương",
                "Yêu cầu đặc biệt: Cần người dìu"
            ]
        )
    ]

    static func makeReliefData(peopleCount: PeopleCount) -> ReliefData {
        ReliefData(
            supplies: [.water, .food, .clothes, .blanket, .medicine, .other],
            otherSupplyDescription: "Pin sạc dự phòng",
            peopleCount: peopleCount,
            waterDuration: WaterDuration.from6to12h.rawValue,
            waterRemaining: nil,
            foodDuration: FoodDuration.from12to24h.rawValue,
            specialDietNeed: nil,
            specialDietPersonIds: [childId, adultId, elderlyId],
            specialDietInfoByPerson: [
                childId: PersonSpecialDietInfo(personId: childId, dietDescription: "Ăn lỏng"),
                adultId: PersonSpecialDietInfo(personId: adultId, dietDescription: "Không ăn béo."),
                elderlyId: PersonSpecialDietInfo(personId: elderlyId, dietDescription: "Dị ứng hải sản.")
            ],
            needsUrgentMedicine: true,
            medicineConditions: [.chronicDisease, .injured],
            medicineOtherDescription: "",
            medicalNeeds: [.commonMedicine, .firstAid],
            medicalDescription: "",
            isColdOrWet: true,
            blanketAvailability: .notEnough,
            areBlanketsEnough: false,
            blanketRequestCount: 2,
            clothingStatus: .partiallyLacking,
            clothingPersonIds: [childId],
            clothingInfoByPerson: [
                childId: ClothingPersonInfo(personId: childId, gender: .male)
            ]
        )
    }

    static func makeRescueData(peopleCount: PeopleCount, people: [Person]) -> RescueData {
        RescueData(
            situation: RescueSituation.trapped.rawValue,
            otherSituationDescription: "",
            peopleCount: peopleCount,
            people: people,
            hasInjured: true,
            injuredPersonIds: [childId],
            medicalInfoByPerson: [
                childId: PersonMedicalInfo(
                    personId: childId,
                    medicalIssues: [
                        MedicalIssue.fracture.rawValue,
                        MedicalIssue.unconscious.rawValue,
                        MedicalIssue.lostParent.rawValue,
                        MedicalIssue.cannotMove.rawValue,
                        MedicalIssue.bleeding.rawValue
                    ],
                    otherDescription: ""
                )
            ],
            medicalIssues: [],
            otherMedicalDescription: "",
            othersAreStable: false
        )
    }
}

struct SOSManualLocation: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
}

struct SavedRelativeProfileNoteItem: Identifiable, Equatable {
    let id: String
    let displayName: String
    let personType: Person.PersonType
    let summaryLines: [String]
}

/// Dữ liệu cứu trợ (relief)
struct ReliefData: Codable, Equatable {
    var supplies: Set<SupplyNeed> = []
    var otherSupplyDescription: String = ""
    var peopleCount: PeopleCount = PeopleCount()
    
    // Follow-up: Nước uống
    var waterDuration: String?
    var waterRemaining: WaterRemaining?
    
    // Follow-up: Thực phẩm
    var foodDuration: String?
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
    var situation: String?
    var otherSituationDescription: String = ""
    var peopleCount: PeopleCount = PeopleCount()
    
    // Legacy mirrored people list for local persistence/detail view
    var people: [Person] = []
    
    // Người bị thương được chọn
    var hasInjured: Bool = false
    var injuredPersonIds: Set<String> = []
    var canMove: Bool?
    
    // Thông tin y tế cho từng người bị thương
    var medicalInfoByPerson: [String: PersonMedicalInfo] = [:]
    
    // Để lại cho backwards compatibility
    var medicalIssues: Set<String> = []
    var otherMedicalDescription: String = ""
    var othersAreStable: Bool = false
    
    /// Tạo danh sách người từ peopleCount
    mutating func generatePeople() {
        // Lưu customName hiện có để khôi phục sau khi tạo lại
        let existingNames = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0.customName) })
        
        var newPeople: [Person] = []
        
        if peopleCount.adults > 0 {
            for i in 1...peopleCount.adults {
                var person = Person(id: "adult_\(i)", type: .adult, index: i)
                person.customName = existingNames[person.id] ?? ""
                newPeople.append(person)
            }
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
    func weightedMedicalScore(using config: SOSRuleConfig) -> Double {
        var total = 0.0
        for personId in injuredPersonIds {
            guard let info = medicalInfoByPerson[personId],
                  let person = people.first(where: { $0.id == personId }) else { continue }
            total += info.issueWeightSum(using: config) * config.ageWeight(for: person.type)
        }
        return total
    }
    
    /// Medical Severe Flag: có bất kỳ issue nào isSevere
    func medicalSevere(using config: SOSRuleConfig) -> Bool {
        medicalInfoByPerson.values.contains { info in
            info.medicalIssues.contains { config.isSevereMedicalIssue($0) }
        }
    }
    
    /// Situation Severe Flag
    var situationSevere: Bool {
        switch SOSRuleConfig.normalizeKey(situation) {
        case "FLOODING", "COLLAPSED":
            return true
        default:
            return false
        }
    }
}

// MARK: - Main Form Data

/// Form data chính cho SOS Wizard
@MainActor
final class SOSFormData: ObservableObject {
    // Step tracking
    @Published var currentStep: SOSWizardStep = .reportingMode
    @Published var completedSteps: Set<SOSWizardStep> = []
    
    // Auto-collected (Step 0)
    @Published var autoInfo: AutoCollectedInfo?
    @Published var reportingTarget: SOSReportingTarget = .self {
        didSet {
            reportingTargetSelectionMade = true
        }
    }
    @Published private(set) var reportingTargetSelectionMade: Bool = false
    @Published var victimName: String = ""
    @Published var victimPhone: String = ""
    @Published var addressQuery: String = ""
    @Published var resolvedAddress: String?
    @Published var manualLocation: SOSManualLocation?
    @Published var personSourceMode: SOSPersonSourceMode = .manual
    @Published var selectedRelativeSnapshots: [SelectedRelativeSnapshot] = []
    
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
            guard !isUpdatingSharedPeopleCount else { return }
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
    @Published var supplementalMedicalContextItems: [SavedRelativeProfileNoteItem] = []
    
    // Quick preset applied
    @Published var appliedPreset: QuickPreset?
    
    private var isUpdatingSharedPeopleCount = false
    private var configObserver: AnyCancellable?

    init() {
        configObserver = SOSRuleConfigStore.shared.$activeConfig.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        syncPeopleCount()
    }
    
    // MARK: - Computed Properties
    
    var canSendMinimalSOS: Bool {
        effectiveLocation != nil
    }
    
    var canProceedToNextStep: Bool {
        switch currentStep {
        case .reportingMode:
            return reportingTargetSelectionMade
        case .autoInfo:
            guard effectiveLocation != nil else { return false }
            if reportingTarget == .other {
                return victimName.nilIfBlank != nil
            }
            return autoInfo != nil
        case .selectType:
            return !selectedTypes.isEmpty && sharedPeopleCount.total >= minimumPeopleToProceed
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

    var usesSavedRelativeProfiles: Bool {
        !selectedRelativeSnapshots.isEmpty
    }

    var savedRelativeProfileBaseCount: PeopleCount {
        selectedRelativeSnapshots.reduce(into: PeopleCount()) { partialResult, snapshot in
            switch snapshot.personType {
            case .adult:
                partialResult.adults += 1
            case .child:
                partialResult.children += 1
            case .elderly:
                partialResult.elderly += 1
            }
        }
    }

    var hasManualAdditionalPeople: Bool {
        guard usesSavedRelativeProfiles else { return false }
        return sharedPeopleCount.adults > savedRelativeProfileBaseCount.adults ||
            sharedPeopleCount.children > savedRelativeProfileBaseCount.children ||
            sharedPeopleCount.elderly > savedRelativeProfileBaseCount.elderly
    }

    var selectedRelativeProfileIds: Set<String> {
        Set(selectedRelativeSnapshots.map(\.profileId))
    }

    var effectiveLocation: SOSManualLocation? {
        if let manualLocation {
            return manualLocation
        }
        guard let latitude = autoInfo?.latitude, let longitude = autoInfo?.longitude else {
            return nil
        }
        return SOSManualLocation(
            latitude: latitude,
            longitude: longitude,
            accuracy: autoInfo?.accuracy
        )
    }

    var locationSourceTitle: String {
        if manualLocation != nil {
            return "Vị trí đã chọn"
        }
        return reportingTarget == .other ? "Vị trí SOS" : "GPS thiết bị"
    }

    var addressToSend: String? {
        resolvedAddress?.nilIfBlank ?? addressQuery.nilIfBlank
    }

    var effectiveStatusBatteryLevel: Int? {
        switch reportingTarget {
        case .self:
            return autoInfo?.batteryLevel
        case .other:
            return nil
        }
    }

    var effectiveStatusIsOnline: Bool? {
        switch reportingTarget {
        case .self:
            return autoInfo?.isOnline
        case .other:
            return false
        }
    }

    var effectiveVictimName: String? {
        if usesSavedRelativeProfiles {
            return victimName.nilIfBlank
        }

        switch reportingTarget {
        case .self:
            return autoInfo?.userName?.nilIfBlank ?? UserProfile.shared.currentUser?.name.nilIfBlank
        case .other:
            return victimName.nilIfBlank
        }
    }

    var effectiveVictimPhone: String? {
        if usesSavedRelativeProfiles {
            return victimPhone.nilIfBlank
        }

        switch reportingTarget {
        case .self:
            return autoInfo?.userPhone?.nilIfBlank ?? UserProfile.shared.currentUser?.phoneNumber.nilIfBlank
        case .other:
            return victimPhone.nilIfBlank
        }
    }

    var effectiveVictimInfo: SOSVictimInfo? {
        let userId = (reportingTarget == .self && !usesSavedRelativeProfiles) ? autoInfo?.userId : nil
        let name = effectiveVictimName
        let phone = effectiveVictimPhone
        if userId == nil && name == nil && phone == nil {
            return nil
        }
        return SOSVictimInfo(
            userId: userId,
            userName: name,
            userPhone: phone
        )
    }

    var effectiveReporterInfo: SOSReporterInfo? {
        guard let info = autoInfo else { return nil }
        return SOSReporterInfo(
            deviceId: info.deviceId,
            userId: info.userId,
            userName: info.userName,
            userPhone: info.userPhone,
            batteryLevel: effectiveStatusBatteryLevel,
            isOnline: effectiveStatusIsOnline
        )
    }

    var legacySenderInfo: SOSSenderInfo? {
        guard let info = autoInfo else { return nil }
        return SOSSenderInfo(
            deviceId: info.deviceId,
            userId: info.userId,
            userName: effectiveVictimName,
            userPhone: effectiveVictimPhone,
            batteryLevel: effectiveStatusBatteryLevel,
            isOnline: effectiveStatusIsOnline
        )
    }

    var packetReporterInfo: SOSReporterInfo? {
        let currentUser = UserProfile.shared.currentUser
        let userId = autoInfo?.userId ?? AuthSessionStore.shared.session?.userId
        let userName = autoInfo?.userName?.nilIfBlank ?? currentUser?.name.nilIfBlank
        let userPhone = autoInfo?.userPhone?.nilIfBlank ?? currentUser?.phoneNumber.nilIfBlank
        let deviceId = autoInfo?.deviceId

        if deviceId == nil && userId == nil && userName == nil && userPhone == nil {
            return nil
        }

        return SOSReporterInfo(
            deviceId: deviceId,
            userId: userId,
            userName: userName,
            userPhone: userPhone,
            batteryLevel: effectiveStatusBatteryLevel,
            isOnline: effectiveStatusIsOnline
        )
    }

    var packetSenderInfo: SOSSenderInfo? {
        packetReporterInfo
    }

    var packetVictimName: String? {
        let totalCount = sharedPeopleCount.total
        if totalCount > 1 {
            return "Nhóm \(totalCount) người"
        }
        return effectiveVictimName
    }

    var packetVictimPhone: String? {
        let totalCount = sharedPeopleCount.total
        // BE link nhiều nạn nhân qua structured_data.victims[].person_phone, không qua victim_info.user_phone.
        guard totalCount <= 1 else { return nil }
        return effectiveVictimPhone?.nilIfBlank
    }

    var packetVictimInfo: SOSVictimInfo? {
        let totalCount = sharedPeopleCount.total
        let userId: String? = (totalCount <= 1 && reportingTarget == .self && !usesSavedRelativeProfiles)
            ? packetReporterInfo?.userId
            : nil
        let userName = packetVictimName
        let userPhone = packetVictimPhone

        if userId == nil && userName == nil && userPhone == nil {
            return nil
        }

        return SOSVictimInfo(
            userId: userId,
            userName: userName,
            userPhone: userPhone
        )
    }

    var savedProfileNoteItems: [SavedRelativeProfileNoteItem] {
        selectedRelativeSnapshots.compactMap { snapshot in
            let summaryLines = snapshot.storedInfoLines
            guard !summaryLines.isEmpty else { return nil }

            return SavedRelativeProfileNoteItem(
                id: snapshot.personId,
                displayName: person(for: snapshot.personId)?.displayName ?? snapshot.displayName,
                personType: snapshot.personType,
                summaryLines: summaryLines
            )
        }
    }

    var medicalContextNoteItems: [SavedRelativeProfileNoteItem] {
        let selectedProfileMedicalItems = selectedRelativeSnapshots.compactMap { snapshot -> SavedRelativeProfileNoteItem? in
            let summaryLines = packetMedicalContextLines(for: snapshot)
            guard !summaryLines.isEmpty else { return nil }

            return SavedRelativeProfileNoteItem(
                id: snapshot.personId,
                displayName: person(for: snapshot.personId)?.displayName ?? snapshot.displayName,
                personType: snapshot.personType,
                summaryLines: summaryLines
            )
        }

        return selectedProfileMedicalItems + supplementalMedicalContextItems
    }

    var savedProfileContextMessage: String? {
        let lines = savedProfileNoteItems.compactMap { item -> String? in
            guard !item.summaryLines.isEmpty else { return nil }
            return "\(item.displayName) (\(item.summaryLines.joined(separator: "; ")))"
        }

        guard !lines.isEmpty else { return nil }
        return "Hồ sơ đã lưu: \(lines.joined(separator: " | "))"
    }

    var medicalContextMessage: String? {
        let lines = medicalContextNoteItems.compactMap { item -> String? in
            let summaryLines = item.summaryLines
            guard !summaryLines.isEmpty else { return nil }
            let displayName = person(for: item.id)?.displayName ?? item.displayName
            return "\(displayName) (\(summaryLines.joined(separator: "; ")))"
        }

        guard !lines.isEmpty else { return nil }
        return "Thông tin y tế nền: \(lines.joined(separator: " | "))"
    }

    var mergedAdditionalDescription: String? {
        let userNote = additionalDescription.nilIfBlank
        let medicalContextNote = medicalContextMessage.nilIfBlank

        switch (userNote, medicalContextNote) {
        case let (.some(userNote), .some(medicalContextNote)):
            return "\(userNote)\n\(medicalContextNote)"
        case let (.some(userNote), .none):
            return userNote
        case let (.none, .some(medicalContextNote)):
            return medicalContextNote
        case (.none, .none):
            return nil
        }
    }

    var packetAdditionalDescription: String? {
        mergedAdditionalDescription.nilIfBlank
    }

    var userEnteredAdditionalDescription: String? {
        additionalDescription.nilIfBlank
    }

    var ruleConfig: SOSRuleConfig {
        SOSRuleConfigStore.shared.currentConfig
    }

    var minimumPeopleToProceed: Int {
        ruleConfig.minimumPeopleToProceed()
    }

    var availableWaterDurationOptions: [SOSSelectionOption] {
        ruleConfig.waterDurationOptions()
    }

    var availableFoodDurationOptions: [SOSSelectionOption] {
        ruleConfig.foodDurationOptions()
    }

    var availableSituationOptions: [SOSSituationDescriptor] {
        ruleConfig.situationOptions()
    }

    func availableMedicalIssueGroups(for personType: Person.PersonType) -> [(category: MedicalIssueCategory, issues: [SOSMedicalIssueDescriptor])] {
        ruleConfig.medicalIssueGroups(for: personType)
    }

    func medicalIssueTitle(for issueKey: String) -> String {
        MedicalIssue.title(for: issueKey)
    }

    func medicalIssueIcon(for issueKey: String) -> String {
        MedicalIssue.icon(for: issueKey)
    }

    func medicalIssueSymbol(for issueKey: String) -> String {
        MedicalIssue.symbol(for: issueKey)
    }

    func situationTitle(for situationKey: String) -> String {
        RescueSituation.title(for: situationKey)
    }

    func situationIcon(for situationKey: String) -> String {
        RescueSituation.icon(for: situationKey)
    }

    func situationSymbol(for situationKey: String) -> String {
        RescueSituation.symbol(for: situationKey)
    }

    func waterDurationTitle(for optionKey: String) -> String {
        WaterDuration.title(for: optionKey)
    }

    func foodDurationTitle(for optionKey: String) -> String {
        FoodDuration.title(for: optionKey)
    }

    var situationMultiplierValue: Double {
        ruleConfig.resolveSituationMultiplier(for: rescueData.situation)
    }

    var vulnerabilityRawScore: Double {
        let rules = ruleConfig.reliefScore.vulnerabilityScore.vulnerabilityRaw
        return (Double(sharedPeopleCount.children) * rules.childPerPerson)
            + (Double(sharedPeopleCount.elderly) * rules.elderlyPerPerson)
            + (hasPregnantVictim ? rules.hasPregnantAny : 0)
    }

    private var medicalScore: Double {
        needsRescueStep ? rescueData.weightedMedicalScore(using: ruleConfig) : 0
    }

    private var waterUrgencyScore: Double {
        guard needsReliefStep, reliefData.supplies.contains(.water) else { return 0 }
        return ruleConfig.mappedWaterUrgency(for: reliefData.waterDuration)
    }

    private var foodUrgencyScore: Double {
        guard needsReliefStep, reliefData.supplies.contains(.food) else { return 0 }
        return ruleConfig.mappedFoodUrgency(for: reliefData.foodDuration)
    }

    private var blanketUrgencyScore: Double {
        let rules = ruleConfig.reliefScore.supplyUrgencyScore.blanketUrgencyScore
        let supplySelected = reliefData.supplies.contains(.blanket)

        if rules.applyOnlyWhenSupplySelected && !supplySelected {
            return rules.noneOrNotSelectedScore
        }

        if rules.applyOnlyWhenAreBlanketsEnoughIsFalse && reliefData.areBlanketsEnough != false {
            return rules.noneOrNotSelectedScore
        }

        let requestedCount = max(0, reliefData.blanketRequestCount ?? 0)
        guard requestedCount > 0 else { return rules.noneOrNotSelectedScore }
        if requestedCount == 1 { return rules.requestedCountEquals1Score }

        let totalPeople = max(sharedPeopleCount.total, 1)
        if exceedsHalf(count: requestedCount, totalPeople: totalPeople, operatorSymbol: rules.halfPeopleOperator) {
            return rules.requestedCountMoreThanHalfPeopleScore
        }

        return rules.requestedCountBetween2AndHalfPeopleScore
    }

    private var clothingUrgencyScore: Double {
        let rules = ruleConfig.reliefScore.supplyUrgencyScore.clothingUrgencyScore
        let supplySelected = reliefData.supplies.contains(.clothes)

        if rules.applyOnlyWhenSupplySelected && !supplySelected {
            return rules.noneOrNotSelectedScore
        }

        let neededCount = reliefData.clothingPersonIds.count
        guard neededCount > 0 else { return rules.noneOrNotSelectedScore }
        if neededCount == 1 { return rules.neededPeopleEquals1Score }

        let totalPeople = max(sharedPeopleCount.total, 1)
        if exceedsHalf(count: neededCount, totalPeople: totalPeople, operatorSymbol: rules.halfPeopleOperator) {
            return rules.neededPeopleMoreThanHalfPeopleScore
        }

        return rules.neededPeopleBetween2AndHalfPeopleScore
    }

    private var hasPregnantVictim: Bool {
        let activePersonIds = Set(sharedPeople.map(\.id))
        return selectedRelativeSnapshots.contains { snapshot in
            activePersonIds.contains(snapshot.personId) && snapshot.medicalProfile.specialSituation.isPregnant
        }
    }

    /// Supply Urgency Score thành phần cho Relief.
    var supplyUrgencyScore: Double {
        guard needsReliefStep else { return 0 }
        return waterUrgencyScore + foodUrgencyScore + blanketUrgencyScore + clothingUrgencyScore
    }

    /// Vulnerability Score: CHILD +1, ELDERLY +1, có thai +2; cap = 10% supplyUrgencyScore.
    var vulnerabilityScore: Double {
        guard needsReliefStep else { return 0 }
        let context: [String: Double] = [
            "VULNERABILITY_RAW": vulnerabilityRawScore,
            "SUPPLY_URGENCY_SCORE": supplyUrgencyScore,
            "CAP_RATIO": ruleConfig.reliefScore.vulnerabilityScore.capRatio
        ]

        return (try? SOSExpressionEngine.evaluate(
            ruleConfig.reliefScore.vulnerabilityScore.expression,
            context: context
        )) ?? min(vulnerabilityRawScore, max(0, supplyUrgencyScore * ruleConfig.reliefScore.vulnerabilityScore.capRatio))
    }

    /// Relief Score = Supply Urgency + Vulnerability.
    var reliefScore: Double {
        guard needsReliefStep else { return 0 }
        let context: [String: Double] = [
            "SUPPLY_URGENCY_SCORE": supplyUrgencyScore,
            "VULNERABILITY_SCORE": vulnerabilityScore
        ]

        return (try? SOSExpressionEngine.evaluate(ruleConfig.reliefScore.expression, context: context))
            ?? (supplyUrgencyScore + vulnerabilityScore)
    }

    /// PriorityScore = (medicalScore + reliefScore) × situationMultiplier
    var priorityScore: Int {
        let context: [String: Double] = [
            "MEDICAL_SCORE": medicalScore,
            "REQUEST_TYPE_SCORE": ruleConfig.requestTypeScore(for: sosType?.rawValue),
            "SUPPLY_URGENCY_SCORE": supplyUrgencyScore,
            "VULNERABILITY_RAW": vulnerabilityRawScore,
            "CAP_RATIO": ruleConfig.reliefScore.vulnerabilityScore.capRatio,
            "VULNERABILITY_SCORE": vulnerabilityScore,
            "RELIEF_SCORE": reliefScore,
            "SITUATION_MULTIPLIER": situationMultiplierValue
        ]

        let raw = (try? SOSExpressionEngine.evaluate(ruleConfig.priorityScore.expression, context: context))
            ?? ((medicalScore + reliefScore) * situationMultiplierValue).rounded()
        return Int(raw.rounded())
    }
    
    // MARK: - Priority Level (P1–P4)
    
    /// Ngưỡng điểm cho từng mức ưu tiên
    /// Flags tổng hợp
    var hasSevereFlag: Bool {
        (needsRescueStep && rescueData.medicalSevere(using: ruleConfig)) || (needsRescueStep && rescueData.situationSevere)
    }
    
    /// Mức ưu tiên theo triage rule
    var priorityLevel: PriorityLevel {
        let score = priorityScore
        if score >= ruleConfig.priorityLevel.p1Threshold && hasSevereFlag { return .p1 }
        if score >= ruleConfig.priorityLevel.p2Threshold && hasSevereFlag { return .p2 }
        if score >= ruleConfig.priorityLevel.p3Threshold                  { return .p3 }
        return .p4
    }

    private func exceedsHalf(count: Int, totalPeople: Int, operatorSymbol: String) -> Bool {
        let threshold = Double(totalPeople) / 2.0
        switch operatorSymbol.trimmingCharacters(in: .whitespacesAndNewlines) {
        case ">=":
            return Double(count) >= threshold
        default:
            return Double(count) > threshold
        }
    }
    
    // MARK: - Methods
    
    func reset() {
        currentStep = .reportingMode
        completedSteps = []
        reportingTarget = .self
        reportingTargetSelectionMade = false
        victimName = ""
        victimPhone = ""
        addressQuery = ""
        resolvedAddress = nil
        manualLocation = nil
        personSourceMode = .manual
        selectedRelativeSnapshots = []
        selectedTypes = []
        reliefData = ReliefData()
        rescueData = RescueData()
        additionalDescription = ""
        supplementalMedicalContextItems = []
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
        case .reportingMode:
            currentStep = .autoInfo
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
        case .reportingMode:
            break
        case .autoInfo:
            currentStep = .reportingMode
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
        if usesSavedRelativeProfiles {
            syncPeopleFromSelectedSnapshots()
        } else {
            personSourceMode = .manual
            syncManualPeopleCount()
        }
    }

    func applySelectedRelativeProfiles(_ profiles: [EmergencyRelativeProfile]) {
        guard !profiles.isEmpty else {
            switchToManualPersonSelection()
            return
        }

        var typeCounters: [Person.PersonType: Int] = [:]
        selectedRelativeSnapshots = profiles.map { profile in
            let nextIndex = (typeCounters[profile.personType] ?? 0) + 1
            typeCounters[profile.personType] = nextIndex
            return SelectedRelativeSnapshot(profile: profile, personIndex: nextIndex)
        }

        setSharedPeopleCountSilently(savedRelativeProfileBaseCount)
        syncPeopleCount()
        supplementalMedicalContextItems = []
        prefillSpecialDietFromSavedProfiles()
        prefillClothingInfoFromSavedProfiles()
    }

    func switchToManualPersonSelection() {
        let currentPeople = sharedPeople
        let currentCount = PeopleCount(
            adults: currentPeople.filter { $0.type == .adult }.count,
            children: currentPeople.filter { $0.type == .child }.count,
            elderly: currentPeople.filter { $0.type == .elderly }.count
        )

        var typeCounters: [Person.PersonType: Int] = [:]
        var idMap: [String: String] = [:]
        let convertedPeople = currentPeople.map { person -> Person in
            let nextIndex = (typeCounters[person.type] ?? 0) + 1
            typeCounters[person.type] = nextIndex

            let newId = "\(person.type.idPrefix)_\(nextIndex)"
            idMap[person.id] = newId

            var converted = Person(id: newId, type: person.type, index: nextIndex)
            converted.customName = person.customName
            return converted
        }

        personSourceMode = .manual
        selectedRelativeSnapshots = []
        setSharedPeopleCountSilently(currentCount)
        sharedPeople = convertedPeople
        rescueData.peopleCount = currentCount
        reliefData.peopleCount = currentCount
        rescueData.people = convertedPeople

        remapPersonScopedData(using: idMap, validIds: Set(convertedPeople.map(\.id)))
    }

    private func syncManualPeopleCount() {
        let existingNames = Dictionary(uniqueKeysWithValues: sharedPeople.map { ($0.id, $0.customName) })
        var newPeople: [Person] = []

        if sharedPeopleCount.adults > 0 {
            for index in 1...sharedPeopleCount.adults {
                var person = Person(id: "adult_\(index)", type: .adult, index: index)
                person.customName = existingNames[person.id] ?? ""
                newPeople.append(person)
            }
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
        supplementalMedicalContextItems = supplementalMedicalContextItems.filter { validIds.contains($0.id) }
        rescueData.syncToValidPeople(validIds: validIds)
        reliefData.syncToValidPeople(validIds: validIds, maxPeopleCount: sharedPeopleCount.total)
    }

    private func syncPeopleFromSelectedSnapshots() {
        let currentNames = Dictionary(uniqueKeysWithValues: sharedPeople.map { ($0.id, $0.customName) })
        let minimumCount = savedRelativeProfileBaseCount
        let counts = PeopleCount(
            adults: max(sharedPeopleCount.adults, minimumCount.adults),
            children: max(sharedPeopleCount.children, minimumCount.children),
            elderly: max(sharedPeopleCount.elderly, minimumCount.elderly)
        )

        let selectedPeople = selectedRelativeSnapshots.map { snapshot -> Person in
            var person = Person(
                id: snapshot.personId,
                type: snapshot.personType,
                index: snapshot.personIndex
            )
            person.customName = currentNames[snapshot.personId] ?? snapshot.displayName
            return person
        }

        let manualSupplementalPeople = makeManualSupplementalPeople(
            totalCount: counts,
            minimumCount: minimumCount,
            existingNames: currentNames
        )
        let allPeople = selectedPeople + manualSupplementalPeople

        setSharedPeopleCountSilently(counts)
        sharedPeople = allPeople
        rescueData.peopleCount = counts
        reliefData.peopleCount = counts
        rescueData.people = allPeople

        let validIds = Set(allPeople.map(\.id))
        rescueData.syncToValidPeople(validIds: validIds)
        reliefData.syncToValidPeople(validIds: validIds, maxPeopleCount: counts.total)
        personSourceMode = hasManualAdditionalPeople ? .mixed : .savedProfiles
        refreshVictimIdentityFromSavedSelection()
    }

    func restoreSharedPeople(_ people: [Person]) {
        sharedPeople = people
        setSharedPeopleCountSilently(
            PeopleCount(
                adults: people.filter { $0.type == .adult }.count,
                children: people.filter { $0.type == .child }.count,
                elderly: people.filter { $0.type == .elderly }.count
            )
        )
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

    func selectedRelativeSnapshot(for personId: String) -> SelectedRelativeSnapshot? {
        selectedRelativeSnapshots.first(where: { $0.personId == personId })
    }

    func packetMedicalContextLines(for snapshot: SelectedRelativeSnapshot) -> [String] {
        var lines = snapshot.medicalProfile.summaryLines
        if let medicalBaselineNote = snapshot.medicalBaselineNote.nilIfBlank {
            lines.append("Ghi chú y tế nền: \(medicalBaselineNote)")
        }
        if let specialNeedsNote = snapshot.specialNeedsNote.nilIfBlank {
            lines.append("Yêu cầu đặc biệt: \(specialNeedsNote)")
        }
        return lines
    }

    func prefillSpecialDietFromSavedProfiles() {
        guard usesSavedRelativeProfiles else { return }

        for snapshot in selectedRelativeSnapshots {
            guard let specialDietNote = snapshot.specialDietNote.nilIfBlank else { continue }

            let currentDescription = reliefData.specialDietInfoByPerson[snapshot.personId]?
                .dietDescription
                .nilIfBlank
            reliefData.specialDietPersonIds.insert(snapshot.personId)
            reliefData.specialDietInfoByPerson[snapshot.personId] = PersonSpecialDietInfo(
                personId: snapshot.personId,
                dietDescription: currentDescription ?? specialDietNote
            )
        }

        reliefData.syncToValidPeople(
            validIds: Set(sharedPeople.map(\.id)),
            maxPeopleCount: sharedPeopleCount.total
        )
    }

    func prefillClothingInfoFromSavedProfiles() {
        guard usesSavedRelativeProfiles else { return }

        for snapshot in selectedRelativeSnapshots {
            guard let gender = snapshot.gender else { continue }
            let currentGender = reliefData.clothingInfoByPerson[snapshot.personId]?.gender
            reliefData.clothingInfoByPerson[snapshot.personId] = ClothingPersonInfo(
                personId: snapshot.personId,
                gender: currentGender ?? gender
            )
        }

        reliefData.syncToValidPeople(
            validIds: Set(sharedPeople.map(\.id)),
            maxPeopleCount: sharedPeopleCount.total
        )
    }

    private func setSharedPeopleCountSilently(_ count: PeopleCount) {
        guard sharedPeopleCount != count else { return }
        isUpdatingSharedPeopleCount = true
        sharedPeopleCount = count
        isUpdatingSharedPeopleCount = false
    }

    private func makeManualSupplementalPeople(
        totalCount: PeopleCount,
        minimumCount: PeopleCount,
        existingNames: [String: String]
    ) -> [Person] {
        var people: [Person] = []
        appendManualSupplementalPeople(
            to: &people,
            type: .adult,
            totalCount: totalCount.adults,
            minimumCount: minimumCount.adults,
            existingNames: existingNames
        )
        appendManualSupplementalPeople(
            to: &people,
            type: .child,
            totalCount: totalCount.children,
            minimumCount: minimumCount.children,
            existingNames: existingNames
        )
        appendManualSupplementalPeople(
            to: &people,
            type: .elderly,
            totalCount: totalCount.elderly,
            minimumCount: minimumCount.elderly,
            existingNames: existingNames
        )
        return people
    }

    private func appendManualSupplementalPeople(
        to people: inout [Person],
        type: Person.PersonType,
        totalCount: Int,
        minimumCount: Int,
        existingNames: [String: String]
    ) {
        guard totalCount > minimumCount else { return }

        for index in (minimumCount + 1)...totalCount {
            let personId = "manual_\(type.idPrefix)_\(index)"
            var person = Person(id: personId, type: type, index: index)
            person.customName = existingNames[personId] ?? ""
            people.append(person)
        }
    }

    private func refreshVictimIdentityFromSavedSelection() {
        guard usesSavedRelativeProfiles else { return }

        let totalCount = sharedPeopleCount.total
        guard totalCount > 0 else {
            victimName = ""
            victimPhone = ""
            return
        }

        if totalCount == 1,
           selectedRelativeSnapshots.count == 1,
           !hasManualAdditionalPeople,
           let snapshot = selectedRelativeSnapshots.first {
            victimName = snapshot.displayName
            victimPhone = snapshot.phoneNumber ?? ""
        } else {
            victimName = "Nhóm \(totalCount) người"
            victimPhone = ""
        }
    }

    private func remapPersonScopedData(using idMap: [String: String], validIds: Set<String>) {
        reliefData.specialDietPersonIds = Set(
            reliefData.specialDietPersonIds.compactMap { idMap[$0] }
        )
        reliefData.specialDietInfoByPerson = Dictionary(
            uniqueKeysWithValues: reliefData.specialDietInfoByPerson.compactMap { key, value in
                guard let newKey = idMap[key] else { return nil }
                return (newKey, PersonSpecialDietInfo(personId: newKey, dietDescription: value.dietDescription))
            }
        )

        reliefData.clothingPersonIds = Set(
            reliefData.clothingPersonIds.compactMap { idMap[$0] }
        )
        reliefData.clothingInfoByPerson = Dictionary(
            uniqueKeysWithValues: reliefData.clothingInfoByPerson.compactMap { key, value in
                guard let newKey = idMap[key] else { return nil }
                return (newKey, ClothingPersonInfo(personId: newKey, gender: value.gender))
            }
        )

        rescueData.injuredPersonIds = Set(
            rescueData.injuredPersonIds.compactMap { idMap[$0] }
        )
        rescueData.medicalInfoByPerson = Dictionary(
            uniqueKeysWithValues: rescueData.medicalInfoByPerson.compactMap { key, value in
                guard let newKey = idMap[key] else { return nil }
                return (
                    newKey,
                    PersonMedicalInfo(
                        personId: newKey,
                        medicalIssues: value.medicalIssues,
                        otherDescription: value.otherDescription
                    )
                )
            }
        )

        rescueData.syncToValidPeople(validIds: validIds)
        reliefData.syncToValidPeople(validIds: validIds, maxPeopleCount: sharedPeopleCount.total)
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
            rescueData.situation = RescueSituation.trapped.rawValue
        case .flooding:
            rescueData.situation = RescueSituation.flooding.rawValue
        case .collapsed:
            rescueData.situation = RescueSituation.collapsed.rawValue
        }
    }

    func applyQuickFillSample() {
        appliedPreset = nil
        reportingTarget = .self
        reportingTargetSelectionMade = true
        resolvedAddress = SOSQuickFillSample.demoAddress
        addressQuery = SOSQuickFillSample.demoAddress
        manualLocation = SOSManualLocation(
            latitude: SOSQuickFillSample.demoLatitude,
            longitude: SOSQuickFillSample.demoLongitude,
            accuracy: nil
        )

        selectedTypes = [.rescue, .relief]
        additionalDescription = SOSQuickFillSample.additionalDescription
        supplementalMedicalContextItems = SOSQuickFillSample.medicalContextItems

        reliefData = SOSQuickFillSample.makeReliefData(peopleCount: sharedPeopleCount)
        rescueData = SOSQuickFillSample.makeRescueData(
            peopleCount: sharedPeopleCount,
            people: sharedPeople
        )

        let validIds = Set(sharedPeople.map(\.id))
        reliefData.syncToValidPeople(validIds: validIds, maxPeopleCount: sharedPeopleCount.total)
        rescueData.syncToValidPeople(validIds: validIds)
        completedSteps = []
        currentStep = .reportingMode
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
                parts.append("Tình trạng: \(situationTitle(for: situation))")
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
                        let issues = medicalInfo.medicalIssues
                            .map(medicalIssueTitle(for:))
                            .joined(separator: ", ")
                        let issueDescription = [issues.nilIfBlank, medicalInfo.otherDescription.nilIfBlank]
                            .compactMap { $0 }
                            .joined(separator: " - ")
                            .nilIfBlank ?? "Chưa rõ"
                        let nameLabel: String
                        if person.customName.isEmpty {
                            nameLabel = person.displayName
                        } else {
                            nameLabel = "\(person.type.title) \(person.index): \(person.customName)"
                        }
                        injuredInfo.append("\(nameLabel) - \(issueDescription)")
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
                parts.append("Nước: \(waterDurationTitle(for: waterDuration))")
            }

            if let foodDuration = reliefData.foodDuration {
                parts.append("Thực phẩm: \(foodDurationTitle(for: foodDuration))")
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
        if let userEnteredAdditionalDescription {
            parts.append("Ghi chú: \(userEnteredAdditionalDescription.replacingOccurrences(of: "\n", with: "; "))")
        }
        
        return parts.joined(separator: " | ")
    }
    
    /// Convert to structured JSON for server
    func toStructuredPayload() -> SOSStructuredPayload {
        SOSStructuredPayload(
            sosType: sosType?.rawValue,
            reliefData: needsReliefStep ? reliefData : nil,
            rescueData: needsRescueStep ? rescueData : nil,
            additionalDescription: packetAdditionalDescription,
            priorityScore: priorityScore,
            autoInfo: autoInfo
        )
    }
}

// MARK: - Wizard Steps

enum SOSWizardStep: Int, CaseIterable, Comparable {
    case reportingMode = 0
    case autoInfo = 1
    case selectType = 2
    case relief = 3     // 2A
    case rescue = 4     // 2B (same step number conceptually)
    case additionalInfo = 5
    case review = 6
    
    static func < (lhs: SOSWizardStep, rhs: SOSWizardStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var title: String {
        switch self {
        case .reportingMode: return "Phương thức gửi SOS"
        case .autoInfo: return "Nạn nhân & vị trí"
        case .selectType: return "Loại SOS"
        case .relief: return "Chi tiết cứu trợ"
        case .rescue: return "Chi tiết cứu hộ"
        case .additionalInfo: return "Mô tả thêm"
        case .review: return "Xác nhận"
        }
    }
    
    var stepNumber: Int {
        switch self {
        case .reportingMode: return 0
        case .autoInfo: return 1
        case .selectType: return 2
        case .relief, .rescue: return 3
        case .additionalInfo: return 4
        case .review: return 5
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

    var symbolName: String {
        switch self {
        case .needWaterFood: return "fork.knife"
        case .hasInjured: return "bandage.fill"
        case .trapped: return "exclamationmark.triangle.fill"
        case .flooding: return "drop.fill"
        case .collapsed: return "house.fill"
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
    func toSOSPacket(
        originIdOverride: String? = nil,
        packetIdOverride: String? = nil,
        timestampOverride: Date? = nil
    ) -> SOSPacket {
        let latitude = effectiveLocation?.latitude ?? 0
        let longitude = effectiveLocation?.longitude ?? 0
        let accuracy = effectiveLocation?.accuracy
        
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

        let structuredData = SOSStructuredData(
            incident: SOSIncidentData(
                situation: needsRescueStep ? rescueData.situation : nil,
                otherSituationDescription: needsRescueStep ? rescueData.otherSituationDescription.nilIfBlank : nil,
                address: addressToSend,
                additionalDescription: packetAdditionalDescription,
                peopleCount: SOSPeopleCount(
                    adult: sharedPeopleCount.adults,
                    child: sharedPeopleCount.children,
                    elderly: sharedPeopleCount.elderly
                ),
                hasInjured: needsRescueStep ? rescueData.hasInjured : nil,
                othersAreStable: {
                    guard needsRescueStep,
                          sharedPeopleCount.total > 1,
                          rescueData.injuredPersonIds.isEmpty == false,
                          rescueData.injuredPersonIds.count < sharedPeopleCount.total,
                          rescueData.othersAreStable else {
                        return nil
                    }
                    return true
                }(),
                canMove: needsRescueStep ? rescueData.canMove : nil,
                needMedical: needsRescueStep ? rescueData.hasInjured : nil,
                otherMedicalDescription: needsRescueStep ? rescueData.otherMedicalDescription.nilIfBlank : nil
            ),
            groupNeeds: packetGroupNeeds(),
            victims: sharedPeople.isEmpty ? nil : packetVictimEntries()
        )

        let originId = originIdOverride ?? autoInfo?.deviceId ?? UUID().uuidString
        let timestamp = timestampOverride ?? Date()

        return SOSPacket(
            packetId: packetIdOverride ?? UUID().uuidString,
            originId: originId,
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            address: addressToSend,
            sosType: sosTypeString,
            message: toSOSMessage(),
            structuredData: structuredData,
            // BE hiện link các nạn nhân/companions từ structured_data.victims[].person_phone.
            // Không gửi victim_info để tránh trùng nghĩa và tránh lệch dữ liệu với case nhiều người.
            victimInfo: nil,
            reporterInfo: packetReporterInfo,
            isSentOnBehalf: reportingTarget == .other,
            senderInfo: packetSenderInfo,
            hopCount: 0,
            path: []
        )
    }

    private func packetGroupNeeds() -> SOSGroupNeedsData? {
        guard needsReliefStep else { return nil }

        let orderedSupplies = SupplyNeed.allCases
            .filter { reliefData.supplies.contains($0) }
            .map(\.rawValue)
        let orderedMedicineConditions = MedicineCondition.allCases
            .filter { reliefData.medicineConditions.contains($0) }
            .map(\.rawValue)
        let orderedMedicalNeeds = MedicalSupportNeed.allCases
            .filter { reliefData.medicalNeeds.contains($0) }
            .map(\.rawValue)

        let water = reliefData.waterDuration != nil
            ? SOSWaterNeedData(
                duration: reliefData.waterDuration,
                remaining: nil
            )
            : nil

        let food = reliefData.foodDuration != nil
            ? SOSFoodNeedData(duration: reliefData.foodDuration)
            : nil

        let blanket = reliefData.isColdOrWet != nil ||
            reliefData.blanketAvailability != nil ||
            reliefData.blanketRequestCount != nil
            ? SOSBlanketNeedData(
                isColdOrWet: reliefData.isColdOrWet,
                availability: reliefData.blanketAvailability?.rawValue,
                requestCount: reliefData.areBlanketsEnough == true ? nil : reliefData.blanketRequestCount
            )
            : nil

        let medicine = reliefData.needsUrgentMedicine != nil ||
            !orderedMedicineConditions.isEmpty ||
            reliefData.medicineOtherDescription.nilIfBlank != nil ||
            !orderedMedicalNeeds.isEmpty ||
            reliefData.medicalDescription.nilIfBlank != nil
            ? SOSMedicineNeedData(
                needsUrgentMedicine: reliefData.needsUrgentMedicine,
                conditions: orderedMedicineConditions.isEmpty ? nil : orderedMedicineConditions,
                otherDescription: reliefData.medicineOtherDescription.nilIfBlank,
                medicalNeeds: orderedMedicalNeeds.isEmpty ? nil : orderedMedicalNeeds,
                medicalDescription: reliefData.medicalDescription.nilIfBlank
            )
            : nil

        let clothing = reliefData.clothingStatus != nil
            ? SOSClothingGroupNeedData(status: reliefData.clothingStatus?.rawValue)
            : nil

        let hasContent = !orderedSupplies.isEmpty ||
            water != nil ||
            food != nil ||
            blanket != nil ||
            medicine != nil ||
            clothing != nil ||
            reliefData.otherSupplyDescription.nilIfBlank != nil

        guard hasContent else { return nil }

        return SOSGroupNeedsData(
            supplies: orderedSupplies.isEmpty ? nil : orderedSupplies,
            water: water,
            food: food,
            blanket: blanket,
            medicine: medicine,
            clothing: clothing,
            otherSupplyDescription: reliefData.otherSupplyDescription.nilIfBlank
        )
    }

    private func packetVictimEntries() -> [SOSVictimEntry] {
        sharedPeople.map { person in
            let snapshot = selectedRelativeSnapshot(for: person.id)
            let manualSingleVictimName: String? = {
                guard reportingTarget == .other, !usesSavedRelativeProfiles, sharedPeopleCount.total == 1 else {
                    return nil
                }
                return effectiveVictimName?.nilIfBlank
            }()
            let manualSingleVictimPhone: String? = {
                guard reportingTarget == .other, !usesSavedRelativeProfiles, sharedPeopleCount.total == 1 else {
                    return nil
                }
                return effectiveVictimPhone?.nilIfBlank
            }()
            let isInjured = needsRescueStep && rescueData.injuredPersonIds.contains(person.id)
            let issues = isInjured
                ? Array(rescueData.medicalInfoByPerson[person.id]?.medicalIssues ?? [])
                : []
            let severity: String? = {
                guard isInjured else { return nil }
                let personIssues = rescueData.medicalInfoByPerson[person.id]?.medicalIssues ?? []
                let meaningfulIssues = personIssues.filter { $0 != MedicalIssue.other.rawValue }
                guard meaningfulIssues.isEmpty == false else { return nil }
                return meaningfulIssues.contains(where: { ruleConfig.isSevereMedicalIssue($0) }) ? "CRITICAL" : "HIGH"
            }()
            let resolvedName = manualSingleVictimName
                ?? person.displayName.nilIfBlank
                ?? snapshot?.displayName.nilIfBlank
                ?? "\(person.type.title) \(person.index)"
            let dietDescription = needsReliefStep
                ? reliefData.specialDietInfoByPerson[person.id]?.dietDescription.nilIfBlank
                : nil

            return SOSVictimEntry(
                personId: person.id,
                personType: person.type.rawValue,
                index: person.index,
                customName: resolvedName,
                personPhone: snapshot?.phoneNumber?.nilIfBlank ?? manualSingleVictimPhone,
                incidentStatus: SOSVictimIncidentStatus(
                    isInjured: isInjured,
                    severity: severity,
                    medicalIssues: issues
                ),
                personalNeeds: SOSVictimPersonalNeeds(
                    clothing: SOSVictimClothingNeed(
                        needed: needsReliefStep && reliefData.clothingPersonIds.contains(person.id),
                        gender: reliefData.clothingInfoByPerson[person.id]?.gender?.rawValue ?? snapshot?.gender?.rawValue
                    ),
                    diet: SOSVictimDietNeed(
                        hasSpecialDiet: needsReliefStep && (
                            reliefData.specialDietPersonIds.contains(person.id) ||
                            dietDescription != nil
                        ),
                        description: dietDescription
                    )
                )
            )
        }
    }
}
