//
//  SettingsView.swift
//  SosMienTrung
//
//  Màn hình Cài đặt
//

import SwiftUI
import Combine

// MARK: - App Theme Enum
enum AppTheme: String, CaseIterable {
    case system = "Hệ thống"
    case light = "Sáng"
    case dark = "Tối"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "iphone"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - App Language Enum
enum AppLanguage: String, CaseIterable {
    case vietnamese = "Tiếng Việt"
    case english = "English"
    
    var flag: String {
        switch self {
        case .vietnamese: return "🇻🇳"
        case .english: return "🇺🇸"
        }
    }
}

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "appTheme")
        }
    }
    
    @Published var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "appLanguage")
        }
    }
    
    init() {
        let themeRaw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        self.selectedTheme = AppTheme(rawValue: themeRaw) ?? .system
        
        let langRaw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.vietnamese.rawValue
        self.selectedLanguage = AppLanguage(rawValue: langRaw) ?? .vietnamese
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var userProfile = UserProfile.shared
    @ObservedObject var appearanceManager = AppearanceManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    @State private var showEditProfile = false
    @State private var showThemePicker = false
    @State private var showLanguagePicker = false
    @State private var showAbout = false
    @State private var showAppearanceCustomization = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                TelegramBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        profileHeader
                        
                        // Account Section
                        settingsSection(title: "Tài khoản") {
                            SettingsRow(
                                icon: "person.fill",
                                iconColor: .blue,
                                title: "Cập nhật thông tin",
                                subtitle: "Tên, số điện thoại"
                            ) {
                                showEditProfile = true
                            }
                        }
                        
                        // Appearance Section
                        settingsSection(title: "Giao diện") {
                            SettingsRow(
                                icon: "paintbrush.fill",
                                iconColor: .purple,
                                title: "Tùy chỉnh hình nền",
                                subtitle: "Màu sắc, hoạ tiết, cường độ"
                            ) {
                                showAppearanceCustomization = true
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            SettingsRow(
                                icon: "moon.fill",
                                iconColor: .indigo,
                                title: "Chế độ hiển thị",
                                subtitle: settingsManager.selectedTheme.rawValue
                            ) {
                                showThemePicker = true
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            SettingsRow(
                                icon: "globe",
                                iconColor: .green,
                                title: "Ngôn ngữ",
                                subtitle: "\(settingsManager.selectedLanguage.flag) \(settingsManager.selectedLanguage.rawValue)"
                            ) {
                                showLanguagePicker = true
                            }
                        }
                        
                        // About Section
                        settingsSection(title: "Thông tin") {
                            SettingsRow(
                                icon: "info.circle.fill",
                                iconColor: .gray,
                                title: "Về ứng dụng",
                                subtitle: "Phiên bản 1.0.0"
                            ) {
                                showAbout = true
                            }
                        }
                        
                        // App Info
                        VStack(spacing: 4) {
                            Text("SOS Miền Trung")
                                .font(.caption)
                                .foregroundColor(appearanceManager.secondaryTextColor)
                            Text("Ứng dụng hỗ trợ cứu trợ thiên tai")
                                .font(.caption2)
                                .foregroundColor(appearanceManager.tertiaryTextColor)
                        }
                        .padding(.top, 20)
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .fullScreenCover(isPresented: $showAppearanceCustomization) {
            AppearanceCustomizationView()
        }
        .sheet(isPresented: $showThemePicker) {
            ThemePickerView(selectedTheme: $settingsManager.selectedTheme)
                .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(selectedLanguage: $settingsManager.selectedLanguage)
                .presentationDetents([.height(250)])
        }
        .alert("Về ứng dụng", isPresented: $showAbout) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("SOS Miền Trung v1.0.0\n\nỨng dụng hỗ trợ kết nối và cứu trợ trong thiên tai, hoạt động offline qua mạng mesh.\n\n© 2026 Capstone Project")
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(appearanceManager.textColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                if let firstChar = userProfile.currentUser?.name.first {
                    Text(String(firstChar).uppercased())
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(appearanceManager.textColor)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(appearanceManager.textColor)
                }
            }
            
            // Name
            Text(userProfile.currentUser?.name ?? "Chưa đặt tên")
                .font(.title2.bold())
                .foregroundColor(appearanceManager.textColor)
            
            // Phone
            Text(userProfile.currentUser?.phoneNumber ?? "Chưa có số điện thoại")
                .font(.subheadline)
                .foregroundColor(appearanceManager.secondaryTextColor)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Settings Section Builder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(appearanceManager.secondaryTextColor)
                .padding(.leading, 16)
            
            VStack(spacing: 0) {
                content()
            }
            .background(appearanceManager.textColor.opacity(0.15))
            .cornerRadius(12)
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    @ObservedObject var appearanceManager = AppearanceManager.shared
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                // Title & Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(appearanceManager.textColor)
                    
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(appearanceManager.tertiaryTextColor)
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(appearanceManager.tertiaryTextColor)
            }
            .padding()
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var userProfile = UserProfile.shared
    
    @State private var name: String = ""
    @State private var phoneNumber: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Avatar
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    
                    Text("Đặt ảnh đại diện")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
                
                Section {
                    TextField("Tên", text: $name)
                        .textContentType(.name)
                    
                    TextField("Số điện thoại", text: $phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Thông tin cá nhân")
                } footer: {
                    Text("Nhập tên và số điện thoại để người khác có thể nhận diện bạn.")
                }
            }
            .navigationTitle("Sửa hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy bỏ") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        saveProfile()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                name = userProfile.currentUser?.name ?? ""
                phoneNumber = userProfile.currentUser?.phoneNumber ?? ""
            }
            .alert("Lỗi", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        phoneNumber.count >= 9
    }
    
    private func saveProfile() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Vui lòng nhập tên"
            showError = true
            return
        }
        
        guard trimmedPhone.count >= 9 else {
            errorMessage = "Số điện thoại không hợp lệ"
            showError = true
            return
        }
        
        userProfile.saveUser(name: trimmedName, phoneNumber: trimmedPhone)
        dismiss()
    }
}

// MARK: - Theme Picker View
struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTheme: AppTheme
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button {
                        selectedTheme = theme
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: theme.icon)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            
                            Text(theme.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chọn giao diện")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Language Picker View
struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLanguage: AppLanguage
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Button {
                        selectedLanguage = language
                        dismiss()
                    } label: {
                        HStack {
                            Text(language.flag)
                                .font(.title)
                            
                            Text(language.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chọn ngôn ngữ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
