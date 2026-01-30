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
        ZStack {
            // Background pattern (fallback cho toàn bộ TabView)
            TelegramBackground()

            TabView(selection: $selectedTab) {
                HomeView(
                    bridgefyManager: bridgefyManager,
                    nearbyManager: nearbyManager,
                    multipeerSession: multipeerSession,
                    selectedPeer: $selectedPeer
                )
                    .tabItem {
                        Label("Trang chủ", systemImage: "house.fill")
                    }
                    .tag(0)
                
                SOSHistoryView(bridgefyManager: bridgefyManager)
                    .tabItem {
                        Label("Quản lý SOS", systemImage: "list.clipboard.fill")
                    }
                    .tag(1)

                ChatRoomsView(bridgefyManager: bridgefyManager)
                    .tabItem {
                        Label("Tin Nhắn", systemImage: "message.fill")
                    }
                    .apply { view in
                        let totalUnread = unreadMessagesCount + bridgefyManager.connectedUsersList.count
                        if totalUnread > 0 {
                            view.badge(totalUnread)
                        } else {
                            view
                        }
                    }
                    .tag(2)

                // MARK: - Map tab tạm ẩn để tối ưu launch time
                // SOSMapView(messages: $bridgefyManager.messages)
                //     .tabItem {
                //         Label("Bản đồ", systemImage: "map.fill")
                //     }
                //     .tag(3)

                ChatBotView()
                    .tabItem {
                        Label("AI Trợ lý", systemImage: "brain.head.profile")
                    }
                    .tag(3)
                
                SettingsView()
                    .tabItem {
                        Label("Cài đặt", systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .onAppear {
                // Làm trong suốt TabBar để nhìn thấy nền phía sau
                let tabBarAppearance = UITabBarAppearance()
                tabBarAppearance.configureWithTransparentBackground()
                tabBarAppearance.backgroundColor = .clear
                tabBarAppearance.backgroundEffect = nil
                UITabBar.appearance().standardAppearance = tabBarAppearance
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
                
                UITabBar.appearance().backgroundImage = UIImage()
                UITabBar.appearance().shadowImage = UIImage()
                UITabBar.appearance().isTranslucent = true
                UITabBar.appearance().barTintColor = .clear
                
                UIView.appearance(whenContainedInInstancesOf: [UITabBar.self]).backgroundColor = .clear
                UIView.appearance(whenContainedInInstancesOf: [UITabBarController.self]).backgroundColor = .clear
            }
            .background(Color.clear)
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
