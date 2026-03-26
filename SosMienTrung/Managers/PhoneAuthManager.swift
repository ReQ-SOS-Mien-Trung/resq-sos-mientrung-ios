import Foundation
import Combine
import UIKit
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
        logPhoneAuthPreflight()

        if UIApplication.shared.isRegisteredForRemoteNotifications == false {
            print("⚠️ APNs chưa sẵn sàng trước khi gửi OTP, yêu cầu đăng ký remote notifications lại")
            UIApplication.shared.registerForRemoteNotifications()
        }

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

    private func firebaseHTTPErrorPayload(from nsError: NSError) -> [String: Any]? {
        if let direct = nsError.userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"] as? [String: Any] {
            return direct
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           let nested = underlying.userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"] as? [String: Any] {
            return nested
        }

        return nil
    }

    private func mapFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        let localizedDescription = nsError.localizedDescription.lowercased()

        if localizedDescription.contains("no apns token specified") {
            return "Thiết bị chưa nhận APNs token. Hãy chờ vài giây sau khi mở app rồi gửi lại OTP trên thiết bị thật."
        }

        if let payload = firebaseHTTPErrorPayload(from: nsError),
           let httpCode = payload["code"] as? Int {
            let message = (payload["message"] as? String) ?? ""
            let details = payload["details"] as? [[String: Any]] ?? []
            let reason = details
                .first(where: { ($0["@type"] as? String)?.contains("ErrorInfo") == true })?["reason"] as? String

            if httpCode == 403, reason == "API_KEY_HTTP_REFERRER_BLOCKED" {
                return "Firebase API key hiện đang bị chặn theo HTTP referrer nên iOS không gọi được Phone Auth. Vào Google Cloud Console > APIs & Services > Credentials > chọn API key của Firebase và bỏ Application restriction kiểu HTTP referrers (hoặc tạo key mới cho iOS/Firebase), sau đó tải lại GoogleService-Info.plist và thay vào app."
            }

            if httpCode == 403, message.localizedCaseInsensitiveContains("PERMISSION_DENIED") {
                return "Firebase từ chối quyền truy cập (403). Hãy kiểm tra API key trong GoogleService-Info.plist và cấu hình restriction của key trên Google Cloud/Firebase Console."
            }
        }

        // Firebase backend error 503: parse inner error code for more specific messages
        if nsError.code == 17999,
           let responseDict = firebaseHTTPErrorPayload(from: nsError),
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

    @MainActor
    private func logPhoneAuthPreflight() {
        let isRegistered = UIApplication.shared.isRegisteredForRemoteNotifications
        let backgroundRefreshStatus: String

        switch UIApplication.shared.backgroundRefreshStatus {
        case .available:
            backgroundRefreshStatus = "available"
        case .denied:
            backgroundRefreshStatus = "denied"
        case .restricted:
            backgroundRefreshStatus = "restricted"
        @unknown default:
            backgroundRefreshStatus = "unknown"
        }

        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif

        print(
            """
            📲 Phone Auth preflight:
            - registeredForRemoteNotifications: \(isRegistered)
            - backgroundRefreshStatus: \(backgroundRefreshStatus)
            - simulator: \(isSimulator)
            """
        )
    }
}
