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

    private var requiresRescuerEligibility: Bool {
        authSession.session?.roleId == 3
    }

    private var rescuerEligibility: Bool? {
        authSession.session?.isEligibleRescuer
    }

    private var hasUnlockedInterface: Bool {
        guard isFullyAuthenticated else { return false }
        guard requiresRescuerEligibility else { return true }
        return rescuerEligibility == true
    }

    private var isRescuerExplicitlyLocked: Bool {
        guard isFullyAuthenticated, requiresRescuerEligibility else { return false }
        return rescuerEligibility == false
    }

    private var isCheckingRescuerEligibility: Bool {
        guard isFullyAuthenticated, requiresRescuerEligibility else { return false }
        // Keep checking state while eligibility is still unknown,
        // instead of treating unknown as locked.
        return rescuerEligibility == nil || authSession.isRefreshingCurrentUser
    }

    private var currentDiscoveryRole: MultipeerSession.DiscoveryRole? {
        guard hasUnlockedInterface else { return nil }
        return authSession.session?.roleId == 3 ? .rescuer : .victim
    }

    private func bootstrapAuthenticatedNetworking() {
        guard hasUnlockedInterface else { return }
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
            await authSession.refreshCurrentUserIfNeeded(force: force && requiresRescuerEligibility)

            if hasUnlockedInterface {
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
            if requiresRescuerEligibility {
                if hasUnlockedInterface {
                    MainTabView(
                        nearbyManager: nearbyManager,
                        multipeerSession: multipeerSession,
                        bridgefyManager: bridgefyManager,
                        selectedPeer: $selectedPeer
                    )
                } else if isRescuerExplicitlyLocked {
                    RescuerEligibilityGateView(
                        state: .locked,
                        retryAction: { refreshAuthenticatedAccess(force: true) }
                    )
                } else if isCheckingRescuerEligibility {
                    RescuerEligibilityGateView(
                        state: .checking,
                        retryAction: { refreshAuthenticatedAccess(force: true) }
                    )
                }
            } else {
                MainTabView(
                    nearbyManager: nearbyManager,
                    multipeerSession: multipeerSession,
                    bridgefyManager: bridgefyManager,
                    selectedPeer: $selectedPeer
                )
            }
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
