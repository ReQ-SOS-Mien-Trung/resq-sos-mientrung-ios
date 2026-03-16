import SwiftUI
import MultipeerConnectivity

/// Màn hình chờ ghép đôi UWB theo cơ chế đối xứng.
struct VictimStandbyView: View {
    @ObservedObject var nearbyManager: NearbyInteractionManager
    @ObservedObject var multipeerSession: MultipeerSession
    @State private var pulse = false
    @State private var hasStartedSession = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    EyebrowLabel(text: "CHỜ CỨU HỘ")
                    Text("Chế Độ Chờ")
                        .font(DS.Typography.largeTitle)
                        .foregroundColor(DS.Colors.text)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)

            EditorialDivider(height: DS.Border.thick)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.xs)

            activeStandbyView

            Spacer()
        }
        .background(DS.Colors.background)
        .onAppear {
            if !hasStartedSession {
                hasStartedSession = true
                startVictimMode()
            }
            pulse = true
        }
        .onDisappear {
            if hasStartedSession {
                hasStartedSession = false
                stopVictimMode()
            }
            pulse = false
        }
    }

    // MARK: - Active: đang chờ cứu

    private var activeStandbyView: some View {
        VStack(spacing: DS.Spacing.lg) {

            // Pulsing SOS icon
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(DS.Colors.danger.opacity(0.3 - Double(i) * 0.08), lineWidth: 2)
                        .frame(width: CGFloat(80 + i * 40), height: CGFloat(80 + i * 40))
                        .scaleEffect(pulse ? 1.2 : 0.9)
                        .animation(
                            .easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.3),
                            value: pulse
                        )
                }
                Image(systemName: "sos.circle.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(DS.Colors.danger)
            }
            .frame(height: 180)
            .padding(.top, DS.Spacing.lg)

            Text("Tín hiệu đang phát")
                .font(DS.Typography.title)
                .foregroundColor(DS.Colors.text)

            Text("Thiết bị đang tham gia tìm kiếm UWB.\nCác thiết bị gần đó có thể ghép đôi và định vị nhau.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.md)

            // Danh sách peer đã kết nối
            if !multipeerSession.connectedPeers.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("THIẾT BỊ ĐÃ KẾT NỐI")
                        .font(DS.Typography.caption)
                        .tracking(2)
                        .foregroundColor(DS.Colors.textSecondary)
                        .padding(.horizontal, DS.Spacing.md)

                    ForEach(multipeerSession.connectedPeers, id: \.self) { peer in
                        HStack {
                            Rectangle()
                                .fill(DS.Colors.success)
                                .frame(width: 10, height: 10)
                            Text(peer.displayName)
                                .font(DS.Typography.headline)
                                .foregroundColor(DS.Colors.text)
                            Spacer()
                            ResQBadge(text: "ĐÃ GHÉP ĐÔI", color: DS.Colors.success)
                        }
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.success.opacity(0.06))
                        .overlay(Rectangle().stroke(DS.Colors.success, lineWidth: DS.Border.thin))
                        .padding(.horizontal, DS.Spacing.md)
                    }
                }
                .padding(.top, DS.Spacing.sm)
            }

            // Lưu ý
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text("Giữ màn hình bật và đứng yên để tín hiệu ổn định")
                    .font(DS.Typography.caption)
            }
            .foregroundColor(DS.Colors.textTertiary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.xs)
        }
    }

    // MARK: - Victim Mode Control

    private func startVictimMode() {
        nearbyManager.configureForPeerFinding()
        multipeerSession.startPeerDiscovery()
    }

    private func stopVictimMode() {
        nearbyManager.scheduleDeactivateNearbyMode()
        multipeerSession.scheduleStopAll()
    }
}
