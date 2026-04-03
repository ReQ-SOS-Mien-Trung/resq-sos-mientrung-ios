//
//  SettingsView.swift
//  SosMienTrung
//
//  Màn hình Cài đặt
//

import SwiftUI
import Combine
import UIKit

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
            AppearanceManager.shared.isDarkTheme = (selectedTheme == .dark)
            AppearanceManager.shared.isLightThemeForced = (selectedTheme == .light)
        }
    }
    
    @Published var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "appLanguage")
        }
    }
    
    @Published var batterySavingMode: Bool {
        didSet {
            UserDefaults.standard.set(batterySavingMode, forKey: "batterySavingMode")
            // Sync với AppearanceManager để áp dụng cho toàn app
            AppearanceManager.shared.batterySavingMode = batterySavingMode
        }
    }
    
    init() {
        let themeRaw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        self.selectedTheme = AppTheme(rawValue: themeRaw) ?? .system
        
        let langRaw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.vietnamese.rawValue
        self.selectedLanguage = AppLanguage(rawValue: langRaw) ?? .vietnamese
        
        let savedBatterySaving = UserDefaults.standard.bool(forKey: "batterySavingMode")
        self.batterySavingMode = savedBatterySaving
        // Sync với AppearanceManager khi khởi tạo - defer to avoid publishing during view update
        DispatchQueue.main.async {
            let theme = AppTheme(rawValue: themeRaw) ?? .system
            AppearanceManager.shared.batterySavingMode = savedBatterySaving
            AppearanceManager.shared.isDarkTheme = (theme == .dark)
            AppearanceManager.shared.isLightThemeForced = (theme == .light)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var userProfile = UserProfile.shared
    @ObservedObject private var relativeProfileStore = RelativeProfileStore.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var keyManager = IdentityKeyManager.shared
    @StateObject private var identityStore = IdentityStore.shared

    @State private var showEditProfile = false
    @State private var showRelativeProfiles = false
    @State private var showThemePicker = false
    @State private var showLanguagePicker = false
    @State private var showAbout = false
    @State private var showIdentityHandover = false
    @State private var showIdentityInfo = false
    @State private var showLogoutConfirmation = false
    @State private var isLoggingOut = false
    @StateObject private var authSession = AuthSessionStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Editorial header
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        EyebrowLabel(text: "CÀI ĐẶT")
                        Text("Tùy chỉnh")
                            .font(DS.Typography.largeTitle)
                            .foregroundColor(DS.Colors.text)
                        EditorialDivider(height: DS.Border.thick)
                    }
                    .padding(.top, DS.Spacing.md)

                    // Profile Header
                    profileHeader

                    // Identity Status Banner (if transferred)
                    if identityStore.isTransferred {
                        identityTransferredBanner
                    }

                    // Account Section
                    Text("TÀI KHOẢN").sectionHeader()
                    settingsSection {
                        SettingsRow(icon: "person.fill", iconColor: DS.Colors.info, title: "Cập nhật thông tin", subtitle: "Tên, số điện thoại") {
                            showEditProfile = true
                        }
                        EditorialDivider()
                        SettingsRow(
                            icon: "person.3.fill",
                            iconColor: DS.Colors.success,
                            title: "Người thân & hồ sơ SOS",
                            subtitle: relativeProfileSubtitle
                        ) {
                            showRelativeProfiles = true
                        }
                        EditorialDivider()
                        SettingsRow(icon: "arrow.left.arrow.right", iconColor: DS.Colors.warning, title: "Chuyển tài khoản", subtitle: identityStore.isTransferred ? "Đã chuyển sang thiết bị khác" : "Chuyển sang thiết bị mới") {
                            showIdentityHandover = true
                        }
                        EditorialDivider()
                        SettingsRow(icon: "key.fill", iconColor: DS.Colors.success, title: "Danh tính số", subtitle: identityStatusText) {
                            showIdentityInfo = true
                        }
                        if userProfile.currentUser != nil {
                            EditorialDivider()
                            SettingsRow(icon: "rectangle.portrait.and.arrow.right", iconColor: DS.Colors.danger, title: "Đăng xuất", subtitle: authSession.session?.username ?? authSession.session?.fullName ?? userProfile.currentUser?.name ?? "Tài khoản") {
                                showLogoutConfirmation = true
                            }
                        }
                    }

                    // Appearance Section
                    Text("GIAO DIỆN").sectionHeader()
                    settingsSection {
                        BatterySavingToggleRow(isOn: $settingsManager.batterySavingMode)
                        EditorialDivider()
                        SettingsRow(icon: "moon.fill", iconColor: .indigo, title: "Chế độ hiển thị", subtitle: settingsManager.selectedTheme.rawValue) {
                            showThemePicker = true
                        }
                        EditorialDivider()
                        SettingsRow(icon: "globe", iconColor: DS.Colors.success, title: "Ngôn ngữ", subtitle: "\(settingsManager.selectedLanguage.flag) \(settingsManager.selectedLanguage.rawValue)") {
                            showLanguagePicker = true
                        }
                    }

                    // About Section
                    Text("THÔNG TIN").sectionHeader()
                    settingsSection {
                        SettingsRow(icon: "info.circle.fill", iconColor: DS.Colors.textTertiary, title: "Về ứng dụng", subtitle: "Phiên bản 1.0.0") {
                            showAbout = true
                        }
                    }

                    // App Info
                    VStack(spacing: 4) {
                        Text("ResQ — SOS Miền Trung")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                        Text("Ứng dụng hỗ trợ cứu trợ thiên tai")
                            .font(.caption2)
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, DS.Spacing.md)

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, DS.Spacing.md)
            }
            .background(DS.Colors.background)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showRelativeProfiles) {
            RelativeProfilesView()
        }
        .fullScreenCover(isPresented: $showIdentityHandover) {
            IdentityHandoverView()
        }
        .sheet(isPresented: $showIdentityInfo) {
            IdentityInfoView()
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
            Text("ResQ — SOS Miền Trung v1.0.0\n\nỨng dụng hỗ trợ kết nối và cứu trợ trong thiên tai, hoạt động offline qua mạng mesh.\n\n© 2026 Capstone Project")
        }
        .alert("Đăng xuất", isPresented: $showLogoutConfirmation) {
            Button("Hủy", role: .cancel) { }
            Button("Đăng xuất", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?")
        }
    }

    // MARK: - Logout Action
    private func performLogout() {
        isLoggingOut = true
        AuthService.shared.logout { _ in
            isLoggingOut = false
        }
    }

    // MARK: - Identity Status Text
    private var identityStatusText: String {
        switch keyManager.identityStatus {
        case .notInitialized: return "Chưa khởi tạo"
        case .active: return "Đang hoạt động"
        case .transferred: return "Đã chuyển"
        case .revoked: return "Đã thu hồi"
        }
    }

    private var relativeProfileSubtitle: String {
        let count = relativeProfileStore.profiles.count
        let syncStatus: String

        if relativeProfileStore.isSyncing {
            syncStatus = "đang đồng bộ"
        } else if relativeProfileStore.isServerSyncEnabled {
            syncStatus = "đồng bộ máy chủ"
        } else {
            syncStatus = "chỉ lưu local"
        }

        if count == 0 {
            return "Lưu sẵn người thân để chọn nhanh khi gửi SOS, \(syncStatus)"
        }
        return "\(count) hồ sơ, \(syncStatus)"
    }

    // MARK: - Identity Transferred Banner
    private var identityTransferredBanner: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(DS.Colors.warning)
            VStack(alignment: .leading, spacing: 4) {
                Text("Tài khoản đã chuyển")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
                Text("Tài khoản đã được chuyển sang thiết bị khác. Một số tính năng bị giới hạn.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
        .padding(DS.Spacing.sm)
        .sharpCard(borderColor: DS.Colors.warning, shadow: DS.Shadow.none, backgroundColor: DS.Colors.warning.opacity(0.1))
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Avatar — sharp rectangle
            ZStack {
                Rectangle()
                    .fill(DS.Colors.accent.opacity(0.15))
                    .frame(width: 88, height: 88)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))

                if let firstChar = userProfile.currentUser?.name.first {
                    Text(String(firstChar).uppercased())
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(DS.Colors.accent)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundColor(DS.Colors.accent)
                }
            }

            Text(userProfile.currentUser?.name ?? "Chưa đặt tên")
                .font(DS.Typography.title)
                .foregroundColor(DS.Colors.text)

            Text(userProfile.currentUser?.phoneNumber ?? "Chưa có số điện thoại")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Settings Section Builder
    private func settingsSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .sharpCard(shadow: DS.Shadow.none)
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                // Icon — sharp square
                ZStack {
                    Rectangle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.sm)
        }
    }
}

// MARK: - Battery Saving Toggle Row
struct BatterySavingToggleRow: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ZStack {
                Rectangle()
                    .fill(DS.Colors.warning.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "battery.100.bolt")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(DS.Colors.warning)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Tiết kiệm pin")
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text)
                Text(isOn ? "Đang bật" : "Đang tắt")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DS.Colors.warning)
        }
        .padding(DS.Spacing.sm)
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

// MARK: - Identity Info View
struct IdentityInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var keyManager = IdentityKeyManager.shared
    @StateObject private var identityStore = IdentityStore.shared
    
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // Identity Status Section
                Section {
                    HStack {
                        Text("Trạng thái")
                        Spacer()
                        Text(statusText)
                            .foregroundColor(statusColor)
                    }
                    
                    if let identity = identityStore.currentIdentity {
                        HStack {
                            Text("ID")
                            Spacer()
                            Text(String(identity.id.prefix(12)) + "...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Vai trò")
                            Spacer()
                            Text(identity.role.displayName)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Tạo lúc")
                            Spacer()
                            Text(identity.createdAt, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Danh tính số")
                } footer: {
                    Text("Danh tính số được bảo vệ bằng mã hóa và lưu trữ an toàn trên thiết bị.")
                }
                
                // Public Key Section
                Section {
                    if let publicKeyBase64 = try? keyManager.getPublicKeyBase64() {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Khóa công khai")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(String(publicKeyBase64.prefix(32)) + "...")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Thông tin mã hóa")
                } footer: {
                    Text("Khóa riêng được lưu trong Secure Enclave và không bao giờ rời khỏi thiết bị.")
                }
                
                // Audit Logs Section
                Section {
                    let logs = IdentityHandoverManager.shared.getAuditLogs().suffix(5)
                    if logs.isEmpty {
                        Text("Chưa có hoạt động nào")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(logs), id: \.id) { log in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(log.success ? .green : .red)
                                        .font(.caption)
                                    
                                    Text(eventTypeText(log.eventType))
                                        .font(.subheadline)
                                }
                                
                                Text(log.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("Lịch sử hoạt động")
                }
                
                // Reset Section
                if keyManager.identityStatus == .active {
                    Section {
                        Button(role: .destructive) {
                            showResetConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Đặt lại danh tính")
                            }
                        }
                    } footer: {
                        Text("Cảnh báo: Thao tác này sẽ xóa danh tính số và không thể hoàn tác.")
                    }
                }
            }
            .navigationTitle("Danh tính số")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        dismiss()
                    }
                }
            }
            .alert("Xác nhận đặt lại", isPresented: $showResetConfirmation) {
                Button("Hủy", role: .cancel) { }
                Button("Đặt lại", role: .destructive) {
                    keyManager.fullReset()
                    identityStore.clearIdentity()
                    dismiss()
                }
            } message: {
                Text("Bạn có chắc muốn đặt lại danh tính số? Thao tác này không thể hoàn tác.")
            }
        }
    }
    
    private var statusText: String {
        switch keyManager.identityStatus {
        case .notInitialized:
            return "Chưa khởi tạo"
        case .active:
            return "Hoạt động"
        case .transferred:
            return "Đã chuyển"
        case .revoked:
            return "Đã thu hồi"
        }
    }
    
    private var statusColor: Color {
        switch keyManager.identityStatus {
        case .notInitialized:
            return .gray
        case .active:
            return .green
        case .transferred, .revoked:
            return .orange
        }
    }
    
    private func eventTypeText(_ type: HandoverAuditLog.EventType) -> String {
        switch type {
        case .handoverInitiated:
            return "Bắt đầu chuyển tài khoản"
        case .tokenCreated:
            return "Tạo mã xác nhận"
        case .tokenTransferred:
            return "Gửi mã xác nhận"
        case .tokenVerified:
            return "Xác minh thành công"
        case .identityActivated:
            return "Kích hoạt tài khoản"
        case .identityRevoked:
            return "Thu hồi tài khoản"
        case .handoverCompleted:
            return "Hoàn tất chuyển tài khoản"
        case .handoverFailed:
            return "Chuyển tài khoản thất bại"
        case .replayAttempt:
            return "Phát hiện tấn công replay"
        case .expiredTokenRejected:
            return "Từ chối mã hết hạn"
        }
    }
}

#Preview {
    SettingsView()
}
