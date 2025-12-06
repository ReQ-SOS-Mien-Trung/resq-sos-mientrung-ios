import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    @StateObject private var nearbyManager: NearbyInteractionManager
    @StateObject private var multipeerSession: MultipeerSession
    @StateObject private var bridgefyManager = BridgefyNetworkManager.shared
    @State private var selectedPeer: MCPeerID?
    
    init() {
        let manager = NearbyInteractionManager()
        _nearbyManager = StateObject(wrappedValue: manager)
        _multipeerSession = StateObject(wrappedValue: MultipeerSession(nearbyManager: manager))
    }
    
    var body: some View {
        TabView {
            RescuersView(
                nearbyManager: nearbyManager,
                multipeerSession: multipeerSession,
                selectedPeer: $selectedPeer
            )
            .tabItem {
                Label("Rescuers", systemImage: "location.fill")
            }
            
            ChatView(bridgefyManager: bridgefyManager)
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .badge(unreadCount)
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
    
    private var unreadCount: Int {
        let count = bridgefyManager.messages.filter { !$0.isFromMe }.count
        return count > 0 ? count : 0
    }
}

#Preview {
    ContentView()
}
