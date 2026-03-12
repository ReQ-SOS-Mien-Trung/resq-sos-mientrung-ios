import SwiftUI
import MultipeerConnectivity

// MARK: - Keyboard Dismiss Extension
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ContentView: View {
    @StateObject private var nearbyManager: NearbyInteractionManager
    @StateObject private var multipeerSession: MultipeerSession
    @StateObject private var bridgefyManager = BridgefyNetworkManager.shared
    @StateObject private var userProfile = UserProfile.shared
    @StateObject private var authSession = AuthSessionStore.shared
    @ObservedObject private var appearance = AppearanceManager.shared
    @State private var selectedPeer: MCPeerID?
    @State private var isSetupComplete = false
    
    init() {
        let manager = NearbyInteractionManager()
        _nearbyManager = StateObject(wrappedValue: manager)
        _multipeerSession = StateObject(wrappedValue: MultipeerSession(nearbyManager: manager))
    }
    
    /// Cho vào app khi có user profile VÀ có session hợp lệ
    private var isFullyAuthenticated: Bool {
        userProfile.isSetupComplete && authSession.isValid
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
            .onTapGesture {
                hideKeyboard()
            }
            .onAppear {
                isSetupComplete = isFullyAuthenticated
                if isFullyAuthenticated {
                    bridgefyManager.start()
                    ServerRequestGateway.shared.start()
                }
            }
            .onChange(of: userProfile.currentUser) { newUser in
                if newUser == nil {
                    isSetupComplete = false
                }
            }
            .onChange(of: authSession.session) { newSession in
                // Session bị xóa (logout hoặc hết hạn) → về màn hình đăng nhập
                if newSession == nil {
                    isSetupComplete = false
                }
            }
    }

    var body: some View {
        configuredView
            .preferredColorScheme(appearance.computedColorScheme)
            .onChange(of: isSetupComplete) { newValue in
                if newValue {
                    bridgefyManager.start()
                    ServerRequestGateway.shared.start()
                }
            }
            .onChange(of: multipeerSession.connectedPeers) { peers in
                if peers.count == 1, selectedPeer == nil {
                    selectedPeer = peers.first
                    nearbyManager.setActivePeer(peers.first)
                }
            }
    }
}
