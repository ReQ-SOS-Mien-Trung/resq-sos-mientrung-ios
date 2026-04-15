import SwiftUI
import MapKit

struct ChatView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @State private var messageText = ""
    @State private var showSOSForm = false
    @FocusState private var isTextFieldFocused: Bool

    var generalMessages: [Message] {
        bridgefyManager.messages.filter { $0.recipientId == nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                EyebrowLabel(text: "TRÒ CHUYỆN KHẨN CẤP")
                Text("Trò chuyện tổng")
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text)

                HStack(spacing: 6) {
                    Circle()
                        .fill(bridgefyManager.connectedUsers.isEmpty ? DS.Colors.textTertiary : DS.Colors.success)
                        .frame(width: 8, height: 8)
                    Text("\(bridgefyManager.connectedUsers.count) người kết nối")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }

                if bridgefyManager.connectedUsers.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DS.Colors.warning)
                        Text("Broadcast: Tin nhắn gửi đến tất cả thiết bị gần đây")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textTertiary)
                    }
                }

                EditorialDivider(height: DS.Border.thick)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
                
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.sm) {
                            if generalMessages.isEmpty {
                                Text("Chưa có tin nhắn. Gửi tin nhắn để bắt đầu trò chuyện!")
                                    .font(DS.Typography.subheadline)
                                    .foregroundColor(DS.Colors.textTertiary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 60)
                            } else {
                                ForEach(generalMessages) { message in
                                    MessageBubble(message: message)
                                        .environmentObject(bridgefyManager)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: generalMessages.count) { _ in
                        if let lastMessage = generalMessages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Message Input — Sharp Design
                HStack(spacing: DS.Spacing.sm) {
                    Button {
                        isTextFieldFocused = false
                        showSOSForm = true
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DS.Colors.danger)
                            .frame(width: 40, height: 40)
                            .background(DS.Colors.danger.opacity(0.1))
                            .overlay(Rectangle().stroke(DS.Colors.danger, lineWidth: DS.Border.thin))
                    }

                    ResQTextField(placeholder: "Nhập tin nhắn...", text: $messageText)

                    Button { sendMessage() } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(messageText.isEmpty ? DS.Colors.textTertiary : .white)
                            .frame(width: 40, height: 40)
                            .background(messageText.isEmpty ? DS.Colors.surface : DS.Colors.accent)
                            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding(DS.Spacing.sm)
                .background(DS.Colors.surface)
                .overlay(Rectangle().frame(height: DS.Border.thin).foregroundColor(DS.Colors.border), alignment: .top)
            }
            .background(DS.Colors.background)
        .fullScreenCover(isPresented: $showSOSForm) {
            SOSFormView(bridgefyManager: bridgefyManager)
        }
    }

    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        bridgefyManager.sendBroadcastMessage(trimmedText)
        messageText = ""
        isTextFieldFocused = false
    }
}

struct MessageBubble: View {
    let message: Message
    @State private var showMap = false
    @EnvironmentObject var bridgefyManager: BridgefyNetworkManager
    
    var body: some View {
        HStack {
            if message.isFromMe {
                Spacer()
            }
            
            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                // Sender name (if not from me)
                if !message.isFromMe && !message.senderName.isEmpty {
                    Text(message.senderName)
                        .font(.caption.bold())
                        .foregroundColor(message.type == .sosLocation ? .red : .blue)
                }
                
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(message.text)
                        .foregroundColor(.white)

                    if message.hasLocation, let lat = message.latitude, let long = message.longitude {
                        EditorialDivider(color: .white.opacity(0.3))

                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(String(format: "%.6f, %.6f", lat, long))
                                .font(.system(.caption, design: .monospaced))
                        }
                        .foregroundColor(.white.opacity(0.8))

                        Button { showMap = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "map.fill")
                                Text("Xem bản đồ")
                            }
                            .font(.caption.weight(.bold))
                            .padding(6)
                            .background(Color.white.opacity(0.2))
                        }
                    }
                }
                .padding(DS.Spacing.sm)
                .background(message.type == .sosLocation ? DS.Colors.danger : (message.isFromMe ? DS.Colors.accent : DS.Colors.surface))
                .foregroundColor(message.isFromMe || message.type == .sosLocation ? .white : DS.Colors.text)
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                
                // Just show time, no status
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: 250, alignment: message.isFromMe ? .trailing : .leading)
            
            if !message.isFromMe {
                Spacer()
            }
        }
        .sheet(isPresented: $showMap) {
            if message.hasLocation, let lat = message.latitude, let long = message.longitude {
                NavigationStack {
                    LocationDetailMapView(latitude: lat, longitude: long, title: message.text)
                        .navigationTitle("Vị trí SOS")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Đóng") {
                                    showMap = false
                                }
                            }
                        }
                }
            }
        }
    }
}

// View riêng để hiển thị bản đồ cho một tin nhắn cụ thể
struct LocationDetailMapView: View {
    let latitude: Double
    let longitude: Double
    let title: String
    
    @State private var region: MKCoordinateRegion
    
    init(latitude: Double, longitude: Double, title: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.title = title
        
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: [makeAnnotation()]) { item in
            MapAnnotation(coordinate: item.coordinate) {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    Text("SOS")
                        .font(.caption)
                        .padding(4)
                        .background(Color.white)
                        .cornerRadius(4)
                }
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
    
    private func makeAnnotation() -> LocationAnnotation {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return LocationAnnotation(
            coordinate: coordinate,
            title: title,
            subtitle: "SOS Location",
            userId: UUID(),
            timestamp: Date()
        )
    }
}

#Preview {
    NavigationStack {
        ChatView(bridgefyManager: BridgefyNetworkManager.shared)
    }
}
