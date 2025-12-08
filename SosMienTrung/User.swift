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
    
    init(id: UUID = UUID(), name: String, phoneNumber: String, isOnline: Bool = true, lastSeen: Date = Date()) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.isOnline = isOnline
        self.lastSeen = lastSeen
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
    
    func saveUser(name: String, phoneNumber: String) {
        let user = User(name: name, phoneNumber: phoneNumber)
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
}
