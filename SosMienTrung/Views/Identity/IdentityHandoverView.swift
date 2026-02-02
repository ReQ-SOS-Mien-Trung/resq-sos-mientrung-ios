//
//  IdentityHandoverView.swift
//  SosMienTrung
//
//  UI for the offline P2P account handover process.
//  Supports both normal mode and emergency QR mode.
//

import SwiftUI
import MultipeerConnectivity
import CoreImage.CIFilterBuiltins

// MARK: - Main Handover View
struct IdentityHandoverView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appearanceManager = AppearanceManager.shared
    @StateObject private var handoverManager = IdentityHandoverManager.shared
    @StateObject private var keyManager = IdentityKeyManager.shared
    @StateObject private var identityStore = IdentityStore.shared
    
    @State private var selectedRole: HandoverRole = .none
    @State private var showQRScanner = false
    @State private var showQRCode = false
    @State private var qrCodeString: String = ""
    @State private var pendingRequestPeer: MCPeerID?
    
    var body: some View {
        NavigationStack {
            ZStack {
                TelegramBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Status header
                        statusHeader
                        
                        // Content based on state
                        contentView
                    }
                    .padding()
                }
            }
            .navigationTitle("Chuyển tài khoản")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        handoverManager.stopHandover()
                        dismiss()
                    }
                }
            }
        }

        .sheet(isPresented: $showQRScanner) {
            QRScannerView { scannedCode in
                processQRCode(scannedCode)
            }
        }
        .sheet(isPresented: $showQRCode) {
            EmergencyQRView(qrString: qrCodeString)
        }
        .onReceive(handoverManager.$state) { state in
            handleStateChange(state)
        }
        .onAppear {
            setupCallbacks()
        }
    }
    
    // MARK: - Status Header
    private var statusHeader: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 36))
                    .foregroundColor(statusColor)
            }
            
            // Status text
            Text(handoverManager.statusMessage.isEmpty ? "Chọn phương thức" : handoverManager.statusMessage)
                .font(.headline)
                .foregroundColor(appearanceManager.textColor)
                .multilineTextAlignment(.center)
            
            // Progress bar (if active)
            if handoverManager.progress > 0 {
                ProgressView(value: handoverManager.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(maxWidth: 200)
            }
            
            // Battery warning
            if handoverManager.isLowBattery && handoverManager.role == .oldDevice {
                HStack {
                    Image(systemName: "battery.25")
                        .foregroundColor(.red)
                    Text("Pin yếu - Nên dùng QR Code")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        switch handoverManager.state {
        case .idle:
            roleSelectionView
            
        case .advertising:
            advertisingView
            
        case .browsing:
            browsingView
            
        case .connecting:
            connectingView
            
        case .waitingForConfirmation:
            waitingConfirmationView
            
        case .requestingTakeover:
            requestingView
            
        case .creatingToken, .transferringToken, .receivingToken, .verifyingToken, .activatingIdentity, .revokingIdentity:
            processingView
            
        case .completed:
            completedView
            
        case .failed(let error):
            failedView(error: error)
        }
    }
    
    // MARK: - Role Selection View
    private var roleSelectionView: some View {
        VStack(spacing: 20) {
            // Transfer identity section (for old device)
            if keyManager.identityStatus == .active {
                sectionCard(title: "Chuyển tài khoản đi", icon: "arrow.right.circle.fill", color: .orange) {
                    VStack(spacing: 16) {
                        Text("Chuyển tài khoản từ thiết bị này sang thiết bị mới")
                            .font(.subheadline)
                            .foregroundColor(appearanceManager.secondaryTextColor)
                            .multilineTextAlignment(.center)
                        
                        Button {
                            handoverManager.startAsOldDevice()
                        } label: {
                            HStack {
                                Image(systemName: "wifi")
                                Text("Bắt đầu chuyển (P2P)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button {
                            generateEmergencyQR()
                        } label: {
                            HStack {
                                Image(systemName: "qrcode")
                                Text("Tạo mã QR khẩn cấp")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Receive identity section (for new device)
            sectionCard(title: "Nhận tài khoản", icon: "arrow.down.circle.fill", color: .blue) {
                VStack(spacing: 16) {
                    Text("Nhận tài khoản từ thiết bị cũ vào thiết bị này")
                        .font(.subheadline)
                        .foregroundColor(appearanceManager.secondaryTextColor)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        handoverManager.startAsNewDevice()
                    } label: {
                        HStack {
                            Image(systemName: "wifi")
                            Text("Tìm thiết bị cũ (P2P)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button {
                        showQRScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Quét mã QR")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            
            // Identity status
            if keyManager.identityStatus == .transferred {
                identityTransferredBanner
            }
        }
    }
    
    // MARK: - Advertising View (Old Device)
    private var advertisingView: some View {
        VStack(spacing: 20) {
            // Animation
            PulsingCircle()
                .frame(height: 120)
            
            Text("Đang chờ thiết bị mới kết nối...")
                .font(.headline)
                .foregroundColor(appearanceManager.textColor)
            
            Text("Hãy mở ứng dụng trên thiết bị mới và chọn 'Nhận tài khoản'")
                .font(.subheadline)
                .foregroundColor(appearanceManager.secondaryTextColor)
                .multilineTextAlignment(.center)
            
            Button {
                handoverManager.stopHandover()
            } label: {
                Text("Hủy")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(appearanceManager.textColor)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    // MARK: - Browsing View (New Device)
    private var browsingView: some View {
        VStack(spacing: 20) {
            if handoverManager.discoveredPeers.isEmpty {
                // Searching animation
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Đang tìm thiết bị cũ...")
                        .font(.headline)
                        .foregroundColor(appearanceManager.textColor)
                    
                    Text("Đảm bảo thiết bị cũ đang trong chế độ 'Chuyển tài khoản'")
                        .font(.subheadline)
                        .foregroundColor(appearanceManager.secondaryTextColor)
                        .multilineTextAlignment(.center)
                }
            } else {
                // Device list
                Text("Thiết bị tìm thấy")
                    .font(.headline)
                    .foregroundColor(appearanceManager.textColor)
                
                ForEach(handoverManager.discoveredPeers, id: \.displayName) { peer in
                    Button {
                        handoverManager.connectToPeer(peer)
                    } label: {
                        HStack {
                            Image(systemName: "iphone")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(peer.displayName)
                                    .font(.headline)
                                    .foregroundColor(appearanceManager.textColor)
                                
                                Text("Nhấn để kết nối")
                                    .font(.caption)
                                    .foregroundColor(appearanceManager.secondaryTextColor)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(appearanceManager.secondaryTextColor)
                        }
                        .padding()
                        .background(appearanceManager.textColor.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            
            Button {
                handoverManager.stopHandover()
            } label: {
                Text("Hủy")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .foregroundColor(appearanceManager.textColor)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    // MARK: - Connecting View
    private var connectingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Đang kết nối...")
                .font(.headline)
                .foregroundColor(appearanceManager.textColor)
        }
        .padding()
    }
    
    // MARK: - Waiting Confirmation View
    private var waitingConfirmationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.clock")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            if let request = handoverManager.pendingRequest {
                Text("Yêu cầu từ: \(request.newDeviceName)")
                    .font(.headline)
                    .foregroundColor(appearanceManager.textColor)
            }
            
            Text("Xác nhận chuyển tài khoản?")
                .font(.subheadline)
                .foregroundColor(appearanceManager.secondaryTextColor)
            
            HStack(spacing: 16) {
                Button {
                    handoverManager.rejectTakeoverRequest()
                } label: {
                    Text("Từ chối")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(appearanceManager.textColor)
                        .cornerRadius(12)
                }
                
                Button {
                    handoverManager.approveTakeoverRequest()
                } label: {
                    Text("Đồng ý")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Requesting View
    private var requestingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Đang chờ xác nhận từ thiết bị cũ...")
                .font(.headline)
                .foregroundColor(appearanceManager.textColor)
            
            Text("Vui lòng xác nhận trên thiết bị cũ")
                .font(.subheadline)
                .foregroundColor(appearanceManager.secondaryTextColor)
        }
        .padding()
    }
    
    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: handoverManager.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(maxWidth: 250)
            
            Text(handoverManager.statusMessage)
                .font(.headline)
                .foregroundColor(appearanceManager.textColor)
            
            Text("Vui lòng không tắt ứng dụng")
                .font(.caption)
                .foregroundColor(appearanceManager.secondaryTextColor)
        }
        .padding()
    }
    
    // MARK: - Completed View
    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Thành công!")
                .font(.title2.bold())
                .foregroundColor(appearanceManager.textColor)
            
            if handoverManager.role == .oldDevice {
                VStack(spacing: 12) {
                    Text("Tài khoản đã được chuyển sang thiết bị mới.")
                        .font(.subheadline)
                        .foregroundColor(appearanceManager.secondaryTextColor)
                        .multilineTextAlignment(.center)
                    
                    Text("Thiết bị này sẽ quay về màn hình đăng ký để bạn có thể tạo tài khoản mới.")
                        .font(.caption)
                        .foregroundColor(appearanceManager.tertiaryTextColor)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("Tài khoản đã được kích hoạt trên thiết bị này.")
                    .font(.subheadline)
                    .foregroundColor(appearanceManager.secondaryTextColor)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                handoverManager.stopHandover()
                dismiss()
                // For old device, the app will automatically show SetupProfileView
                // because UserProfile.shared.currentUser is now nil
            } label: {
                Text(handoverManager.role == .oldDevice ? "Đăng ký tài khoản mới" : "Hoàn tất")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(handoverManager.role == .oldDevice ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    // MARK: - Failed View
    private func failedView(error: HandoverError) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Không thành công")
                .font(.title2.bold())
                .foregroundColor(appearanceManager.textColor)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(appearanceManager.secondaryTextColor)
                .multilineTextAlignment(.center)
            
            Button {
                handoverManager.stopHandover()
            } label: {
                Text("Thử lại")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    // MARK: - Identity Transferred Banner
    private var identityTransferredBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading) {
                Text("Tài khoản đã được chuyển")
                    .font(.headline)
                    .foregroundColor(appearanceManager.textColor)
                
                Text("Tài khoản trên thiết bị này đã được chuyển sang thiết bị khác")
                    .font(.caption)
                    .foregroundColor(appearanceManager.secondaryTextColor)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Section Card
    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(appearanceManager.textColor)
            }
            
            content()
        }
        .padding()
        .background(appearanceManager.textColor.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Computed Properties
    private var statusColor: Color {
        switch handoverManager.state {
        case .idle: return .gray
        case .completed: return .green
        case .failed: return .red
        default: return .blue
        }
    }
    
    private var statusIcon: String {
        switch handoverManager.state {
        case .idle: return "arrow.left.arrow.right"
        case .advertising, .browsing: return "wifi"
        case .connecting: return "link"
        case .waitingForConfirmation: return "person.badge.clock"
        case .requestingTakeover: return "paperplane"
        case .creatingToken, .transferringToken: return "key.fill"
        case .receivingToken, .verifyingToken: return "checkmark.shield"
        case .activatingIdentity, .revokingIdentity: return "person.badge.key"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }
    
    // MARK: - Actions
    private func setupCallbacks() {
        handoverManager.onRequestReceived = { request, peer in
            // Request received - UI will update via state change to .waitingForConfirmation
            pendingRequestPeer = peer
        }
        
        handoverManager.onHandoverComplete = { identity in
            // Handled by state change
        }
        
        handoverManager.onHandoverFailed = { error in
            // Handled by state change
        }
    }
    
    private func handleStateChange(_ state: HandoverState) {
        // State changes are handled by SwiftUI's reactive updates
    }
    
    private func generateEmergencyQR() {
        do {
            qrCodeString = try handoverManager.generateEmergencyQR()
            showQRCode = true
        } catch {
            // Show error
            print("Failed to generate QR: \(error)")
        }
    }
    
    private func processQRCode(_ code: String) {
        do {
            try handoverManager.processEmergencyQR(code)
        } catch {
            // Show error
            print("Failed to process QR: \(error)")
        }
    }
}

// MARK: - Pulsing Circle Animation
struct PulsingCircle: View {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.8
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .scaleEffect(scale)
                .opacity(opacity)
            
            Circle()
                .fill(Color.blue.opacity(0.5))
                .frame(width: 60, height: 60)
            
            Image(systemName: "wifi")
                .font(.title)
                .foregroundColor(.white)
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scale = 1.5
                opacity = 0.2
            }
        }
    }
}

// MARK: - Emergency QR View
struct EmergencyQRView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appearanceManager = AppearanceManager.shared
    let qrString: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Mã QR khẩn cấp")
                    .font(.title2.bold())
                    .foregroundColor(appearanceManager.textColor)
                
                // QR Code
                if let qrImage = generateQRCode(from: qrString) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Quan trọng")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Mã này chỉ có hiệu lực trong 5 phút.\nSau khi quét, tài khoản sẽ được chuyển và thiết bị này sẽ bị khóa.")
                        .font(.subheadline)
                        .foregroundColor(appearanceManager.secondaryTextColor)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Text("Đóng")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(appearanceManager.textColor)
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(TelegramBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - QR Scanner View
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void
    
    @State private var scannedCode: String = ""
    @State private var isScanning = true
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Camera view would go here - using placeholder for now
                Color.black.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // Scanner frame
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 250, height: 250)
                    
                    Spacer()
                    
                    Text("Đưa mã QR vào khung hình")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                    
                    // Manual input option
                    VStack(spacing: 12) {
                        Text("Hoặc nhập mã thủ công:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        HStack {
                            TextField("Mã chuyển tài khoản", text: $scannedCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($isCodeFieldFocused)
                            
                            Button("Xác nhận") {
                                if !scannedCode.isEmpty {
                                    onScan(scannedCode)
                                    dismiss()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Quét mã QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onTapGesture {
                isCodeFieldFocused = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    IdentityHandoverView()
}
