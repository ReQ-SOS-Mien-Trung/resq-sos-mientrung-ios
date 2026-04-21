import SwiftUI
import MultipeerConnectivity
import Combine

extension View {
    @ViewBuilder
    func apply<V: View>(@ViewBuilder _ transform: (Self) -> V) -> some View {
        transform(self)
    }
}

enum AppSheetDestination: Identifiable, Equatable {
    case notifications
    case assemblyEvents

    var id: String {
        switch self {
        case .notifications:
            return "notifications"
        case .assemblyEvents:
            return "assembly-events"
        }
    }
}

enum AppFullScreenDestination: Identifiable, Equatable {
    case coordinatorChat(conversationId: Int?)
    case assemblyPointMap
    case rescuerDashboard
    case missionDetail(missionId: Int)

    var id: String {
        switch self {
        case .coordinatorChat(let conversationId):
            return "coordinator-chat-\(conversationId.map(String.init) ?? "latest")"
        case .assemblyPointMap:
            return "assembly-point-map"
        case .rescuerDashboard:
            return "rescuer-dashboard"
        case .missionDetail(let missionId):
            return "mission-detail-\(missionId)"
        }
    }
}

@MainActor
final class AppNavigationCoordinator: ObservableObject {
    static let shared = AppNavigationCoordinator()

    @Published var selectedTab: Int = 0
    @Published var activeSheet: AppSheetDestination?
    @Published var activeFullScreen: AppFullScreenDestination?

    private var pendingFullScreenAfterSheetDismiss: AppFullScreenDestination?

    private init() { }

    func resetToHome(clearPresentedDestinations: Bool = true) {
        selectedTab = 0
        pendingFullScreenAfterSheetDismiss = nil

        guard clearPresentedDestinations else { return }

        activeSheet = nil
        activeFullScreen = nil
    }

    func openNotifications() {
        presentSheet(.notifications)
    }

    func dismissSheet() {
        activeSheet = nil
    }

    func dismissFullScreen() {
        activeFullScreen = nil
    }

    func handleSheetDismissed() {
        guard activeSheet == nil, let destination = pendingFullScreenAfterSheetDismiss else {
            return
        }

        pendingFullScreenAfterSheetDismiss = nil

        DispatchQueue.main.async {
            self.activeFullScreen = destination
        }
    }

    func handleNotificationTap(_ notification: RealtimeNotification) {
        switch resolveDestination(for: notification) {
        case .sheet(let destination):
            presentSheet(destination)
        case .fullScreen(let destination):
            presentFullScreen(destination)
        }
    }

    private enum NavigationAction {
        case sheet(AppSheetDestination)
        case fullScreen(AppFullScreenDestination)
    }

    private var currentSession: AuthSession? {
        AuthSessionStore.shared.session
    }

    private var canOpenCoordinatorChat: Bool {
        currentSession?.roleId != 3
    }

    private var canAccessRescuerWorkspace: Bool {
        currentSession?.canAccessRescuerWorkspace ?? false
    }

    private var canViewMissionWorkspace: Bool {
        currentSession?.canViewMissionWorkspace ?? false
    }

    private func resolveDestination(for notification: RealtimeNotification) -> NavigationAction {
        switch notification.normalizedType {
        case "chat_message", "coordinator_join", "coordinator_leave":
            if canOpenCoordinatorChat {
                return .fullScreen(.coordinatorChat(conversationId: notification.conversationId))
            }
            return .sheet(.notifications)

        case "assembly_gathering":
            if canAccessRescuerWorkspace {
                return .sheet(.assemblyEvents)
            }
            return .sheet(.notifications)

        case "assembly_point_assignment":
            return .fullScreen(.assemblyPointMap)

        case
            "team_assigned",
            "team_invitation",
            "supply_request",
            "supply_request_urgent",
            "supply_request_high_escalation",
            "supply_request_urgent_escalation",
            "supply_accepted",
            "supply_preparing",
            "supply_shipped",
            "supply_completed",
            "supply_rejected",
            "supply_request_auto_rejected",
            "fund_allocation":
            if canViewMissionWorkspace, let missionId = notification.missionId {
                return .fullScreen(.missionDetail(missionId: missionId))
            }
            if canAccessRescuerWorkspace {
                return .fullScreen(.rescuerDashboard)
            }
            return .sheet(.notifications)

        case "flood_alert", "general":
            return .sheet(.notifications)

        default:
            return .sheet(.notifications)
        }
    }

    private func presentSheet(_ destination: AppSheetDestination) {
        selectedTab = 0
        activeFullScreen = nil
        activeSheet = destination
    }

    private func presentFullScreen(_ destination: AppFullScreenDestination) {
        selectedTab = 0

        guard activeSheet == nil else {
            pendingFullScreenAfterSheetDismiss = destination
            activeSheet = nil
            return
        }

        activeFullScreen = destination
    }
}

struct MainTabView: View {
    @ObservedObject var nearbyManager: NearbyInteractionManager
    @ObservedObject var multipeerSession: MultipeerSession
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @ObservedObject private var authSession = AuthSessionStore.shared
    @ObservedObject private var navigationCoordinator = AppNavigationCoordinator.shared
    @Binding var selectedPeer: MCPeerID?
    
    var unreadMessagesCount: Int {
        bridgefyManager.messages.filter { !$0.isFromMe && $0.recipientId == nil }.count
    }

    private var canAccessSosHistory: Bool {
        authSession.session?.canCreateSosRequest ?? false
    }

    var body: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
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
        .sheet(item: $navigationCoordinator.activeSheet, onDismiss: {
            navigationCoordinator.handleSheetDismissed()
        }) { destination in
            switch destination {
            case .notifications:
                NotificationCenterView(notificationHub: NotificationHubService.shared)
                    .presentationDetents([.medium, .large])
            case .assemblyEvents:
                RescuerAssemblyEventsView()
                    .presentationDetents([.medium, .large])
            }
        }
        .fullScreenCover(item: $navigationCoordinator.activeFullScreen) { destination in
            switch destination {
            case .coordinatorChat(let conversationId):
                CoordinatorChatMainView(preferredConversationId: conversationId)
            case .assemblyPointMap:
                AssemblyPointMapView()
            case .rescuerDashboard:
                RescuerDashboardView()
            case .missionDetail(let missionId):
                MissionDetailLoaderView(missionId: missionId)
            }
        }
        // setActivePeer được xử lý bởi RescuersView (sau khi token được trao đổi xong)
        // Không gọi ở đây để tránh race condition với token exchange
    }

    private func normalizeSelectedTab() {
        let availableTabs = [0] + (canAccessSosHistory ? [1] : []) + [2, 3, 4]
        if availableTabs.contains(navigationCoordinator.selectedTab) == false {
            navigationCoordinator.selectedTab = availableTabs.first ?? 0
        }
    }
}

private struct MissionDetailLoaderView: View {
    let missionId: Int

    @Environment(\.dismiss) private var dismiss
    @State private var mission: Mission?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let mission {
                    MissionDetailView(mission: mission)
                } else if isLoading {
                    VStack(spacing: DS.Spacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Đang tải chi tiết nhiệm vụ...")
                            .font(DS.Typography.subheadline)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.Colors.background)
                } else {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(DS.Colors.warning)

                        Text("Không mở được nhiệm vụ")
                            .font(DS.Typography.headline)
                            .foregroundColor(DS.Colors.text)

                        Text(errorMessage ?? "Dữ liệu nhiệm vụ không khả dụng.")
                            .font(DS.Typography.subheadline)
                            .foregroundColor(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)

                        Button("Đóng") {
                            dismiss()
                        }
                        .font(DS.Typography.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.background)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: missionId) {
            await loadMission()
        }
    }

    @MainActor
    private func loadMission() async {
        if mission?.id == missionId {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            mission = try await MissionService.shared.getMission(missionId: missionId)
        } catch {
            mission = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    ContentView()
}
