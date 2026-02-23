//
//  SOSWizardView.swift
//  SosMienTrung
//
//  Main Wizard container cho SOS Form
//

import SwiftUI
import CoreLocation

struct SOSWizardView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var formData = SOSFormData()
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var sentToServer = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                TelegramBackground()
                Color.black.opacity(0.35).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    SOSProgressBar(currentStep: formData.currentStep)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Step content
                    TabView(selection: $formData.currentStep) {
                        Step0AutoInfoView(formData: formData, bridgefyManager: bridgefyManager, networkMonitor: networkMonitor)
                            .tag(SOSWizardStep.autoInfo)
                        
                        Step1SelectTypeView(formData: formData)
                            .tag(SOSWizardStep.selectType)
                        
                        Step2AReliefView(formData: formData)
                            .tag(SOSWizardStep.relief)
                        
                        Step2BRescueView(formData: formData)
                            .tag(SOSWizardStep.rescue)
                        
                        Step3AdditionalInfoView(formData: formData)
                            .tag(SOSWizardStep.additionalInfo)
                        
                        Step4ReviewView(formData: formData)
                            .tag(SOSWizardStep.review)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: formData.currentStep)
                    
                // Bottom navigation
                    bottomNavigation
                }
            }
            .navigationTitle("Gửi SOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert(sentToServer ? "✅ Đã gửi lên Server" : "📡 Đã gửi qua Mesh Network", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
            .onAppear {
                // Enable battery monitoring sớm để có thời gian cập nhật
                UIDevice.current.isBatteryMonitoringEnabled = true
                setupAutoInfo()
            }
        }
    }
    
    // MARK: - Bottom Navigation
    
    private var bottomNavigation: some View {
        HStack(spacing: 16) {
            // Back button
            if formData.currentStep != .autoInfo {
                Button {
                    formData.goToPreviousStep()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Quay lại")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                }
            }
            
            Spacer()
            
            // Next/Send button
            if formData.currentStep == .review {
                Button {
                    sendSOS()
                } label: {
                    HStack {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("GỬI SOS")
                                .fontWeight(.bold)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .cornerRadius(12)
                }
                .disabled(isSending)
            } else {
                Button {
                    formData.goToNextStep()
                } label: {
                    HStack {
                        Text("Tiếp tục")
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(formData.canProceedToNextStep ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!formData.canProceedToNextStep)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }
    
    // MARK: - Helpers
    
    private var successMessage: String {
        if sentToServer {
            return "✅ Tin hiệu SOS đã được gửi trực tiếp lên server thành công."
        } else {
            return "📡 Không có kết nối mạng. SOS đã được broadcast qua Mesh Network – khi có thiết bị liên mạng nhận được sẽ relay lên server giúp bạn."
        }
    }
    
    private func setupAutoInfo() {
        let baseInfo = AutoCollectedInfo(
            deviceId: bridgefyManager.currentUserId?.uuidString ?? UUID().uuidString,
            userId: UserProfile.shared.currentUser?.id.uuidString,
            userName: UserProfile.shared.currentUser?.name,
            userPhone: UserProfile.shared.currentUser?.phoneNumber,
            timestamp: Date(),
            latitude: nil,
            longitude: nil,
            accuracy: nil,
            isOnline: networkMonitor.isConnected,
            batteryLevel: getBatteryLevel()
        )
        formData.autoInfo = baseInfo

        bridgefyManager.locationManager.requestLocation { location in
            DispatchQueue.main.async {
                let accuracy = location?.horizontalAccuracy
                self.formData.autoInfo = AutoCollectedInfo(
                    deviceId: baseInfo.deviceId,
                    userId: baseInfo.userId,
                    userName: baseInfo.userName,
                    userPhone: baseInfo.userPhone,
                    timestamp: Date(),
                    latitude: location?.coordinate.latitude,
                    longitude: location?.coordinate.longitude,
                    accuracy: accuracy,
                    isOnline: self.networkMonitor.isConnected,
                    batteryLevel: self.getBatteryLevel()
                )
            }
        }
    }
    
    private func getBatteryLevel() -> Int? {
        // Battery monitoring đã được enable trong onAppear
        let level = UIDevice.current.batteryLevel
        
        // -1.0 nghĩa là không xác định được (simulator hoặc chưa enable monitoring)
        guard level >= 0 else { 
            print("⚠️ Battery level unavailable: \(level)")
            return nil 
        }
        
        let percentage = Int(level * 100)
        print("🔋 Battery level: \(percentage)%")
        return percentage
    }
    
    private func sendSOS() {
        guard formData.canSendMinimalSOS else { return }
        isSending = true
        
        print("📡 [sendSOS] isConnected=\(networkMonitor.isConnected), bridgefyRunning=\(bridgefyManager.currentUserId != nil)")
        print("🔑 [sendSOS] authSession=\(AuthSessionStore.shared.session != nil ? "exists (valid=\(AuthSessionStore.shared.isValid))" : "NIL – will get 401!")")
        
        Task {
            var serverReached = false
            if formData.sosType != nil {
                serverReached = await bridgefyManager.sendStructuredSOS(formData)
            } else {
                let message = formData.toSOSMessage()
                await bridgefyManager.sendSOSWithUpload(message)
                serverReached = networkMonitor.isConnected
            }
            
            await MainActor.run {
                isSending = false
                sentToServer = serverReached
                showSuccess = true
            }
        }
    }
}

// MARK: - Progress Bar

struct SOSProgressBar: View {
    let currentStep: SOSWizardStep
    
    private let totalSteps = 5
    
    var body: some View {
        VStack(spacing: 8) {
            // Step indicator
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep.stepNumber ? Color.red : Color.white.opacity(0.3))
                        .frame(height: 4)
                }
            }
            
            // Step title
            Text("Bước \(currentStep.stepNumber + 1): \(currentStep.title)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Preview

#Preview {
    SOSWizardView(bridgefyManager: BridgefyNetworkManager.shared)
}
