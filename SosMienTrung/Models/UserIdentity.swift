//
//  UserIdentity.swift
//  SosMienTrung
//
//  Data models for user identity and delegation tokens
//  used in offline P2P account handover.
//

import Foundation

// MARK: - User Identity
/// Represents the application-layer identity of a user
/// Independent of Bridgefy Peer ID (transport layer)
struct UserIdentity: Codable, Identifiable, Equatable {
    let id: String  // Unique user identifier (UUID string)
    var displayName: String
    var phoneNumber: String
    var role: UserRole
    var activeMissions: [String]  // IDs of active rescue missions
    var publicKeyData: Data  // The user's public key for verification
    var createdAt: Date
    var lastActiveAt: Date
    
    enum UserRole: String, Codable, CaseIterable {
        case civilian = "civilian"
        case rescuer = "rescuer"
        case coordinator = "coordinator"
        case admin = "admin"
        
        var displayName: String {
            switch self {
            case .civilian: return "Người dân"
            case .rescuer: return "Cứu hộ viên"
            case .coordinator: return "Điều phối viên"
            case .admin: return "Quản trị viên"
            }
        }
        
        var icon: String {
            switch self {
            case .civilian: return "person.fill"
            case .rescuer: return "cross.case.fill"
            case .coordinator: return "person.2.wave.2.fill"
            case .admin: return "shield.checkered"
            }
        }
    }
    
    init(
        id: String = UUID().uuidString,
        displayName: String,
        phoneNumber: String,
        role: UserRole = .civilian,
        activeMissions: [String] = [],
        publicKeyData: Data,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.phoneNumber = phoneNumber
        self.role = role
        self.activeMissions = activeMissions
        self.publicKeyData = publicKeyData
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
    
    /// Create a copy with updated public key (for handover to new device)
    func withNewPublicKey(_ newPublicKey: Data) -> UserIdentity {
        var copy = self
        copy.publicKeyData = newPublicKey
        copy.lastActiveAt = Date()
        return copy
    }
}

// MARK: - Delegation Token
/// One-time-use token for transferring identity between devices
struct DelegationToken: Codable {
    let tokenId: String  // Unique token identifier
    let userIdentity: UserIdentity  // The identity being transferred
    let issuedAt: Date
    let expiresAt: Date
    let newDevicePublicKey: Data  // Public key of the new device
    let oldDevicePublicKey: Data  // Public key of the old device (for verification)
    var signatureByOldDevice: Data?  // Signature by old device's private key
    let nonce: String  // Prevent replay attacks
    
    // Token validity duration (5-15 minutes)
    static let defaultTTLSeconds: TimeInterval = 10 * 60  // 10 minutes
    static let minTTLSeconds: TimeInterval = 5 * 60  // 5 minutes
    static let maxTTLSeconds: TimeInterval = 15 * 60  // 15 minutes
    
    /// Data used for signing (excludes signature field)
    var signingPayload: DelegationTokenSigningPayload {
        DelegationTokenSigningPayload(
            tokenId: tokenId,
            userIdentityId: userIdentity.id,
            userIdentityName: userIdentity.displayName,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            newDevicePublicKey: newDevicePublicKey,
            oldDevicePublicKey: oldDevicePublicKey,
            nonce: nonce
        )
    }
    
    /// Check if token is still valid
    var isValid: Bool {
        Date() < expiresAt
    }
    
    /// Time remaining in seconds
    var timeRemaining: TimeInterval {
        max(0, expiresAt.timeIntervalSince(Date()))
    }
    
    init(
        userIdentity: UserIdentity,
        newDevicePublicKey: Data,
        oldDevicePublicKey: Data,
        ttlSeconds: TimeInterval = DelegationToken.defaultTTLSeconds
    ) {
        self.tokenId = UUID().uuidString
        self.userIdentity = userIdentity
        self.issuedAt = Date()
        self.expiresAt = Date().addingTimeInterval(min(max(ttlSeconds, Self.minTTLSeconds), Self.maxTTLSeconds))
        self.newDevicePublicKey = newDevicePublicKey
        self.oldDevicePublicKey = oldDevicePublicKey
        self.signatureByOldDevice = nil
        self.nonce = UUID().uuidString + "-" + String(Int(Date().timeIntervalSince1970))
    }
}

/// Payload used for signing (separates signature from data)
struct DelegationTokenSigningPayload: Codable {
    let tokenId: String
    let userIdentityId: String
    let userIdentityName: String
    let issuedAt: Date
    let expiresAt: Date
    let newDevicePublicKey: Data
    let oldDevicePublicKey: Data
    let nonce: String
}

// MARK: - Handover Request
/// Request sent from new device to old device
struct HandoverRequest: Codable {
    let requestId: String
    let requestType: RequestType
    let newDevicePublicKey: Data
    let newDeviceName: String
    let timestamp: Date
    
    enum RequestType: String, Codable {
        case identityTakeover = "IDENTITY_TAKEOVER"
        case statusQuery = "STATUS_QUERY"
    }
    
    init(
        newDevicePublicKey: Data,
        newDeviceName: String,
        requestType: RequestType = .identityTakeover
    ) {
        self.requestId = UUID().uuidString
        self.requestType = requestType
        self.newDevicePublicKey = newDevicePublicKey
        self.newDeviceName = newDeviceName
        self.timestamp = Date()
    }
}

// MARK: - Handover Response
/// Response sent from old device to new device
struct HandoverResponse: Codable {
    let requestId: String
    let status: ResponseStatus
    let delegationToken: DelegationToken?
    let errorMessage: String?
    let timestamp: Date
    
    enum ResponseStatus: String, Codable {
        case approved = "APPROVED"
        case rejected = "REJECTED"
        case pending = "PENDING"
        case expired = "EXPIRED"
        case alreadyTransferred = "ALREADY_TRANSFERRED"
    }
    
    init(
        requestId: String,
        status: ResponseStatus,
        delegationToken: DelegationToken? = nil,
        errorMessage: String? = nil
    ) {
        self.requestId = requestId
        self.status = status
        self.delegationToken = delegationToken
        self.errorMessage = errorMessage
        self.timestamp = Date()
    }
}

// MARK: - Identity Takeover Broadcast
/// Broadcast to mesh network announcing identity transfer
struct IdentityTakeoverBroadcast: Codable {
    let userId: String
    let oldPeerId: String?  // Old Bridgefy peer ID (nil if unknown)
    let newPeerId: String  // New Bridgefy peer ID
    let timestamp: Date
    let signatureByNewDevice: Data  // Signed by new device's key
    
    init(
        userId: String,
        oldPeerId: String?,
        newPeerId: String,
        signatureByNewDevice: Data
    ) {
        self.userId = userId
        self.oldPeerId = oldPeerId
        self.newPeerId = newPeerId
        self.timestamp = Date()
        self.signatureByNewDevice = signatureByNewDevice
    }
    
    /// Data used for signing
    var signingPayload: Data {
        let payload = "\(userId):\(newPeerId):\(Int(timestamp.timeIntervalSince1970))"
        return payload.data(using: .utf8) ?? Data()
    }
}

// MARK: - Used Token Record
/// Track used tokens to prevent replay attacks
struct UsedTokenRecord: Codable {
    let tokenId: String
    let usedAt: Date
    let userId: String
}

// MARK: - Handover Audit Log
/// Audit log entry for identity handover events
struct HandoverAuditLog: Codable, Identifiable {
    let id: String
    let eventType: EventType
    let userId: String
    let timestamp: Date
    let details: String
    let sourceDeviceName: String?
    let targetDeviceName: String?
    let success: Bool
    
    enum EventType: String, Codable {
        case handoverInitiated = "HANDOVER_INITIATED"
        case tokenCreated = "TOKEN_CREATED"
        case tokenTransferred = "TOKEN_TRANSFERRED"
        case tokenVerified = "TOKEN_VERIFIED"
        case identityActivated = "IDENTITY_ACTIVATED"
        case identityRevoked = "IDENTITY_REVOKED"
        case handoverCompleted = "HANDOVER_COMPLETED"
        case handoverFailed = "HANDOVER_FAILED"
        case replayAttempt = "REPLAY_ATTEMPT"
        case expiredTokenRejected = "EXPIRED_TOKEN_REJECTED"
    }
    
    init(
        eventType: EventType,
        userId: String,
        details: String,
        sourceDeviceName: String? = nil,
        targetDeviceName: String? = nil,
        success: Bool = true
    ) {
        self.id = UUID().uuidString
        self.eventType = eventType
        self.userId = userId
        self.timestamp = Date()
        self.details = details
        self.sourceDeviceName = sourceDeviceName
        self.targetDeviceName = targetDeviceName
        self.success = success
    }
}

// MARK: - QR Code Payload
/// Compact payload for emergency QR code transfer
struct EmergencyQRPayload: Codable {
    let version: Int
    let token: DelegationToken
    let checksum: String  // SHA256 hash of token data for integrity
    
    init(token: DelegationToken) throws {
        self.version = 1
        self.token = token
        
        // Calculate checksum
        let tokenData = try JSONEncoder().encode(token)
        let hash = tokenData.sha256Hash()
        self.checksum = hash.base64EncodedString()
    }
    
    /// Verify checksum integrity
    func verifyChecksum() throws -> Bool {
        let tokenData = try JSONEncoder().encode(token)
        let hash = tokenData.sha256Hash()
        return hash.base64EncodedString() == checksum
    }
    
    /// Encode to JSON string for QR code
    func toQRString() throws -> String {
        let data = try JSONEncoder().encode(self)
        return data.base64EncodedString()
    }
    
    /// Decode from QR string
    static func fromQRString(_ string: String) throws -> EmergencyQRPayload {
        guard let data = Data(base64Encoded: string) else {
            throw HandoverError.invalidQRCode
        }
        return try JSONDecoder().decode(EmergencyQRPayload.self, from: data)
    }
}

// MARK: - Handover Errors
enum HandoverError: Error, LocalizedError {
    case noIdentityToTransfer
    case identityAlreadyTransferred
    case tokenExpired
    case tokenInvalid
    case signatureInvalid
    case replayAttack
    case peerNotConnected
    case transferInProgress
    case userRejected
    case invalidQRCode
    case concurrentTakeoverAttempt
    case oldDeviceOffline
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .noIdentityToTransfer:
            return "Không có tài khoản để chuyển"
        case .identityAlreadyTransferred:
            return "Tài khoản đã được chuyển sang thiết bị khác"
        case .tokenExpired:
            return "Mã xác nhận đã hết hạn"
        case .tokenInvalid:
            return "Mã xác nhận không hợp lệ"
        case .signatureInvalid:
            return "Chữ ký số không hợp lệ"
        case .replayAttack:
            return "Phát hiện tấn công replay - mã đã được sử dụng"
        case .peerNotConnected:
            return "Chưa kết nối với thiết bị"
        case .transferInProgress:
            return "Đang trong quá trình chuyển tài khoản"
        case .userRejected:
            return "Yêu cầu đã bị từ chối"
        case .invalidQRCode:
            return "Mã QR không hợp lệ"
        case .concurrentTakeoverAttempt:
            return "Phát hiện yêu cầu chuyển tài khoản đồng thời"
        case .oldDeviceOffline:
            return "Thiết bị cũ không còn kết nối"
        case .networkError(let message):
            return "Lỗi kết nối: \(message)"
        }
    }
}

// MARK: - Data Extension for SHA256
extension Data {
    func sha256Hash() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto
