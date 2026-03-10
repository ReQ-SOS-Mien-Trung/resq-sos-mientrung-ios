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
    @StateObject private var phoneAuth = PhoneAuthManager.shared
    
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var rescuerUsername = ""
    @State private var rescuerPassword = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var authMode: AuthMode = .register
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var showIdentityHandover = false
    @State private var isRescuerMode = false
    @State private var showOTPSheet = false
    @State private var otpCode = ""
    @Binding var isSetupComplete: Bool
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, phone, password, confirmPassword, rescuerUsername, rescuerPassword, otp
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
                        if !isRescuerMode {
                            Picker("", selection: $authMode) {
                                ForEach(AuthMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: authMode) { newMode in
                                if newMode == .register { isRescuerMode = false }
                            }
                        }

                        // Rescuer mode toggle (chỉ hiện ở trang Đăng nhập)
                        if authMode == .login {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .foregroundColor(isRescuerMode ? DS.Colors.warning : DS.Colors.textTertiary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Lính cứu trợ")
                                        .font(DS.Typography.subheadline.bold())
                                        .foregroundColor(DS.Colors.text)
                                    Text("Đăng nhập với tư cách Rescuer")
                                        .font(DS.Typography.caption)
                                        .foregroundColor(DS.Colors.textSecondary)
                                }
                                Spacer()
                                Toggle("", isOn: $isRescuerMode)
                                    .labelsHidden()
                                    .tint(DS.Colors.warning)
                                    .onChange(of: isRescuerMode) { on in
                                        if on { authMode = .login }
                                    }
                            }
                            .padding(DS.Spacing.sm)
                            .background(
                                isRescuerMode
                                    ? DS.Colors.warning.opacity(0.08)
                                    : DS.Colors.surface
                            )
                            .overlay(Rectangle().stroke(
                                isRescuerMode ? DS.Colors.warning : DS.Colors.border,
                                lineWidth: DS.Border.medium
                            ))
                        }
                        
                        // Form
                        if isRescuerMode {
                            // Rescuer: nhập tài khoản và mật khẩu
                            VStack(spacing: DS.Spacing.md) {
                                // Username field
                                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                    Text("TÀI KHOẢN")
                                        .font(DS.Typography.caption).tracking(1)
                                        .foregroundColor(DS.Colors.textSecondary)
                                    
                                    HStack {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(DS.Colors.warning)
                                            .frame(width: 20)
                                        TextField("Nhập tài khoản...", text: $rescuerUsername)
                                            .textContentType(.username)
                                            .autocapitalization(.none)
                                            .disableAutocorrection(true)
                                            .foregroundColor(DS.Colors.text)
                                            .focused($focusedField, equals: .rescuerUsername)
                                    }
                                    .padding(DS.Spacing.sm)
                                    .background(DS.Colors.surface)
                                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
                                }

                                // Password field
                                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                    Text("MẬT KHẨU")
                                        .font(DS.Typography.caption).tracking(1)
                                        .foregroundColor(DS.Colors.textSecondary)
                                    
                                    HStack {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(DS.Colors.accent)
                                            .frame(width: 20)
                                        
                                        Group {
                                            if showPassword {
                                                TextField("Nhập mật khẩu...", text: $rescuerPassword)
                                            } else {
                                                SecureField("Nhập mật khẩu...", text: $rescuerPassword)
                                            }
                                        }
                                        .textContentType(.password)
                                        .foregroundColor(DS.Colors.text)
                                        .focused($focusedField, equals: .rescuerPassword)
                                        
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
                        } else {
                            VStack(spacing: DS.Spacing.md) {
                            // Phone field
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text("SỐ ĐIỆN THOẠI")
                                    .font(DS.Typography.caption).tracking(1)
                                    .foregroundColor(DS.Colors.textSecondary)
                                
                                HStack(spacing: 0) {
                                    Image(systemName: "phone.fill")
                                        .foregroundColor(DS.Colors.success)
                                        .frame(width: 20)
                                        .padding(.trailing, DS.Spacing.xs)
                                    
                                    Text("+84")
                                        .font(DS.Typography.body.monospacedDigit())
                                        .foregroundColor(DS.Colors.text)
                                    
                                    Divider()
                                        .frame(height: 20)
                                        .padding(.horizontal, DS.Spacing.xs)
                                    
                                    TextField("9 chữ số...", text: $phoneNumber)
                                        .textContentType(.telephoneNumber)
                                        .keyboardType(.phonePad)
                                        .foregroundColor(DS.Colors.text)
                                        .focused($focusedField, equals: .phone)
                                        .onChange(of: phoneNumber) { newValue in
                                            // Chỉ cho nhập số, tối đa 10 ký tự
                                            let filtered = newValue.filter { $0.isNumber }
                                            let trimmed = String(filtered.prefix(10))
                                            if trimmed != newValue { phoneNumber = trimmed }
                                        }
                                }
                                .padding(DS.Spacing.sm)
                                .background(DS.Colors.surface)
                                .overlay(Rectangle().stroke(
                                    phoneValidationColor,
                                    lineWidth: DS.Border.medium
                                ))
                                
                                // Validation hint
                                if !phoneNumber.isEmpty && !isPhoneValid {
                                    Text("Nhập 9-10 chữ số (VD: 901234567)")
                                        .font(DS.Typography.caption)
                                        .foregroundColor(DS.Colors.accent)
                                }
                            }

                            // Password field
                            if authMode == .register || authMode == .login {
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
                                    .onChange(of: password) { newValue in
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
                                .overlay(Rectangle().stroke(
                                    pinValidationColor,
                                    lineWidth: DS.Border.medium
                                ))
                                
                                // PIN validation hints
                                if !password.isEmpty {
                                    if password.count < 6 {
                                        Text("Cần nhập đủ 6 chữ số")
                                            .font(DS.Typography.caption)
                                            .foregroundColor(DS.Colors.textSecondary)
                                    } else if isWeakPIN(password) {
                                        Text("⚠️ Mã PIN quá đơn giản, vui lòng chọn mã khác")
                                            .font(DS.Typography.caption)
                                            .foregroundColor(DS.Colors.accent)
                                    }
                                }
                            }

                            // Confirm PIN field (chỉ khi đăng ký)
                            if authMode == .register {
                                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                    Text("NHẬP LẠI MÃ PIN")
                                        .font(DS.Typography.caption).tracking(1)
                                        .foregroundColor(DS.Colors.textSecondary)

                                    HStack {
                                        Image(systemName: "lock.rotation")
                                            .foregroundColor(DS.Colors.accent)
                                            .frame(width: 20)

                                        SecureField("Nhập lại 6 chữ số...", text: $confirmPassword)
                                            .keyboardType(.numberPad)
                                            .textContentType(.oneTimeCode)
                                            .foregroundColor(DS.Colors.text)
                                            .focused($focusedField, equals: .confirmPassword)
                                            .onChange(of: confirmPassword) { newValue in
                                                let filtered = newValue.filter { $0.isNumber }
                                                if filtered.count > 6 {
                                                    confirmPassword = String(filtered.prefix(6))
                                                } else if filtered != newValue {
                                                    confirmPassword = filtered
                                                }
                                            }
                                    }
                                    .padding(DS.Spacing.sm)
                                    .background(DS.Colors.surface)
                                    .overlay(Rectangle().stroke(
                                        confirmPinValidationColor,
                                        lineWidth: DS.Border.medium
                                    ))

                                    // Confirm PIN hint
                                    if !confirmPassword.isEmpty && confirmPassword.count == 6 && confirmPassword != password {
                                        Text("Mã PIN không khớp")
                                            .font(DS.Typography.caption)
                                            .foregroundColor(DS.Colors.accent)
                                    }
                                }
                            } // end if register (confirm PIN)
                            }
                        }


                        } // end else (normal form fields)
                        
                        // Submit button
                        if isRescuerMode {
                            Button { submitRescuer() } label: {
                                HStack(spacing: DS.Spacing.sm) {
                                    if isLoading { ProgressView().tint(.white) }
                                    Image(systemName: "shield.lefthalf.filled")
                                    Text("ĐĂNG NHẬP LÍNH CỨU TRỢ")
                                        .font(DS.Typography.headline).tracking(2)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.md)
                                .background(isFormValid && !isLoading ? DS.Colors.warning : DS.Colors.textTertiary)
                                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
                                .shadow(color: .black.opacity(0.2), radius: 0, x: 3, y: 3)
                            }
                            .disabled(!isFormValid || isLoading)
                        } else if authMode == .register {
                            Button { sendOTP() } label: {
                                HStack(spacing: DS.Spacing.sm) {
                                    if isLoading { ProgressView().tint(.white) }
                                    Image(systemName: "ellipsis.bubble.fill")
                                    Text("GỬI MÃ XÁC MINH")
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
                        } else {
                            // Đăng nhập: PIN là chính, SMS OTP là tuỳ chọn
                            VStack(spacing: DS.Spacing.sm) {
                                Button { loginWithPIN() } label: {
                                    HStack(spacing: DS.Spacing.sm) {
                                        if isLoading { ProgressView().tint(.white) }
                                        Image(systemName: "lock.fill")
                                        Text("ĐĂNG NHẬP")
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

                                HStack {
                                    EditorialDivider()
                                    Text("hoặc")
                                        .font(DS.Typography.caption)
                                        .foregroundColor(DS.Colors.textTertiary)
                                        .padding(.horizontal, DS.Spacing.sm)
                                    EditorialDivider()
                                }

                                Button { sendOTP() } label: {
                                    HStack(spacing: DS.Spacing.sm) {
                                        Image(systemName: "ellipsis.bubble.fill")
                                        Text("ĐĂNG NHẬP BẰNG SMS")
                                            .font(DS.Typography.subheadline).tracking(1)
                                    }
                                    .foregroundColor(DS.Colors.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, DS.Spacing.sm)
                                    .background(DS.Colors.surface)
                                    .overlay(Rectangle().stroke(DS.Colors.accent, lineWidth: DS.Border.medium))
                                }
                                .disabled(!isPhoneValid || isLoading)
                            }
                        }
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
        .sheet(isPresented: $showOTPSheet) {
            otpVerificationSheet
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                focusedField = nil
            }
        )
    }
    
    // MARK: - Validation helpers
    
    /// Danh sách PIN yếu bị chặn
    private static let weakPINs: Set<String> = [
        "000000", "111111", "222222", "333333", "444444",
        "555555", "666666", "777777", "888888", "999999",
        "123456", "654321", "123123", "112233"
    ]
    
    private func isWeakPIN(_ pin: String) -> Bool {
        Self.weakPINs.contains(pin)
    }
    
    /// Chuẩn hoá số điện thoại thành +84...
    private func normalizedPhone(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        if digits.hasPrefix("0") {
            return "+84" + digits.dropFirst()
        }
        return "+84" + digits
    }
    
    private var isPhoneValid: Bool {
        let digits = phoneNumber.filter { $0.isNumber }
        // 9 digits (without leading 0) or 10 digits (with leading 0)
        return digits.count >= 9 && digits.count <= 10
    }
    
    private var isPINValid: Bool {
        password.count == 6 && !isWeakPIN(password)
    }
    
    private var phoneValidationColor: Color {
        if phoneNumber.isEmpty { return DS.Colors.border }
        return isPhoneValid ? DS.Colors.success : DS.Colors.accent
    }
    
    private var pinValidationColor: Color {
        if password.isEmpty { return DS.Colors.border }
        if password.count < 6 { return DS.Colors.border }
        return isPINValid ? DS.Colors.success : DS.Colors.accent
    }
    
    private var confirmPinValidationColor: Color {
        if confirmPassword.isEmpty { return DS.Colors.border }
        if confirmPassword.count < 6 { return DS.Colors.border }
        return confirmPassword == password ? DS.Colors.success : DS.Colors.accent
    }
    
    private var isFormValid: Bool {
        if isRescuerMode {
            let trimmedUser = rescuerUsername.trimmingCharacters(in: .whitespaces)
            let trimmedPass = rescuerPassword.trimmingCharacters(in: .whitespaces)
            return !trimmedUser.isEmpty && !trimmedPass.isEmpty
        }
        if authMode == .register {
            return isPhoneValid && isPINValid && confirmPassword == password
        }
        // Đăng nhập bằng PIN: cần phone + PIN hợp lệ
        return isPhoneValid && password.count == 6
    }

    // MARK: - OTP Verification Sheet
    
    private var otpVerificationSheet: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "ellipsis.bubble.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(DS.Colors.accent)
                    
                    Text("Xác minh OTP")
                        .font(DS.Typography.largeTitle)
                        .foregroundColor(DS.Colors.text)
                    
                    Text("Nhập mã 6 số đã gửi đến \(normalizedPhone(phoneNumber))")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // OTP input
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("MÃ OTP")
                        .font(DS.Typography.caption).tracking(1)
                        .foregroundColor(DS.Colors.textSecondary)
                    
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(DS.Colors.accent)
                            .frame(width: 20)
                        
                        TextField("6 chữ số...", text: $otpCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .foregroundColor(DS.Colors.text)
                            .focused($focusedField, equals: .otp)
                            .onChange(of: otpCode) { newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered.count > 6 {
                                    otpCode = String(filtered.prefix(6))
                                } else if filtered != newValue {
                                    otpCode = filtered
                                }
                            }
                    }
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.surface)
                    .overlay(Rectangle().stroke(
                        otpCode.count == 6 ? DS.Colors.success : DS.Colors.border,
                        lineWidth: DS.Border.medium
                    ))
                }
                
                // Error from PhoneAuthManager
                if let error = phoneAuth.errorMessage {
                    Text(error)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.accent)
                        .multilineTextAlignment(.center)
                }
                
                // Verify button
                Button {
                    Task { await verifyOTPAndSubmit() }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        if phoneAuth.isLoading { ProgressView().tint(.white) }
                        Text("XÁC NHẬN")
                            .font(DS.Typography.headline).tracking(2)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(otpCode.count == 6 && !phoneAuth.isLoading ? DS.Colors.accent : DS.Colors.textTertiary)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
                    .shadow(color: .black.opacity(0.2), radius: 0, x: 3, y: 3)
                }
                .disabled(otpCode.count != 6 || phoneAuth.isLoading)
                
                // Resend OTP
                HStack {
                    if phoneAuth.resendCooldown > 0 {
                        Text("Gửi lại sau \(phoneAuth.resendCooldown)s")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                    } else {
                        Button("Gửi lại mã OTP") {
                            Task {
                                await phoneAuth.resendOTP(to: normalizedPhone(phoneNumber))
                            }
                        }
                        .font(DS.Typography.subheadline.bold())
                        .foregroundColor(DS.Colors.accent)
                    }
                }
                
                Spacer()
            }
            .padding(DS.Spacing.lg)
            .background(DS.Colors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") {
                        showOTPSheet = false
                        otpCode = ""
                        phoneAuth.reset()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Login with PIN
    
    private func loginWithPIN() {
        guard isPhoneValid else {
            errorMessage = "Số điện thoại không hợp lệ (cần 9-10 chữ số)"
            showError = true
            return
        }
        guard password.count == 6 else {
            errorMessage = "Mã PIN phải đúng 6 chữ số"
            showError = true
            return
        }

        let formattedPhone = normalizedPhone(phoneNumber)
        isLoading = true
        AuthService.shared.login(phone: formattedPhone, password: password) { result in
            isLoading = false
            switch result {
            case .success(let response):
                AuthSessionStore.shared.save(from: response)
                let displayName = response.displayName ?? formattedPhone
                userProfile.saveUser(name: displayName, phoneNumber: formattedPhone)
                isSetupComplete = true
            case .failure(let error):
                handleError(error)
            }
        }
    }

    // MARK: - Send OTP
    
    private func sendOTP() {
        guard isPhoneValid else {
            errorMessage = "Số điện thoại không hợp lệ (cần 9-10 chữ số)"
            showError = true
            return
        }

        if authMode == .register {
            guard password.count == 6 else {
                errorMessage = "Mã PIN phải đúng 6 chữ số"
                showError = true
                return
            }
            guard !isWeakPIN(password) else {
                errorMessage = "Mã PIN quá đơn giản, vui lòng chọn mã khác"
                showError = true
                return
            }
            guard confirmPassword == password else {
                errorMessage = "Mã PIN nhập lại không khớp"
                showError = true
                return
            }
        }

        let formattedPhone = normalizedPhone(phoneNumber)
        
        Task {
            print("📱 Sending OTP to: \(formattedPhone)")
            await phoneAuth.sendOTP(to: formattedPhone)
            print("📱 OTP sent: \(phoneAuth.otpSent), error: \(phoneAuth.errorMessage ?? "none")")
            if phoneAuth.otpSent {
                otpCode = ""
                showOTPSheet = true
            } else if let error = phoneAuth.errorMessage {
                errorMessage = error
                showError = true
            }
        }
    }
    
    // MARK: - Verify OTP & Submit to Backend
    
    private func verifyOTPAndSubmit() async {
        await phoneAuth.verifyOTP(otpCode)
        
        guard let idToken = phoneAuth.firebaseIdToken else { return }
        
        let formattedPhone = normalizedPhone(phoneNumber)
        
        if authMode == .register {
            // Đăng ký: gửi phone + password + firebaseIdToken
            isLoading = true
            AuthService.shared.register(phone: formattedPhone, password: password, firebaseIdToken: idToken) { result in
                isLoading = false
                switch result {
                case .success:
                    showOTPSheet = false
                    phoneAuth.reset()
                    successMessage = "Đăng ký thành công! Vui lòng đăng nhập để tiếp tục."
                    showSuccess = true
                case .failure(let error):
                    handleError(error)
                }
            }
        } else {
            // Đăng nhập: gửi firebaseIdToken lên endpoint firebase-phone-login
            isLoading = true
            AuthService.shared.firebasePhoneLogin(idToken: idToken) { result in
                isLoading = false
                switch result {
                case .success(let response):
                    showOTPSheet = false
                    phoneAuth.reset()
                    AuthSessionStore.shared.save(from: response)
                    let displayName = response.displayName ?? formattedPhone
                    userProfile.saveUser(name: displayName, phoneNumber: formattedPhone)
                    isSetupComplete = true
                case .failure(let error):
                    handleError(error)
                }
            }
        }
    }

    private func submitRescuer() {
        let trimmedUser = rescuerUsername.trimmingCharacters(in: .whitespaces)
        let trimmedPass = rescuerPassword.trimmingCharacters(in: .whitespaces)

        guard !trimmedUser.isEmpty else {
            errorMessage = "Vui lòng nhập tài khoản"
            showError = true
            return
        }
        guard !trimmedPass.isEmpty else {
            errorMessage = "Vui lòng nhập mật khẩu"
            showError = true
            return
        }

        isLoading = true
        AuthService.shared.login(username: trimmedUser, phone: nil, password: trimmedPass) { result in
            isLoading = false
            switch result {
            case .success(let response):
                AuthSessionStore.shared.save(from: response)
                let displayName = response.displayName ?? "Lính Cứu Trợ"
                userProfile.saveUser(name: displayName, phoneNumber: "")
                isSetupComplete = true
            case .failure(let error):
                handleError(error)
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
