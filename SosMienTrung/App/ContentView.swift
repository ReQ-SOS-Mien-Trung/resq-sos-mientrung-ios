import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var nearbyManager: NearbyInteractionManager
    @StateObject private var multipeerSession: MultipeerSession
    @StateObject private var bridgefyManager = BridgefyNetworkManager.shared
    @StateObject private var notificationHub = NotificationHubService.shared
    @StateObject private var userProfile = UserProfile.shared
    @StateObject private var authSession = AuthSessionStore.shared
    @ObservedObject private var appearance = AppearanceManager.shared
    @State private var selectedPeer: MCPeerID?
    @State private var isSetupComplete = false
    @State private var lastObservedAuthSession: AuthSession? = AuthSessionStore.shared.session
    
    init() {
        let manager = NearbyInteractionManager()
        _nearbyManager = StateObject(wrappedValue: manager)
        _multipeerSession = StateObject(
            wrappedValue: MultipeerSession(
                nearbyManager: manager,
                coordinationPolicy: .coexistWithBridgefy
            )
        )
    }
    
    /// Cho vào app khi có user profile VÀ có session hợp lệ
    private var isFullyAuthenticated: Bool {
        userProfile.isSetupComplete && authSession.isValid
    }

    private var currentDiscoveryRole: MultipeerSession.DiscoveryRole? {
        guard isFullyAuthenticated else { return nil }
        // Default session discovery role. If role is 3, start as rescuer. Otherwise start as victim.
        return authSession.session?.roleId == 3 ? .rescuer : .victim
    }

    private func bootstrapAuthenticatedNetworking() {
        guard isFullyAuthenticated else { return }
        ServerRequestGateway.shared.register(multipeerSession: multipeerSession)
        if let role = currentDiscoveryRole {
            multipeerSession.startBackgroundDiscovery(for: role)
        }
        if !bridgefyManager.isPaused {
            bridgefyManager.start()
        }
        ServerRequestGateway.shared.start()
        Task {
            await notificationHub.applicationDidBecomeActive()
        }
    }

    private func refreshAuthenticatedAccess(force: Bool = false) {
        guard isFullyAuthenticated else {
            teardownAuthenticatedNetworking()
            return
        }

        Task { @MainActor in
            await authSession.refreshCurrentUserIfNeeded(force: force)

            if isFullyAuthenticated {
                bootstrapAuthenticatedNetworking()
            } else {
                teardownAuthenticatedNetworking()
            }
        }
    }

    private func teardownAuthenticatedNetworking() {
        multipeerSession.stopAll()
        notificationHub.disconnect()
    }

    @ViewBuilder
    private var rootView: some View {
        if isFullyAuthenticated {
            MainTabView(
                nearbyManager: nearbyManager,
                multipeerSession: multipeerSession,
                bridgefyManager: bridgefyManager,
                selectedPeer: $selectedPeer
            )
        } else {
            SetupProfileView(isSetupComplete: $isSetupComplete)
        }
    }

    @ViewBuilder
    private var configuredView: some View {
        rootView
            .onAppear {
                isSetupComplete = isFullyAuthenticated
                if isFullyAuthenticated {
                    refreshAuthenticatedAccess(force: true)
                }
            }
            .onChange(of: userProfile.currentUser) { newUser in
                if newUser == nil {
                    isSetupComplete = false
                    teardownAuthenticatedNetworking()
                } else if isFullyAuthenticated {
                    isSetupComplete = true
                    refreshAuthenticatedAccess()
                }
            }
            .onChange(of: authSession.session) { newSession in
                let previousSession = lastObservedAuthSession
                lastObservedAuthSession = newSession

                if newSession != nil {
                    Task { @MainActor in
                        await notificationHub.handleAuthSessionTransition(from: previousSession, to: newSession)
                    }
                }

                if newSession == nil {
                    isSetupComplete = false
                    teardownAuthenticatedNetworking()
                } else if isFullyAuthenticated {
                    isSetupComplete = true
                    refreshAuthenticatedAccess()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                guard newPhase == .active else { return }
                guard isFullyAuthenticated else { return }
                refreshAuthenticatedAccess(force: true)
            }
    }

    var body: some View {
        configuredView
            .preferredColorScheme(appearance.computedColorScheme)
            .onChange(of: isSetupComplete) { newValue in
                if newValue {
                    refreshAuthenticatedAccess()
                } else {
                    teardownAuthenticatedNetworking()
                }
            }
            // NOTE: setActivePeer() không được gọi khi peer kết nối — thời điểm đó token chưa
            // được trao đổi xong. RescuersView sẽ tự động chọn peer sau khi
            // receivedPeerDiscoveryToken() được gọi (xảy ra sau .connected event)
    }
}
