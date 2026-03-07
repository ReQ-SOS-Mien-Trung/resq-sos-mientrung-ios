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
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) var dismiss
    
    @State private var formData = SOSFormData()
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var sentToServer = false
    @State private var showLocationRequiredAlert = false
    
    init(bridgefyManager: BridgefyNetworkManager) {
        self.bridgefyManager = bridgefyManager
        self.locationManager = bridgefyManager.locationManager
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                SOSProgressBar(currentStep: formData.currentStep)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.sm)
                
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
                
                bottomNavigation
            }
            .background(DS.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("GỬI SOS")
                        .font(DS.Typography.headline).tracking(2)
                        .foregroundColor(DS.Colors.text)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Huỷ") { dismiss() }
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            .alert(sentToServer ? "✅ Đã gửi lên Server" : "📡 Đang chờ gửi lên Server", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
            .alert("⚠️ Chưa có vị trí", isPresented: $showLocationRequiredAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Hệ thống chưa lấy được vị trí GPS. Vui lòng đợi hoặc kiểm tra quyền truy cập vị trí trong Cài đặt.")
            }
            .onAppear {
                // Enable battery monitoring sớm để có thời gian cập nhật
                UIDevice.current.isBatteryMonitoringEnabled = true
                setupAutoInfo()
                // Bắt đầu cập nhật vị trí liên tục
                locationManager.startContinuousUpdates()
            }
            .onDisappear {
                // Dừng cập nhật vị trí khi đóng form
                locationManager.stopContinuousUpdates()
            }
            .onChange(of: locationManager.currentLocation) { _, newLocation in
                // Tự động cập nhật autoInfo khi vị trí thay đổi
                updateAutoInfoWithLocation(newLocation)
            }
            .onChange(of: networkMonitor.isConnected) { _, _ in
                // Cập nhật khi trạng thái mạng thay đổi
                updateAutoInfoWithLocation(locationManager.currentLocation)
            }
        }
    }
    
    // MARK: - Bottom Navigation
    
    private var bottomNavigation: some View {
        HStack(spacing: DS.Spacing.md) {
            if formData.currentStep != .autoInfo {
                Button { formData.goToPreviousStep() } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Quay lại")
                    }
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.surface)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                }
            }
            Spacer()
            if formData.currentStep == .review {
                Button { sendSOS() } label: {
                    HStack {
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("GỬI SOS").font(DS.Typography.headline).tracking(2)
                        }
                    }
                    .foregroundColor(DS.Colors.text)
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.danger)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
                    .shadow(color: .black.opacity(0.25), radius: 0, x: 3, y: 3)
                }
                .disabled(isSending || !locationManager.hasValidLocation)
                .opacity(locationManager.hasValidLocation ? 1.0 : 0.5)
            } else {
                Button { formData.goToNextStep() } label: {
                    HStack {
                        Text("Tiếp tục")
                        Image(systemName: "chevron.right")
                    }
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(formData.canProceedToNextStep ? DS.Colors.accent : DS.Colors.textTertiary)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
                }
                .disabled(!formData.canProceedToNextStep)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface)
        .overlay(Rectangle().frame(height: DS.Border.thin).foregroundColor(DS.Colors.border), alignment: .top)
    }
    
    // MARK: - Helpers
    
    private var successMessage: String {
        if sentToServer {
            return "✅ Tín hiệu SOS đã được gửi trực tiếp lên server thành công."
        } else {
            return "📡 Chưa có kết nối mạng. SOS đang ở trạng thái \"Đang gửi\" – hệ thống sẽ tự gửi lên server khi có mạng, hoặc nhờ thiết bị lân cận relay qua Mesh Network."
        }
    }
    
    private func setupAutoInfo() {
        let location = locationManager.currentLocation
        formData.autoInfo = AutoCollectedInfo(
            deviceId: bridgefyManager.currentUserId?.uuidString
                ?? UIDevice.current.identifierForVendor?.uuidString
                ?? UUID().uuidString,
            userId: AuthSessionStore.shared.session?.userId,
            userName: UserProfile.shared.currentUser?.name,
            userPhone: UserProfile.shared.currentUser?.phoneNumber,
            timestamp: Date(),
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            accuracy: location?.horizontalAccuracy,
            isOnline: networkMonitor.isConnected,
            batteryLevel: getBatteryLevel()
        )
    }
    
    /// Cập nhật autoInfo mỗi khi vị trí hoặc mạng thay đổi
    private func updateAutoInfoWithLocation(_ location: CLLocation?) {
        guard let info = formData.autoInfo else {
            setupAutoInfo()
            return
        }
        formData.autoInfo = AutoCollectedInfo(
            deviceId: info.deviceId,
            userId: info.userId,
            userName: info.userName,
            userPhone: info.userPhone,
            timestamp: Date(),
            latitude: location?.coordinate.latitude ?? info.latitude,
            longitude: location?.coordinate.longitude ?? info.longitude,
            accuracy: location?.horizontalAccuracy ?? info.accuracy,
            isOnline: networkMonitor.isConnected,
            batteryLevel: getBatteryLevel()
        )
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
        // Bắt buộc phải có vị trí
        guard formData.autoInfo?.latitude != nil, formData.autoInfo?.longitude != nil else {
            showLocationRequiredAlert = true
            return
        }
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
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: 3) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Rectangle()
                        .fill(index <= currentStep.stepNumber ? DS.Colors.danger : DS.Colors.border)
                        .frame(height: 3)
                }
            }
            Text("Bước \(currentStep.stepNumber + 1): \(currentStep.title)")
                .font(DS.Typography.caption).tracking(1)
                .foregroundColor(DS.Colors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    SOSWizardView(bridgefyManager: BridgefyNetworkManager.shared)
}
