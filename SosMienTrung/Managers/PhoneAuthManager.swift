import Foundation
import Combine
import FirebaseAuth

/// Quản lý xác thực OTP qua Firebase Phone Auth
final class PhoneAuthManager: ObservableObject {
    static let shared = PhoneAuthManager()

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var otpSent = false
    @Published var otpVerified = false
    @Published var firebaseIdToken: String?

    /// Cooldown gửi lại OTP (giây)
    @Published var resendCooldown: Int = 0

    private var verificationID: String?
    private var cooldownTimer: Timer?

    private init() {}

    // MARK: - Bước 1: Gửi OTP

    /// Gửi mã OTP đến số điện thoại (đã chuẩn hoá E.164, VD: +84901234567)
    @MainActor
    func sendOTP(to phone: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let provider = PhoneAuthProvider.provider(auth: Auth.auth())
            let verificationID = try await provider
                .verifyPhoneNumber(phone, uiDelegate: nil)
            self.verificationID = verificationID
            UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
            otpSent = true
            startCooldown()
        } catch {
            print("🔴 Firebase Phone Auth Error: \(error)")
            print("🔴 NSError domain: \((error as NSError).domain), code: \((error as NSError).code)")
            print("🔴 UserInfo: \((error as NSError).userInfo)")
            errorMessage = mapFirebaseError(error)
        }
    }

    // MARK: - Bước 2: Xác nhận OTP → lấy idToken

    /// Xác nhận mã OTP 6 số, nếu thành công sẽ set `firebaseIdToken`
    @MainActor
    func verifyOTP(_ code: String) async {
        guard let verificationID = verificationID
                ?? UserDefaults.standard.string(forKey: "authVerificationID") else {
            errorMessage = "Phiên xác thực hết hạn, vui lòng gửi lại OTP"
            return
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let provider = PhoneAuthProvider.provider(auth: Auth.auth())
            let credential = provider
                .credential(withVerificationID: verificationID, verificationCode: code)
            let authResult = try await Auth.auth().signIn(with: credential)
            let idToken = try await authResult.user.getIDToken()
            print("🔑 Firebase ID Token: \(idToken)")
            self.firebaseIdToken = idToken
            otpVerified = true
        } catch {
            errorMessage = mapFirebaseError(error)
        }
    }

    // MARK: - Gửi lại OTP

    @MainActor
    func resendOTP(to phone: String) async {
        guard resendCooldown == 0 else { return }
        await sendOTP(to: phone)
    }

    // MARK: - Reset

    func reset() {
        verificationID = nil
        firebaseIdToken = nil
        otpSent = false
        otpVerified = false
        errorMessage = nil
        isLoading = false
        resendCooldown = 0
        cooldownTimer?.invalidate()
        cooldownTimer = nil
    }

    // MARK: - Cooldown

    private func startCooldown() {
        resendCooldown = 60
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                guard let self = self else { timer.invalidate(); return }
                if self.resendCooldown > 0 {
                    self.resendCooldown -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }

    // MARK: - Error mapping

    private func mapFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError

        // Firebase backend error 503: parse inner error code for more specific messages
        if nsError.code == 17999,
           let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           let responseDict = underlying.userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"] as? [String: Any],
           let httpCode = responseDict["code"] as? Int, httpCode == 503 {
            let innerMessage = (responseDict["message"] as? String) ?? ""
            print("🔴 Firebase 503 inner message: \(innerMessage)")
            // Error code 39 = Backend không thể xử lý yêu cầu (APNs/reCAPTCHA issue, KHÔNG phải quota)
            if innerMessage.contains("39") {
                return "Lỗi xác thực thiết bị (Error 39). Vui lòng kiểm tra:\n• Chạy trên thiết bị thật (không phải Simulator)\n• APNs đã được cấu hình đúng\n• Thử lại sau vài phút"
            }
            return "Dịch vụ SMS tạm thời không khả dụng (503), vui lòng thử lại sau"
        }
        switch AuthErrorCode(rawValue: nsError.code) {
        case .invalidVerificationCode:
            return "Mã OTP không đúng"
        case .sessionExpired:
            return "Phiên xác thực hết hạn, vui lòng gửi lại OTP"
        case .tooManyRequests:
            return "Bạn đã gửi OTP quá nhiều lần, vui lòng thử lại sau"
        case .invalidPhoneNumber:
            return "Số điện thoại không hợp lệ"
        case .missingPhoneNumber:
            return "Vui lòng nhập số điện thoại"
        case .quotaExceeded:
            return "Đã vượt quá giới hạn gửi OTP, vui lòng thử lại sau"
        case .webContextCancelled:
            return "Xác minh bị huỷ, vui lòng thử lại"
        default:
            return "Lỗi xác thực: \(error.localizedDescription)"
        }
    }
}
