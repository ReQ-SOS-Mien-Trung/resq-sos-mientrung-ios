import SwiftUI

enum RescuerEligibilityGateState {
    case checking
    case locked
}

struct RescuerEligibilityGateView: View {
    @Environment(\.openURL) private var openURL

    let state: RescuerEligibilityGateState
    let retryAction: () -> Void

    private let registrationURL = URL(string: "https://resq-sos-mientrung.vercel.app/")!

    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            VStack(spacing: DS.Spacing.lg) {
                Spacer(minLength: 24)

                VStack(spacing: DS.Spacing.md) {
                    gateIcon

                    Text(title)
                        .font(DS.Typography.largeTitle)
                        .foregroundColor(DS.Colors.text)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)

                    if state == .checking {
                        ProgressView()
                            .tint(DS.Colors.warning)
                            .padding(.top, DS.Spacing.xs)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(DS.Spacing.lg)
                .background(DS.Colors.surface)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))

                VStack(spacing: DS.Spacing.sm) {
                    if state == .locked {
                        Button {
                            openURL(registrationURL)
                        } label: {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "safari.fill")
                                Text("ĐĂNG KÝ RESCUER TRÊN WEB")
                                    .font(DS.Typography.headline).tracking(1)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.md)
                            .background(DS.Colors.warning)
                            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
                            .shadow(color: .black.opacity(0.2), radius: 0, x: 3, y: 3)
                        }
                    }

                    Button {
                        retryAction()
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "arrow.clockwise")
                            Text("KIỂM TRA LẠI")
                                .font(DS.Typography.subheadline).tracking(1)
                        }
                        .foregroundColor(DS.Colors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.surface)
                        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
                    }

                    Button {
                        AuthService.shared.logout()
                    } label: {
                        Text("Đăng xuất")
                            .font(DS.Typography.subheadline)
                            .foregroundColor(DS.Colors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                    }
                }

                Spacer()
            }
            .padding(DS.Spacing.lg)
        }
    }

    private var gateIcon: some View {
        Group {
            switch state {
            case .checking:
                Image(systemName: "shield.lefthalf.filled")
            case .locked:
                Image(systemName: "lock.shield.fill")
            }
        }
        .font(.system(size: 46, weight: .bold))
        .foregroundColor(state == .locked ? DS.Colors.warning : DS.Colors.accent)
    }

    private var title: String {
        switch state {
        case .checking:
            return "Dang xac minh rescuer"
        case .locked:
            return "Tai khoan chua duoc mo khoa"
        }
    }

    private var message: String {
        switch state {
        case .checking:
            return "App dang goi /identity/user/me de kiem tra quyen isEligibleRescuer truoc khi mo giao dien noi bo."
        case .locked:
            return "Tai khoan Google cua ban da dang nhap thanh cong nhung chua du dieu kien rescuer. Ban can dang ky tren web va cho backend phe duyet."
        }
    }
}

