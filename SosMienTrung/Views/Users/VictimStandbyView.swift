import SwiftUI
import MultipeerConnectivity

/// View cho phía VICTIM — bật chế độ chờ cứu hộ
/// Victim cần advertise Multipeer để rescuer tìm thấy qua UWB
struct VictimStandbyView: View {
    @ObservedObject var nearbyManager: NearbyInteractionManager
    @ObservedObject var multipeerSession: MultipeerSession

    @AppStorage("victimModeEnabled") private var savedVictimMode = false
    @State private var isVictimModeActive = false
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                EyebrowLabel(text: "CHỜ CỨU HỘ")
                Text("Chế Độ Chờ")
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text)
                EditorialDivider(height: DS.Border.thick)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)

            // Toggle
            victimToggle

            if isVictimModeActive {
                activeStandbyView
            } else {
                inactiveStandbyView
            }

            Spacer()
        }
        .background(DS.Colors.background)
        .onAppear {
            isVictimModeActive = savedVictimMode
            if isVictimModeActive { startVictimMode() }
        }
        .onDisappear {
            stopVictimMode()
        }
    }

    // MARK: - Toggle

    private var victimToggle: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: isVictimModeActive
                              ? "antenna.radiowaves.left.and.right"
                              : "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isVictimModeActive ? DS.Colors.danger : DS.Colors.textTertiary)
                        Text("Chế độ chờ cứu")
                            .font(DS.Typography.headline)
                            .foregroundColor(DS.Colors.text)
                    }
                    Text(isVictimModeActive
                         ? "Đang phát tín hiệu — chờ đội cứu hộ"
                         : "Bật để đội cứu hộ có thể định vị bạn")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $isVictimModeActive)
                    .labelsHidden()
                    .tint(DS.Colors.danger)
                    .onChange(of: isVictimModeActive) { newValue in
                        savedVictimMode = newValue
                        if newValue { startVictimMode() } else { stopVictimMode() }
                    }
            }
            .padding(DS.Spacing.md)
            .background(isVictimModeActive ? DS.Colors.danger.opacity(0.08) : DS.Colors.surface)
            .overlay(
                Rectangle().stroke(
                    isVictimModeActive ? DS.Colors.danger : DS.Colors.border,
                    lineWidth: DS.Border.medium
                )
            )

            if isVictimModeActive {
                HStack(spacing: DS.Spacing.sm) {
                    Circle()
                        .fill(DS.Colors.danger)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulse ? 1.4 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                        .onAppear { pulse = true }
                        .onDisappear { pulse = false }
                    Text("Đang phát tín hiệu • Kết nối: \(multipeerSession.connectedPeers.count) cứu hộ viên")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.danger)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.xs)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.sm)
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

            Text("Thiết bị đang broadcast tín hiệu UWB.\nĐội cứu hộ có thể định vị bạn trong phạm vi ~9m.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.md)

            // Danh sách rescuer đã kết nối
            if !multipeerSession.connectedPeers.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("CỨU HỘ VIÊN ĐÃ KẾT NỐI")
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
                            ResQBadge(text: "ĐANG TÌM", color: DS.Colors.success)
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

    // MARK: - Inactive

    private var inactiveStandbyView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(DS.Colors.textSecondary.opacity(0.5))
            Text("Chưa phát tín hiệu")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
            Text("Bật công tắc ở trên để bắt đầu phát tín hiệu UWB.\nĐội cứu hộ trong bán kính ~9m sẽ có thể định vị bạn.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                withAnimation {
                    isVictimModeActive = true
                    savedVictimMode = true
                    startVictimMode()
                }
            } label: {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("PHÁT TÍN HIỆU CHỜ CỨU").font(DS.Typography.headline).tracking(1)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, DS.Spacing.md)
                .background(DS.Colors.danger)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
                .shadow(color: .black.opacity(0.2), radius: 0, x: 3, y: 3)
            }
            .padding(.top, DS.Spacing.sm)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, DS.Spacing.md)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Victim Mode Control

    private func startVictimMode() {
        // Set role về victim
        nearbyManager.configureAsVictim()
        // Victim CHỈ advertise — chờ rescuer browser tìm thấy
        // KHÔNG browse — tránh dual-invitation conflict
        multipeerSession.startAsVictim()
    }

    private func stopVictimMode() {
        nearbyManager.userRole = .victim
        multipeerSession.stopAll()
    }
}
