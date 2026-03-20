import SwiftUI
import MultipeerConnectivity
import Combine

struct RescuersView: View {
    @ObservedObject var nearbyManager: NearbyInteractionManager
    @ObservedObject var multipeerSession: MultipeerSession
    
    @StateObject private var headingManager = HeadingManager()
    @Binding var selectedPeer: MCPeerID?
    @State private var hasStartedSession = false
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Editorial header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    EyebrowLabel(text: "TÌM KIẾM")
                    Text("Cứu Hộ")
                        .font(DS.Typography.largeTitle)
                        .foregroundColor(DS.Colors.text)
                    if selectedPeer == nil {
                        Text(nearbyManager.statusMessage)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textTertiary)
                    }
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

            peerList
            if let peer = selectedPeer ?? multipeerSession.connectedPeers.first {
                TrackingView(peer: peer, nearbyManager: nearbyManager, findingMode: .rescuer)
            } else {
                waitingForVictimView
            }
            Spacer()
        }
        .background(DS.Colors.background)
        .onAppear {
            if !hasStartedSession {
                hasStartedSession = true
                startRescueMode()
            }
            syncSelectedPeerWithConnections()
        }
        .onReceive(multipeerSession.$connectedPeers) { _ in
            syncSelectedPeerWithConnections()
        }
        .onDisappear {
            guard hasStartedSession else { return }
            hasStartedSession = false
            stopRescueMode()
        }
    }

    // MARK: - Waiting for Victim View
    private var waitingForVictimView: some View {
        VStack(spacing: DS.Spacing.md) {
            ProgressView()
                .tint(DS.Colors.success)
                .scaleEffect(1.4)
                .padding(.bottom, DS.Spacing.xs)
            Text("Đang quét tín hiệu UWB...")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
            Text("Yêu cầu thiết bị còn lại mở tính năng\nTìm kiếm UWB để ghép đôi")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 48)
        .padding(.horizontal, DS.Spacing.md)
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
        nearbyManager.configureForPeerFinding()
        multipeerSession.activateNearbyInteractionDiscovery(for: .rescuer)
    }

    private func stopRescueMode() {
        selectedPeer = nil
        nearbyManager.scheduleDeactivateNearbyMode()
        multipeerSession.scheduleDeactivateNearbyInteraction()
    }

    private func syncSelectedPeerWithConnections() {
        let peers = multipeerSession.connectedPeers

        if let current = selectedPeer, !peers.contains(current) {
            selectedPeer = nil
            nearbyManager.setActivePeer(nil)
        }

        if selectedPeer == nil, let firstPeer = peers.first {
            selectedPeer = firstPeer
            nearbyManager.setActivePeer(firstPeer)
        }
    }
}
