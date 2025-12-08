import SwiftUI
import MapKit

struct ChatView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    // Only show broadcast messages (no recipientId = general chat)
    var generalMessages: [Message] {
        bridgefyManager.messages.filter { message in
            message.recipientId == nil
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Emergency Chat")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(bridgefyManager.connectedUsers.isEmpty ? .gray : .green)
                            .frame(width: 10, height: 10)
                        Text("\(bridgefyManager.connectedUsers.count) rescuer\(bridgefyManager.connectedUsers.count == 1 ? "" : "s") connected")
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.subheadline)
                    }
                    
                    // Warning nếu không có kết nối
                    if bridgefyManager.connectedUsers.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text("Broadcast mode: Messages sent to all nearby devices")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if generalMessages.isEmpty {
                                Text("No messages yet. Send a message to start the conversation!")
                                    .foregroundStyle(.white.opacity(0.5))
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
                    .onChange(of: generalMessages.count) {
                        if let lastMessage = generalMessages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Message Input
                HStack(spacing: 12) {
                    // Nút SOS
                    Button {
                        sendSOSMessage()
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(20)
                    }
                    
                    TextField("Type message...", text: $messageText)
                        .focused($isTextFieldFocused)
                        .padding(12)
                        .background(Color.white.opacity(0.15))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageText.isEmpty ? .gray : .blue)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding()
                .background(Color(white: 0.1))
            }
        }
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        bridgefyManager.sendBroadcastMessage(trimmedText)
        messageText = ""
        isTextFieldFocused = false
    }
    
    private func sendSOSMessage() {
        bridgefyManager.sendSOSWithLocation()
        isTextFieldFocused = false
    }
}

struct MessageBubble: View {
    let message: Message
    @State private var showMap = false
    @State private var statusOpacity: Double = 0
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.text)
                        .foregroundColor(.white)
                        .onAppear {
                            // Mark message as read when it appears on screen
                            if !message.isFromMe {
                                bridgefyManager.markMessageAsRead(message.id)
                            }
                        }
                    
                    // Hiển thị thông tin vị trí nếu có
                    if message.hasLocation, let lat = message.latitude, let long = message.longitude {
                        Divider()
                            .background(Color.white.opacity(0.3))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text(String(format: "%.6f, %.6f", lat, long))
                                .font(.caption)
                                .monospaced()
                        }
                        .foregroundColor(.white.opacity(0.8))
                        
                        Button {
                            showMap = true
                        } label: {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("Xem bản đồ")
                            }
                            .font(.caption)
                            .padding(6)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(12)
                .background(message.type == .sosLocation ? Color.red : (message.isFromMe ? Color.blue : Color.gray.opacity(0.3)))
                .foregroundColor(.white)
                .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    // Show status with icon and label for messages from me
                    if message.isFromMe {
                        HStack(spacing: 3) {
                            Image(systemName: message.statusIcon)
                                .font(.caption2)
                            
                            Text(message.status.displayText)
                                .font(.caption2)
                        }
                        .foregroundColor(message.status == .failed ? .red : .blue.opacity(0.7))
                        .opacity(statusOpacity)
                        .animation(.easeInOut(duration: 0.4), value: message.status)
                        .onAppear {
                            withAnimation(.easeIn(duration: 0.3)) {
                                statusOpacity = 1.0
                            }
                        }
                        .onChange(of: message.status) {
                            // Fade out and fade in effect when status changes
                            withAnimation(.easeOut(duration: 0.2)) {
                                statusOpacity = 0.3
                            }
                            withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
                                statusOpacity = 1.0
                            }
                        }
                    }
                }
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
    
    @State private var cameraPosition: MapCameraPosition
    
    init(latitude: Double, longitude: Double, title: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.title = title
        
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        _cameraPosition = State(initialValue: .region(region))
    }
    
    var body: some View {
        let annotation = makeAnnotation()
        Map(position: $cameraPosition) {
            Annotation(annotation.title ?? "SOS", coordinate: annotation.coordinate) {
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
