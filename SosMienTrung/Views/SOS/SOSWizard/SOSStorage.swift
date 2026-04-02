//
//  SOSStorage.swift
//  SosMienTrung
//
//  Lưu trữ SOS đã gửi với đầy đủ structured data để xem lại và chỉnh sửa
//

import Foundation
import SwiftUI
import Combine

/// SOS đã lưu với đầy đủ thông tin
struct SavedSOS: Codable, Identifiable, Equatable {
    var id: String                          // packetId (có thể được update sang server packetId sau sync)
    let timestamp: Date
    let sosType: SOSType?
    let latitude: Double?
    let longitude: Double?
    let message: String
    
    // Structured data
    var sharedPeople: [Person]
    var personSourceMode: SOSPersonSourceMode
    var selectedRelativeSnapshots: [SelectedRelativeSnapshot]
    var reliefData: ReliefData?
    var rescueData: SavedRescueData?
    var additionalDescription: String
    
    // Status
    var status: SOSSendStatus
    var lastUpdated: Date
    
    // Lịch sử gửi
    var sendHistory: [SOSSendEvent]
    
    // Victim / reporter info
    let reportingTarget: SOSReportingTarget
    let victimName: String?
    let victimPhone: String?
    let reporterName: String?
    let reporterPhone: String?
    let addressQuery: String
    let resolvedAddress: String?
    let manualLocation: SOSManualLocation?
    
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
        self.sharedPeople = formData.sharedPeople
        self.personSourceMode = formData.personSourceMode
        self.selectedRelativeSnapshots = formData.selectedRelativeSnapshots
        
        // Lưu cả relief và rescue data nếu có
        if formData.needsReliefStep {
            self.reliefData = formData.reliefData
        } else {
            self.reliefData = nil
        }
        
        if formData.needsRescueStep {
            self.rescueData = SavedRescueData(from: formData.rescueData)
        } else {
            self.rescueData = nil
        }
        
        self.additionalDescription = formData.additionalDescription
        self.status = .pending
        self.lastUpdated = Date()
        self.sendHistory = [SOSSendEvent(type: .created)]
        self.reportingTarget = formData.reportingTarget
        self.victimName = formData.effectiveVictimName
        self.victimPhone = formData.effectiveVictimPhone
        self.reporterName = formData.autoInfo?.userName
        self.reporterPhone = formData.autoInfo?.userPhone
        self.addressQuery = formData.addressQuery
        self.resolvedAddress = formData.resolvedAddress
        self.manualLocation = formData.manualLocation
        self.isMine = true
    }
    
    /// Khôi phục lại SOSFormData để chỉnh sửa
    func toFormData() -> SOSFormData {
        let formData = SOSFormData()
        
        // Khôi phục selectedTypes từ sosType và data có sẵn
        if let type = sosType {
            formData.selectedTypes.insert(type)
        }
        // Nếu có cả relief và rescue data, thêm cả 2 type
        if reliefData != nil && !formData.selectedTypes.contains(.relief) {
            formData.selectedTypes.insert(.relief)
        }
        if rescueData != nil && !formData.selectedTypes.contains(.rescue) {
            formData.selectedTypes.insert(.rescue)
        }
        
        formData.additionalDescription = additionalDescription
        
        if let relief = reliefData {
            formData.reliefData = relief
            formData.sharedPeopleCount = relief.peopleCount
        }
        
        if let rescue = rescueData {
            formData.rescueData = rescue.toRescueData()
            formData.sharedPeopleCount = rescue.peopleCount
        }

        formData.personSourceMode = personSourceMode
        formData.selectedRelativeSnapshots = selectedRelativeSnapshots

        let restoredPeople = !sharedPeople.isEmpty
            ? sharedPeople
            : (rescueData?.people ?? [])
        if !restoredPeople.isEmpty {
            formData.restoreSharedPeople(restoredPeople)
        } else {
            formData.syncPeopleCount()
        }
        
        formData.reportingTarget = reportingTarget
        formData.victimName = victimName ?? ""
        formData.victimPhone = victimPhone ?? ""
        formData.addressQuery = addressQuery
        formData.resolvedAddress = resolvedAddress
        formData.manualLocation = manualLocation

        // Set auto info nếu có location
        if let lat = latitude, let lon = longitude {
            formData.autoInfo = AutoCollectedInfo(
                deviceId: UserProfile.shared.currentUser?.id.uuidString ?? "",
                userId: AuthSessionStore.shared.session?.userId,
                userName: reporterName,
                userPhone: reporterPhone,
                timestamp: timestamp,
                latitude: lat,
                longitude: lon
            )
        }
        
        return formData
    }
    
    /// Tạo từ record trả về bởi server (GET /emergency/sos-requests/me)
    init(fromServer record: SOSServerRecord) {
        self.id          = record.packetId
        self.timestamp   = Date(timeIntervalSince1970: TimeInterval(record.timestamp))
        self.sosType     = SOSType(rawValue: record.sosType ?? "")
        self.latitude    = record.latitude
        self.longitude   = record.longitude
        self.message     = record.rawMessage
        self.sharedPeople = []
        self.personSourceMode = .manual
        self.selectedRelativeSnapshots = []
        self.reliefData  = nil
        self.rescueData  = nil
        self.additionalDescription = record.structuredData?.additionalDescription ?? ""
        self.status      = SOSServerRecord.mapStatus(record.status)
        self.lastUpdated = Date()
        self.sendHistory = [SOSSendEvent(type: .serverAcknowledged, note: "Đồng bộ từ server (trạng thái: \(record.status ?? "unknown"))")]
        self.reportingTarget = record.isSentOnBehalf == true ? .other : .self
        self.victimName  = record.victimInfo?.userName ?? record.senderInfo?.userName
        self.victimPhone = record.victimInfo?.userPhone ?? record.senderInfo?.userPhone
        self.reporterName = record.reporterInfo?.userName ?? (record.isSentOnBehalf == true ? nil : record.senderInfo?.userName)
        self.reporterPhone = record.reporterInfo?.userPhone ?? (record.isSentOnBehalf == true ? nil : record.senderInfo?.userPhone)
        self.addressQuery = record.structuredData?.address ?? ""
        self.resolvedAddress = record.structuredData?.address
        if record.structuredData?.address != nil,
           let latitude = record.latitude,
           let longitude = record.longitude {
            self.manualLocation = SOSManualLocation(latitude: latitude, longitude: longitude, accuracy: record.locationAccuracy)
        } else {
            self.manualLocation = nil
        }
        self.isMine      = true
    }
    
    // MARK: - Codable (backward compat cho sendHistory)
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, sosType, latitude, longitude, message
        case sharedPeople, personSourceMode, selectedRelativeSnapshots, reliefData, rescueData, additionalDescription
        case status, lastUpdated, sendHistory
        case reportingTarget, victimName, victimPhone, reporterName, reporterPhone
        case addressQuery, resolvedAddress, manualLocation
        case senderName, senderPhone, isMine
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let legacySenderName = try c.decodeIfPresent(String.self, forKey: .senderName)
        let legacySenderPhone = try c.decodeIfPresent(String.self, forKey: .senderPhone)
        id                   = try c.decode(String.self, forKey: .id)
        timestamp            = try c.decode(Date.self, forKey: .timestamp)
        sosType              = try c.decodeIfPresent(SOSType.self, forKey: .sosType)
        latitude             = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude            = try c.decodeIfPresent(Double.self, forKey: .longitude)
        message              = try c.decode(String.self, forKey: .message)
        sharedPeople         = (try? c.decodeIfPresent([Person].self, forKey: .sharedPeople)) ?? []
        personSourceMode     = try c.decodeIfPresent(SOSPersonSourceMode.self, forKey: .personSourceMode) ?? .manual
        selectedRelativeSnapshots = (try? c.decodeIfPresent([SelectedRelativeSnapshot].self, forKey: .selectedRelativeSnapshots)) ?? []
        reliefData           = try c.decodeIfPresent(ReliefData.self, forKey: .reliefData)
        rescueData           = try c.decodeIfPresent(SavedRescueData.self, forKey: .rescueData)
        additionalDescription = try c.decode(String.self, forKey: .additionalDescription)
        status               = try c.decode(SOSSendStatus.self, forKey: .status)
        lastUpdated          = try c.decode(Date.self, forKey: .lastUpdated)
        // sendHistory không tồn tại ở dữ liệu cũ → mặc định []
        sendHistory          = (try? c.decodeIfPresent([SOSSendEvent].self, forKey: .sendHistory)) ?? []
        reportingTarget      = try c.decodeIfPresent(SOSReportingTarget.self, forKey: .reportingTarget) ?? .self
        victimName           = try c.decodeIfPresent(String.self, forKey: .victimName) ?? legacySenderName
        victimPhone          = try c.decodeIfPresent(String.self, forKey: .victimPhone) ?? legacySenderPhone
        reporterName         = try c.decodeIfPresent(String.self, forKey: .reporterName) ?? legacySenderName
        reporterPhone        = try c.decodeIfPresent(String.self, forKey: .reporterPhone) ?? legacySenderPhone
        addressQuery         = try c.decodeIfPresent(String.self, forKey: .addressQuery) ?? ""
        resolvedAddress      = try c.decodeIfPresent(String.self, forKey: .resolvedAddress)
        manualLocation       = try c.decodeIfPresent(SOSManualLocation.self, forKey: .manualLocation)
        isMine               = try c.decode(Bool.self, forKey: .isMine)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sosType, forKey: .sosType)
        try c.encodeIfPresent(latitude, forKey: .latitude)
        try c.encodeIfPresent(longitude, forKey: .longitude)
        try c.encode(message, forKey: .message)
        try c.encode(sharedPeople, forKey: .sharedPeople)
        try c.encode(personSourceMode, forKey: .personSourceMode)
        try c.encode(selectedRelativeSnapshots, forKey: .selectedRelativeSnapshots)
        try c.encodeIfPresent(reliefData, forKey: .reliefData)
        try c.encodeIfPresent(rescueData, forKey: .rescueData)
        try c.encode(additionalDescription, forKey: .additionalDescription)
        try c.encode(status, forKey: .status)
        try c.encode(lastUpdated, forKey: .lastUpdated)
        try c.encode(sendHistory, forKey: .sendHistory)
        try c.encode(reportingTarget, forKey: .reportingTarget)
        try c.encodeIfPresent(victimName, forKey: .victimName)
        try c.encodeIfPresent(victimPhone, forKey: .victimPhone)
        try c.encodeIfPresent(reporterName, forKey: .reporterName)
        try c.encodeIfPresent(reporterPhone, forKey: .reporterPhone)
        try c.encode(addressQuery, forKey: .addressQuery)
        try c.encodeIfPresent(resolvedAddress, forKey: .resolvedAddress)
        try c.encodeIfPresent(manualLocation, forKey: .manualLocation)
        // Keep legacy keys so older local payloads can still read the victim identity.
        try c.encodeIfPresent(victimName, forKey: .senderName)
        try c.encodeIfPresent(victimPhone, forKey: .senderPhone)
        try c.encode(isMine, forKey: .isMine)
    }
}

/// Status của SOS đã gửi
enum SOSSendStatus: String, Codable {
    case draft = "DRAFT"        // Nháp
    case pending = "PENDING"    // Đang gửi (chưa lên server)
    case sent = "SENT"          // Đã gửi lên server
    case delivered = "DELIVERED" // Server đã xác nhận
    case relayed = "RELAYED"    // Đang relay qua mesh
    case resolved = "RESOLVED"  // Đã xử lý xong
    
    var title: String {
        switch self {
        case .draft: return "Nháp"
        case .pending: return "Đang gửi"
        case .sent: return "Đã gửi"
        case .delivered: return "Đã nhận"
        case .relayed: return "Đang relay"
        case .resolved: return "Đã xử lý"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return .gray
        case .pending: return .orange
        case .sent: return .blue
        case .delivered: return .green
        case .relayed: return .purple
        case .resolved: return Color(red: 0.2, green: 0.7, blue: 0.4)
        }
    }
    
    var icon: String {
        switch self {
        case .draft: return "doc"
        case .pending: return "clock.arrow.circlepath"
        case .sent: return "arrow.up.circle.fill"
        case .delivered: return "checkmark.circle.fill"
        case .relayed: return "antenna.radiowaves.left.and.right"
        case .resolved: return "checkmark.seal.fill"
        }
    }
}

// MARK: - SOS Send Event

/// Loại sự kiện trong lịch sử gửi SOS
enum SOSSendEventType: String, Codable {
    case created = "CREATED"                   // Tạo ra cục bộ
    case sentViaNetwork = "SENT_NETWORK"        // Gửi trực tiếp qua mạng lên server
    case sentViaMesh = "SENT_MESH"              // Broadcast qua Mesh để nhờ relay
    case pendingRetry = "PENDING_RETRY"         // Đang chờ retry (chưa có mạng)
    case serverAcknowledged = "SERVER_ACK"      // Server đã xác nhận nhận được
    
    var title: String {
        switch self {
        case .created:            return "Đã tạo"
        case .sentViaNetwork:     return "Gửi qua Internet"
        case .sentViaMesh:        return "Phát qua Mesh Network"
        case .pendingRetry:       return "Chờ gửi lại"
        case .serverAcknowledged: return "Server xác nhận"
        }
    }
    
    var icon: String {
        switch self {
        case .created:            return "plus.circle.fill"
        case .sentViaNetwork:     return "wifi"
        case .sentViaMesh:        return "antenna.radiowaves.left.and.right"
        case .pendingRetry:       return "clock.arrow.circlepath"
        case .serverAcknowledged: return "checkmark.seal.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .created:            return .gray
        case .sentViaNetwork:     return .blue
        case .sentViaMesh:        return .purple
        case .pendingRetry:       return .orange
        case .serverAcknowledged: return .green
        }
    }
}

/// Một sự kiện trong lịch sử gửi SOS
struct SOSSendEvent: Codable, Identifiable, Equatable {
    let id: String
    let timestamp: Date
    let type: SOSSendEventType
    let note: String?
    
    init(type: SOSSendEventType, note: String? = nil) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.type = type
        self.note = note
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
    var people: [Person]
    
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
        self.people = rescueData.people
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
        data.people = people
        if data.people.isEmpty {
            data.generatePeople()
        }
        return data
    }
}

// MARK: - Server Response Models

/// Record SOS trả về từ API /emergency/sos-requests/me
struct SOSServerRecord: Codable {
    let id: Int
    let packetId: String
    let clusterId: Int?
    let userId: String?
    let sosType: String?
    let rawMessage: String
    let structuredData: SOSStructuredData?
    let networkMetadata: SOSNetworkMetadata?
    let victimInfo: SOSVictimInfo?
    let reporterInfo: SOSReporterInfo?
    let isSentOnBehalf: Bool?
    let senderInfo: SOSSenderInfo?
    let originId: String?
    let status: String?
    let priorityLevel: String?
    let waitTimeMinutes: Int?
    let latitude: Double?
    let longitude: Double?
    let locationAccuracy: Double?
    let timestamp: Int64
    let createdAt: String?
    let lastUpdatedAt: String?
    let reviewedAt: String?
    let reviewedById: String?

    enum CodingKeys: String, CodingKey {
        case id, packetId, clusterId, userId, sosType, rawMessage
        case structuredData = "structuredData"
        case networkMetadata = "networkMetadata"
        case victimInfo = "victimInfo"
        case reporterInfo = "reporterInfo"
        case isSentOnBehalf = "isSentOnBehalf"
        case senderInfo = "senderInfo"
        case originId, status, priorityLevel, waitTimeMinutes
        case latitude, longitude, locationAccuracy, timestamp
        case createdAt, lastUpdatedAt, reviewedAt, reviewedById
    }

    /// Map server status string → SOSSendStatus
    static func mapStatus(_ raw: String?) -> SOSSendStatus {
        switch raw {
        case "Pending":                 return .sent
        case "Approved", "InProgress":  return .delivered
        case "Resolved", "Closed":      return .resolved
        default:                        return .sent
        }
    }
}

struct SOSServerResponse: Codable {
    let sosRequests: [SOSServerRecord]
}

// MARK: - SOS Storage Manager

final class SOSStorageManager: ObservableObject {
    nonisolated static let shared = SOSStorageManager()
    
    private var currentUserId: String?
    @Published private(set) var savedSOSList: [SavedSOS] = []
    
    private init() {
        // Nếu app restart và user đã đăng nhập trước đó
        if let userId = AuthSessionStore.shared.session?.userId {
            currentUserId = userId
            loadFromStorage()
        }
    }
    
    private func storageKey(for userId: String) -> String {
        "saved_sos_list_\(userId)"
    }
    
    // MARK: - Session Management
    
    /// Gọi khi đăng nhập thành công — load dữ liệu local của user đó
    func reloadForUser(_ userId: String) {
        currentUserId = userId
        loadFromStorage()
    }
    
    /// Gọi khi đăng xuất — xóa in-memory (dữ liệu local vẫn giữ trong UserDefaults)
    func clearSession() {
        currentUserId = nil
        savedSOSList = []
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
    
    /// Ghi thêm sự kiện vào lịch sử gửi của SOS
    func addSendEvent(id: String, event: SOSSendEvent) {
        if let index = savedSOSList.firstIndex(where: { $0.id == id }) {
            savedSOSList[index].sendHistory.append(event)
            savedSOSList[index].lastUpdated = Date()
            saveToStorage()
        }
    }
    
    /// Cập nhật status và đồng thời ghi sự kiện vào lịch sử
    func updateStatusWithEvent(id: String, status: SOSSendStatus, event: SOSSendEvent) {
        if let index = savedSOSList.firstIndex(where: { $0.id == id }) {
            savedSOSList[index].status = status
            savedSOSList[index].lastUpdated = Date()
            savedSOSList[index].sendHistory.append(event)
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
    
    // MARK: - Server Sync
    
    /// Fetch từ /emergency/sos-requests/me và merge vào local list
    func fetchAndMergeFromServer() async {
        guard let records = await APIService.shared.fetchMySOS() else { return }
        await MainActor.run {
            for record in records {
                let serverTs = Date(timeIntervalSince1970: TimeInterval(record.timestamp))
                let serverStatus = SOSServerRecord.mapStatus(record.status)

                // 1. Khớp chính xác theo packetId
                if let index = savedSOSList.firstIndex(where: { $0.id.caseInsensitiveCompare(record.packetId) == .orderedSame }) {
                    updateStatusIfNeeded(at: index, serverStatus: serverStatus)

                // 2. Khớp mờ: cùng sosType + timestamp ±120s (server có thể dùng UUID riêng)
                } else if let index = savedSOSList.firstIndex(where: {
                    $0.isMine &&
                    $0.sosType?.rawValue == record.sosType &&
                    abs($0.timestamp.timeIntervalSince(serverTs)) < 120
                }) {
                    print("[SOS Sync] 🔄 Fuzzy match – cập nhật id local \(savedSOSList[index].id) → server \(record.packetId)")
                    // Đồng bộ id về server packetId để lần sau khớp chính xác
                    savedSOSList[index].id = record.packetId
                    updateStatusIfNeeded(at: index, serverStatus: serverStatus)

                // 3. Record chỉ tồn tại trên server (gửi từ session/thiết bị khác)
                } else {
                    let saved = SavedSOS(fromServer: record)
                    savedSOSList.append(saved)
                }
            }
            savedSOSList.sort { $0.timestamp > $1.timestamp }
            saveToStorage()
        }
    }
    
    private func updateStatusIfNeeded(at index: Int, serverStatus: SOSSendStatus) {
        if savedSOSList[index].status != serverStatus {
            let event = SOSSendEvent(type: .serverAcknowledged,
                                    note: "Cập nhật từ server: \(serverStatus.title)")
            savedSOSList[index].status      = serverStatus
            savedSOSList[index].lastUpdated  = Date()
            savedSOSList[index].sendHistory.append(event)
        }
    }
    
    // MARK: - Private Methods
    
    private func saveToStorage() {
        guard let userId = currentUserId else { return }
        do {
            let data = try JSONEncoder().encode(savedSOSList)
            UserDefaults.standard.set(data, forKey: storageKey(for: userId))
        } catch {
            print("❌ Failed to save SOS list: \(error)")
        }
    }
    
    private func loadFromStorage() {
        guard let userId = currentUserId else {
            savedSOSList = []
            return
        }
        let key = storageKey(for: userId)
        guard let data = UserDefaults.standard.data(forKey: key) else {
            savedSOSList = []
            return
        }
        do {
            var list = try JSONDecoder().decode([SavedSOS].self, from: data)
            // Loại bỏ trùng lặp: cùng message + sosType + timestamp ±30s
            // Ưu tiên giữ bản có sendHistory dài hơn (bản đã sync với server)
            list = deduplicateList(list)
            savedSOSList = list
        } catch {
            print("❌ Failed to load SOS list: \(error)")
            savedSOSList = []
        }
    }
    
    /// Loại bỏ các entry trùng nội dung, giữ bản có nhiều sendHistory nhất
    private func deduplicateList(_ list: [SavedSOS]) -> [SavedSOS] {
        var seen: [SavedSOS] = []
        for item in list {
            if let existingIndex = seen.firstIndex(where: {
                $0.sosType == item.sosType &&
                $0.message == item.message &&
                abs($0.timestamp.timeIntervalSince(item.timestamp)) < 30
            }) {
                // Giữ bản có sendHistory dài hơn (hoặc mới được update hơn)
                if item.sendHistory.count > seen[existingIndex].sendHistory.count ||
                   item.lastUpdated > seen[existingIndex].lastUpdated {
                    seen[existingIndex] = item
                }
            } else {
                seen.append(item)
            }
        }
        let before = list.count
        let after = seen.count
        if before != after {
            print("[SOS Storage] 🧹 Dedup: \(before) → \(after) records")
        }
        return seen
    }}
