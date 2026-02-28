//
//  SetupProfileView.swift
//  SosMienTrung
//
//  Màn hình setup profile lần đầu
//

import SwiftUI
import MultipeerConnectivity

struct SetupProfileView: View {
    @ObservedObject var userProfile = UserProfile.shared
    
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var authMode: AuthMode = .register
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var showIdentityHandover = false
    @Binding var isSetupComplete: Bool
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, phone, password
    }

    enum AuthMode: String, CaseIterable, Identifiable {
        case register = "Đăng ký"
        case login = "Đăng nhập"

        var id: String { rawValue }
    }
    
    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    
                    // Main card
                    VStack(spacing: DS.Spacing.md) {
                        // Header
                        VStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(DS.Colors.accent)
                            
                            EyebrowLabel(text: "THIẾT LẬP")
                            Text("Thông Tin")
                                .font(DS.Typography.largeTitle)
                                .foregroundColor(DS.Colors.text)
                            EditorialDivider(height: DS.Border.thick)
                        }
                        .frame(maxWidth: .infinity)

                        // Auth mode selector
                        Picker("", selection: $authMode) {
                            ForEach(AuthMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        // Form
                        VStack(spacing: DS.Spacing.md) {
                            // Phone field
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("SỐ ĐIỆN THOẠI")
                                    .font(DS.Typography.caption).tracking(1)
                                    .foregroundColor(DS.Colors.textSecondary)
                                
                                HStack {
                                    Image(systemName: "phone.fill")
                                        .foregroundColor(DS.Colors.success)
                                        .frame(width: 20)
                                    TextField("Nhập số điện thoại...", text: $phoneNumber)
                                        .textContentType(.telephoneNumber)
                                        .keyboardType(.phonePad)
                                        .foregroundColor(DS.Colors.text)
                                        .focused($focusedField, equals: .phone)
                                }
                                .padding(DS.Spacing.sm)
                                .background(DS.Colors.surface)
                                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
                            }

                            // Password field
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("MÃ PIN (6 CHỮ SỐ)")
                                    .font(DS.Typography.caption).tracking(1)
                                    .foregroundColor(DS.Colors.textSecondary)

                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(DS.Colors.accent)
                                        .frame(width: 20)

                                    Group {
                                        if showPassword {
                                            TextField("Nhập 6 chữ số...", text: $password)
                                        } else {
                                            SecureField("Nhập 6 chữ số...", text: $password)
                                        }
                                    }
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .foregroundColor(DS.Colors.text)
                                    .focused($focusedField, equals: .password)
                                    .onChange(of: password) { _, newValue in
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered.count > 6 {
                                            password = String(filtered.prefix(6))
                                        } else if filtered != newValue {
                                            password = filtered
                                        }
                                    }

                                    Button { showPassword.toggle() } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundColor(DS.Colors.textSecondary)
                                    }
                                }
                                .padding(DS.Spacing.sm)
                                .background(DS.Colors.surface)
                                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
                            }
                        }
                        
                        // Submit button
                        Button { submit() } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                if isLoading { ProgressView().tint(.white) }
                                Text(authMode == .register ? "TẠO TÀI KHOẢN MỚI" : "ĐĂNG NHẬP")
                                    .font(DS.Typography.headline).tracking(2)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                            .background(isFormValid && !isLoading ? DS.Colors.accent : DS.Colors.textTertiary)
                            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
                            .shadow(color: .black.opacity(0.2), radius: 0, x: 3, y: 3)
                        }
                        .disabled(!isFormValid || isLoading)
                    }
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.surface)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
                    .padding(.horizontal, DS.Spacing.md)
                    
                    // Import from old device
                    if authMode == .register {
                        VStack(spacing: DS.Spacing.sm) {
                            HStack {
                                EditorialDivider()
                                Text("hoặc")
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.textTertiary)
                                    .padding(.horizontal, DS.Spacing.sm)
                                EditorialDivider()
                            }
                            
                            Button { showIdentityHandover = true } label: {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("NHẬP TỪ THIẾT BỊ CŨ").font(DS.Typography.headline).tracking(1)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.md)
                                .background(DS.Colors.warning)
                                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
                                .shadow(color: .black.opacity(0.2), radius: 0, x: 3, y: 3)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                    }
                }
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, 40)
            }
        }
        .alert("Lỗi", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Thành công", isPresented: $showSuccess) {
            Button("Đăng nhập ngay", role: .cancel) {
                authMode = .login
            }
        } message: {
            Text(successMessage)
        }
        .fullScreenCover(isPresented: $showIdentityHandover) {
            SetupIdentityHandoverView(isSetupComplete: $isSetupComplete)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                focusedField = nil
            }
        )
    }
    
    private var isFormValid: Bool {
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespaces)
        let trimmedPassword = password.trimmingCharacters(in: .whitespaces)

        // Phone >= 9 digits, PIN must be exactly 6 digits
        return !trimmedPhone.isEmpty && trimmedPhone.count >= 9 && trimmedPassword.count == 6
    }

    private func submit() {
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespaces)
        let trimmedPassword = password.trimmingCharacters(in: .whitespaces)

        guard trimmedPhone.count >= 9 else {
            errorMessage = "Số điện thoại không hợp lệ"
            showError = true
            return
        }

        guard trimmedPassword.count == 6 else {
            errorMessage = "Mã PIN phải đúng 6 chữ số"
            showError = true
            return
        }

        if authMode == .register {
            isLoading = true
            AuthService.shared.register(phone: trimmedPhone, password: trimmedPassword) { result in
                isLoading = false
                switch result {
                case .success:
                    // Registration successful - prompt user to login
                    successMessage = "Đăng ký thành công! Vui lòng đăng nhập để tiếp tục."
                    showSuccess = true
                case .failure(let error):
                    handleError(error)
                }
            }
        } else {
            isLoading = true
            AuthService.shared.login(phone: trimmedPhone, password: trimmedPassword) { result in
                isLoading = false
                switch result {
                case .success(let response):
                    AuthSessionStore.shared.save(from: response)
                    let displayName = response.fullName ?? response.username ?? trimmedPhone
                    userProfile.saveUser(name: displayName, phoneNumber: trimmedPhone)
                    isSetupComplete = true
                case .failure(let error):
                    handleError(error)
                }
            }
        }
    }

    private func handleError(_ error: Error) {
        if let authError = error as? AuthService.AuthServiceError {
            errorMessage = authError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }
}

// MARK: - Setup Identity Handover View
/// Phiên bản đơn giản của IdentityHandoverView dùng cho màn hình setup lần đầu
struct SetupIdentityHandoverView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var handoverManager = IdentityHandoverManager.shared
    @StateObject private var keyManager = IdentityKeyManager.shared
    @Binding var isSetupComplete: Bool
    
    @State private var showQRScanner = false
    @State private var scannedCode = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        VStack(spacing: DS.Spacing.md) {
                            // Header
                            VStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(DS.Colors.warning)
                                
                                EyebrowLabel(text: "CHUYỂN")
                                Text("Tài Khoản")
                                    .font(DS.Typography.largeTitle)
                                    .foregroundColor(DS.Colors.text)
                                
                                Text("Chuyển tài khoản từ thiết bị cũ sang thiết bị này")
                                    .font(DS.Typography.subheadline)
                                    .foregroundColor(DS.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                                EditorialDivider(height: DS.Border.thick)
                            }
                            
                            contentView
                        }
                        .padding(DS.Spacing.lg)
                        .background(DS.Colors.surface)
                        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
                    }
                    .padding(DS.Spacing.md)
                }
            }
            .background(DS.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") {
                        handoverManager.stopHandover()
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.text)
                }
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { code in
                processQRCode(code)
            }
        }
        .onReceive(handoverManager.$state) { state in
            if case .completed = state {
                // Chuyển tài khoản thành công
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isSetupComplete = true
                    dismiss()
                }
            }
        }
        .onAppear {
            setupHandoverCallback()
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch handoverManager.state {
        case .idle:
            optionsView
            
        case .browsing:
            browsingView
            
        case .connecting:
            connectingView
            
        case .requestingTakeover:
            requestingView
            
        case .receivingToken, .verifyingToken, .activatingIdentity:
            processingView
            
        case .completed:
            completedView
            
        case .failed(let error):
            failedView(error: error)
            
        default:
            optionsView
        }
    }
    
    // MARK: - Options View
    private var optionsView: some View {
        VStack(spacing: 16) {
            // P2P Option
            optionCard(
                icon: "wifi",
                iconColor: .blue,
                title: "Kết nối P2P",
                description: "Tìm và kết nối trực tiếp với thiết bị cũ qua WiFi/Bluetooth"
            ) {
                handoverManager.startAsNewDevice()
            }
            
            // QR Option
            optionCard(
                icon: "qrcode.viewfinder",
                iconColor: .green,
                title: "Quét mã QR",
                description: "Quét mã QR từ thiết bị cũ (dùng khi thiết bị cũ sắp hết pin)"
            ) {
                showQRScanner = true
            }
            
            // Instructions
            instructionsCard
        }
    }
    
    // MARK: - Browsing View
    private var browsingView: some View {
        VStack(spacing: 20) {
            if handoverManager.discoveredPeers.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(DS.Colors.text)
                    
                    Text("Đang tìm thiết bị cũ...")
                        .font(.headline)
                        .foregroundColor(DS.Colors.text)
                    
                    Text("Đảm bảo thiết bị cũ đang ở chế độ 'Chuyển tài khoản'")
                        .font(.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                Text("Chọn thiết bị")
                    .font(.headline)
                    .foregroundColor(DS.Colors.text)
                
                ForEach(handoverManager.discoveredPeers, id: \.displayName) { peer in
                    Button {
                        handoverManager.connectToPeer(peer)
                    } label: {
                        HStack {
                            Image(systemName: "iphone")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(peer.displayName)
                                    .font(.headline)
                                    .foregroundColor(DS.Colors.text)
                                
                                Text("Nhấn để kết nối")
                                    .font(.caption)
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(DS.Colors.textTertiary)
                        }
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.surface)
                        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                    }
                }
            }
            
            cancelButton
        }
    }
    
    // MARK: - Connecting View
    private var connectingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(DS.Colors.text)
            
            Text("Đang kết nối...")
                .font(.headline)
                .foregroundColor(DS.Colors.text)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Requesting View
    private var requestingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.clock")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Đang chờ xác nhận")
                .font(.headline)
                .foregroundColor(DS.Colors.text)
            
            Text("Vui lòng xác nhận yêu cầu trên thiết bị cũ")
                .font(.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            cancelButton
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: handoverManager.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(maxWidth: 200)
            
            Text(handoverManager.statusMessage)
                .font(.headline)
                .foregroundColor(DS.Colors.text)
            
            Text("Vui lòng không tắt ứng dụng")
                .font(.caption)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Completed View
    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Thành công!")
                .font(.title2.bold())
                .foregroundColor(DS.Colors.text)
            
            Text("Tài khoản đã được nhập thành công")
                .font(.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Failed View
    private func failedView(error: HandoverError) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Không thành công")
                .font(.title2.bold())
                .foregroundColor(DS.Colors.text)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                handoverManager.stopHandover()
            } label: {
                Text("Thử lại")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.accent)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }
    
    // MARK: - Helper Views
    private func optionCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Rectangle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(iconColor)
                }
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)
                    Text(description)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface)
            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
            .shadow(color: .black.opacity(0.1), radius: 0, x: 2, y: 2)
        }
    }
    
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(DS.Colors.info)
                Text("HƯỚNG DẪN")
                    .font(DS.Typography.caption).tracking(1)
                    .foregroundColor(DS.Colors.text)
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                instructionRow(number: "1", text: "Trên thiết bị cũ, vào Cài đặt → Chuyển tài khoản")
                instructionRow(number: "2", text: "Chọn 'Bắt đầu chuyển' hoặc 'Tạo mã QR'")
                instructionRow(number: "3", text: "Trên thiết bị này, kết nối P2P hoặc quét mã QR")
                instructionRow(number: "4", text: "Xác nhận trên thiết bị cũ để hoàn tất")
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.info.opacity(0.06))
        .overlay(Rectangle().stroke(DS.Colors.info.opacity(0.3), lineWidth: DS.Border.thin))
    }
    
    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text(number)
                .font(.system(size: 11, weight: .black))
                .foregroundColor(DS.Colors.info)
                .frame(width: 18, height: 18)
                .background(DS.Colors.info.opacity(0.12))
            
            Text(text)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
    
    private var cancelButton: some View {
        Button {
            handoverManager.stopHandover()
        } label: {
            Text("HUỶ")
                .font(DS.Typography.headline).tracking(1)
                .foregroundColor(DS.Colors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.surface)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
        }
    }
    
    // MARK: - Actions
    private func setupHandoverCallback() {
        handoverManager.onHandoverComplete = { identity in
            // Identity đã được activate trong IdentityHandoverManager
            // UserProfile cũng đã được cập nhật
        }
    }
    
    private func processQRCode(_ code: String) {
        do {
            try handoverManager.processEmergencyQR(code)
        } catch {
            print("Failed to process QR: \(error)")
        }
    }
}
