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
    
    @StateObject private var formData = SOSFormData()
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var sentToServer = false
    @State private var showLocationRequiredAlert = false
    @State private var showBackendErrorAlert = false
    @State private var backendErrorMessage = ""
    @State private var showTermsSheet = false
    @State private var showRelativeProfilePicker = false
    @State private var medicalFormTarget: MedicalFormPresentationTarget?
    
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
                        Step0ReportingModeView(formData: formData)
                            .tag(SOSWizardStep.reportingMode)

                        Step0AutoInfoView(formData: formData, bridgefyManager: bridgefyManager, networkMonitor: networkMonitor)
                            .tag(SOSWizardStep.autoInfo)
                        
                        Step1SelectTypeView(
                            formData: formData,
                            onChangeSavedProfiles: { showRelativeProfilePicker = true },
                            onSwitchToManual: { formData.switchToManualPersonSelection() }
                        )
                            .tag(SOSWizardStep.selectType)
                        
                        Step2AReliefView(formData: formData)
                            .tag(SOSWizardStep.relief)
                        
                        Step2BRescueView(
                            formData: formData,
                            onOpenMedicalForm: presentMedicalForm
                        )
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
            .alert(sentToServer ? "Đã gửi lên Server" : "Đang chờ gửi lên Server", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
            .alert("Chưa có vị trí", isPresented: $showLocationRequiredAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Chưa có toạ độ hợp lệ. Vui lòng đợi GPS hoặc nhập địa chỉ để tra cứu vị trí.")
            }
            .alert("Gửi SOS chưa thành công", isPresented: $showBackendErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backendErrorMessage)
            }
            .onAppear {
                // Enable battery monitoring sớm để có thời gian cập nhật
                UIDevice.current.isBatteryMonitoringEnabled = true
                let relativeProfileStore = RelativeProfileStore.shared
                relativeProfileStore.refreshFromServerIfPossible(force: relativeProfileStore.profiles.isEmpty)
                setupAutoInfo()
                // Bắt đầu cập nhật vị trí liên tục
                locationManager.startContinuousUpdates()
            }
            .onDisappear {
                // Dừng cập nhật vị trí khi đóng form
                locationManager.stopContinuousUpdates()
            }
            .onChange(of: locationManager.currentLocation) { newLocation in
                // Tự động cập nhật autoInfo khi vị trí thay đổi
                updateAutoInfoWithLocation(newLocation)
            }
            .onChange(of: networkMonitor.isConnected) { _ in
                // Cập nhật khi trạng thái mạng thay đổi
                updateAutoInfoWithLocation(locationManager.currentLocation)
            }
            .medicalFormSheet(target: $medicalFormTarget, formData: formData)
        }
    }
    
    // MARK: - Bottom Navigation
    
    private var bottomNavigation: some View {
        VStack(spacing: 0) {
            // Disclaimer - visible on relief step
            if formData.currentStep == .relief {
                reliefDisclaimer
            }
            
            HStack(spacing: DS.Spacing.md) {
                if formData.currentStep != .reportingMode {
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
                        .foregroundColor(.white)
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(DS.Colors.danger)
                        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thick))
                        .shadow(color: .black.opacity(0.25), radius: 0, x: 3, y: 3)
                    }
                    .disabled(isSending || formData.effectiveLocation == nil)
                    .opacity(formData.effectiveLocation == nil ? 0.5 : 1.0)
                } else {
                    Button { formData.goToNextStep() } label: {
                        HStack {
                            Text("Tiếp tục")
                            Image(systemName: "chevron.right")
                        }
                        .font(DS.Typography.headline)
                        .foregroundColor(formData.canProceedToNextStep ? .white : DS.Colors.text)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(formData.canProceedToNextStep ? DS.Colors.accent : DS.Colors.textTertiary)
                        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.medium))
                    }
                    .disabled(!formData.canProceedToNextStep)
                }
            }
            .padding(DS.Spacing.md)
        }
        .background(DS.Colors.surface)
        .overlay(Rectangle().frame(height: DS.Border.thin).foregroundColor(DS.Colors.border), alignment: .top)
        .sheet(isPresented: $showTermsSheet) {
            SOSTermsSheet()
        }
        .sheet(isPresented: $showRelativeProfilePicker) {
            RelativeProfilePickerSheet(initialSelectedProfileIds: formData.selectedRelativeProfileIds) { profiles in
                formData.applySelectedRelativeProfiles(profiles)
            }
        }
    }

    private func presentMedicalForm(for person: Person) {
        guard medicalFormTarget?.id != person.id else { return }
        medicalFormTarget = MedicalFormPresentationTarget(person: person)
    }
    
    // MARK: - Relief Disclaimer
    
    private var reliefDisclaimer: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Thông tin bạn cung cấp sẽ được sử dụng để ưu tiên và điều phối cứu trợ. Việc cung cấp thông tin không chính xác hoặc sai sự thật có thể làm ảnh hưởng đến các nạn nhân khác đang cần hỗ trợ khẩn cấp.")
                        .font(.caption2)
                        .foregroundColor(DS.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button {
                        showTermsSheet = true
                    } label: {
                        Text("Điều khoản")
                            .font(.caption2.bold())
                            .underline()
                            .foregroundColor(DS.Colors.accent)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
    }
    
    // MARK: - Helpers
    
    private var successMessage: String {
        if sentToServer {
            return "Tín hiệu SOS đã được gửi trực tiếp lên server thành công."
        } else {
            return "Chưa có kết nối mạng. SOS đang ở trạng thái \"Đang gửi\" – hệ thống sẽ tự gửi lên server khi có mạng, hoặc nhờ thiết bị lân cận relay qua Mesh Network."
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
        guard formData.effectiveLocation != nil else {
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

                let backendMessage = bridgefyManager.lastSOSUploadErrorMessage?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if serverReached == false,
                   networkMonitor.isConnected,
                   let backendMessage,
                   backendMessage.isEmpty == false {
                    backendErrorMessage = "\(backendMessage)\nYêu cầu đã được lưu và hệ thống sẽ tự thử gửi lại."
                    showBackendErrorAlert = true
                    return
                }

                showSuccess = true
            }
        }
    }
}

// MARK: - Progress Bar

struct SOSProgressBar: View {
    let currentStep: SOSWizardStep
    
    private let totalSteps = 6
    
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

// MARK: - Terms Sheet

struct SOSTermsSheet: View {
    @Environment(\.dismiss) var dismiss

    private struct TermsSection {
        let title: String
        let body: String
    }

    private let sections: [TermsSection] = [
        TermsSection(title: "Điều 1. Phạm vi áp dụng",
                     body: "Điều khoản này áp dụng đối với mọi cá nhân tải xuống, cài đặt, đăng ký, đăng nhập, truy cập hoặc sử dụng ứng dụng RESQ.\n\nKhi tạo tài khoản, đăng nhập, gửi yêu cầu khẩn cấp, chia sẻ vị trí, sử dụng tính năng nhắn tin, trợ lý ảo, hồ sơ khẩn cấp hoặc tiếp tục sử dụng ứng dụng, người dùng được xem là đã đọc, hiểu và đồng ý với toàn bộ nội dung của Điều khoản này.\n\nNếu người dùng không đồng ý với bất kỳ nội dung nào trong Điều khoản này, người dùng phải ngừng sử dụng ứng dụng."),
        TermsSection(title: "Điều 2. Mục đích của ứng dụng",
                     body: "RESQ là ứng dụng hỗ trợ tiếp nhận, ghi nhận, chuyển thông tin và phối hợp hỗ trợ trong các tình huống khẩn cấp, thiên tai, tai nạn hoặc hoàn cảnh nguy hiểm cần cứu trợ, cứu nạn, cứu hộ.\n\nỨng dụng được tạo ra để hỗ trợ người dùng gửi thông tin nhanh hơn, rõ hơn và thuận tiện hơn. Tuy nhiên, RESQ không thay thế số điện thoại khẩn cấp, cơ quan công an, ủy ban nhân dân địa phương hoặc cơ quan nhà nước có thẩm quyền.\n\nTrong trường hợp nguy cấp, đe dọa trực tiếp đến tính mạng, sức khỏe hoặc an toàn, người dùng phải ưu tiên liên hệ cơ quan chức năng phù hợp. Việc gửi thông tin qua RESQ chỉ là một kênh hỗ trợ bổ sung."),
        TermsSection(title: "Điều 3. Quyền sử dụng ứng dụng",
                     body: "Đơn vị vận hành cho phép người dùng sử dụng ứng dụng RESQ trong phạm vi cá nhân, đúng mục đích, đúng quy định và không trái pháp luật.\n\nNgười dùng không được:\n1. Sao chép, sửa đổi, phát tán hoặc sử dụng ứng dụng vào mục đích kinh doanh trái phép;\n2. Tìm cách can thiệp, phá hoại, làm sai lệch hoặc gây ảnh hưởng xấu đến hoạt động của ứng dụng;\n3. Dùng công cụ hoặc cách thức không hợp pháp để lấy dữ liệu, làm nghẽn ứng dụng hoặc vượt qua các biện pháp bảo vệ của ứng dụng;\n4. Sử dụng ứng dụng vào mục đích lừa đảo, quấy rối, trục lợi hoặc gây hại cho người khác."),
        TermsSection(title: "Điều 4. Tài khoản người dùng",
                     body: "Người dùng phải cung cấp thông tin đúng sự thật, đầy đủ và còn hiệu lực khi đăng ký tài khoản hoặc khi được yêu cầu bổ sung thông tin.\n\nNgười dùng có trách nhiệm:\n• Giữ bí mật thông tin đăng nhập;\n• Tự bảo quản thiết bị dùng để truy cập ứng dụng;\n• Không cho người khác mượn, dùng chung, mua bán hoặc chuyển nhượng tài khoản;\n• Thông báo kịp thời cho đơn vị vận hành nếu phát hiện tài khoản bị sử dụng trái phép.\n\nĐơn vị vận hành có quyền yêu cầu người dùng xác minh lại thông tin trong trường hợp cần thiết để bảo đảm an toàn cho người dùng và cho hoạt động chung của ứng dụng."),
        TermsSection(title: "Điều 5. Các tính năng của ứng dụng",
                     body: "Tùy từng thời điểm vận hành, RESQ có thể cung cấp một hoặc nhiều tính năng như:\n• Gửi yêu cầu khẩn cấp;\n• Theo dõi lịch sử yêu cầu đã gửi;\n• Chia sẻ vị trí và tình trạng cần hỗ trợ;\n• Nhắn tin với bộ phận điều phối hoặc người hỗ trợ;\n• Sử dụng trợ lý ảo để tham khảo thông tin;\n• Lưu hồ sơ khẩn cấp của bản thân hoặc người thân;\n• Chuyển quyền sử dụng tài khoản từ thiết bị cũ sang thiết bị mới;\n• Sử dụng mã khẩn cấp để hỗ trợ đăng nhập hoặc chuyển thông tin khi cần thiết.\n\nĐơn vị vận hành có quyền bổ sung, thay đổi, tạm ngừng hoặc chấm dứt một phần tính năng của ứng dụng khi cần bảo trì, bảo đảm an toàn hoặc theo yêu cầu của pháp luật."),
        TermsSection(title: "Điều 6. Quyền truy cập thông tin cần thiết",
                     body: "Để ứng dụng hoạt động đúng mục đích, người dùng đồng ý cho RESQ sử dụng các thông tin cần thiết phù hợp với tính năng đang dùng, như:\n• Vị trí hiện tại hoặc vị trí do người dùng chọn;\n• Thời điểm gửi thông tin;\n• Tình trạng kết nối;\n• Mức pin của thiết bị;\n• Thông tin liên hệ;\n• Thông tin trong hồ sơ khẩn cấp;\n• Hình ảnh, âm thanh hoặc các thông tin khác nếu người dùng chủ động cung cấp.\n\nNgười dùng hiểu rằng một số tính năng của ứng dụng sẽ không hoạt động đầy đủ nếu người dùng không cho phép sử dụng những thông tin cần thiết nói trên."),
        TermsSection(title: "Điều 7. Gửi yêu cầu khẩn cấp",
                     body: "Người dùng chỉ được gửi yêu cầu khẩn cấp khi thực sự có nhu cầu hỗ trợ hoặc có căn cứ hợp lý để tin rằng một người hoặc một nhóm người đang cần được giúp đỡ.\n\nNgười dùng phải cung cấp thông tin trung thực, rõ ràng và trong phạm vi cần thiết, bao gồm:\n• Người đang cần hỗ trợ;\n• Vị trí xảy ra sự việc;\n• Số lượng người liên quan;\n• Tình trạng nguy hiểm, bị thương, mắc kẹt hoặc thiếu nhu yếu phẩm;\n• Thông tin liên hệ;\n• Ghi chú quan trọng khác nếu có.\n\nNgười dùng phải tự chịu trách nhiệm về nội dung mình cung cấp. Nếu người dùng cố ý báo tin giả, báo sai sự thật, báo trùng lặp có chủ ý hoặc cung cấp thông tin gây hiểu nhầm làm ảnh hưởng đến hoạt động hỗ trợ, người dùng phải chịu trách nhiệm theo quy định của ứng dụng và theo pháp luật.\n\nViệc một yêu cầu được ghi nhận trên ứng dụng không có nghĩa là yêu cầu đó chắc chắn sẽ được xử lý ngay hoặc được hỗ trợ trong một thời hạn nhất định."),
        TermsSection(title: "Điều 8. Nội dung do người dùng cung cấp",
                     body: "Mọi thông tin, hình ảnh, âm thanh, tin nhắn, hồ sơ, tài liệu hoặc dữ liệu do người dùng cung cấp qua RESQ đều thuộc trách nhiệm của người dùng.\n\nNgười dùng đồng ý cho đơn vị vận hành được lưu giữ, sắp xếp, xem xét, hiển thị, chuyển tiếp, giới hạn hoặc gỡ bỏ các nội dung đó trong phạm vi cần thiết để:\n• Vận hành ứng dụng;\n• Kiểm tra tính xác thực của thông tin;\n• Hỗ trợ việc điều phối;\n• Xử lý vi phạm;\n• Bảo đảm an toàn cho người dùng và cho ứng dụng;\n• Thực hiện yêu cầu hợp pháp của cơ quan có thẩm quyền.\n\nĐơn vị vận hành có quyền từ chối hiển thị, gỡ bỏ hoặc hạn chế bất kỳ nội dung nào nếu có căn cứ cho rằng nội dung đó sai sự thật, không phù hợp, gây hại, xâm phạm quyền riêng tư của người khác hoặc vi phạm Điều khoản này."),
        TermsSection(title: "Điều 9. Hồ sơ khẩn cấp",
                     body: "Ứng dụng có thể cho phép người dùng lưu hồ sơ khẩn cấp của bản thân hoặc của người thân để phục vụ việc hỗ trợ trong tình huống nguy cấp.\n\nNhững thông tin này có thể bao gồm:\n• Họ tên;\n• Số điện thoại;\n• Mối quan hệ;\n• Tình trạng sức khỏe;\n• Khả năng đi lại;\n• Nhu cầu đặc biệt;\n• Ghi chú quan trọng liên quan đến việc hỗ trợ.\n\nNgười dùng chỉ được lưu thông tin của người khác khi có căn cứ hợp pháp và phù hợp với mục đích hỗ trợ khẩn cấp. Người dùng không được lợi dụng tính năng này để thu thập, lưu giữ hoặc phát tán trái phép thông tin riêng tư của người khác."),
        TermsSection(title: "Điều 10. Tính năng nhắn tin và trợ lý ảo",
                     body: "Ứng dụng có thể cung cấp tính năng nhắn tin để người dùng trao đổi với bộ phận điều phối hoặc người hỗ trợ.\n\nNgười dùng không được dùng tính năng nhắn tin để:\n• Gửi nội dung quấy rối, xúc phạm, đe dọa hoặc vu khống;\n• Phát tán tin sai sự thật;\n• Gửi nội dung phản cảm, độc hại hoặc trái pháp luật;\n• Làm phiền, gây nghẽn hoặc cản trở quá trình hỗ trợ.\n\nTrợ lý ảo trong ứng dụng chỉ có tính chất tham khảo. Nội dung do trợ lý ảo đưa ra có thể chưa đầy đủ, chưa chính xác hoặc không phù hợp với mọi trường hợp cụ thể. Người dùng không được xem đó là căn cứ duy nhất để đưa ra quyết định ảnh hưởng đến tính mạng, sức khỏe, tài sản hoặc an toàn của mình và của người khác."),
        TermsSection(title: "Điều 11. Chuyển tài khoản và mã khẩn cấp",
                     body: "Ứng dụng có thể cho phép người dùng chuyển quyền sử dụng tài khoản từ thiết bị cũ sang thiết bị mới hoặc dùng mã khẩn cấp trong một số trường hợp cần thiết.\n\nNgười dùng chỉ được sử dụng tính năng này đối với tài khoản của chính mình. Người dùng không được:\n• Chiếm đoạt tài khoản của người khác;\n• Sao chép hoặc sử dụng trái phép mã khẩn cấp;\n• Dùng tính năng này để vượt qua các biện pháp bảo vệ của ứng dụng.\n\nĐơn vị vận hành có quyền áp dụng các biện pháp cần thiết để bảo đảm một tài khoản không bị sử dụng trái phép trên nhiều thiết bị theo cách gây mất an toàn."),
        TermsSection(title: "Điều 12. Hành vi bị cấm",
                     body: "Người dùng không được thực hiện các hành vi sau:\n1. Báo tin giả hoặc cung cấp thông tin sai sự thật;\n2. Mạo danh người khác;\n3. Cản trở, gây rối hoặc làm chậm hoạt động tiếp nhận và xử lý thông tin khẩn cấp;\n4. Phá hoại, làm hỏng hoặc làm sai lệch hoạt động của ứng dụng;\n5. Thu thập, công khai, chia sẻ hoặc sử dụng trái phép thông tin cá nhân của người khác;\n6. Lợi dụng thiên tai, tai nạn hoặc hoàn cảnh nguy cấp để trục lợi;\n7. Sử dụng ứng dụng vào mục đích trái pháp luật hoặc trái đạo đức xã hội;\n8. Né tránh việc bị xử lý bằng cách tạo tài khoản mới hoặc dùng cách thức khác để tiếp tục vi phạm."),
        TermsSection(title: "Điều 13. Quyền của đơn vị vận hành",
                     body: "Để bảo đảm an toàn cho người dùng và cho hoạt động của ứng dụng, đơn vị vận hành có quyền:\n• Yêu cầu người dùng cung cấp thêm thông tin để xác minh;\n• Đánh dấu thông tin chưa được kiểm tra hoặc có dấu hiệu rủi ro;\n• Hạn chế một phần quyền sử dụng của người dùng;\n• Ẩn hoặc gỡ nội dung;\n• Tạm khóa hoặc khóa vĩnh viễn tài khoản;\n• Lưu giữ thông tin cần thiết để phục vụ việc kiểm tra, xử lý vi phạm hoặc đáp ứng yêu cầu của cơ quan có thẩm quyền.\n\nTrong trường hợp có nguy cơ gây hại ngay lập tức cho con người, cho dữ liệu hoặc cho hoạt động hỗ trợ, đơn vị vận hành có thể áp dụng biện pháp ngăn chặn ngay mà không cần chờ người dùng giải trình trước."),
        TermsSection(title: "Điều 14. Dữ liệu cá nhân và chia sẻ thông tin",
                     body: "Đơn vị vận hành thu thập và sử dụng dữ liệu cá nhân trong phạm vi cần thiết để:\n• Vận hành ứng dụng;\n• Tiếp nhận và xử lý thông tin hỗ trợ;\n• Xác minh, điều phối và liên lạc khi cần;\n• Bảo đảm an toàn cho người dùng;\n• Xử lý vi phạm;\n• Thực hiện nghĩa vụ theo quy định của pháp luật.\n\nTrong trường hợp khẩn cấp, đơn vị vận hành có thể chia sẻ những thông tin thật sự cần thiết với lực lượng hỗ trợ, cơ quan có thẩm quyền hoặc bên liên quan phù hợp để phục vụ việc cứu trợ, cứu nạn, cứu hộ hoặc bảo vệ tính mạng, sức khỏe và an toàn của con người.\n\nViệc thu thập, sử dụng, lưu giữ và chia sẻ dữ liệu cá nhân còn được thực hiện theo Chính sách bảo mật dữ liệu của ứng dụng và theo quy định của pháp luật hiện hành."),
        TermsSection(title: "Điều 15. Giới hạn trách nhiệm",
                     body: "Người dùng hiểu và đồng ý rằng:\n• Thông tin vị trí có thể sai lệch do thiết bị, tín hiệu hoặc điều kiện thực tế;\n• Kết nối mạng có thể chậm, gián đoạn hoặc mất hoàn toàn;\n• Ứng dụng có thể bị lỗi, quá tải, ngừng hoạt động tạm thời hoặc không thể hoạt động trong một số hoàn cảnh bất khả kháng;\n• Trợ lý ảo hoặc thông tin do người dùng khác cung cấp có thể không chính xác.\n\nTrong phạm vi pháp luật cho phép, đơn vị vận hành không chịu trách nhiệm đối với thiệt hại phát sinh từ:\n• Thông tin sai do người dùng cung cấp;\n• Sự cố thiết bị, mất mạng, mất điện hoặc thiên tai;\n• Sai lệch của dữ liệu vị trí;\n• Việc người dùng chậm liên hệ cơ quan chức năng trong tình huống nguy cấp;\n• Quyết định của người dùng dựa hoàn toàn vào thông tin tham khảo trên ứng dụng."),
        TermsSection(title: "Điều 16. Tạm ngừng hoặc chấm dứt quyền sử dụng",
                     body: "Đơn vị vận hành có quyền tạm ngừng hoặc chấm dứt quyền sử dụng ứng dụng của người dùng nếu:\n1. Người dùng vi phạm Điều khoản này;\n2. Người dùng gây nguy cơ mất an toàn cho ứng dụng hoặc cho người khác;\n3. Có yêu cầu từ cơ quan có thẩm quyền;\n4. Việc tiếp tục cho sử dụng không còn phù hợp với yêu cầu pháp luật hoặc yêu cầu vận hành an toàn.\n\nNgười dùng cũng có thể ngừng sử dụng ứng dụng bất cứ lúc nào bằng cách ngừng truy cập hoặc thực hiện việc xóa tài khoản theo hướng dẫn của ứng dụng, nếu tính năng đó được cung cấp."),
        TermsSection(title: "Điều 17. Thay đổi điều khoản",
                     body: "Đơn vị vận hành có quyền sửa đổi, bổ sung hoặc cập nhật Điều khoản này khi cần thiết.\n\nPhiên bản mới sẽ được thông báo trên ứng dụng hoặc bằng hình thức phù hợp khác. Nếu người dùng tiếp tục sử dụng ứng dụng sau thời điểm điều khoản mới có hiệu lực, người dùng được xem là đã đồng ý với nội dung đã được cập nhật."),
        TermsSection(title: "Điều 18. Điều khoản riêng cho một số tính năng",
                     body: "Đối với một số tính năng đặc biệt như trợ lý ảo, hồ sơ khẩn cấp, chuyển tài khoản, mã khẩn cấp, quyên góp hoặc các tính năng cộng đồng nếu được bổ sung trong tương lai, đơn vị vận hành có thể ban hành quy định riêng để áp dụng bổ sung.\n\nTrong trường hợp có sự khác nhau giữa Điều khoản này và quy định riêng của từng tính năng, quy định riêng của tính năng đó sẽ được ưu tiên áp dụng trong phạm vi liên quan."),
        TermsSection(title: "Điều 19. Liên hệ",
                     body: "Nếu có câu hỏi, phản ánh, khiếu nại hoặc yêu cầu liên quan đến việc sử dụng ứng dụng, người dùng có thể liên hệ:\n• Đơn vị vận hành: ResQ Team\n• Thư điện tử: cuonghkse182700@fpt.edu.vn\n• Số điện thoại: 0374745872\n\nPhiên bản: 1.0\nNgày có hiệu lực: 1/5/2026")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("ĐIỀU KHOẢN SỬ DỤNG\nỨNG DỤNG RESQ")
                        .font(.title2.bold())
                        .foregroundColor(DS.Colors.text)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)

                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(DS.Typography.headline)
                                .foregroundColor(DS.Colors.text)
                            Text(section.body)
                                .font(DS.Typography.body)
                                .foregroundColor(DS.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DS.Colors.background)
            .navigationTitle("Điều khoản")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.text)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SOSWizardView(bridgefyManager: BridgefyNetworkManager.shared)
}
