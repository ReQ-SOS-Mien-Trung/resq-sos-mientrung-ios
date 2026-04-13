//
//  HomeView.swift
//  SosMienTrung
//
//  ResQ Home — Editorial Grid Layout
//

import SwiftUI
import CoreLocation
import MultipeerConnectivity

struct HomeView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @ObservedObject var nearbyManager: NearbyInteractionManager
    @ObservedObject var multipeerSession: MultipeerSession
    @ObservedObject private var authSession = AuthSessionStore.shared
    @ObservedObject private var navigationCoordinator = AppNavigationCoordinator.shared
    @Binding var selectedPeer: MCPeerID?

    @StateObject private var locationManager = LocationManager()
    @StateObject private var notificationHub = NotificationHubService.shared

    @State private var showAssemblyPointMap = false
    @State private var showSOSForm = false
    @State private var showChatBot = false
    @State private var showWaterEject = false
    @State private var showRescuersView = false
    @State private var showRescuerDashboard = false
    @State private var showVictimStandby = false
    @State private var showCoordinatorChat = false
    @State private var showSOSSignal = false

    @State private var weatherInfo = "TP Hồ Chí Minh - Có Mây"

    private var canCreateSosRequest: Bool {
        authSession.session?.canCreateSosRequest ?? false
    }

    private var canAccessRescuerWorkspace: Bool {
        authSession.session?.canAccessRescuerWorkspace ?? false
    }

    private var canUseRescuerTracking: Bool {
        authSession.session?.canUseRescuerTracking ?? false
    }

    private var canOpenCoordinatorChat: Bool {
        authSession.session?.roleId != 3
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                    // MARK: - Header
                    headerSection
                        .padding(.top, DS.Spacing.md)

                    // MARK: - Weather strip
                    weatherSection

                    // MARK: - SOS CTA Button
                    if canCreateSosRequest {
                        sosCTAButton
                    }

                    // MARK: - Coordinator Chat Button
                    if canOpenCoordinatorChat {
                        coordinatorChatButton
                    }

                    // MARK: - Main grid
                    Text("BẢN ĐỒ & CỨU HỘ").sectionHeader()
                    mainGridSection

                    // MARK: - Secondary grid
                    Text("TIỆN ÍCH").sectionHeader()
                    secondaryGridSection

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, DS.Spacing.md)
            }
            .background(DS.Colors.background)
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showAssemblyPointMap) {
            AssemblyPointMapView()
        }
        .fullScreenCover(isPresented: $showSOSForm) {
            SOSFormView(bridgefyManager: bridgefyManager)
        }
        .sheet(isPresented: $showChatBot) {
            ChatBotView()
        }
        .sheet(isPresented: $showWaterEject) {
            WaterEjectView()
        }
        .fullScreenCover(isPresented: $showSOSSignal) {
            SOSSignalView()
        }
        .fullScreenCover(isPresented: $showCoordinatorChat) {
            CoordinatorChatMainView()
        }
        .fullScreenCover(isPresented: $showRescuersView) {
            NavigationStack {
                RescuersView(
                    nearbyManager: nearbyManager,
                    multipeerSession: multipeerSession,
                    selectedPeer: $selectedPeer
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Đóng") { showRescuersView = false }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showRescuerDashboard) {
            RescuerDashboardView()
        }
        .fullScreenCover(isPresented: $showVictimStandby) {
            NavigationStack {
                VictimStandbyView(
                    nearbyManager: nearbyManager,
                    multipeerSession: multipeerSession
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Đóng") { showVictimStandby = false }
                    }
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                Image("resq_typo_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)

                Spacer()

                notificationButton
            }

            EditorialDivider(height: DS.Border.thin)
        }
    }

    private var notificationButton: some View {
        Button {
            navigationCoordinator.openNotifications()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: notificationHub.unreadCount == 0 ? "bell" : "bell.badge.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DS.Colors.text)
                    .frame(width: 44, height: 44)
                    .background(DS.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
                    )

                if notificationHub.unreadCount > 0 {
                    Text(badgeText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(DS.Colors.danger)
                        .clipShape(Capsule())
                        .offset(x: 8, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trung tâm thông báo")
    }

    private var badgeText: String {
        let count = notificationHub.unreadCount
        return count > 99 ? "99+" : "\(count)"
    }

    // MARK: - Weather
    private var weatherSection: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(DS.Colors.warning)
            Text(weatherInfo)
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .padding(DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sharpCard(
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.small,
            backgroundColor: DS.Colors.background
        )
    }

    // MARK: - Coordinator Chat Button
    private var coordinatorChatButton: some View {
        Button {
            showCoordinatorChat = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "headphones.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHAT VỚI TỔNG ĐÀI VIÊN")
                        .font(DS.Typography.headline)
                        .tracking(1.5)
                    Text("Kết nối trực tiếp với Coordinator hỗ trợ")
                        .font(DS.Typography.caption)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.md)
            .background(DS.Colors.info)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }

    // MARK: - SOS CTA
    private var sosCTAButton: some View {
        Button {
            showSOSForm = true
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "sos.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                Text("GỬI TÍN HIỆU SOS")
                    .font(DS.Typography.headline)
                    .tracking(2)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.danger)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
    }

    // MARK: - Main Grid (Maps & Rescue)
    private var mainGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: DS.Spacing.sm),
            GridItem(.flexible(), spacing: DS.Spacing.sm)
        ], spacing: DS.Spacing.sm) {
            ResQGridButton(
                icon: "house.and.flag.fill",
                title: "Bản đồ\nlánh nạn",
                accentColor: DS.Colors.warning
            ) {
                showAssemblyPointMap = true
            }

            if canCreateSosRequest {
                ResQGridButton(
                    icon: "figure.wave.circle.fill",
                    title: "Chờ cứu\n(Victim)",
                    accentColor: DS.Colors.danger
                ) {
                    showVictimStandby = true
                }
            }

            if canUseRescuerTracking {
                ResQGridButton(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Cứu hộ\n(Cứu hộ viên)",
                    accentColor: DS.Colors.accent
                ) {
                    showRescuersView = true
                }
            }

            if canAccessRescuerWorkspace {
                ResQGridButton(
                    icon: "checklist",
                    title: "Nhiệm vụ\n& Xác nhận có mặt",
                    accentColor: DS.Colors.warning
                ) {
                    showRescuerDashboard = true
                }
            }
        }
    }

    // MARK: - Secondary Grid (Utils)
    private var secondaryGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: DS.Spacing.sm),
            GridItem(.flexible(), spacing: DS.Spacing.sm),
            GridItem(.flexible(), spacing: DS.Spacing.sm)
        ], spacing: DS.Spacing.sm) {
            ResQGridButton(
                icon: "speaker.wave.3.fill",
                title: "Đẩy nước\nkhỏi loa",
                accentColor: DS.Colors.info
            ) {
                showWaterEject = true
            }

            ResQGridButton(
                icon: "brain.head.profile",
                title: "AI\nTrợ lý",
                accentColor: DS.Colors.success
            ) {
                showChatBot = true
            }

            ResQGridButton(
                icon: "light.beacon.max.fill",
                title: "Flash\nSOS",
                accentColor: DS.Colors.danger
            ) {
                showSOSSignal = true
            }
        }
    }
}

// MARK: - HomeGridButton (backward compat alias)
struct HomeGridButton: View {
    let icon: String
    let title: String
    let iconColor: Color
    let backgroundColor: Color
    let action: () -> Void

    var body: some View {
        ResQGridButton(icon: icon, title: title, accentColor: iconColor, action: action)
    }
}

#if swift(>=5.9)
@available(iOS 17, *)
#Preview {
    @Previewable @State var selectedPeer: MCPeerID? = nil
    let nearbyManager = NearbyInteractionManager()
    HomeView(
        bridgefyManager: BridgefyNetworkManager.shared,
        nearbyManager: nearbyManager,
        multipeerSession: MultipeerSession(nearbyManager: nearbyManager),
        selectedPeer: $selectedPeer
    )
}
#endif
