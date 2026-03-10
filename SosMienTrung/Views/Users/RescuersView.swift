import SwiftUI
import MultipeerConnectivity

struct RescuersView: View {
    @ObservedObject var nearbyManager: NearbyInteractionManager
    @ObservedObject var multipeerSession: MultipeerSession
    
    @StateObject private var headingManager = HeadingManager()
    @Binding var selectedPeer: MCPeerID?
    
    @State private var isRescueModeActive = false
    @AppStorage("rescueModeEnabled") private var savedRescueMode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Editorial header
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                EyebrowLabel(text: "TÌM KIẾM")
                Text("Cứu Hộ")
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text)
                if isRescueModeActive && selectedPeer == nil {
                    Text(nearbyManager.statusMessage)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textTertiary)
                }
                EditorialDivider(height: DS.Border.thick)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)

            rescueToggle

            if isRescueModeActive {
                peerList
                if let peer = selectedPeer ?? multipeerSession.connectedPeers.first {
                    TrackingView(peer: peer, nearbyManager: nearbyManager, findingMode: .visitor)
                } else {
                    Text("Đang tìm kiếm người cần cứu hộ...")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            } else {
                inactiveView
            }
            Spacer()
        }
        .background(DS.Colors.background)
        .onAppear {
            isRescueModeActive = savedRescueMode
            if isRescueModeActive { startRescueMode() }
        }
        .onDisappear {
            if !isRescueModeActive { stopRescueMode() }
        }
    }

    private var rescueToggle: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: isRescueModeActive ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isRescueModeActive ? DS.Colors.success : DS.Colors.textTertiary)
                        Text("Chế độ cứu hộ")
                            .font(DS.Typography.headline)
                            .foregroundColor(DS.Colors.text)
                    }
                    Text(isRescueModeActive ? "Đang tìm kiếm người cần cứu" : "Bật để bắt đầu tìm kiếm")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $isRescueModeActive)
                    .labelsHidden()
                    .tint(DS.Colors.success)
                    .onChange(of: isRescueModeActive) { newValue in
                        savedRescueMode = newValue
                        if newValue { startRescueMode() } else { stopRescueMode() }
                    }
            }
            .padding(DS.Spacing.md)
            .background(isRescueModeActive ? DS.Colors.success.opacity(0.08) : DS.Colors.surface)
            .overlay(Rectangle().stroke(isRescueModeActive ? DS.Colors.success : DS.Colors.border, lineWidth: DS.Border.medium))

            if isRescueModeActive {
                HStack(spacing: DS.Spacing.sm) {
                    Rectangle().fill(DS.Colors.success).frame(width: 8, height: 8)
                    Text("Đang hoạt động • \(multipeerSession.connectedPeers.count) người kết nối")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.success)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.xs)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.sm)
    }

    private var inactiveView: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "figure.wave")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(DS.Colors.textSecondary.opacity(0.5))
            Text("Chế độ cứu hộ đang tắt")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
            Text("Bật công tắc ở trên để bắt đầu tìm kiếm\nvà hỗ trợ những người cần cứu hộ gần đây.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                withAnimation { isRescueModeActive = true; savedRescueMode = true; startRescueMode() }
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("BẬT CHẾ ĐỘ CỨU HỘ").font(DS.Typography.headline).tracking(1)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, DS.Spacing.md)
                .background(DS.Colors.success)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
                .shadow(color: .black.opacity(0.2), radius: 0, x: 3, y: 3)
            }
            .padding(.top, DS.Spacing.sm)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, DS.Spacing.md)
        .frame(maxWidth: .infinity)
    }

    private var peerList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("NGƯỜI CẦN CỨU HỘ").font(DS.Typography.caption).tracking(2)
                .foregroundColor(DS.Colors.textSecondary)
                .padding(.horizontal, DS.Spacing.md)

            if multipeerSession.connectedPeers.isEmpty {
                HStack {
                    ProgressView().tint(DS.Colors.warning)
                    Text("Đang quét tín hiệu...")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.warning)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.surface)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                .padding(.horizontal, DS.Spacing.md)
            } else {
                ForEach(multipeerSession.connectedPeers, id: \.self) { peer in
                    Button {
                        selectedPeer = peer
                        nearbyManager.setActivePeer(peer)
                    } label: {
                        HStack {
                            Rectangle()
                                .fill(selectedPeer == peer ? DS.Colors.success : DS.Colors.warning)
                                .frame(width: 12, height: 12)
                            Text(peer.displayName)
                                .font(DS.Typography.headline)
                                .foregroundColor(DS.Colors.text)
                            Spacer()
                            if selectedPeer == peer {
                                ResQBadge(text: "TRACKING", color: DS.Colors.success)
                            } else {
                                ResQBadge(text: "CẦN HỖ TRỢ", color: DS.Colors.warning)
                            }
                        }
                        .padding(DS.Spacing.md)
                        .background(selectedPeer == peer ? DS.Colors.success.opacity(0.06) : DS.Colors.surface)
                        .overlay(Rectangle().stroke(selectedPeer == peer ? DS.Colors.success : DS.Colors.border, lineWidth: DS.Border.thin))
                    }
                    .padding(.horizontal, DS.Spacing.md)
                }
            }
        }
        .padding(.top, DS.Spacing.sm)
    }
    
    // MARK: - Rescue Mode Control
    
    private func startRescueMode() {
        // Start scanning for nearby peers
        multipeerSession.startBrowsing()
        multipeerSession.startAdvertising()
    }
    
    private func stopRescueMode() {
        // Stop scanning
        selectedPeer = nil
        multipeerSession.stopBrowsing()
        multipeerSession.stopAdvertising()
    }
}
