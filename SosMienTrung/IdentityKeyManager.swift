//
//  IdentityKeyManager.swift
//  SosMienTrung
//
//  Manages cryptographic keys using Secure Enclave for identity verification
//  in offline P2P account handover scenarios.
//

import Foundation
import Combine
import CryptoKit
import Security
import LocalAuthentication

// MARK: - Key Manager Errors
enum IdentityKeyError: Error, LocalizedError {
    case keyGenerationFailed
    case keyNotFound
    case keyStorageFailed
    case signatureFailed
    case verificationFailed
    case secureEnclaveNotAvailable
    case keychainError(OSStatus)
    case invalidKeyData
    case keyAlreadyRevoked
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate cryptographic key pair"
        case .keyNotFound:
            return "Identity key not found"
        case .keyStorageFailed:
            return "Failed to store key securely"
        case .signatureFailed:
            return "Failed to sign data"
        case .verificationFailed:
            return "Signature verification failed"
        case .secureEnclaveNotAvailable:
            return "Secure Enclave is not available on this device"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .invalidKeyData:
            return "Invalid key data format"
        case .keyAlreadyRevoked:
            return "Identity key has been revoked"
        }
    }
}

// MARK: - Identity Key Manager
final class IdentityKeyManager: ObservableObject {
    static let shared = IdentityKeyManager()
    
    // Keychain identifiers
    private let privateKeyTag = "com.sosmientrung.identity.privatekey"
    private let publicKeyTag = "com.sosmientrung.identity.publickey"
    private let identityStatusKey = "identity_key_status"
    
    // Published state
    @Published private(set) var hasValidIdentity: Bool = false
    @Published private(set) var identityStatus: IdentityStatus = .notInitialized
    @Published private(set) var publicKeyData: Data?
    
    enum IdentityStatus: String, Codable {
        case notInitialized = "not_initialized"
        case active = "active"
        case transferred = "transferred"
        case revoked = "revoked"
    }
    
    private init() {
        loadIdentityStatus()
        checkExistingKey()
    }
    
    // MARK: - Public Key Access
    
    /// Get the public key as raw data for sharing
    func getPublicKeyData() throws -> Data {
        guard identityStatus == .active else {
            throw IdentityKeyError.keyAlreadyRevoked
        }
        
        if let cached = publicKeyData {
            return cached
        }
        
        // Try to load from keychain
        guard let key = loadPublicKey() else {
            throw IdentityKeyError.keyNotFound
        }
        
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            throw IdentityKeyError.invalidKeyData
        }
        
        DispatchQueue.main.async {
            self.publicKeyData = data
        }
        
        return data
    }
    
    /// Get public key as Base64 string for display/QR
    func getPublicKeyBase64() throws -> String {
        let data = try getPublicKeyData()
        return data.base64EncodedString()
    }
    
    // MARK: - Key Generation
    
    /// Generate a new identity key pair using Secure Enclave if available
    func generateIdentityKeyPair() throws {
        // Check if key already exists
        if loadPrivateKey() != nil {
            print("⚠️ Identity key already exists")
            return
        }
        
        // Determine if Secure Enclave is available
        let useSecureEnclave = isSecureEnclaveAvailable()
        
        if useSecureEnclave {
            try generateSecureEnclaveKey()
        } else {
            try generateSoftwareKey()
        }
        
        // Update status
        setIdentityStatus(.active)
        checkExistingKey()
        
        print("✅ Identity key pair generated successfully (Secure Enclave: \(useSecureEnclave))")
    }
    
    /// Generate key in Secure Enclave (hardware-protected)
    private func generateSecureEnclaveKey() throws {
        // Create access control for Secure Enclave
        var accessError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            &accessError
        ) else {
            throw IdentityKeyError.keyGenerationFailed
        }
        
        // Private key attributes
        let privateKeyAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: privateKeyTag.data(using: .utf8)!,
            kSecAttrAccessControl as String: accessControl
        ]
        
        // Public key attributes
        let publicKeyAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: publicKeyTag.data(using: .utf8)!
        ]
        
        // Key generation parameters
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: privateKeyAttributes,
            kSecPublicKeyAttrs as String: publicKeyAttributes
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            print("❌ Secure Enclave key generation failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
            throw IdentityKeyError.keyGenerationFailed
        }
        
        // Extract and store public key
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw IdentityKeyError.keyGenerationFailed
        }
        
        try storePublicKey(publicKey)
    }
    
    /// Generate software-based key (fallback for simulator)
    private func generateSoftwareKey() throws {
        let privateKeyAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: privateKeyTag.data(using: .utf8)!
        ]
        
        let publicKeyAttributes: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: publicKeyTag.data(using: .utf8)!
        ]
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: privateKeyAttributes,
            kSecPublicKeyAttrs as String: publicKeyAttributes
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            print("❌ Software key generation failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
            throw IdentityKeyError.keyGenerationFailed
        }
        
        // Store private key
        try storePrivateKey(privateKey)
        
        // Extract and store public key
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw IdentityKeyError.keyGenerationFailed
        }
        
        try storePublicKey(publicKey)
    }
    
    // MARK: - Signing
    
    /// Sign data using the private key
    func sign(data: Data) throws -> Data {
        guard identityStatus == .active else {
            throw IdentityKeyError.keyAlreadyRevoked
        }
        
        guard let privateKey = loadPrivateKey() else {
            throw IdentityKeyError.keyNotFound
        }
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) as Data? else {
            print("❌ Signing failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
            throw IdentityKeyError.signatureFailed
        }
        
        return signature
    }
    
    /// Sign a delegation token
    func signDelegationToken(_ token: DelegationToken) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]  // Ensure consistent key order
        encoder.dateEncodingStrategy = .secondsSince1970  // More consistent than iso8601
        encoder.dataEncodingStrategy = .base64  // Explicit base64 for Data
        let tokenData = try encoder.encode(token.signingPayload)
        print("📝 Signing - payload length: \(tokenData.count)")
        if let payloadString = String(data: tokenData, encoding: .utf8) {
            print("📝 Signing payload: \(payloadString)")
        }
        return try sign(data: tokenData)
    }
    
    // MARK: - Verification
    
    /// Verify signature using a public key
    func verify(signature: Data, data: Data, publicKeyData: Data) throws -> Bool {
        // Reconstruct public key from data
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256
        ]
        
        var error: Unmanaged<CFError>?
        guard let publicKey = SecKeyCreateWithData(publicKeyData as CFData, attributes as CFDictionary, &error) else {
            print("❌ Failed to reconstruct public key: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
            throw IdentityKeyError.invalidKeyData
        }
        
        let result = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            signature as CFData,
            &error
        )
        
        if !result {
            print("❌ Signature verification failed: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
        }
        
        return result
    }
    
    /// Verify a delegation token
    func verifyDelegationToken(_ token: DelegationToken, oldDevicePublicKey: Data) throws -> Bool {
        guard let signature = token.signatureByOldDevice else {
            print("❌ No signature in token")
            return false
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]  // Must match signing encoder
        encoder.dateEncodingStrategy = .secondsSince1970  // Must match signing encoder
        encoder.dataEncodingStrategy = .base64  // Must match signing encoder
        let tokenData = try encoder.encode(token.signingPayload)
        print("🔍 Verifying - payload length: \(tokenData.count), signature length: \(signature.count), publicKey length: \(oldDevicePublicKey.count)")
        if let payloadString = String(data: tokenData, encoding: .utf8) {
            print("🔍 Verifying payload: \(payloadString)")
        }
        
        return try verify(signature: signature, data: tokenData, publicKeyData: oldDevicePublicKey)
    }
    
    // MARK: - Key Revocation
    
    /// Revoke identity (destroy private key) - used when transferring to new device
    func revokeIdentity() throws {
        // Delete private key from keychain
        let privateQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: privateKeyTag.data(using: .utf8)!
        ]
        
        let privateStatus = SecItemDelete(privateQuery as CFDictionary)
        if privateStatus != errSecSuccess && privateStatus != errSecItemNotFound {
            print("⚠️ Failed to delete private key: \(privateStatus)")
        }
        
        // Update status
        setIdentityStatus(.transferred)
        
        DispatchQueue.main.async {
            self.hasValidIdentity = false
            self.publicKeyData = nil
        }
        
        print("🔐 Identity revoked - private key destroyed")
    }
    
    /// Full reset - delete all keys (for testing/recovery)
    func fullReset() {
        // Delete private key
        let privateQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: privateKeyTag.data(using: .utf8)!
        ]
        SecItemDelete(privateQuery as CFDictionary)
        
        // Delete public key
        let publicQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: publicKeyTag.data(using: .utf8)!
        ]
        SecItemDelete(publicQuery as CFDictionary)
        
        // Reset status
        setIdentityStatus(.notInitialized)
        
        DispatchQueue.main.async {
            self.hasValidIdentity = false
            self.publicKeyData = nil
        }
        
        print("🗑️ Full identity reset completed")
    }
    
    // MARK: - Private Helpers
    
    private func isSecureEnclaveAvailable() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave
        ]
        return SecKeyIsAlgorithmSupported(
            SecKeyCreateRandomKey(attributes as CFDictionary, nil)!,
            .sign,
            .ecdsaSignatureMessageX962SHA256
        )
        #endif
    }
    
    private func loadPrivateKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: privateKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let key = item else {
            return nil
        }
        
        return (key as! SecKey)
    }
    
    private func loadPublicKey() -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: publicKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecReturnRef as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess, let key = item else {
            return nil
        }
        
        return (key as! SecKey)
    }
    
    private func storePrivateKey(_ key: SecKey) throws {
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            throw IdentityKeyError.invalidKeyData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: privateKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing if any
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw IdentityKeyError.keychainError(status)
        }
    }
    
    private func storePublicKey(_ key: SecKey) throws {
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            throw IdentityKeyError.invalidKeyData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: publicKeyTag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing if any
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw IdentityKeyError.keychainError(status)
        }
        
        DispatchQueue.main.async {
            self.publicKeyData = keyData
        }
    }
    
    private func checkExistingKey() {
        let hasKey = loadPrivateKey() != nil && identityStatus == .active
        DispatchQueue.main.async {
            self.hasValidIdentity = hasKey
        }
        
        if hasKey {
            // Load public key data
            if let publicKey = loadPublicKey() {
                var error: Unmanaged<CFError>?
                if let data = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? {
                    DispatchQueue.main.async {
                        self.publicKeyData = data
                    }
                }
            }
        }
    }
    
    private func loadIdentityStatus() {
        if let statusRaw = UserDefaults.standard.string(forKey: identityStatusKey),
           let status = IdentityStatus(rawValue: statusRaw) {
            DispatchQueue.main.async {
                self.identityStatus = status
            }
        }
    }
    
    private func setIdentityStatus(_ status: IdentityStatus) {
        UserDefaults.standard.set(status.rawValue, forKey: identityStatusKey)
        DispatchQueue.main.async {
            self.identityStatus = status
        }
    }
}
