import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    @StateObject private var nearbyManager: NearbyInteractionManager
    @StateObject private var multipeerSession: MultipeerSession
    @StateObject private var bridgefyManager = BridgefyNetworkManager.shared
    @StateObject private var userProfile = UserProfile.shared
    @State private var selectedPeer: MCPeerID?
    @State private var isSetupComplete = false
    
    init() {
        let manager = NearbyInteractionManager()
        _nearbyManager = StateObject(wrappedValue: manager)
        _multipeerSession = StateObject(wrappedValue: MultipeerSession(nearbyManager: manager))
    }
    
    var body: some View {
        Group {
            if !userProfile.isSetupComplete {
                SetupProfileView(isSetupComplete: $isSetupComplete)
            } else {
                MainTabView(
                    nearbyManager: nearbyManager,
                    multipeerSession: multipeerSession,
                    bridgefyManager: bridgefyManager,
                    selectedPeer: $selectedPeer
                )
            }
        }
        .onAppear {
            // Check if setup is complete
            isSetupComplete = userProfile.isSetupComplete
            
            // Khởi động Bridgefy khi app mở
            if userProfile.isSetupComplete {
                bridgefyManager.start()
            }
        }
        .onChange(of: userProfile.currentUser) { _, newUser in
            // When user is cleared (after handover), show setup screen
            if newUser == nil {
                isSetupComplete = false
            }
        }
        .onChange(of: isSetupComplete) { _, newValue in
            if newValue {
                // Start Bridgefy after setup complete
                bridgefyManager.start()
            }
        }
        .onChange(of: multipeerSession.connectedPeers) { _, peers in
            if peers.count == 1, selectedPeer == nil {
                selectedPeer = peers.first
                nearbyManager.setActivePeer(peers.first)
            } 
            // Commented out to prevent UWB disconnection when Multipeer drops.
            // UWB operates independently once tokens are exchanged and often has better range/stability.
            /*
            else if let selected = selectedPeer, !peers.contains(selected) {
                selectedPeer = nil
                nearbyManager.setActivePeer(nil)
            }
            */
        }
    }
}

#Preview {
    ContentView()
}
