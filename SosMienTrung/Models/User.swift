//
//  User.swift
//  SosMienTrung
//
//  User model cho hệ thống chat
//

import Foundation
import Combine

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var isOnline: Bool
    var lastSeen: Date
    var identityId: String?  // Link to UserIdentity
    var publicKeyFingerprint: String?  // For verification
    
    init(id: UUID = UUID(), name: String, phoneNumber: String, isOnline: Bool = true, lastSeen: Date = Date(), identityId: String? = nil, publicKeyFingerprint: String? = nil) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.identityId = identityId
        self.publicKeyFingerprint = publicKeyFingerprint
    }
}

// MARK: - UserProfile (current user)
class UserProfile: ObservableObject {
    static let shared = UserProfile()
    
    @Published var currentUser: User?
    
    private let userKey = "currentUserProfile"
    
    private init() {
        loadUser()
    }
    
    var isSetupComplete: Bool {
        currentUser != nil
    }
    
    /// Check if identity has been transferred (account moved to another device)
    var isIdentityTransferred: Bool {
        IdentityStore.shared.isTransferred
    }
    
    /// Check if user has valid cryptographic identity
    var hasValidIdentity: Bool {
        IdentityKeyManager.shared.hasValidIdentity && !isIdentityTransferred
    }
    
    func saveUser(name: String, phoneNumber: String) {
        // Generate identity key if needed
        let keyManager = IdentityKeyManager.shared
        if !keyManager.hasValidIdentity && keyManager.identityStatus == .notInitialized {
            do {
                try keyManager.generateIdentityKeyPair()
            } catch {
                print("⚠️ Failed to generate identity key: \(error)")
            }
        }
        
        // Get identity info
        var identityId: String? = nil
        var publicKeyFingerprint: String? = nil
        
        if let publicKey = try? keyManager.getPublicKeyBase64() {
            publicKeyFingerprint = String(publicKey.prefix(16))
            
            // Create/update identity
            if let identity = IdentityStore.shared.createIdentityFromProfile(try! keyManager.getPublicKeyData()) {
                identityId = identity.id
            }
        }
        
        let user = User(
            name: name,
            phoneNumber: phoneNumber,
            identityId: identityId,
            publicKeyFingerprint: publicKeyFingerprint
        )
        self.currentUser = user
        
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userKey)
        }
    }
    
    func loadUser() {
        if let data = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            self.currentUser = user
        }
    }
    
    func clearUser() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: userKey)
    }
    
    /// Update user after identity handover
    func updateFromIdentity(_ identity: UserIdentity) {
        let user = User(
            name: identity.displayName,
            phoneNumber: identity.phoneNumber,
            identityId: identity.id,
            publicKeyFingerprint: identity.publicKeyData.base64EncodedString().prefix(16).description
        )
        self.currentUser = user
        
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userKey)
        }
    }
}
