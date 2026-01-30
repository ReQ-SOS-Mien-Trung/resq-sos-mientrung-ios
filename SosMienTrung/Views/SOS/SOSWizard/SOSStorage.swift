//
//  SOSStorage.swift
//  SosMienTrung
//
//  Lưu trữ SOS đã gửi với đầy đủ structured data để xem lại và chỉnh sửa
//

import Foundation
import SwiftUI

/// SOS đã lưu với đầy đủ thông tin
struct SavedSOS: Codable, Identifiable, Equatable {
    let id: String                          // packetId
    let timestamp: Date
    let sosType: SOSType?
    let latitude: Double?
    let longitude: Double?
    let message: String
    
    // Structured data
    var reliefData: ReliefData?
    var rescueData: SavedRescueData?
    var additionalDescription: String
    
    // Status
    var status: SOSSendStatus
    var lastUpdated: Date
    
    // Sender info
    let senderName: String?
    let senderPhone: String?
    
    /// Kiểm tra có phải của mình không
    var isMine: Bool
    
    /// Tạo từ SOSFormData khi gửi mới
    init(from formData: SOSFormData, packetId: String, latitude: Double?, longitude: Double?) {
        self.id = packetId
        self.timestamp = Date()
        self.sosType = formData.sosType
        self.latitude = latitude
        self.longitude = longitude
        self.message = formData.toSOSMessage()
        
        if formData.sosType == .relief {
            self.reliefData = formData.reliefData
            self.rescueData = nil
        } else if formData.sosType == .rescue {
            self.reliefData = nil
            self.rescueData = SavedRescueData(from: formData.rescueData)
        } else {
            self.reliefData = nil
            self.rescueData = nil
        }
        
        self.additionalDescription = formData.additionalDescription
        self.status = .sent
        self.lastUpdated = Date()
        self.senderName = formData.autoInfo?.userName
        self.senderPhone = formData.autoInfo?.userPhone
        self.isMine = true
    }
    
    /// Khôi phục lại SOSFormData để chỉnh sửa
    func toFormData() -> SOSFormData {
        let formData = SOSFormData()
        formData.sosType = sosType
        formData.additionalDescription = additionalDescription
        
        if let relief = reliefData {
            formData.reliefData = relief
        }
        
        if let rescue = rescueData {
            formData.rescueData = rescue.toRescueData()
        }
        
        // Set auto info nếu có location
        if let lat = latitude, let lon = longitude {
            formData.autoInfo = AutoCollectedInfo(
                deviceId: UserProfile.shared.currentUser?.id.uuidString ?? "",
                userId: UserProfile.shared.currentUser?.id.uuidString,
                userName: senderName,
                userPhone: senderPhone,
                timestamp: timestamp,
                latitude: lat,
                longitude: lon
            )
        }
        
        return formData
    }
}

/// Status của SOS đã gửi
enum SOSSendStatus: String, Codable {
    case draft = "DRAFT"        // Nháp
    case sent = "SENT"          // Đã gửi
    case delivered = "DELIVERED" // Đã nhận
    case relayed = "RELAYED"    // Đã relay
    case resolved = "RESOLVED"  // Đã xử lý xong
    
    var title: String {
        switch self {
        case .draft: return "Nháp"
        case .sent: return "Đã gửi"
        case .delivered: return "Đã nhận"
        case .relayed: return "Đã relay"
        case .resolved: return "Đã xử lý"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return .gray
        case .sent: return .orange
        case .delivered: return .blue
        case .relayed: return .purple
        case .resolved: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .draft: return "doc"
        case .sent: return "arrow.up.circle"
        case .delivered: return "checkmark.circle"
        case .relayed: return "arrow.triangle.branch"
        case .resolved: return "checkmark.seal"
        }
    }
}

/// Phiên bản lưu trữ của RescueData (Codable friendly)
struct SavedRescueData: Codable, Equatable {
    var situation: RescueSituation?
    var otherSituationDescription: String
    var peopleCount: PeopleCount
    var hasInjured: Bool
    var injuredPersonIds: [String]
    var medicalInfoByPerson: [String: PersonMedicalInfo]
    var medicalIssues: [MedicalIssue]
    var otherMedicalDescription: String
    var othersAreStable: Bool
    
    init(from rescueData: RescueData) {
        self.situation = rescueData.situation
        self.otherSituationDescription = rescueData.otherSituationDescription
        self.peopleCount = rescueData.peopleCount
        self.hasInjured = rescueData.hasInjured
        self.injuredPersonIds = Array(rescueData.injuredPersonIds)
        self.medicalInfoByPerson = rescueData.medicalInfoByPerson
        self.medicalIssues = Array(rescueData.medicalIssues)
        self.otherMedicalDescription = rescueData.otherMedicalDescription
        self.othersAreStable = rescueData.othersAreStable
    }
    
    func toRescueData() -> RescueData {
        var data = RescueData()
        data.situation = situation
        data.otherSituationDescription = otherSituationDescription
        data.peopleCount = peopleCount
        data.hasInjured = hasInjured
        data.injuredPersonIds = Set(injuredPersonIds)
        data.medicalInfoByPerson = medicalInfoByPerson
        data.medicalIssues = Set(medicalIssues)
        data.otherMedicalDescription = otherMedicalDescription
        data.othersAreStable = othersAreStable
        data.generatePeople()
        return data
    }
}

// MARK: - SOS Storage Manager

@Observable
final class SOSStorageManager {
    static let shared = SOSStorageManager()
    
    private let storageKey = "saved_sos_list"
    private(set) var savedSOSList: [SavedSOS] = []
    
    private init() {
        loadFromStorage()
    }
    
    // MARK: - Public Methods
    
    /// Lưu SOS mới khi gửi
    func saveSOS(_ formData: SOSFormData, packetId: String, latitude: Double?, longitude: Double?) {
        let savedSOS = SavedSOS(from: formData, packetId: packetId, latitude: latitude, longitude: longitude)
        savedSOSList.insert(savedSOS, at: 0) // Mới nhất lên đầu
        saveToStorage()
    }
    
    /// Cập nhật SOS đã lưu
    func updateSOS(_ sos: SavedSOS) {
        if let index = savedSOSList.firstIndex(where: { $0.id == sos.id }) {
            var updated = sos
            updated.lastUpdated = Date()
            savedSOSList[index] = updated
            saveToStorage()
        }
    }
    
    /// Cập nhật status của SOS
    func updateStatus(id: String, status: SOSSendStatus) {
        if let index = savedSOSList.firstIndex(where: { $0.id == id }) {
            savedSOSList[index].status = status
            savedSOSList[index].lastUpdated = Date()
            saveToStorage()
        }
    }
    
    /// Xóa SOS
    func deleteSOS(id: String) {
        savedSOSList.removeAll { $0.id == id }
        saveToStorage()
    }
    
    /// Lấy SOS theo ID
    func getSOS(id: String) -> SavedSOS? {
        savedSOSList.first { $0.id == id }
    }
    
    /// SOS do mình gửi
    var mySOS: [SavedSOS] {
        savedSOSList.filter { $0.isMine }
    }
    
    // MARK: - Private Methods
    
    private func saveToStorage() {
        do {
            let data = try JSONEncoder().encode(savedSOSList)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ Failed to save SOS list: \(error)")
        }
    }
    
    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            savedSOSList = try JSONDecoder().decode([SavedSOS].self, from: data)
        } catch {
            print("❌ Failed to load SOS list: \(error)")
            savedSOSList = []
        }
    }
}
