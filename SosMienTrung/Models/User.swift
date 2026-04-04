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
    var firstName: String?
    var lastName: String?
    var address: String?
    var ward: String?
    var province: String?
    var latitude: Double?
    var longitude: Double?
    var avatarUrl: String?

    init(
        id: UUID = UUID(),
        name: String,
        phoneNumber: String,
        isOnline: Bool = true,
        lastSeen: Date = Date(),
        identityId: String? = nil,
        publicKeyFingerprint: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        address: String? = nil,
        ward: String? = nil,
        province: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        avatarUrl: String? = nil
    ) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.identityId = identityId
        self.publicKeyFingerprint = publicKeyFingerprint
        self.firstName = firstName
        self.lastName = lastName
        self.address = address
        self.ward = ward
        self.province = province
        self.latitude = latitude
        self.longitude = longitude
        self.avatarUrl = avatarUrl
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
        let user = User(
            id: currentUser?.id ?? UUID(),
            name: Self.trimmed(name),
            phoneNumber: Self.trimmed(phoneNumber),
            isOnline: currentUser?.isOnline ?? true,
            lastSeen: currentUser?.lastSeen ?? Date(),
            identityId: currentUser?.identityId,
            publicKeyFingerprint: currentUser?.publicKeyFingerprint,
            firstName: currentUser?.firstName,
            lastName: currentUser?.lastName,
            address: currentUser?.address,
            ward: currentUser?.ward,
            province: currentUser?.province,
            latitude: currentUser?.latitude,
            longitude: currentUser?.longitude,
            avatarUrl: currentUser?.avatarUrl
        )
        persist(user)
    }

    func saveVictimProfile(
        firstName: String,
        lastName: String,
        phoneNumber: String,
        address: String,
        ward: String,
        province: String,
        latitude: Double?,
        longitude: Double?,
        avatarUrl: String
    ) {
        let normalizedFirstName = Self.optionalTrimmed(firstName)
        let normalizedLastName = Self.optionalTrimmed(lastName)
        let displayName = Self.composeDisplayName(
            firstName: normalizedFirstName,
            lastName: normalizedLastName,
            fallbackName: currentUser?.name,
            fallbackPhone: phoneNumber
        )

        let user = User(
            id: currentUser?.id ?? UUID(),
            name: displayName,
            phoneNumber: Self.trimmed(phoneNumber),
            isOnline: currentUser?.isOnline ?? true,
            lastSeen: currentUser?.lastSeen ?? Date(),
            identityId: currentUser?.identityId,
            publicKeyFingerprint: currentUser?.publicKeyFingerprint,
            firstName: normalizedFirstName,
            lastName: normalizedLastName,
            address: Self.optionalTrimmed(address),
            ward: Self.optionalTrimmed(ward),
            province: Self.optionalTrimmed(province),
            latitude: latitude,
            longitude: longitude,
            avatarUrl: Self.optionalTrimmed(avatarUrl)
        )
        persist(user)
    }

    func apply(currentUser response: CurrentUserResponse, fallbackPhone: String? = nil) {
        let existing = currentUser
        let resolvedFirstName = Self.optionalTrimmed(response.firstName) ?? existing?.firstName
        let resolvedLastName = Self.optionalTrimmed(response.lastName) ?? existing?.lastName
        let resolvedPhone = Self.optionalTrimmed(response.phone)
            ?? Self.optionalTrimmed(fallbackPhone)
            ?? existing?.phoneNumber
            ?? ""
        let resolvedName = Self.optionalTrimmed(response.displayName)
            ?? Self.composeDisplayName(
                firstName: resolvedFirstName,
                lastName: resolvedLastName,
                fallbackName: existing?.name,
                fallbackPhone: resolvedPhone
            )

        let user = User(
            id: existing?.id ?? UUID(),
            name: resolvedName,
            phoneNumber: resolvedPhone,
            isOnline: existing?.isOnline ?? true,
            lastSeen: existing?.lastSeen ?? Date(),
            identityId: existing?.identityId,
            publicKeyFingerprint: existing?.publicKeyFingerprint,
            firstName: resolvedFirstName,
            lastName: resolvedLastName,
            address: Self.optionalTrimmed(response.address) ?? existing?.address,
            ward: Self.optionalTrimmed(response.ward) ?? existing?.ward,
            province: Self.optionalTrimmed(response.province) ?? existing?.province,
            latitude: response.latitude ?? existing?.latitude,
            longitude: response.longitude ?? existing?.longitude,
            avatarUrl: Self.optionalTrimmed(response.avatarUrl) ?? existing?.avatarUrl
        )
        persist(user)
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
            id: currentUser?.id ?? UUID(),
            name: identity.displayName,
            phoneNumber: identity.phoneNumber,
            isOnline: currentUser?.isOnline ?? true,
            lastSeen: currentUser?.lastSeen ?? Date(),
            identityId: identity.id,
            publicKeyFingerprint: identity.publicKeyData.base64EncodedString().prefix(16).description,
            firstName: currentUser?.firstName,
            lastName: currentUser?.lastName,
            address: currentUser?.address,
            ward: currentUser?.ward,
            province: currentUser?.province,
            latitude: currentUser?.latitude,
            longitude: currentUser?.longitude,
            avatarUrl: currentUser?.avatarUrl
        )
        persist(user)
    }

    private func persist(_ user: User) {
        let finalizedUser = userWithIdentityMetadata(from: user)
        currentUser = finalizedUser

        if let encoded = try? JSONEncoder().encode(finalizedUser) {
            UserDefaults.standard.set(encoded, forKey: userKey)
        }
    }

    private func userWithIdentityMetadata(from user: User) -> User {
        let keyManager = IdentityKeyManager.shared
        if !keyManager.hasValidIdentity && keyManager.identityStatus == .notInitialized {
            do {
                try keyManager.generateIdentityKeyPair()
            } catch {
                print("⚠️ Failed to generate identity key: \(error)")
            }
        }

        var enrichedUser = user
        if let publicKey = try? keyManager.getPublicKeyBase64() {
            enrichedUser.publicKeyFingerprint = String(publicKey.prefix(16))
        }

        if let publicKeyData = try? keyManager.getPublicKeyData(),
           let identity = IdentityStore.shared.createIdentityFromProfile(publicKeyData, user: enrichedUser) {
            enrichedUser.identityId = identity.id
        }

        return enrichedUser
    }

    private static func composeDisplayName(
        firstName: String?,
        lastName: String?,
        fallbackName: String?,
        fallbackPhone: String
    ) -> String {
        let parts = [optionalTrimmed(lastName), optionalTrimmed(firstName)].compactMap { $0 }
        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }

        if let fallbackName = optionalTrimmed(fallbackName) {
            return fallbackName
        }

        return trimmed(fallbackPhone)
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func optionalTrimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = trimmed(value)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
