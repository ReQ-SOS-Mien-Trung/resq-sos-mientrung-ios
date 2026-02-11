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
                TelegramBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with status
                        statusHeader
                        
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
                    .foregroundColor(.white)
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
                            .foregroundColor(.white)
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
    
    private var statusHeader: some View {
        VStack(spacing: 12) {
            // Status badge
            HStack {
                Image(systemName: savedSOS.status.icon)
                    .font(.title2)
                Text(savedSOS.status.title)
                    .font(.headline)
            }
            .foregroundColor(savedSOS.status.color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(savedSOS.status.color.opacity(0.2))
            .cornerRadius(20)
            
            // Timestamps
            VStack(spacing: 4) {
                Text("Gửi lúc: \(savedSOS.timestamp.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                if savedSOS.lastUpdated != savedSOS.timestamp {
                    Text("Cập nhật: \(savedSOS.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Location Card
    
    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                Text("Vị trí")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            if let lat = savedSOS.latitude, let lon = savedSOS.longitude {
                // Mini map
                Map {
                    Marker("SOS", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        .tint(.red)
                }
                .frame(height: 150)
                .cornerRadius(12)
                .disabled(true)
                
                // Coordinates
                HStack {
                    Text(String(format: "%.6f, %.6f", lat, lon))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    Button {
                        openInMaps(lat: lat, lon: lon)
                    } label: {
                        Label("Mở bản đồ", systemImage: "map")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - SOS Type Card
    
    private func sosTypeCard(_ type: SOSType) -> some View {
        HStack(spacing: 16) {
            Text(type.icon)
                .font(.system(size: 40))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(type.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text(type.subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding()
        .background(
            type == .rescue ? Color.red.opacity(0.25) : Color.yellow.opacity(0.25)
        )
        .cornerRadius(16)
    }
    
    // MARK: - Rescue Details
    
    private var rescueDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🚨 Thông tin cứu hộ")
                .font(.headline)
                .foregroundColor(.white)
            
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
                    Divider().background(Color.white.opacity(0.3))
                    
                    Text("🩹 Người bị thương: \(rescue.injuredPersonIds.count)")
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                    
                    // Medical issues
                    if !rescue.medicalIssues.isEmpty {
                        let issues = rescue.medicalIssues.map { $0.title }.joined(separator: ", ")
                        DetailRow(icon: "🏥", title: "Vấn đề y tế", value: issues)
                    }
                    
                    // Individual medical info
                    ForEach(Array(rescue.medicalInfoByPerson.values), id: \.personId) { info in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Người \(info.personId)")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                
                                Text(info.severity.title)
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(severityColor(info.severity))
                                    .cornerRadius(6)
                            }
                            
                            if !info.medicalIssues.isEmpty {
                                Text(info.medicalIssues.map { $0.title }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(8)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Relief Details
    
    private var reliefDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🎒 Thông tin cứu trợ")
                .font(.headline)
                .foregroundColor(.white)
            
            if let relief = savedSOS.reliefData {
                // Supplies needed
                if !relief.supplies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nhu yếu phẩm cần:")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        FlowLayout(spacing: 8) {
                            ForEach(Array(relief.supplies), id: \.self) { supply in
                                HStack(spacing: 4) {
                                    Text(supply.icon)
                                    Text(supply.title)
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.yellow.opacity(0.3))
                                .cornerRadius(12)
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
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Additional Description
    
    private var additionalDescriptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.white.opacity(0.7))
                Text("Mô tả thêm")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text(savedSOS.additionalDescription)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
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
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            
            // Mark as resolved
            if savedSOS.status != .resolved {
                Button {
                    SOSStorageManager.shared.updateStatus(id: savedSOS.id, status: .resolved)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.seal")
                        Text("Đánh dấu đã xử lý")
                    }
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(12)
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
    
    private func openInMaps(lat: Double, lon: Double) {
        let urlString = "maps://?ll=\(lat),\(lon)&q=SOS%20Location"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func resendSOS() {
        isSending = true
        let formData = savedSOS.toFormData()
        
        Task {
            await bridgefyManager.sendStructuredSOS(formData)
            await MainActor.run {
                isSending = false
                dismiss()
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
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.white)
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
                    .foregroundColor(.white)
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
            // Send as new SOS
            await bridgefyManager.sendStructuredSOS(formData)
            
            // Update stored SOS
            var updated = savedSOS
            updated.status = .sent
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
            TelegramBackground()
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
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
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
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
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
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
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
