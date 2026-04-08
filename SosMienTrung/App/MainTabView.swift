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
    @ObservedObject private var authSession = AuthSessionStore.shared
    @Binding var selectedPeer: MCPeerID?
    @State private var selectedTab: Int = 0
    
    var unreadMessagesCount: Int {
        bridgefyManager.messages.filter { !$0.isFromMe && $0.recipientId == nil }.count
    }

    private var canAccessSosHistory: Bool {
        authSession.session?.canCreateSosRequest ?? false
    }

    var body: some View {
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

            if canAccessSosHistory {
                SOSHistoryView(bridgefyManager: bridgefyManager)
                    .tabItem {
                        Label("Quản lý SOS", systemImage: "list.clipboard.fill")
                    }
                    .tag(1)
            }

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
        .tint(DS.Colors.accent)
        .onAppear {
            // Sharp opaque tab bar with top border
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor.systemBackground
            tabBarAppearance.shadowColor = UIColor.label

            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            normalizeSelectedTab()
        }
        .onChange(of: authSession.session) { _ in
            normalizeSelectedTab()
        }
        // setActivePeer được xử lý bởi RescuersView (sau khi token được trao đổi xong)
        // Không gọi ở đây để tránh race condition với token exchange
    }

    private func normalizeSelectedTab() {
        let availableTabs = [0] + (canAccessSosHistory ? [1] : []) + [2, 3, 4]
        if availableTabs.contains(selectedTab) == false {
            selectedTab = availableTabs.first ?? 0
        }
    }
}

#Preview {
    ContentView()
}
