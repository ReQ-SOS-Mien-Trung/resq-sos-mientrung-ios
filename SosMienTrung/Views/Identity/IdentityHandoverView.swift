//
//  IdentityHandoverView.swift
//  SosMienTrung
//
//  UI for the offline P2P account handover process.
//  Supports both normal mode and emergency QR mode.
//

import SwiftUI
import Combine
import MultipeerConnectivity
import CoreImage.CIFilterBuiltins
import AVFoundation

// MARK: - Main Handover View
struct IdentityHandoverView: View {
    @Environment(\.dismiss) private var dismiss
    
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
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
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
                        .font(DS.Typography.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
                
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
                            .font(DS.Typography.subheadline)
                            .foregroundColor(DS.Colors.textSecondary)
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
                            .background(DS.Colors.warning)
                            .foregroundColor(.white)
                            
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
                            .background(DS.Colors.danger)
                            .foregroundColor(.white)
                            
                        }
                    }
                }
            }
            
            // Receive identity section (for new device)
            sectionCard(title: "Nhận tài khoản", icon: "arrow.down.circle.fill", color: .blue) {
                VStack(spacing: 16) {
                    Text("Nhận tài khoản từ thiết bị cũ vào thiết bị này")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.textSecondary)
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
                        .background(DS.Colors.accent)
                        .foregroundColor(.white)
                        
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
                        .background(DS.Colors.success)
                        .foregroundColor(.white)
                        
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
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
            
            Text("Hãy mở ứng dụng trên thiết bị mới và chọn 'Nhận tài khoản'")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                handoverManager.stopHandover()
            } label: {
                Text("Hủy")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DS.Colors.surface)
                    .foregroundColor(DS.Colors.text)
                    
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
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)
                    
                    Text("Đảm bảo thiết bị cũ đang trong chế độ 'Chuyển tài khoản'")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                // Device list
                Text("Thiết bị tìm thấy")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
                
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
                                    .font(DS.Typography.headline)
                                    .foregroundColor(DS.Colors.text)
                                
                                Text("Nhấn để kết nối")
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                        .padding()
                        .background(DS.Colors.surface)
                        
                    }
                }
            }
            
            Button {
                handoverManager.stopHandover()
            } label: {
                Text("Hủy")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DS.Colors.surface)
                    .foregroundColor(DS.Colors.text)
                    
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
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
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
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
            }
            
            Text("Xác nhận chuyển tài khoản?")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
            
            HStack(spacing: 16) {
                Button {
                    handoverManager.rejectTakeoverRequest()
                } label: {
                    Text("Từ chối")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DS.Colors.surface)
                        .foregroundColor(DS.Colors.text)
                        
                }
                
                Button {
                    handoverManager.approveTakeoverRequest()
                } label: {
                    Text("Đồng ý")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DS.Colors.success)
                        .foregroundColor(.white)
                        
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
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
            
            Text("Vui lòng xác nhận trên thiết bị cũ")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
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
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
            
            Text("Vui lòng không tắt ứng dụng")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
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
                .font(DS.Typography.title)
                .foregroundColor(DS.Colors.text)
            
            if handoverManager.role == .oldDevice {
                VStack(spacing: 12) {
                    Text("Tài khoản đã được chuyển sang thiết bị mới.")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Thiết bị này sẽ quay về màn hình đăng ký để bạn có thể tạo tài khoản mới.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("Tài khoản đã được kích hoạt trên thiết bị này.")
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
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
                .font(DS.Typography.title)
                .foregroundColor(DS.Colors.text)
            
            Text(error.localizedDescription)
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button {
                handoverManager.stopHandover()
            } label: {
                Text("Thử lại")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DS.Colors.accent)
                    .foregroundColor(.white)
                    
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
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
                
                Text("Tài khoản trên thiết bị này đã được chuyển sang thiết bị khác")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
        .padding()
        .background(DS.Colors.warning.opacity(0.08))
        
    }
    
    // MARK: - Section Card
    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
            }
            content()
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
        .padding(.horizontal, DS.Spacing.md)
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
    
    let qrString: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Mã QR khẩn cấp")
                    .font(DS.Typography.title)
                    .foregroundColor(DS.Colors.text)
                
                // QR Code
                if let qrImage = generateQRCode(from: qrString) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                        .background(Color.white)
                        
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Quan trọng")
                            .font(DS.Typography.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Text("Mã này chỉ có hiệu lực trong 5 phút.\nSau khi quét, tài khoản sẽ được chuyển và thiết bị này sẽ bị khóa.")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(DS.Colors.warning.opacity(0.08))
                
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Text("Đóng")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DS.Colors.surface)
                        .foregroundColor(DS.Colors.text)
                        
                }
            }
            .padding()
            .background(DS.Colors.background)
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

// MARK: - QR Camera Preview (AVFoundation)
private struct QRCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds // corrected to actual size in updateUIView
        view.layer.addSublayer(preview)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let preview = uiView.layer.sublayers?.compactMap({ $0 as? AVCaptureVideoPreviewLayer }).first {
            preview.frame = uiView.bounds
        }
    }
}

// MARK: - QR Scanner View
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void

    @State private var scannedCode: String = ""
    @State private var cameraPermissionDenied = false
    @State private var didScan = false
    @FocusState private var isCodeFieldFocused: Bool

    @StateObject private var scanner = QRScannerCoordinator()

    var body: some View {
        NavigationStack {
            ZStack {
                // Live camera feed
                QRCameraPreview(session: scanner.session)
                    .ignoresSafeArea()

                // Dark gradient at bottom for legibility
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 280)
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Viewfinder frame
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.9), lineWidth: 3)
                            .frame(width: 250, height: 250)

                        // Corner brackets
                        ViewfinderBrackets()
                            .frame(width: 250, height: 250)
                    }

                    Spacer()

                    Text("Đưa mã QR vào khung hình")
                        .font(DS.Typography.headline)
                        .foregroundColor(.white)
                        .padding(.bottom, 20)

                    // Manual input fallback
                    VStack(spacing: 10) {
                        Text("Hoặc nhập mã thủ công:")
                            .font(DS.Typography.caption)
                            .foregroundColor(.white.opacity(0.7))

                        HStack {
                            TextField("Mã chuyển tài khoản", text: $scannedCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($isCodeFieldFocused)

                            Button("Xác nhận") {
                                guard !scannedCode.isEmpty, !didScan else { return }
                                didScan = true
                                scanner.stop()
                                onScan(scannedCode)
                                dismiss()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(DS.Colors.accent)
                            .foregroundColor(.white)
                            
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                }

                // Camera permission denied overlay
                if cameraPermissionDenied {
                    ZStack {
                        Color.black.opacity(0.85).ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white)
                            Text("Cần quyền truy cập camera")
                                .font(DS.Typography.headline)
                                .foregroundColor(.white)
                            Text("Vào Cài đặt > SosMienTrung > Camera để cấp quyền.")
                                .font(DS.Typography.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button("Mở Cài đặt") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(DS.Colors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .navigationTitle("Quét mã QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        scanner.stop()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .onTapGesture { isCodeFieldFocused = false }
            .onAppear {
                scanner.onScan = { code in
                    guard !didScan else { return }
                    didScan = true
                    scanner.stop()
                    onScan(code)
                    dismiss()
                }
                scanner.requestPermissionAndStart { denied in
                    cameraPermissionDenied = denied
                }
            }
            .onDisappear {
                scanner.stop()
            }
        }
    }
}

// MARK: - Viewfinder Corner Brackets
private struct ViewfinderBrackets: View {
    private let length: CGFloat = 24
    private let thickness: CGFloat = 4
    private let color: Color = .green

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Top-left
                Path { p in
                    p.move(to: CGPoint(x: 0, y: length))
                    p.addLine(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: length, y: 0))
                }.stroke(color, lineWidth: thickness)

                // Top-right
                Path { p in
                    p.move(to: CGPoint(x: w - length, y: 0))
                    p.addLine(to: CGPoint(x: w, y: 0))
                    p.addLine(to: CGPoint(x: w, y: length))
                }.stroke(color, lineWidth: thickness)

                // Bottom-left
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h - length))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.addLine(to: CGPoint(x: length, y: h))
                }.stroke(color, lineWidth: thickness)

                // Bottom-right
                Path { p in
                    p.move(to: CGPoint(x: w - length, y: h))
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: w, y: h - length))
                }.stroke(color, lineWidth: thickness)
            }
        }
    }
}

// MARK: - QR Scanner Coordinator (AVCaptureSession + Metadata output)
final class QRScannerCoordinator: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    // Manual conformance stub required because NSObject subclasses don't get
    // automatic ObservableObject synthesis.	f
    let objectWillChange = ObservableObjectPublisher()

    let session = AVCaptureSession()
    var onScan: ((String) -> Void)?

    private let metadataQueue = DispatchQueue(label: "qr.metadata.queue")

    func requestPermissionAndStart(onDenied: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupAndStart(onDenied: onDenied)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupAndStart(onDenied: onDenied) }
                    else { onDenied(true) }
                }
            }
        default:
            DispatchQueue.main.async { onDenied(true) }
        }
    }

    private func setupAndStart(onDenied: @escaping (Bool) -> Void) {
        guard !session.isRunning else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            DispatchQueue.main.async { onDenied(true) }
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: metadataQueue)
        output.metadataObjectTypes = [.qr]

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    // AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let code = object.stringValue,
            !code.isEmpty
        else { return }

        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            self.onScan?(code)
        }
    }
}

// MARK: - Preview
#Preview {
    IdentityHandoverView()
}
