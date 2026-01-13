//
//  HomeView.swift
//  SosMienTrung
//
//  Màn hình Home với các chức năng chính
//

import SwiftUI
import CoreLocation

struct HomeView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @ObservedObject var appearanceManager = AppearanceManager.shared
    @StateObject private var locationManager = LocationManager()
    
    // @State private var showSOSMap = false  // Tạm ẩn để tối ưu launch
    @State private var showSOSForm = false
    @State private var showChatBot = false
    @State private var showSettings = false
    @State private var showNotifications = false
    @State private var showMapDisabledAlert = false
    
    // Weather mock data (có thể kết nối API thực sau)
    @State private var weatherInfo = "TP Hồ Chí Minh - Có Mây"
    @State private var weatherIcon = "cloud.sun.fill"
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                TelegramBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerSection
                        
                        // Weather info
                        weatherSection
                        
                        // Notification button
                        notificationButton
                        
                        // Main grid buttons
                        mainGridSection
                        
                        // Secondary grid buttons
                        secondaryGridSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
        }
        // MARK: - Map tạm ẩn để tối ưu launch time
        // .sheet(isPresented: $showSOSMap) {
        //     SOSMapView(messages: .constant(bridgefyManager.messages))
        // }
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
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Image(systemName: weatherIcon)
                .font(.system(size: 32))
                .foregroundColor(.yellow)
            
            Text("TRẠM CỨU TRỢ")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(appearanceManager.textColor)
        }
        .padding(.top, 10)
    }
    
    // MARK: - Weather Section
    private var weatherSection: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .foregroundColor(.yellow)
            Text("Thời tiết: \(weatherInfo)")
                .font(.subheadline)
                .foregroundColor(appearanceManager.secondaryTextColor)
        }
    }
    
    // MARK: - Notification Button
    private var notificationButton: some View {
        Button {
            showNotifications = true
        } label: {
            HStack {
                Text("Xem tất cả thông báo")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(hex: "4CAF50"))
            .cornerRadius(25)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Main Grid Section (Bản đồ)
    private var mainGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            // Bản đồ cần trợ giúp (tạm ẩn)
            HomeGridButton(
                icon: "mappin.and.ellipse",
                title: "Bản đồ\ncần trợ giúp",
                iconColor: Color(hex: "E57373"),
                backgroundColor: Color(hex: "FFEBEE")
            ) {
                showMapDisabledAlert = true
            }
            
            // Bản đồ thiên tai (tạm ẩn)
            HomeGridButton(
                icon: "cloud.rain.fill",
                title: "Bản đồ\nthiên tai",
                iconColor: Color(hex: "E57373"),
                backgroundColor: Color(hex: "FFEBEE")
            ) {
                showMapDisabledAlert = true
            }
            
            // Bản đồ lánh nạn (tạm ẩn)
            HomeGridButton(
                icon: "house.and.flag.fill",
                title: "Bản đồ\nlánh nạn",
                iconColor: Color(hex: "E57373"),
                backgroundColor: Color(hex: "FFEBEE")
            ) {
                showMapDisabledAlert = true
            }
            
            // Đăng cảnh báo
            HomeGridButton(
                icon: "megaphone.fill",
                title: "Đăng\ncảnh báo",
                iconColor: Color(hex: "78909C"),
                backgroundColor: Color(hex: "ECEFF1")
            ) {
                showSOSForm = true
            }
            
            // Đăng tin cần trợ giúp
            HomeGridButton(
                icon: "hand.raised.fill",
                title: "Đăng tin\ncần trợ giúp",
                iconColor: Color(hex: "78909C"),
                backgroundColor: Color(hex: "ECEFF1")
            ) {
                showSOSForm = true
            }
            
            // Liên hệ
            HomeGridButton(
                icon: "envelope.fill",
                title: "Liên hệ",
                iconColor: Color(hex: "78909C"),
                backgroundColor: Color(hex: "ECEFF1")
            ) {
                // Action liên hệ
            }
        }
    }
    
    // MARK: - Secondary Grid Section
    private var secondaryGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            // Tin tức
            HomeGridButton(
                icon: "newspaper.fill",
                title: "Tin tức",
                iconColor: Color(hex: "FFB74D"),
                backgroundColor: Color(hex: "FFF3E0")
            ) {
                // Action tin tức
            }
            
            // Tin tức thiên tai
            HomeGridButton(
                icon: "tv.fill",
                title: "Tin tức\nthiên tai",
                iconColor: Color(hex: "FFB74D"),
                backgroundColor: Color(hex: "FFF3E0")
            ) {
                // Action tin tức thiên tai
            }
            
            // Cài đặt / AI Assistant
            HomeGridButton(
                icon: "brain.head.profile",
                title: "AI\nTrợ lý",
                iconColor: Color(hex: "81C784"),
                backgroundColor: Color(hex: "E8F5E9")
            ) {
                showChatBot = true
            }
        }
    }
}

// MARK: - Home Grid Button Component
struct HomeGridButton: View {
    let icon: String
    let title: String
    let iconColor: Color
    let backgroundColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(iconColor)
                }
                
                // Title
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(backgroundColor)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    HomeView(bridgefyManager: BridgefyNetworkManager.shared)
}
