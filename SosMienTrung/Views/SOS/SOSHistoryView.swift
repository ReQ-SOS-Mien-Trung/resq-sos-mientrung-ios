//
//  SOSHistoryView.swift
//  SosMienTrung
//
//  Trang quản lý các SOS đã gửi
//

import SwiftUI

struct SOSHistoryView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @ObservedObject var appearanceManager = AppearanceManager.shared
    
    @State private var showSOSForm = false
    @State private var selectedSOS: SavedSOS?
    
    // SOS từ storage
    private var savedSOSList: [SavedSOS] {
        SOSStorageManager.shared.savedSOSList
    }
    
    // Lọc ra các tin nhắn SOS từ messages (fallback)
    private var sosMessages: [Message] {
        bridgefyManager.messages
            .filter { $0.type == .sosLocation }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    // SOS do mình gửi (từ storage)
    private var mySOS: [SavedSOS] {
        SOSStorageManager.shared.mySOS
    }
    
    // SOS nhận được từ người khác (từ messages)
    private var receivedSOS: [Message] {
        sosMessages.filter { !$0.isFromMe }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                TelegramBackground()
                
                VStack(spacing: 0) {
                    // Header stats
                    statsHeader
                    
                    if savedSOSList.isEmpty && sosMessages.isEmpty {
                        emptyState
                    } else {
                        sosListView
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Quản lý SOS")
                        .font(.headline)
                        .foregroundColor(appearanceManager.textColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSOSForm = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showSOSForm) {
            SOSFormView(bridgefyManager: bridgefyManager)
        }
        .sheet(item: $selectedSOS) { sos in
            SOSDetailView(savedSOS: sos, bridgefyManager: bridgefyManager)
        }
    }
    
    // MARK: - Stats Header
    private var statsHeader: some View {
        HStack(spacing: 12) {
            StatCard(
                icon: "arrow.up.circle.fill",
                value: "\(mySOS.count)",
                label: "Đã gửi",
                color: .red
            )
            
            StatCard(
                icon: "arrow.down.circle.fill",
                value: "\(receivedSOS.count)",
                label: "Đã nhận",
                color: .blue
            )
            
            StatCard(
                icon: networkMonitor.isConnected ? "wifi" : "wifi.slash",
                value: networkMonitor.isConnected ? "Online" : "Mesh",
                label: "Trạng thái",
                color: networkMonitor.isConnected ? .green : .orange
            )
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.green.opacity(0.6))
            
            Text("Chưa có SOS nào")
                .font(.title2.bold())
                .foregroundColor(appearanceManager.textColor)
            
            Text("Bạn chưa gửi hoặc nhận bất kỳ tín hiệu SOS nào.\nNhấn nút + để gửi SOS mới.")
                .font(.subheadline)
                .foregroundColor(appearanceManager.secondaryTextColor)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Big SOS button
            Button {
                showSOSForm = true
            } label: {
                HStack {
                    Image(systemName: "sos.circle.fill")
                    Text("GỬI SOS MỚI")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - SOS List
    private var sosListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Phần SOS đã gửi (từ storage - có thể xem chi tiết)
                if !mySOS.isEmpty {
                    sosSection(title: "🆘 SOS đã gửi", count: mySOS.count) {
                        ForEach(mySOS) { savedSOS in
                            SavedSOSCard(savedSOS: savedSOS) {
                                selectedSOS = savedSOS
                            }
                        }
                    }
                }
                
                // Phần SOS đã nhận
                if !receivedSOS.isEmpty {
                    sosSection(title: "📥 SOS đã nhận", count: receivedSOS.count) {
                        ForEach(receivedSOS) { message in
                            SOSHistoryCard(message: message, isMine: false)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - SOS Section Builder (giống Settings)
    private func sosSection<Content: View>(title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 4)
            
            // Section content với blur background
            VStack(spacing: 12) {
                content()
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - Saved SOS Card (có thể tap để xem chi tiết)
struct SavedSOSCard: View {
    let savedSOS: SavedSOS
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    // SOS Type icon
                    if let type = savedSOS.sosType {
                        Text(type.icon)
                            .font(.title2)
                    } else {
                        Image(systemName: "sos.circle.fill")
                            .foregroundColor(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(savedSOS.sosType?.title ?? "SOS")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            
                            // Status badge
                            Text(savedSOS.status.title)
                                .font(.caption2.bold())
                                .foregroundColor(savedSOS.status.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(savedSOS.status.color.opacity(0.3))
                                .cornerRadius(6)
                        }
                        
                        Text(savedSOS.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    // Chevron to indicate tappable
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Summary info
                HStack(spacing: 16) {
                    // People count
                    if let rescue = savedSOS.rescueData {
                        Label("\(rescue.peopleCount.total)", systemImage: "person.2")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        if rescue.hasInjured {
                            Label("\(rescue.injuredPersonIds.count) thương", systemImage: "bandage")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else if let relief = savedSOS.reliefData {
                        Label("\(relief.peopleCount.total)", systemImage: "person.2")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Label("\(relief.supplies.count) mặt hàng", systemImage: "shippingbox")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    
                    Spacer()
                }
                
                // Location if available
                if let lat = savedSOS.latitude, let lon = savedSOS.longitude {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(String(format: "%.4f, %.4f", lat, lon))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    @ObservedObject var appearanceManager = AppearanceManager.shared
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline.bold())
                .foregroundColor(appearanceManager.textColor)
            
            Text(label)
                .font(.caption)
                .foregroundColor(appearanceManager.secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - SOS History Card
struct SOSHistoryCard: View {
    let message: Message
    let isMine: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: isMine ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(isMine ? .red : .blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isMine ? "Đã gửi" : "Nhận từ: \(message.senderName.isEmpty ? "Không rõ" : message.senderName)")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Status badge
                StatusBadge(status: .sent)
            }
            
            // Message content
            Text(message.text)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(3)
            
            // Location if available
            if let lat = message.latitude, let long = message.longitude {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(String(format: "%.4f, %.4f", lat, long))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Button {
                        openInMaps(lat: lat, long: long)
                    } label: {
                        Text("Xem bản đồ")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
    
    private func openInMaps(lat: Double, long: Double) {
        let urlString = "maps://?ll=\(lat),\(long)&q=SOS%20Location"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Status Badge
enum SOSStatus {
    case sent
    case delivered
    case relayed
    
    var text: String {
        switch self {
        case .sent: return "Đã gửi"
        case .delivered: return "Đã nhận"
        case .relayed: return "Đã relay"
        }
    }
    
    var color: Color {
        switch self {
        case .sent: return .orange
        case .delivered: return .green
        case .relayed: return .blue
        }
    }
}

struct StatusBadge: View {
    let status: SOSStatus
    
    var body: some View {
        Text(status.text)
            .font(.caption2.bold())
            .foregroundColor(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.2))
            .cornerRadius(8)
    }
}

#Preview {
    SOSHistoryView(bridgefyManager: BridgefyNetworkManager.shared)
}
