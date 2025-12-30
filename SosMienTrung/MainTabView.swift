import SwiftUI
import MultipeerConnectivity

extension View {
    @ViewBuilder
    func apply<V: View>(@ViewBuilder _ transform: (Self) -> V) -> some View {
        transform(self)
    }
}

struct MainTabView: View {
    @ObservedObject var nearbyManager: NearbyInteractionManager
    @ObservedObject var multipeerSession: MultipeerSession
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @Binding var selectedPeer: MCPeerID?
    @State private var selectedTab: Int = 0
    
    var unreadMessagesCount: Int {
        bridgefyManager.messages.filter { !$0.isFromMe && $0.recipientId == nil }.count
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RescuersView(
                nearbyManager: nearbyManager,
                multipeerSession: multipeerSession,
                selectedPeer: $selectedPeer
            )
            .tabItem {
                Label("Rescuers", systemImage: "location.fill")
            }
            .tag(0)
            
            UsersListView(bridgefyManager: bridgefyManager)
                .tabItem {
                    Label("Users", systemImage: "person.3.fill")
                }
                .apply { view in
                    if bridgefyManager.connectedUsersList.count > 0 {
                        view.badge(bridgefyManager.connectedUsersList.count)
                    } else {
                        view
                    }
                }
                .tag(1)
            
            ChatView(bridgefyManager: bridgefyManager)
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .apply { view in
                    if unreadMessagesCount > 0 {
                        view.badge(unreadMessagesCount)
                    } else {
                        view
                    }
                }
                .tag(2)
            
            SOSMapView(messages: $bridgefyManager.messages)
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(3)
        }
        .onChange(of: multipeerSession.connectedPeers) { oldValue, newValue in
            if newValue.count == 1, selectedPeer == nil {
                selectedPeer = newValue.first
                nearbyManager.setActivePeer(newValue.first)
            } else {
                // KHÔNG xóa active peer khi Multipeer rớt; NI vẫn tiếp tục sau khi đã trao đổi token.
            }
        }
    }
}

#Preview {
    ContentView()
}
