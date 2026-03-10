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
    @Binding var selectedPeer: MCPeerID?

    @StateObject private var locationManager = LocationManager()

    @State private var showSOSMap = false
    @State private var showSOSForm = false
    @State private var showChatBot = false
    @State private var showNotifications = false
    @State private var showMapDisabledAlert = false
    @State private var showWaterEject = false
    @State private var showRescuersView = false

    @State private var weatherInfo = "TP Hồ Chí Minh - Có Mây"

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
                    sosCTAButton

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
        .fullScreenCover(isPresented: $showSOSMap) {
            SOSMapView()
        }
        .alert("Thông báo", isPresented: $showMapDisabledAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Chức năng bản đồ đang được cập nhật. Vui lòng thử lại sau.")
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
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {

            Image("resq_typo_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 64)

            EditorialDivider(height: DS.Border.thin)
        }
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
                icon: "mappin.and.ellipse",
                title: "Bản đồ\ncần trợ giúp",
                accentColor: DS.Colors.danger
            ) {
                showMapDisabledAlert = true
            }

            ResQGridButton(
                icon: "cloud.rain.fill",
                title: "Bản đồ\nthiên tai",
                accentColor: DS.Colors.info
            ) {
                showSOSMap = true
            }

            ResQGridButton(
                icon: "house.and.flag.fill",
                title: "Bản đồ\nlánh nạn",
                accentColor: DS.Colors.warning
            ) {
                showMapDisabledAlert = true
            }

            ResQGridButton(
                icon: "antenna.radiowaves.left.and.right",
                title: "Cứu hộ",
                accentColor: DS.Colors.accent
            ) {
                showRescuersView = true
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
                icon: "newspaper.fill",
                title: "Tin tức",
                accentColor: DS.Colors.warning
            ) {
                // Action tin tức
            }

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
