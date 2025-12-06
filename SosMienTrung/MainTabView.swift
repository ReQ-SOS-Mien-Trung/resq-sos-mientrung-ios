import SwiftUI
import MultipeerConnectivity

enum Tab {
    case rescuers
    case chat
    case map
}

struct MainTabView: View {
    @StateObject private var nearbyManager: NearbyInteractionManager
    @StateObject private var multipeerSession: MultipeerSession
    @StateObject private var bridgefyManager = BridgefyNetworkManager.shared
    @State private var selectedTab: Tab = .rescuers
    @State private var selectedPeer: MCPeerID?
    
    init() {
        let manager = NearbyInteractionManager()
        _nearbyManager = StateObject(wrappedValue: manager)
        _multipeerSession = StateObject(wrappedValue: MultipeerSession(nearbyManager: manager))
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content - All views exist, opacity controls visibility
            RescuersView(
                nearbyManager: nearbyManager,
                multipeerSession: multipeerSession,
                selectedPeer: $selectedPeer
            )
            .opacity(selectedTab == .rescuers ? 1 : 0)
            .zIndex(selectedTab == .rescuers ? 1 : 0)
            
            ChatView(bridgefyManager: bridgefyManager)
                .opacity(selectedTab == .chat ? 1 : 0)
                .zIndex(selectedTab == .chat ? 1 : 0)
            
            SOSMapView(messages: $bridgefyManager.messages)
                .opacity(selectedTab == .map ? 1 : 0)
                .zIndex(selectedTab == .map ? 1 : 0)
            
            // Floating Tab Bar
            FloatingTabBar(selectedTab: $selectedTab, unreadMessages: bridgefyManager.messages.filter { !$0.isFromMe }.count)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .zIndex(2)
        }
        .onAppear {
            bridgefyManager.start()
        }
        .onChange(of: multipeerSession.connectedPeers) { peers in
            if peers.count == 1, selectedPeer == nil {
                selectedPeer = peers.first
                nearbyManager.setActivePeer(peers.first)
            } else if let selected = selectedPeer, !peers.contains(selected) {
                selectedPeer = nil
                nearbyManager.setActivePeer(nil)
            }
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selectedTab: Tab
    let unreadMessages: Int
    
    var body: some View {
        HStack(spacing: 8) {
            TabBarButton(
                icon: "location.fill",
                title: "Rescuers",
                isSelected: selectedTab == .rescuers
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .rescuers
                }
            }
            
            TabBarButton(
                icon: "message.fill",
                title: "Chat",
                isSelected: selectedTab == .chat,
                badge: unreadMessages > 0 ? unreadMessages : nil
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .chat
                }
            }
            
            TabBarButton(
                icon: "map.fill",
                title: "Map",
                isSelected: selectedTab == .map
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .map
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let badge: Int?
    let action: () -> Void
    
    init(icon: String, title: String, isSelected: Bool, badge: Int? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isSelected = isSelected
        self.badge = badge
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .medium))
                    
                    if let badge = badge {
                        Text("\(badge)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Circle().fill(.red))
                            .offset(x: 10, y: -8)
                    }
                }
                
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.blue)
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
}
