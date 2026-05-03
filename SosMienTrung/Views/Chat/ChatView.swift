import SwiftUI
import MapKit

struct ChatView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @State private var messageText = ""
    @State private var showSosPicker = false
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
                        showSosPicker = true
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
        .sheet(isPresented: $showSosPicker) {
            GeneralChatSosPickerView(bridgefyManager: bridgefyManager)
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

private struct GeneralChatSosPickerView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @Environment(\.dismiss) private var dismiss

    @State private var sosRequests: [SosRequestDto] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sosRequests.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.sm) {
                            ForEach(sosRequests) { sos in
                                Button {
                                    share(sos)
                                } label: {
                                    GeneralChatSosPickerRow(sos: sos)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(DS.Spacing.md)
                    }
                }
            }
            .background(DS.Colors.background)
            .navigationTitle("Chọn SOS đã gửi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task {
                await loadSOSRequests()
            }
            .alert("Không thể gửi SOS vào chat", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(DS.Colors.textTertiary)

            Text("Chưa có SOS đã gửi")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)

            Text("Sau khi tạo SOS, bạn có thể quay lại đây để chọn và gửi vào Trò chuyện tổng.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.md)

            Button {
                Task { await loadSOSRequests() }
            } label: {
                Label("Tải lại", systemImage: "arrow.clockwise")
                    .font(DS.Typography.subheadline.weight(.semibold))
            }
            .padding(.top, DS.Spacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Spacing.lg)
    }

    @MainActor
    private func loadSOSRequests() async {
        isLoading = true
        defer { isLoading = false }

        guard let records = await APIService.shared.fetchMySOS() else {
            sosRequests = []
            errorMessage = "Không tải được danh sách SOS đã gửi."
            return
        }

        sosRequests = records
            .map(Self.mapServerSOSRecord)
            .sorted { lhs, rhs in
                if let leftDate = Self.parseServerDate(lhs.createdAt),
                   let rightDate = Self.parseServerDate(rhs.createdAt) {
                    return leftDate > rightDate
                }
                return lhs.id > rhs.id
            }
    }

    private func share(_ sos: SosRequestDto) {
        guard bridgefyManager.sendSosRequestToGeneralChat(sos) else {
            errorMessage = "Bridgefy chưa sẵn sàng hoặc chưa có thông tin người dùng."
            return
        }
        dismiss()
    }

    private static func mapServerSOSRecord(_ record: SOSServerRecord) -> SosRequestDto {
        SosRequestDto(
            id: record.id,
            sosType: record.sosType,
            msg: record.rawMessage,
            status: record.status ?? "Pending",
            priorityLevel: record.priorityLevel,
            waitTimeMinutes: record.waitTimeMinutes,
            latitude: record.latitude,
            longitude: record.longitude,
            createdAt: record.createdAt
        )
    }

    private static func parseServerDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }
}

private struct GeneralChatSosPickerRow: View {
    let sos: SosRequestDto

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxxs) {
                    Text("SOS #\(sos.id)")
                        .font(DS.Typography.headline.monospacedDigit())
                        .foregroundColor(DS.Colors.text)

                    if let type = SosDisplayFormatter.localizedType(sos.sosType) {
                        Text(type)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }

                Spacer(minLength: DS.Spacing.sm)

                statusBadge
            }

            Text(sos.msg)
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            HStack(spacing: DS.Spacing.xs) {
                if let priority = SosDisplayFormatter.localizedPriority(sos.priorityLevel) {
                    metadataPill(icon: "flag.fill", text: priority)
                }

                if let latitude = sos.latitude, let longitude = sos.longitude {
                    metadataPill(
                        icon: "location.fill",
                        text: String(format: "%.4f, %.4f", latitude, longitude)
                    )
                }
            }
        }
        .padding(DS.Spacing.sm)
        .sharpCard(shadow: DS.Shadow.small, backgroundColor: DS.Colors.surface, radius: DS.Radius.md)
    }

    private var statusBadge: some View {
        Text(SosDisplayFormatter.localizedStatus(sos.status))
            .font(DS.Typography.caption.weight(.bold))
            .foregroundColor(statusColor)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxxs)
            .overlay(Rectangle().stroke(statusColor.opacity(0.45), lineWidth: DS.Border.thin))
    }

    private var statusColor: Color {
        switch SosDisplayFormatter.normalizedKey(sos.status) {
        case "pending", "waiting", "queued", "new":
            return DS.Colors.warning
        case "approved", "accepted", "assigned", "inprogress", "ongoing", "processing":
            return DS.Colors.info
        case "resolved", "closed", "completed", "done":
            return DS.Colors.success
        case "rejected", "declined", "cancelled", "canceled", "cancel":
            return DS.Colors.danger
        default:
            return DS.Colors.textSecondary
        }
    }

    private func metadataPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .lineLimit(1)
        }
        .font(DS.Typography.caption)
        .foregroundColor(DS.Colors.textSecondary)
    }
}

struct MessageBubble: View {
    let message: Message
    @State private var showMap = false
    @EnvironmentObject var bridgefyManager: BridgefyNetworkManager

    /// Tin có nền tối (đỏ SOS hoặc cam của mình) ⇒ chữ sáng. Tin nhận thường ⇒ chữ tối.
    private var usesLightForeground: Bool {
        message.isFromMe || message.type == .sosLocation
    }

    private var primaryTextColor: Color {
        usesLightForeground ? .white : DS.Colors.text
    }

    private var secondaryTextColor: Color {
        usesLightForeground ? .white.opacity(0.8) : DS.Colors.textSecondary
    }

    private var dividerColor: Color {
        usesLightForeground ? .white.opacity(0.3) : DS.Colors.border
    }

    private var mapButtonBackground: Color {
        usesLightForeground ? Color.white.opacity(0.2) : DS.Colors.accent.opacity(0.12)
    }

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
                        .foregroundColor(primaryTextColor)

                    if message.hasLocation, let lat = message.latitude, let long = message.longitude {
                        EditorialDivider(color: dividerColor)

                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(String(format: "%.6f, %.6f", lat, long))
                                .font(.system(.caption, design: .monospaced))
                        }
                        .foregroundColor(secondaryTextColor)

                        Button { showMap = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "map.fill")
                                Text("Xem bản đồ")
                            }
                            .font(.caption.weight(.bold))
                            .foregroundColor(primaryTextColor)
                            .padding(6)
                            .background(mapButtonBackground)
                        }
                    }
                }
                .padding(DS.Spacing.sm)
                .background(message.type == .sosLocation ? DS.Colors.danger : (message.isFromMe ? DS.Colors.accent : DS.Colors.surface))
                .foregroundColor(primaryTextColor)
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
