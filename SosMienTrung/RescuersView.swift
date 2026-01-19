import SwiftUI
import MultipeerConnectivity

struct RescuersView: View {
    @ObservedObject var nearbyManager: NearbyInteractionManager
    @ObservedObject var multipeerSession: MultipeerSession
    @ObservedObject var appearanceManager = AppearanceManager.shared
    @StateObject private var headingManager = HeadingManager()
    @Binding var selectedPeer: MCPeerID?
    
    @State private var isRescueModeActive = false
    @AppStorage("rescueModeEnabled") private var savedRescueMode = false

    var body: some View {
        ZStack {
            TelegramBackground()
            
            VStack(alignment: .leading, spacing: 10) {
                header
                rescueToggle
                
                if isRescueModeActive {
                    peerList

                    if let peer = selectedPeer ?? multipeerSession.connectedPeers.first {
                        TrackingView(
                            peer: peer,
                            nearbyManager: nearbyManager,
                            findingMode: .visitor  // visitor mode: text + sphere
                        )
                    } else {
                        Text("Đang tìm kiếm người cần cứu hộ...")
                            .foregroundStyle(appearanceManager.secondaryTextColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    }
                } else {
                    inactiveView
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            isRescueModeActive = savedRescueMode
            if isRescueModeActive {
                startRescueMode()
            }
        }
        .onDisappear {
            if !isRescueModeActive {
                stopRescueMode()
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text("Cứu hộ")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(appearanceManager.textColor)
            Spacer()
            if isRescueModeActive && selectedPeer == nil {
                Text(nearbyManager.statusMessage)
                    .font(.caption)
                    .foregroundStyle(appearanceManager.tertiaryTextColor)
                    .lineLimit(1)
            }
        }
    }
    
    private var rescueToggle: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: isRescueModeActive ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .font(.title2)
                            .foregroundColor(isRescueModeActive ? .green : .gray)
                        
                        Text("Chế độ cứu hộ")
                            .font(.headline)
                            .foregroundStyle(appearanceManager.textColor)
                    }
                    
                    Text(isRescueModeActive ? "Đang tìm kiếm người cần cứu" : "Bật để bắt đầu tìm kiếm")
                        .font(.caption)
                        .foregroundStyle(appearanceManager.secondaryTextColor)
                }
                
                Spacer()
                
                Toggle("", isOn: $isRescueModeActive)
                    .labelsHidden()
                    .tint(.green)
                    .onChange(of: isRescueModeActive) { _, newValue in
                        savedRescueMode = newValue
                        if newValue {
                            startRescueMode()
                        } else {
                            stopRescueMode()
                        }
                    }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isRescueModeActive ? Color.green.opacity(0.15) : appearanceManager.textColor.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isRescueModeActive ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            
            if isRescueModeActive {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(0.5), lineWidth: 4)
                                .scaleEffect(1.5)
                        )
                    
                    Text("Đang hoạt động • \(multipeerSession.connectedPeers.count) người kết nối")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var inactiveView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.wave")
                .font(.system(size: 60))
                .foregroundColor(appearanceManager.secondaryTextColor.opacity(0.5))
            
            Text("Chế độ cứu hộ đang tắt")
                .font(.headline)
                .foregroundStyle(appearanceManager.textColor)
            
            Text("Bật công tắc ở trên để bắt đầu tìm kiếm\nvà hỗ trợ những người cần cứu hộ gần đây.")
                .font(.subheadline)
                .foregroundStyle(appearanceManager.secondaryTextColor)
                .multilineTextAlignment(.center)
            
            Button {
                withAnimation {
                    isRescueModeActive = true
                    savedRescueMode = true
                    startRescueMode()
                }
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Bật chế độ cứu hộ")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .cornerRadius(12)
            }
            .padding(.top, 10)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
    
    private var peerList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Người cần cứu hộ")
                .font(.headline)
                .foregroundStyle(appearanceManager.secondaryTextColor)
            
            if multipeerSession.connectedPeers.isEmpty {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                    Text("Đang quét tín hiệu...")
                        .foregroundStyle(.yellow)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(appearanceManager.textColor.opacity(0.08))
                .cornerRadius(12)
            } else {
                ForEach(multipeerSession.connectedPeers, id: \.self) { peer in
                    Button {
                        selectedPeer = peer
                        nearbyManager.setActivePeer(peer)
                    } label: {
                        HStack {
                            Circle()
                                .fill(selectedPeer == peer ? Color.green : Color.orange)
                                .frame(width: 14, height: 14)
                            Text(peer.displayName)
                                .foregroundStyle(appearanceManager.textColor)
                                .fontWeight(.semibold)
                            Spacer()
                            if selectedPeer == peer {
                                Text("Đang theo dõi")
                                    .foregroundStyle(.green)
                                    .font(.caption.bold())
                            } else {
                                Text("Cần hỗ trợ")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(appearanceManager.textColor.opacity(selectedPeer == peer ? 0.16 : 0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
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
