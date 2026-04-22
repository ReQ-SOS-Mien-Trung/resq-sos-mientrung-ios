//
//  SettingsView.swift
//  SosMienTrung
//
//  Màn hình Cài đặt
//

import SwiftUI
import Combine
import UIKit
import CoreLocation
import PhotosUI

private func normalizedAvatarURL(from rawValue: String) -> URL? {
    let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedValue.isEmpty else { return nil }

    if let directURL = URL(string: trimmedValue), directURL.scheme != nil {
        return directURL
    }

    if let encodedValue = trimmedValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
       let encodedURL = URL(string: encodedValue),
       encodedURL.scheme != nil {
        return encodedURL
    }

    let httpsValue = "https://\(trimmedValue)"
    if let httpsURL = URL(string: httpsValue) {
        return httpsURL
    }

    if let encodedHttpsValue = httpsValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
        return URL(string: encodedHttpsValue)
    }

    return nil
}

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
@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "appTheme")
            scheduleAppearanceSync()
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
            scheduleAppearanceSync()
        }
    }
    
    init() {
        let themeRaw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue
        self.selectedTheme = AppTheme(rawValue: themeRaw) ?? .system
        
        let langRaw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.vietnamese.rawValue
        self.selectedLanguage = AppLanguage(rawValue: langRaw) ?? .vietnamese
        
        let savedBatterySaving = UserDefaults.standard.bool(forKey: "batterySavingMode")
        self.batterySavingMode = savedBatterySaving
        scheduleAppearanceSync()
    }

    private func scheduleAppearanceSync() {
        let theme = selectedTheme
        let isBatterySavingEnabled = batterySavingMode

        Task { @MainActor in
            AppearanceManager.shared.apply(
                theme: theme,
                batterySavingMode: isBatterySavingEnabled
            )
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
    @State private var isRefreshingCurrentUser = false
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
                            title: "Hồ sơ người thân",
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
            Text("ResQ — SOS Miền Trung v1.0.0\n\nỨng dụng hỗ trợ kết nối và cứu trợ trong thiên tai, hoạt động ngoại tuyến qua mạng mesh.\n\n© 2026 Dự án Capstone")
        }
        .alert("Đăng xuất", isPresented: $showLogoutConfirmation) {
            Button("Hủy", role: .cancel) { }
            Button("Đăng xuất", role: .destructive) {
                performLogout()
            }
        } message: {
            Text("Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?")
        }
        .task {
            await refreshCurrentUserIfNeededForAvatar()
        }
    }

    // MARK: - Logout Action
    private func performLogout() {
        isLoggingOut = true
        AuthService.shared.logout { _ in
            isLoggingOut = false
        }
    }

    @MainActor
    private func refreshCurrentUserIfNeededForAvatar() async {
        guard authSession.hasAuthenticatedSession else { return }
        guard !isRefreshingCurrentUser else { return }

        let currentAvatar = userProfile.currentUser?.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard currentAvatar.isEmpty else { return }

        isRefreshingCurrentUser = true
        defer { isRefreshingCurrentUser = false }

        do {
            let response = try await AuthService.shared.fetchCurrentUser()
            AuthSessionStore.shared.apply(currentUser: response)
            let fallbackPhone = userProfile.currentUser?.phoneNumber ?? authSession.session?.username ?? authSession.session?.email
            userProfile.apply(currentUser: response, fallbackPhone: fallbackPhone)
        } catch {
            print("[SettingsView] Failed to refresh current user: \(error.localizedDescription)")
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
            syncStatus = "chỉ lưu cục bộ"
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

                if let avatarURL = profileAvatarURL {
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 88, height: 88)
                                .clipped()
                        default:
                            profileAvatarFallbackView
                        }
                    }
                } else {
                    profileAvatarFallbackView
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

    private var profileAvatarURL: URL? {
        guard let rawURL = userProfile.currentUser?.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawURL.isEmpty else {
            return nil
        }
        return normalizedAvatarURL(from: rawURL)
    }

    private var profileAvatarFallbackView: some View {
        Group {
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
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
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

    @ObservedObject private var authSession = AuthSessionStore.shared
    @StateObject private var locationManager = LocationManager()
    private let avatarUploader = CloudinaryImageUploader.resQ(folder: "resq/profile")

    @State private var name: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumber: String = ""
    @State private var address: String = ""
    @State private var ward: String = ""
    @State private var province: String = ""
    @State private var avatarUrl: String = ""
    @State private var latitudeText: String = ""
    @State private var longitudeText: String = ""
    @State private var isSaving = false
    @State private var isLoadingVictimProfile = false
    @State private var isUploadingAvatar = false
    @State private var hasLoadedVictimProfile = false
    @State private var showAvatarSourceSheet = false
    @State private var showPhotoPicker = false
    @State private var showCameraPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pickedCameraImage: UIImage?
    @State private var localAvatarImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                avatarSection

                if isLoadingVictimProfile {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Đang tải thông tin hồ sơ...")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if isVictimRole {
                    victimProfileSections
                } else {
                    basicProfileSection
                }
            }
            .navigationTitle(isVictimRole ? "Cập nhật hồ sơ" : "Sửa hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(isSaving || isLoadingVictimProfile || isUploadingAvatar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                    .disabled(isSaving || isUploadingAvatar)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving || isUploadingAvatar {
                        ProgressView()
                    } else {
                        Button("Lưu") {
                            saveProfile()
                        }
                        .fontWeight(.semibold)
                        .disabled(!isFormValid || isLoadingVictimProfile || isUploadingAvatar)
                    }
                }
            }
            .onAppear {
                populateFormFromCurrentUser()
            }
            .task {
                await loadVictimProfileIfNeeded()
            }
            .alert("Lỗi", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("Ảnh đại diện", isPresented: $showAvatarSourceSheet, titleVisibility: .visible) {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Chọn từ thư viện", systemImage: "photo.on.rectangle")
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCameraPicker = true
                    } label: {
                        Label("Chụp từ camera", systemImage: "camera")
                    }
                }

                if isVictimRole && hasAvatar {
                    Button("Xóa ảnh", role: .destructive) {
                        localAvatarImage = nil
                        avatarUrl = ""
                    }
                }

                Button("Huỷ", role: .cancel) { }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .sheet(isPresented: $showCameraPicker) {
                AppCameraPicker(image: $pickedCameraImage)
                    .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItem) { newItem in
                guard let item = newItem else { return }
                Task {
                    await handleAvatarPhotoLibrarySelection(item)
                    await MainActor.run {
                        selectedPhotoItem = nil
                    }
                }
            }
            .onChange(of: pickedCameraImage) { image in
                guard let image else { return }
                Task {
                    await uploadAvatar(image)
                    await MainActor.run {
                        pickedCameraImage = nil
                    }
                }
            }
        }
    }

    private var isVictimRole: Bool {
        authSession.session?.roleId == 5
    }

    @ViewBuilder
    private var avatarSection: some View {
        Section {
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 100, height: 100)

                    if let localAvatarImage {
                        Image(uiImage: localAvatarImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else if let avatarPreviewURL,
                              !avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        AsyncImage(url: avatarPreviewURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                avatarFallbackView
                            }
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                    } else {
                        avatarFallbackView
                    }

                    if isUploadingAvatar {
                        Circle()
                            .fill(.black.opacity(0.38))
                            .frame(width: 100, height: 100)
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                            }
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)

            if isVictimRole {
                Button {
                    showAvatarSourceSheet = true
                } label: {
                    Label(hasAvatar ? "Đổi ảnh đại diện" : "Chọn ảnh đại diện", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .listRowBackground(Color.clear)

                Text(avatarHelperText)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .listRowBackground(Color.clear)
            } else {
                Text("Ảnh đại diện hiện chỉ hiển thị trên thiết bị này.")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .listRowBackground(Color.clear)
            }
        }
    }

    private var avatarFallbackView: some View {
        Group {
            if let firstCharacter = displayNamePreview.first {
                Text(String(firstCharacter).uppercased())
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
            }
        }
    }

    @ViewBuilder
    private var basicProfileSection: some View {
        Section {
            TextField("Tên", text: $name)
                .textContentType(.name)

            TextField("Số điện thoại", text: $phoneNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .disabled(true)
        } header: {
            Text("Thông tin cá nhân")
        } footer: {
            Text("Bạn có thể cập nhật tên hiển thị. Số điện thoại được lấy từ tài khoản và không chỉnh sửa tại đây.")
        }
    }

    @ViewBuilder
    private var victimProfileSections: some View {
        Section {
            TextField("Tên", text: $firstName)
                .textContentType(.givenName)

            TextField("Họ", text: $lastName)
                .textContentType(.familyName)

            TextField("Số điện thoại", text: $phoneNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .disabled(true)
        } header: {
            Text("Thông tin cơ bản")
        } footer: {
            Text("Thông tin này giúp tổng đài liên hệ nhanh hơn khi cần hỗ trợ. Số điện thoại được lấy từ tài khoản và không chỉnh sửa tại đây.")
        }

        Section {
            TextField("Địa chỉ", text: $address, axis: .vertical)
                .lineLimit(2...4)

            TextField("Phường/Xã", text: $ward)
                .textContentType(.addressCityAndState)

            TextField("Tỉnh/Thành", text: $province)
                .textContentType(.addressCity)
        } header: {
            Text("Địa chỉ")
        }

        Section {
            TextField("Vĩ độ", text: $latitudeText)
                .keyboardType(.decimalPad)

            TextField("Kinh độ", text: $longitudeText)
                .keyboardType(.decimalPad)

            Button {
                fillCoordinatesFromCurrentLocation()
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                    Text("Dùng vị trí hiện tại")
                    Spacer()
                    if locationManager.isFetchingLocation {
                        ProgressView()
                    }
                }
            }
            .disabled(locationManager.isFetchingLocation)
        } header: {
            Text("Vị trí trên bản đồ")
        } footer: {
            Text("Nếu để trống, ứng dụng sẽ dùng vị trí đã lưu trước đó.")
        }
    }

    private var isFormValid: Bool {
        hasValidDisplayName && hasValidPhoneNumber
    }

    private var hasValidDisplayName: Bool {
        if isVictimRole {
            return !displayNamePreview.isEmpty
        }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasValidPhoneNumber: Bool {
        let digits = phoneNumber.filter(\.isNumber)
        return !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && digits.count >= 9
    }

    private var displayNamePreview: String {
        if isVictimRole {
            let parts = [
                lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            ].filter { !$0.isEmpty }
            if !parts.isEmpty {
                return parts.joined(separator: " ")
            }
        }

        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var avatarPreviewURL: URL? {
        let trimmedURL = avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return nil }
        return normalizedAvatarURL(from: trimmedURL)
    }

    private var hasAvatar: Bool {
        localAvatarImage != nil || !avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var avatarHelperText: String {
        if isUploadingAvatar {
            return "Đang tải ảnh lên..."
        }
        if hasAvatar {
            return "Ảnh sẽ được cập nhật tự động vào hồ sơ của bạn."
        }
        return "Bạn chỉ cần chọn ảnh từ thư viện hoặc camera, ứng dụng sẽ tự cập nhật ảnh đại diện."
    }

    private func saveProfile() {
        if isVictimRole {
            Task {
                await saveVictimProfile()
            }
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Vui lòng nhập tên"
            showError = true
            return
        }

        guard hasValidPhoneNumber else {
            errorMessage = "Số điện thoại không hợp lệ"
            showError = true
            return
        }

        userProfile.saveUser(name: trimmedName, phoneNumber: trimmedPhone)
        dismiss()
    }

    @MainActor
    private func saveVictimProfile() async {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWard = ward.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedProvince = province.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAvatarUrl = avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let latitude = parsedCoordinate(from: latitudeText) ?? userProfile.currentUser?.latitude ?? 0
        let longitude = parsedCoordinate(from: longitudeText) ?? userProfile.currentUser?.longitude ?? 0

        guard !displayNamePreview.isEmpty else {
            errorMessage = "Vui lòng nhập ít nhất tên hoặc họ"
            showError = true
            return
        }

        guard hasValidPhoneNumber else {
            errorMessage = "Số điện thoại không hợp lệ"
            showError = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        let payload = UserProfileUpdateRequest(
            firstName: trimmedFirstName,
            lastName: trimmedLastName,
            phone: trimmedPhone,
            address: trimmedAddress,
            ward: trimmedWard,
            province: trimmedProvince,
            latitude: latitude,
            longitude: longitude,
            avatarUrl: trimmedAvatarUrl
        )

        do {
            let response = try await AuthService.shared.updateUserProfile(payload)

            userProfile.saveVictimProfile(
                firstName: trimmedFirstName,
                lastName: trimmedLastName,
                phoneNumber: trimmedPhone,
                address: trimmedAddress,
                ward: trimmedWard,
                province: trimmedProvince,
                latitude: latitude,
                longitude: longitude,
                avatarUrl: trimmedAvatarUrl
            )

            if let response {
                AuthSessionStore.shared.apply(currentUser: response)
                userProfile.apply(currentUser: response, fallbackPhone: trimmedPhone)
            }

            dismiss()
        } catch {
            if let authError = error as? AuthService.AuthServiceError {
                errorMessage = authError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
        }
    }

    @MainActor
    private func loadVictimProfileIfNeeded() async {
        guard isVictimRole, !hasLoadedVictimProfile else { return }

        hasLoadedVictimProfile = true
        isLoadingVictimProfile = true
        defer { isLoadingVictimProfile = false }

        do {
            let response = try await AuthService.shared.fetchCurrentUser()
            AuthSessionStore.shared.apply(currentUser: response)
            userProfile.apply(currentUser: response, fallbackPhone: userProfile.currentUser?.phoneNumber)
            populateFormFromCurrentUser()
        } catch {
            print("[EditProfileView] Failed to load victim profile: \(error.localizedDescription)")
        }
    }

    private func fillCoordinatesFromCurrentLocation() {
        locationManager.requestLocation { location in
            guard let location else {
                Task { @MainActor in
                    errorMessage = "Không lấy được vị trí hiện tại"
                    showError = true
                }
                return
            }

            Task { @MainActor in
                latitudeText = Self.coordinateString(location.coordinate.latitude)
                longitudeText = Self.coordinateString(location.coordinate.longitude)

                if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    do {
                        address = try await GeocodingService.shared.reverseGeocode(location.coordinate)
                    } catch {
                        print("[EditProfileView] Reverse geocode failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    @MainActor
    private func handleAvatarPhotoLibrarySelection(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Không thể đọc ảnh từ thư viện"
                showError = true
                return
            }

            await uploadAvatar(image)
        } catch {
            errorMessage = "Không thể chọn ảnh: \(error.localizedDescription)"
            showError = true
        }
    }

    @MainActor
    private func uploadAvatar(_ image: UIImage) async {
        let previousLocalAvatar = localAvatarImage
        let previousAvatarURL = avatarUrl

        localAvatarImage = image
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        do {
            avatarUrl = try await avatarUploader.upload(image: image, fileNamePrefix: "profile")
        } catch {
            localAvatarImage = previousLocalAvatar
            avatarUrl = previousAvatarURL
            errorMessage = "Tải ảnh lên thất bại: \(error.localizedDescription)"
            showError = true
        }
    }

    private func populateFormFromCurrentUser() {
        guard let currentUser = userProfile.currentUser else { return }

        localAvatarImage = nil
        name = currentUser.name
        phoneNumber = currentUser.phoneNumber
        address = currentUser.address ?? ""
        ward = currentUser.ward ?? ""
        province = currentUser.province ?? ""
        avatarUrl = currentUser.avatarUrl ?? ""
        latitudeText = Self.coordinateString(currentUser.latitude)
        longitudeText = Self.coordinateString(currentUser.longitude)

        let storedFirstName = currentUser.firstName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedLastName = currentUser.lastName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if storedFirstName != nil || storedLastName != nil {
            firstName = storedFirstName ?? ""
            lastName = storedLastName ?? ""
            return
        }

        let parts = currentUser.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)

        if let lastComponent = parts.last {
            firstName = lastComponent
            lastName = parts.dropLast().joined(separator: " ")
        } else {
            firstName = ""
            lastName = ""
        }
    }

    private func parsedCoordinate(from value: String) -> Double? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private static func coordinateString(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.6f", value)
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
