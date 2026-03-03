//
//  SOSDetailView.swift
//  SosMienTrung
//
//  View xem chi tiết và chỉnh sửa SOS đã gửi
//

import SwiftUI
import MapKit

struct SOSDetailView: View {
    let savedSOS: SavedSOS
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @Environment(\.dismiss) var dismiss
    
    @State private var isEditing = false
    @State private var showResendConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isSending = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with status
                        statusHeader
                        
                        // Send history timeline
                        sendHistoryCard
                        
                        // Location card
                        if savedSOS.latitude != nil && savedSOS.longitude != nil {
                            locationCard
                        }
                        
                        // SOS Type
                        if let type = savedSOS.sosType {
                            sosTypeCard(type)
                        }
                        
                        // Detailed info based on type
                        if savedSOS.sosType == .rescue {
                            rescueDetailsCard
                        } else if savedSOS.sosType == .relief {
                            reliefDetailsCard
                        }
                        
                        // Additional description
                        if !savedSOS.additionalDescription.isEmpty {
                            additionalDescriptionCard
                        }
                        
                        // Action buttons
                        actionButtons
                    }
                    .padding()
                }
            }
            .navigationTitle("Chi tiết SOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.text)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            isEditing = true
                        } label: {
                            Label("Chỉnh sửa", systemImage: "pencil")
                        }
                        
                        Button {
                            showResendConfirm = true
                        } label: {
                            Label("Gửi lại", systemImage: "arrow.clockwise")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Xóa", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundColor(DS.Colors.text)
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                SOSEditView(
                    savedSOS: savedSOS,
                    bridgefyManager: bridgefyManager
                )
            }
            .alert("Gửi lại SOS?", isPresented: $showResendConfirm) {
                Button("Hủy", role: .cancel) {}
                Button("Gửi lại") {
                    resendSOS()
                }
            } message: {
                Text("SOS này sẽ được gửi lại với thông tin hiện tại.")
            }
            .alert("Xóa SOS?", isPresented: $showDeleteConfirm) {
                Button("Hủy", role: .cancel) {}
                Button("Xóa", role: .destructive) {
                    SOSStorageManager.shared.deleteSOS(id: savedSOS.id)
                    dismiss()
                }
            } message: {
                Text("SOS này sẽ bị xóa khỏi danh sách đã lưu.")
            }
        }
    }
    
    // MARK: - Status Header
    
    private var currentSOS: SavedSOS {
        SOSStorageManager.shared.getSOS(id: savedSOS.id) ?? savedSOS
    }
    
    private var statusHeader: some View {
        VStack(spacing: 12) {
            // Status badge
            HStack {
                Image(systemName: currentSOS.status.icon)
                    .font(.title2)
                Text(currentSOS.status.title)
                    .font(DS.Typography.headline)
            }
            .foregroundColor(currentSOS.status.color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(currentSOS.status.color.opacity(0.2))
            
            
            // Timestamps
            VStack(spacing: 4) {
                Text("Tạo lúc: \(savedSOS.timestamp.formatted(date: .abbreviated, time: .shortened))")
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)
                
                if currentSOS.lastUpdated != savedSOS.timestamp {
                    Text("Cập nhật: \(currentSOS.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(DS.Colors.surface)
        
    }
    
    // MARK: - Send History Card
    
    private var sendHistoryCard: some View {
        let history = currentSOS.sendHistory
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(DS.Colors.accent)
                Text("Lịch sử gửi")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
                Spacer()
                Text("\(history.count) sự kiện")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            if history.isEmpty {
                Text("Chưa có lịch sử gửi")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(history.enumerated()), id: \.element.id) { index, event in
                        HStack(alignment: .top, spacing: 12) {
                            // Timeline đường dọc
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(event.type.color)
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 5)
                                if index < history.count - 1 {
                                    Rectangle()
                                        .fill(DS.Colors.border)
                                        .frame(width: 2)
                                        .frame(minHeight: 30)
                                }
                            }
                            .frame(width: 10)
                            
                            // Nội dung sự kiện
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Image(systemName: event.type.icon)
                                        .font(.caption)
                                        .foregroundColor(event.type.color)
                                    Text(event.type.title)
                                        .font(.caption.bold())
                                        .foregroundColor(DS.Colors.text)
                                }
                                
                                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(DS.Colors.textSecondary)
                                
                                if let note = event.note {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundColor(DS.Colors.textSecondary)
                                        .italic()
                                }
                            }
                            .padding(.bottom, index < history.count - 1 ? 12 : 0)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(DS.Colors.surface)
    }
    
    // MARK: - Location Card
    
    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(DS.Colors.accent)
                Text("Vị trí")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
                Spacer()
            }
            
            if let lat = savedSOS.latitude, let lon = savedSOS.longitude {
                // Mini map
                Map {
                    Marker("SOS", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        .tint(.red)
                }
                .frame(height: 150)
                
                .disabled(true)
                
                // Coordinates
                HStack {
                    Text(String(format: "%.6f, %.6f", lat, lon))
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                    
                    Spacer()
                    
                    Button {
                        openInMaps(lat: lat, lon: lon)
                    } label: {
                        Label("Mở bản đồ", systemImage: "map")
                            .font(.caption.bold())
                            .foregroundColor(DS.Colors.accent)
                    }
                }
            }
        }
        .padding()
        .background(DS.Colors.surface)
        
    }
    
    // MARK: - SOS Type Card
    
    private func sosTypeCard(_ type: SOSType) -> some View {
        HStack(spacing: 16) {
            Text(type.icon)
                .font(.system(size: 40))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(type.title)
                    .font(.title2.bold())
                    .foregroundColor(DS.Colors.text)
                
                Text(type.subtitle)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            type == .rescue ? Color.red.opacity(0.25) : Color.yellow.opacity(0.25)
        )
        
    }
    
    // MARK: - Rescue Details
    
    private var rescueDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🚨 Thông tin cứu hộ")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
            
            if let rescue = savedSOS.rescueData {
                // Situation
                if let situation = rescue.situation {
                    DetailRow(icon: situation.icon, title: "Tình trạng", value: situation.title)
                }
                
                if !rescue.otherSituationDescription.isEmpty {
                    DetailRow(icon: "📝", title: "Mô tả thêm", value: rescue.otherSituationDescription)
                }
                
                // People count
                DetailRow(icon: "👥", title: "Tổng số người", value: "\(rescue.peopleCount.total)")
                
                if rescue.peopleCount.children > 0 {
                    DetailRow(icon: "👶", title: "Trẻ em", value: "\(rescue.peopleCount.children)")
                }
                
                if rescue.peopleCount.elderly > 0 {
                    DetailRow(icon: "👴", title: "Người già", value: "\(rescue.peopleCount.elderly)")
                }
                
                // Injured info
                if rescue.hasInjured {
                    Divider().background(DS.Colors.surface)
                    
                    Text("🩹 Người bị thương: \(rescue.injuredPersonIds.count)")
                        .font(.subheadline.bold())
                        .foregroundColor(DS.Colors.danger)
                    
                    // Medical issues
                    if !rescue.medicalIssues.isEmpty {
                        let issues = rescue.medicalIssues.map { $0.title }.joined(separator: ", ")
                        DetailRow(icon: "🏥", title: "Vấn đề y tế", value: issues)
                    }
                    
                    // Individual medical info
                    ForEach(Array(rescue.medicalInfoByPerson.values), id: \.personId) { info in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(personLabel(info.personId))
                                    .font(.caption.bold())
                                    .foregroundColor(DS.Colors.text)
                                
                                Text(info.severity.title)
                                    .font(.caption2.bold())
                                    .foregroundColor(DS.Colors.text)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(severityColor(info.severity))
                                    
                            }
                            
                            if !info.medicalIssues.isEmpty {
                                Text(info.medicalIssues.map { $0.title }.joined(separator: ", "))
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.2))
                        
                    }
                }
            }
        }
        .padding()
        .background(DS.Colors.surface)
        
    }
    
    // MARK: - Relief Details
    
    private var reliefDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎒 Thông tin cứu trợ")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
            
            if let relief = savedSOS.reliefData {
                // Supplies needed
                if !relief.supplies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nhu yếu phẩm cần:")
                            .font(DS.Typography.subheadline)
                            .foregroundColor(DS.Colors.text)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(Array(relief.supplies), id: \.self) { supply in
                                HStack(spacing: 4) {
                                    Text(supply.icon)
                                    Text(supply.title)
                                }
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.yellow.opacity(0.3))
                                
                            }
                        }
                    }
                }
                
                if !relief.otherSupplyDescription.isEmpty {
                    DetailRow(icon: "📝", title: "Khác", value: relief.otherSupplyDescription)
                }
                
                // People count
                DetailRow(icon: "👥", title: "Số người", value: "\(relief.peopleCount.total)")
                
                if relief.peopleCount.children > 0 {
                    DetailRow(icon: "👶", title: "Trẻ em", value: "\(relief.peopleCount.children)")
                }
                
                if relief.peopleCount.elderly > 0 {
                    DetailRow(icon: "👴", title: "Người già", value: "\(relief.peopleCount.elderly)")
                }
            }
        }
        .padding()
        .background(DS.Colors.surface)
        
    }
    
    // MARK: - Additional Description
    
    private var additionalDescriptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(DS.Colors.textSecondary)
                Text("Mô tả thêm")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)
            }
            
            Text(savedSOS.additionalDescription)
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(DS.Colors.surface)
        
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Edit button
            Button {
                isEditing = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Chỉnh sửa & Gửi lại")
                }
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)
                .frame(maxWidth: .infinity)
                .padding()
                .background(DS.Colors.accent)
                
            }
            
            // Mark as resolved
            if currentSOS.status != .resolved {
                Button {
                    SOSStorageManager.shared.updateStatusWithEvent(
                        id: savedSOS.id,
                        status: .resolved,
                        event: SOSSendEvent(type: .serverAcknowledged, note: "Người dùng đánh dấu đã xử lý")
                    )
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.seal")
                        Text("Đánh dấu đã xử lý")
                    }
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.success)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.2))
                    
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Helpers
    
    private func severityColor(_ severity: MedicalSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .moderate: return .orange
        case .mild: return .yellow
        }
    }
    
    /// Chuyển personId ("adult_1", "child_2", "elderly_1") thành nhãn tiếng Việt
    private func personLabel(_ personId: String) -> String {
        let parts = personId.split(separator: "_")
        guard parts.count == 2, let index = parts.last.flatMap({ Int($0) }) else {
            return "Người \(personId)"
        }
        let typeName: String
        switch parts.first {
        case "adult":   typeName = "Người lớn"
        case "child":   typeName = "Trẻ em"
        case "elderly": typeName = "Người già"
        default:        typeName = "Người"
        }
        return "\(typeName) \(index)"
    }
    
    private func openInMaps(lat: Double, lon: Double) {
        let urlString = "maps://?ll=\(lat),\(lon)&q=SOS%20Location"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func resendSOS() {
        isSending = true
        
        // Ghi sự kiện đang thử gửi lại
        SOSStorageManager.shared.addSendEvent(
            id: savedSOS.id,
            event: SOSSendEvent(type: .pendingRetry, note: "Người dùng yêu cầu gửi lại")
        )
        
        let formData = savedSOS.toFormData()
        
        Task {
            let success = await bridgefyManager.sendStructuredSOS(formData)
            await MainActor.run {
                isSending = false
                // Không dismiss – người dùng có thể xem lịch sử cập nhật
                if success {
                    showResendConfirm = false
                }
            }
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                
                Text(value)
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)
            }
            
            Spacer()
        }
    }
}

// MARK: - SOS Edit View

struct SOSEditView: View {
    let savedSOS: SavedSOS
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @Environment(\.dismiss) var dismiss
    
    @State private var formData: SOSFormData
    @State private var isSending = false
    @State private var showSuccess = false
    
    init(savedSOS: SavedSOS, bridgefyManager: BridgefyNetworkManager) {
        self.savedSOS = savedSOS
        self.bridgefyManager = bridgefyManager
        self._formData = State(initialValue: savedSOS.toFormData())
    }
    
    var body: some View {
        NavigationStack {
            SOSWizardContent(
                formData: formData,
                bridgefyManager: bridgefyManager,
                isSending: $isSending,
                onSend: sendUpdatedSOS
            )
            .navigationTitle("Chỉnh sửa SOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                    .foregroundColor(DS.Colors.text)
                }
            }
            .alert("Đã cập nhật SOS!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            }
        }
    }
    
    private func sendUpdatedSOS() {
        isSending = true
        
        Task {
            // Gửi như SOS mới (tạo packet mới, tự lưu vào storage)
            _ = await bridgefyManager.sendStructuredSOS(formData)
            
            // Cập nhật nội dung của SOS cũ (giữ lịch sử) nhưng không ghi đè sendHistory
            var updated = savedSOS
            updated.lastUpdated = Date()
            
            // Lưu cả relief và rescue data nếu có
            if formData.needsReliefStep {
                updated.reliefData = formData.reliefData
            } else {
                updated.reliefData = nil
            }
            
            if formData.needsRescueStep {
                updated.rescueData = SavedRescueData(from: formData.rescueData)
            } else {
                updated.rescueData = nil
            }
            
            SOSStorageManager.shared.updateSOS(updated)
            // Ghi sự kiện "đã chỉnh sửa & gửi lại"
            SOSStorageManager.shared.addSendEvent(
                id: savedSOS.id,
                event: SOSSendEvent(type: .pendingRetry, note: "Đã chỉnh sửa nội dung và gửi lại")
            )
            
            await MainActor.run {
                isSending = false
                showSuccess = true
            }
        }
    }
}

// MARK: - SOS Wizard Content (Reusable)

struct SOSWizardContent: View {
    @Bindable var formData: SOSFormData
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @Binding var isSending: Bool
    var onSend: () -> Void
    
    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()
            Color.black.opacity(0.35).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress
                SOSProgressBar(currentStep: formData.currentStep)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Content
                TabView(selection: $formData.currentStep) {
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
                
                // Navigation
                HStack {
                    if formData.currentStep != .selectType {
                        Button {
                            withAnimation {
                                formData.goToPreviousStep()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Quay lại")
                            }
                            .foregroundColor(DS.Colors.text)
                            .padding()
                            .background(DS.Colors.surface)
                            
                        }
                    }
                    
                    Spacer()
                    
                    if formData.currentStep == .review {
                        Button {
                            onSend()
                        } label: {
                            HStack {
                                if isSending {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("GỬI SOS")
                                }
                            }
                            .foregroundColor(DS.Colors.text)
                            .padding()
                            .background(DS.Colors.danger)
                            
                        }
                        .disabled(isSending)
                    } else if formData.canProceedToNextStep {
                        Button {
                            withAnimation {
                                formData.goToNextStep()
                            }
                        } label: {
                            HStack {
                                Text("Tiếp theo")
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(DS.Colors.text)
                            .padding()
                            .background(DS.Colors.accent)
                            
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.3))
            }
        }
    }
}

#Preview {
    SOSDetailView(
        savedSOS: SavedSOS(
            from: SOSFormData(),
            packetId: UUID().uuidString,
            latitude: 16.047,
            longitude: 108.206
        ),
        bridgefyManager: BridgefyNetworkManager.shared
    )
}
