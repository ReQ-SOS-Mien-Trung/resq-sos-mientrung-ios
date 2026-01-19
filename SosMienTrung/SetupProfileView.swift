//
//  SetupProfileView.swift
//  SosMienTrung
//
//  Màn hình setup profile lần đầu
//

import SwiftUI
import MultipeerConnectivity

struct SetupProfileView: View {
    @ObservedObject var userProfile = UserProfile.shared
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showIdentityHandover = false
    @Binding var isSetupComplete: Bool
    
    var body: some View {
        ZStack {
            // Background pattern
            TelegramBackground()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Main container with glass morphism background
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Thiết Lập Thông Tin")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Để người khác có thể nhận diện bạn trong mạng")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Form
                    VStack(spacing: 20) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tên của bạn")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.9))
                            
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 20)
                                
                                TextField("Nhập tên...", text: $name)
                                    .textContentType(.name)
                                    .autocapitalization(.words)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                        }
                        
                        // Phone field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Số điện thoại")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.9))
                            
                            HStack {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.green)
                                    .frame(width: 20)
                                
                                TextField("Nhập số điện thoại...", text: $phoneNumber)
                                    .textContentType(.telephoneNumber)
                                    .keyboardType(.phonePad)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black.opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                )
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 12) {
                    // Save button - Tạo tài khoản mới
                    Button {
                        saveProfile()
                    } label: {
                        Text("Tạo Tài Khoản Mới")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                isFormValid ? Color.blue : Color.gray
                            )
                            .cornerRadius(12)
                    }
                    .disabled(!isFormValid)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("hoặc")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 8)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                    }
                    
                    // Import from old device button
                    Button {
                        showIdentityHandover = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Nhập từ thiết bị cũ")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                    
                    // Help text
                    Text("Nếu bạn đã có tài khoản trên thiết bị khác, hãy chuyển tài khoản qua P2P hoặc quét mã QR")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .alert("Lỗi", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showIdentityHandover) {
            SetupIdentityHandoverView(isSetupComplete: $isSetupComplete)
        }
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        phoneNumber.count >= 9
    }
    
    private func saveProfile() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Vui lòng nhập tên"
            showError = true
            return
        }
        
        guard trimmedPhone.count >= 9 else {
            errorMessage = "Số điện thoại không hợp lệ"
            showError = true
            return
        }
        
        userProfile.saveUser(name: trimmedName, phoneNumber: trimmedPhone)
        isSetupComplete = true
    }
}

// MARK: - Setup Identity Handover View
/// Phiên bản đơn giản của IdentityHandoverView dùng cho màn hình setup lần đầu
struct SetupIdentityHandoverView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var handoverManager = IdentityHandoverManager.shared
    @StateObject private var keyManager = IdentityKeyManager.shared
    @Binding var isSetupComplete: Bool
    
    @State private var showQRScanner = false
    @State private var scannedCode = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                TelegramBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.orange)
                            
                            Text("Nhập Tài Khoản")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("Chuyển tài khoản từ thiết bị cũ sang thiết bị này")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Content based on state
                        contentView
                    }
                    .padding()
                }
            }
            .navigationTitle("Nhập tài khoản")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") {
                        handoverManager.stopHandover()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { code in
                processQRCode(code)
            }
        }
        .onReceive(handoverManager.$state) { state in
            if case .completed = state {
                // Chuyển tài khoản thành công
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isSetupComplete = true
                    dismiss()
                }
            }
        }
        .onAppear {
            setupHandoverCallback()
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch handoverManager.state {
        case .idle:
            optionsView
            
        case .browsing:
            browsingView
            
        case .connecting:
            connectingView
            
        case .requestingTakeover:
            requestingView
            
        case .receivingToken, .verifyingToken, .activatingIdentity:
            processingView
            
        case .completed:
            completedView
            
        case .failed(let error):
            failedView(error: error)
            
        default:
            optionsView
        }
    }
    
    // MARK: - Options View
    private var optionsView: some View {
        VStack(spacing: 16) {
            // P2P Option
            optionCard(
                icon: "wifi",
                iconColor: .blue,
                title: "Kết nối P2P",
                description: "Tìm và kết nối trực tiếp với thiết bị cũ qua WiFi/Bluetooth"
            ) {
                handoverManager.startAsNewDevice()
            }
            
            // QR Option
            optionCard(
                icon: "qrcode.viewfinder",
                iconColor: .green,
                title: "Quét mã QR",
                description: "Quét mã QR từ thiết bị cũ (dùng khi thiết bị cũ sắp hết pin)"
            ) {
                showQRScanner = true
            }
            
            // Instructions
            instructionsCard
        }
    }
    
    // MARK: - Browsing View
    private var browsingView: some View {
        VStack(spacing: 20) {
            if handoverManager.discoveredPeers.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text("Đang tìm thiết bị cũ...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Đảm bảo thiết bị cũ đang ở chế độ 'Chuyển tài khoản'")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            } else {
                Text("Chọn thiết bị")
                    .font(.headline)
                    .foregroundColor(.white)
                
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
                                    .foregroundColor(.white)
                                
                                Text("Nhấn để kết nối")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            
            cancelButton
        }
    }
    
    // MARK: - Connecting View
    private var connectingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Đang kết nối...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Requesting View
    private var requestingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.clock")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Đang chờ xác nhận")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Vui lòng xác nhận yêu cầu trên thiết bị cũ")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            cancelButton
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: handoverManager.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(maxWidth: 200)
            
            Text(handoverManager.statusMessage)
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Vui lòng không tắt ứng dụng")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Completed View
    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Thành công!")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text("Tài khoản đã được nhập thành công")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Failed View
    private func failedView(error: HandoverError) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Không thành công")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button {
                handoverManager.stopHandover()
            } label: {
                Text("Thử lại")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Helper Views
    private func optionCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
        }
    }
    
    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Hướng dẫn")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: "1", text: "Trên thiết bị cũ, vào Cài đặt → Chuyển tài khoản")
                instructionRow(number: "2", text: "Chọn 'Bắt đầu chuyển' hoặc 'Tạo mã QR'")
                instructionRow(number: "3", text: "Trên thiết bị này, kết nối P2P hoặc quét mã QR")
                instructionRow(number: "4", text: "Xác nhận trên thiết bị cũ để hoàn tất")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
    
    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(.blue)
                .frame(width: 20, height: 20)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(10)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var cancelButton: some View {
        Button {
            handoverManager.stopHandover()
        } label: {
            Text("Huỷ")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(12)
        }
    }
    
    // MARK: - Actions
    private func setupHandoverCallback() {
        handoverManager.onHandoverComplete = { identity in
            // Identity đã được activate trong IdentityHandoverManager
            // UserProfile cũng đã được cập nhật
        }
    }
    
    private func processQRCode(_ code: String) {
        do {
            try handoverManager.processEmergencyQR(code)
        } catch {
            print("Failed to process QR: \(error)")
        }
    }
}
