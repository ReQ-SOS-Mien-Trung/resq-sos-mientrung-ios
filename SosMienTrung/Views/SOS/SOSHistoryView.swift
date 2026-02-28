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
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    EyebrowLabel(text: "QUẢN LÝ")
                    Text("SOS")
                        .font(DS.Typography.largeTitle)
                        .foregroundColor(DS.Colors.text)
                    EditorialDivider(height: DS.Border.thick)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)

                statsHeader

                if savedSOSList.isEmpty && sosMessages.isEmpty {
                    emptyState
                } else {
                    sosListView
                }
            }
            .background(DS.Colors.background)
            .navigationBarHidden(true)
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
        HStack(spacing: DS.Spacing.sm) {
            StatCard(icon: "arrow.up.circle.fill", value: "\(mySOS.count)", label: "Đã gửi", color: DS.Colors.danger)
            StatCard(icon: "arrow.down.circle.fill", value: "\(receivedSOS.count)", label: "Đã nhận", color: DS.Colors.info)
            StatCard(icon: networkMonitor.isConnected ? "wifi" : "wifi.slash", value: networkMonitor.isConnected ? "Online" : "Mesh", label: "Trạng thái", color: networkMonitor.isConnected ? DS.Colors.success : DS.Colors.warning)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer()
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(DS.Colors.success.opacity(0.6))
            Text("Chưa có SOS nào")
                .font(DS.Typography.title)
                .foregroundColor(DS.Colors.text)
            Text("Bạn chưa gửi hoặc nhận bất kỳ tín hiệu SOS nào.\nNhấn nút + để gửi SOS mới.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button { showSOSForm = true } label: {
                HStack {
                    Image(systemName: "sos.circle.fill")
                    Text("Gửi SOS MỚI").font(DS.Typography.headline).tracking(2)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(DS.Colors.danger)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
                .shadow(color: .black.opacity(0.25), radius: 0, x: 4, y: 4)
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
                    .foregroundColor(DS.Colors.text)
                
                Spacer()
                
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundColor(DS.Colors.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DS.Colors.text.opacity(0.2))
                    .cornerRadius(10)
            }
            .padding(.horizontal, 4)
            
            // Section content với blur background
            VStack(spacing: 12) {
                content()
            }
            .padding(DS.Spacing.xs)
            .background(DS.Colors.surface)
            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
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
                                .font(DS.Typography.headline)
                                .foregroundColor(DS.Colors.text)

                            ResQBadge(text: savedSOS.status.title, color: savedSOS.status.color)
                        }

                        Text(savedSOS.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(DS.Colors.textTertiary)
                }
                
                // Summary info
                HStack(spacing: 16) {
                    // People count
                    if let rescue = savedSOS.rescueData {
                        Label("\(rescue.peopleCount.total)", systemImage: "person.2")
                            .font(.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                        
                        if rescue.hasInjured {
                            Label("\(rescue.injuredPersonIds.count) thương", systemImage: "bandage")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else if let relief = savedSOS.reliefData {
                        Label("\(relief.peopleCount.total)", systemImage: "person.2")
                            .font(.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                        
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
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surface)
            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
            Text(label)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
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
                        .foregroundColor(DS.Colors.text)
                    
                    Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                
                Spacer()
                
                // Status badge
                StatusBadge(status: .sent)
            }
            
            // Message content
            Text(message.text)
                .font(.subheadline)
                .foregroundColor(DS.Colors.text)
                .lineLimit(3)
            
            // Location if available
            if let lat = message.latitude, let long = message.longitude {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(String(format: "%.4f, %.4f", lat, long))
                        .font(.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                    
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
