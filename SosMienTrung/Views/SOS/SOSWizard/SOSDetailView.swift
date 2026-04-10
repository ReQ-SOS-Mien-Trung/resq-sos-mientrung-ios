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
    @State private var serverDetail: SOSServerRecord?
    @State private var isLoadingServerDetail = false
    
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

                        if let summaryIncidentCard = summaryIncidentCard {
                            summaryIncidentCard
                        }

                        if let incidentHistoryCard = incidentHistoryCard {
                            incidentHistoryCard
                        }

                        if let companionsCard = companionsCard {
                            companionsCard
                        }

                        sosContentCard
                        
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
                    savedSOS: currentSOS,
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
                    SOSStorageManager.shared.deleteSOS(id: currentSOS.id)
                    dismiss()
                }
            } message: {
                Text("SOS này sẽ bị xóa khỏi danh sách đã lưu.")
            }
            .task(id: currentSOS.serverSosRequestId) {
                await loadServerDetailIfNeeded()
            }
        }
    }
    
    // MARK: - Status Header
    
    @ObservedObject private var sosStorage = SOSStorageManager.shared
    
    private var currentSOS: SavedSOS {
        sosStorage.getSOS(id: savedSOS.id) ?? savedSOS
    }

    private var displaySOS: SavedSOS {
        guard let serverDetail else { return currentSOS }
        return currentSOS.merged(withServer: serverDetail)
    }

    private var displayIncidentHistory: [SosIncidentHistoryItem] {
        serverDetail?.incidentHistory ?? []
    }

    private var displayCompanions: [CompanionResult] {
        serverDetail?.companions ?? []
    }
    
    private var statusHeader: some View {
        VStack(spacing: 12) {
            // Status badge
            HStack {
                Image(systemName: displaySOS.status.icon)
                    .font(.title2)
                Text(displaySOS.status.title)
                    .font(DS.Typography.headline)
            }
            .foregroundColor(displaySOS.status.color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(displaySOS.status.color.opacity(0.2))
            
            
            // Timestamps
            VStack(spacing: 4) {
                Text("Tạo lúc: \(displaySOS.timestamp.formatted(date: .abbreviated, time: .shortened))")
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)
                
                if currentSOS.lastUpdated != displaySOS.timestamp {
                    Text("Cập nhật: \(currentSOS.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }

                if isLoadingServerDetail {
                    Text("Đang đồng bộ chi tiết từ server...")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(DS.Colors.surface)
        
    }

    private var summaryIncidentCard: AnyView? {
        guard let latestIncidentNote = displaySOS.latestIncidentNote, !latestIncidentNote.isEmpty else {
            return nil
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .foregroundColor(DS.Colors.accent)
                    Text("Cập nhật Incident mới nhất")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)
                    Spacer()
                    if let latestIncidentAt = displaySOS.latestIncidentAt {
                        Text(latestIncidentAt.formatted(date: .abbreviated, time: .shortened))
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                    }
                }

                Text(latestIncidentNote)
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(DS.Colors.surface)
        )
    }

    private var incidentHistoryCard: AnyView? {
        guard !displayIncidentHistory.isEmpty else { return nil }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .foregroundColor(DS.Colors.accent)
                    Text("Lịch sử Incident")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)
                    Spacer()
                    Text("\(displayIncidentHistory.count)")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }

                ForEach(displayIncidentHistory) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(scopeLabel(for: item.incidentScope))
                                .font(DS.Typography.caption.bold())
                                .foregroundColor(DS.Colors.accent)
                            Spacer()
                            Text(formatServerDate(item.createdAt) ?? item.createdAt)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textSecondary)
                        }

                        Text(item.note)
                            .font(DS.Typography.subheadline)
                            .foregroundColor(DS.Colors.text)
                            .fixedSize(horizontal: false, vertical: true)

                        if let teamName = item.teamName, !teamName.isEmpty {
                            Text(teamName)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(DS.Colors.surface)
        )
    }

    private var companionsCard: AnyView? {
        guard !displayCompanions.isEmpty else { return nil }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(DS.Colors.info)
                    Text("Companion liên quan")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)
                }

                ForEach(displayCompanions) { companion in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(companion.fullName ?? "Không rõ tên")
                                .font(DS.Typography.subheadline)
                                .foregroundColor(DS.Colors.text)
                            if let phone = companion.phone, !phone.isEmpty {
                                Text(phone)
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                        }

                        Spacer()
                    }
                }
            }
            .padding()
            .background(DS.Colors.surface)
        )
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
                        let isLast = index == history.count - 1
                        let visualState = timelineVisualState(for: event, isPast: !isLast)

                        HStack(alignment: .top, spacing: 12) {
                            // Timeline đường dọc
                            VStack(spacing: 0) {
                                timelineMarker(for: visualState, isLast: isLast)
                                if index < history.count - 1 {
                                    Rectangle()
                                        .fill(timelineConnectorColor(current: visualState))
                                        .frame(width: 2)
                                        .frame(minHeight: 24)
                                }
                            }
                            .frame(width: timelineColumnWidth)

                            
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
                                        .foregroundColor(noteColor(for: visualState))
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

    private enum TimelineVisualState {
        case success
        case failure
        case inProgress
        case pastInProgress
    }

    private let timelineMarkerDiameter: CGFloat = 22
    private let timelineColumnWidth: CGFloat = 36
    private let timelineRippleBoxSize: CGFloat = 36

    private func timelineVisualState(for event: SOSSendEvent, isPast: Bool) -> TimelineVisualState {
        switch event.type {
        case .created, .sentViaNetwork, .sentViaMesh, .serverAcknowledged:
            return .success
        case .pendingRetry:
            let note = event.note?.lowercased() ?? ""
            let isFailure = note.contains("thất bại") || note.contains("loi") || note.contains("lỗi") || note.contains("failed")
            if isFailure {
                return .failure
            }
            return isPast ? .pastInProgress : .inProgress
        }
    }

    @ViewBuilder
    private func timelineMarker(for state: TimelineVisualState, isLast: Bool) -> some View {
        ZStack {
            Circle()
                .fill(markerBackgroundColor(for: state))
                .frame(width: timelineMarkerDiameter, height: timelineMarkerDiameter)

            switch state {
            case .success:
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
            case .failure:
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red)
            case .inProgress:
                ProgressView()
                    .controlSize(.small)
                    .tint(.blue)
            case .pastInProgress:
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
            }
        }
        .frame(width: timelineMarkerDiameter, height: timelineMarkerDiameter)
        .overlay {
            if isLast {
                RippleCircle(color: timelineConnectorColor(current: state))
                    .frame(width: timelineRippleBoxSize, height: timelineRippleBoxSize)
                    .allowsHitTesting(false)
            }
        }
        .padding(.top, 2)
    }

    private func markerBackgroundColor(for state: TimelineVisualState) -> Color {
        switch state {
        case .success:
            return Color.green.opacity(0.18)
        case .failure:
            return Color.red.opacity(0.18)
        case .inProgress, .pastInProgress:
            return Color.blue.opacity(0.18)
        }
    }

    private func timelineConnectorColor(current: TimelineVisualState) -> Color {
        switch current {
        case .success:
            return .green
        case .failure:
            return .red
        case .inProgress, .pastInProgress:
            return .blue
        }
    }

    private func noteColor(for state: TimelineVisualState) -> Color {
        switch state {
        case .success:
            return DS.Colors.textSecondary
        case .failure:
            return .red
        case .inProgress, .pastInProgress:
            return .blue
        }
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
            
            if let lat = displaySOS.latitude, let lon = displaySOS.longitude {
                // Mini map
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )), annotationItems: [LocationAnnotation(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    title: "SOS",
                    userId: UUID()
                )]) { item in
                    MapMarker(coordinate: item.coordinate, tint: .red)
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

    private var detailSelectedTypes: [SOSType] {
        var types: [SOSType] = []

        if displaySOS.rescueData != nil {
            types.append(.rescue)
        }

        if displaySOS.reliefData != nil {
            types.append(.relief)
        }

        if types.isEmpty, let type = displaySOS.sosType {
            types.append(type)
        }

        return types
    }

    private var detailPeople: [Person] {
        if !displaySOS.sharedPeople.isEmpty {
            return displaySOS.sharedPeople
        }

        if let rescuePeople = displaySOS.rescueData?.people, !rescuePeople.isEmpty {
            return rescuePeople
        }

        return []
    }

    private var detailPeopleCount: PeopleCount {
        if !detailPeople.isEmpty {
            return PeopleCount(
                adults: detailPeople.filter { $0.type == .adult }.count,
                children: detailPeople.filter { $0.type == .child }.count,
                elderly: detailPeople.filter { $0.type == .elderly }.count
            )
        }

        if let rescueCount = displaySOS.rescueData?.peopleCount {
            return rescueCount
        }

        if let reliefCount = displaySOS.reliefData?.peopleCount {
            return reliefCount
        }

        return PeopleCount(adults: 0, children: 0, elderly: 0)
    }

    private var sosContentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let lat = displaySOS.latitude, let lon = displaySOS.longitude {
                ReviewRow(icon: "📍", title: "Vị trí", value: String(format: "%.4f, %.4f", lat, lon))
            }

            if !detailSelectedTypes.isEmpty {
                let typesText = detailSelectedTypes.map(\.title).joined(separator: " + ")
                let icon = detailSelectedTypes.count > 1 ? "🆘" : (detailSelectedTypes.first?.icon ?? "🆘")
                ReviewRow(icon: icon, title: "Loại SOS", value: typesText)
            }

            if detailPeopleCount.total > 0 {
                PeopleCountSummaryGrid(
                    peopleCount: detailPeopleCount,
                    layoutStyle: .inline
                )
            }

            if let rescue = displaySOS.rescueData {
                Divider()
                    .background(DS.Colors.surface)

                Text("🚨 Thông tin cứu hộ")
                    .font(.subheadline.bold())
                    .foregroundColor(DS.Colors.danger)

                if let situation = rescue.situation {
                    ReviewRow(
                        icon: RescueSituation.icon(for: situation),
                        title: "Tình trạng",
                        value: RescueSituation.title(for: situation)
                    )
                }

                if !rescue.otherSituationDescription.isEmpty {
                    ReviewRow(icon: "📝", title: "Mô tả thêm", value: rescue.otherSituationDescription)
                }

                if rescue.hasInjured && !rescue.injuredPersonIds.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🚑 Người bị thương:")
                            .font(.caption.bold())
                            .foregroundColor(DS.Colors.text)

                        LazyVGrid(columns: summaryGridColumns, spacing: 10) {
                            ForEach(detailPeople.filter { rescue.injuredPersonIds.contains($0.id) }) { person in
                                if let medicalInfo = rescue.medicalInfoByPerson[person.id] {
                                    InjuredPersonReviewCard(person: person, medicalInfo: medicalInfo)
                                }
                            }
                        }

                        let totalPeople = detailPeople.isEmpty ? rescue.peopleCount.total : detailPeople.count
                        if rescue.othersAreStable && rescue.injuredPersonIds.count < totalPeople {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Những người còn lại ổn định")
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }

            if let relief = displaySOS.reliefData {
                Divider()
                    .background(DS.Colors.surface)

                Text("🎒 Thông tin cứu trợ")
                    .font(.subheadline.bold())
                    .foregroundColor(.yellow)

                ReliefSummaryGridContent(
                    relief: relief,
                    people: detailPeople
                )
            }

            if !displaySOS.additionalDescription.isEmpty {
                Divider()
                    .background(DS.Colors.surface)
                ReviewRow(icon: "📝", title: "Ghi chú", value: displaySOS.additionalDescription)
            }

            ReviewRow(
                icon: "🕒",
                title: "Thời gian",
                value: displaySOS.timestamp.formatted(date: .abbreviated, time: .shortened)
            )
        }
        .padding()
        .background(DS.Colors.surface)
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
                    DetailRow(
                        icon: RescueSituation.icon(for: situation),
                        title: "Tình trạng",
                        value: RescueSituation.title(for: situation)
                    )
                }
                
                if !rescue.otherSituationDescription.isEmpty {
                    DetailRow(icon: "📝", title: "Mô tả thêm", value: rescue.otherSituationDescription)
                }
                
                PeopleCountSummaryGrid(peopleCount: rescue.peopleCount)
                
                // Injured info
                if rescue.hasInjured {
                    Divider().background(DS.Colors.surface)
                    
                    Text("🩹 Người bị thương: \(rescue.injuredPersonIds.count)")
                        .font(.subheadline.bold())
                        .foregroundColor(DS.Colors.danger)
                    
                    // 2-column grid of injured persons
                    let injuredInfos = rescue.injuredPersonIds.compactMap { personId in
                        rescue.medicalInfoByPerson[personId]
                    }
                    
                    LazyVGrid(columns: summaryGridColumns, spacing: 10) {
                        ForEach(injuredInfos, id: \.personId) { info in
                            injuredPersonCard(info: info, rescue: rescue)
                        }
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
                PeopleCountSummaryGrid(peopleCount: relief.peopleCount)

                ReliefSummaryGridContent(
                    relief: relief,
                    people: savedSOS.sharedPeople.isEmpty ? (savedSOS.rescueData?.people ?? []) : savedSOS.sharedPeople
                )
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
                        id: currentSOS.id,
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
    
    /// Card hiển thị thông tin người bị thương trong grid
    private func injuredPersonCard(info: PersonMedicalInfo, rescue: SavedRescueData) -> some View {
        let person = savedPerson(info.personId) ?? rescue.people.first(where: { $0.id == info.personId })
        let name = person?.displayName ?? personLabel(info.personId)
        let personTypeIcon = person?.type.icon ?? "🧑"
        let personTypeTitle = person?.type.title ?? ""
        
        return VStack(alignment: .leading, spacing: 6) {
            // Header: icon + name
            HStack(spacing: 6) {
                Text(personTypeIcon)
                    .font(.title3)
                Text(name)
                    .font(.caption.bold())
                    .foregroundColor(DS.Colors.text)
                    .lineLimit(1)
            }
            
            // Person type
            Text(personTypeTitle)
                .font(.caption2)
                .foregroundColor(DS.Colors.textSecondary)
            
            // Medical issues
            if !info.medicalIssues.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(info.medicalIssues), id: \.self) { issue in
                        HStack(spacing: 4) {
                            Text(MedicalIssue.icon(for: issue))
                                .font(.caption2)
                            Text(MedicalIssue.title(for: issue))
                                .font(.caption2)
                                .foregroundColor(DS.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
    
    /// Chuyển personId ("adult_1", "child_2", "elderly_1") thành nhãn hiển thị
    /// Ưu tiên hiển thị tên (customName) nếu có, ngược lại hiển thị loại + số thứ tự
    private func personLabel(_ personId: String) -> String {
        if let person = savedPerson(personId) {
            return person.displayName
        }
        
        // Fallback: parse từ personId
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

    private func savedPerson(_ personId: String) -> Person? {
        displaySOS.sharedPeople.first(where: { $0.id == personId }) ??
            displaySOS.rescueData?.people.first(where: { $0.id == personId })
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
            id: currentSOS.id,
            event: SOSSendEvent(type: .pendingRetry, note: "Người dùng yêu cầu gửi lại")
        )
        
        let formData = currentSOS.toFormData()
        
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

    private func loadServerDetailIfNeeded() async {
        guard let serverSosRequestId = currentSOS.serverSosRequestId,
              NetworkMonitor.shared.isConnected else {
            return
        }

        await MainActor.run {
            isLoadingServerDetail = true
        }

        let detail = await APIService.shared.getSosRequestDetail(id: serverSosRequestId)

        await MainActor.run {
            serverDetail = detail
            isLoadingServerDetail = false
        }
    }

    private func scopeLabel(for rawValue: String?) -> String {
        switch RescuerStatusBadgeText.normalized(rawValue) {
        case "mission":
            return "Toàn đội"
        case "activity":
            return "Theo activity"
        default:
            return "Incident"
        }
    }

    private func formatServerDate(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let fullFormatter = ISO8601DateFormatter()
        fullFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let basicFormatter = ISO8601DateFormatter()
        basicFormatter.formatOptions = [.withInternetDateTime]

        let date = fullFormatter.date(from: rawValue) ?? basicFormatter.date(from: rawValue)
        return date?.formatted(date: .abbreviated, time: .shortened)
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
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var formData: SOSFormData
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var successMessage = "Đã cập nhật SOS!"
    
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
            .alert(successMessage, isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            }
        }
    }
    
    private func sendUpdatedSOS() {
        isSending = true
        
        Task {
            let didSyncDirectly = await performDirectVictimUpdateIfPossible()

            if !didSyncDirectly {
                _ = await bridgefyManager.sendStructuredSOS(formData)

                var updated = updatedLocalSnapshot()
                updated.status = .pending
                SOSStorageManager.shared.updateSOS(updated)
                SOSStorageManager.shared.addSendEvent(
                    id: savedSOS.id,
                    event: SOSSendEvent(type: .pendingRetry, note: "Đã chỉnh sửa nội dung và gửi lại như SOS mới")
                )
            }

            await MainActor.run {
                isSending = false
                successMessage = didSyncDirectly
                    ? "Đã cập nhật SOS trên server"
                    : "Đã lưu chỉnh sửa và gửi lại qua luồng SOS hiện tại"
                showSuccess = true
            }
        }
    }

    private func performDirectVictimUpdateIfPossible() async -> Bool {
        guard networkMonitor.isConnected,
              let serverSosRequestId = savedSOS.serverSosRequestId else {
            return false
        }

        let packet = formData.toSOSPacket(
            originIdOverride: bridgefyManager.currentUserId?.uuidString,
            packetIdOverride: savedSOS.id,
            timestampOverride: Date()
        )

        guard let response = await APIService.shared.updateVictimSosRequest(
            id: serverSosRequestId,
            packet: packet
        ) else {
            return false
        }

        var updated = updatedLocalSnapshot()
        updated.serverSosRequestId = response.sosRequestId
        updated.status = .delivered
        SOSStorageManager.shared.updateSOS(updated)
        SOSStorageManager.shared.addSendEvent(
            id: savedSOS.id,
            event: SOSSendEvent(type: .serverAcknowledged, note: "Đã cập nhật SOS trực tiếp trên server")
        )
        return true
    }

    private func updatedLocalSnapshot() -> SavedSOS {
        var updated = savedSOS
        updated.lastUpdated = Date()
        updated.sharedPeople = formData.sharedPeople
        updated.personSourceMode = formData.personSourceMode
        updated.selectedRelativeSnapshots = formData.selectedRelativeSnapshots
        updated.additionalDescription = formData.additionalDescription
        updated.message = formData.toSOSMessage()
        updated.sosType = formData.sosType
        updated.latitude = formData.effectiveLocation?.latitude ?? savedSOS.latitude
        updated.longitude = formData.effectiveLocation?.longitude ?? savedSOS.longitude
        updated.victimName = formData.effectiveVictimName
        updated.victimPhone = formData.effectiveVictimPhone
        updated.reporterName = formData.autoInfo?.userName ?? savedSOS.reporterName
        updated.reporterPhone = formData.autoInfo?.userPhone ?? savedSOS.reporterPhone
        updated.addressQuery = formData.addressQuery
        updated.resolvedAddress = formData.resolvedAddress
        updated.manualLocation = formData.manualLocation

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

        return updated
    }
}

// MARK: - SOS Wizard Content (Reusable)

struct SOSWizardContent: View {
    @ObservedObject var formData: SOSFormData
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var sosRuleConfigStore = SOSRuleConfigStore.shared
    @Binding var isSending: Bool
    var onSend: () -> Void
    @State private var showRelativeProfilePicker = false
    
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
                    Step0ReportingModeView(formData: formData)
                        .tag(SOSWizardStep.reportingMode)

                    Step0AutoInfoView(
                        formData: formData,
                        bridgefyManager: bridgefyManager,
                        networkMonitor: networkMonitor
                    )
                        .tag(SOSWizardStep.autoInfo)

                    Step1SelectTypeView(
                        formData: formData,
                        onChangeSavedProfiles: { showRelativeProfilePicker = true },
                        onSwitchToManual: { formData.switchToManualPersonSelection() }
                    )
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
                .sheet(isPresented: $showRelativeProfilePicker) {
                    RelativeProfilePickerSheet(initialSelectedProfileIds: formData.selectedRelativeProfileIds) { profiles in
                        formData.applySelectedRelativeProfiles(profiles)
                    }
                }
                .task {
                    await sosRuleConfigStore.prepareForSOSFormEntry(
                        isNetworkAvailable: networkMonitor.isConnected
                    )
                }
                .onChange(of: networkMonitor.isConnected) { isConnected in
                    if isConnected {
                        Task {
                            await sosRuleConfigStore.prepareForSOSFormEntry(
                                isNetworkAvailable: true
                            )
                        }
                    } else {
                        sosRuleConfigStore.loadCachedFallbackIfNeeded()
                    }
                }
                
                // Navigation
                HStack {
                    if formData.currentStep != .reportingMode {
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

// MARK: - Ripple Effect
struct RippleCircle: View {
    let color: Color
    private let baseDiameter: CGFloat = 22
    private let maxScale: CGFloat = 1.6
    private let duration: TimeInterval = 1.5
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let progress = (elapsed.truncatingRemainder(dividingBy: duration)) / duration
            let diameter = baseDiameter * (1 + (maxScale - 1) * progress)

            Canvas { context, size in
                let rect = CGRect(
                    x: (size.width - diameter) / 2,
                    y: (size.height - diameter) / 2,
                    width: diameter,
                    height: diameter
                )

                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(color.opacity(0.6 * (1 - progress))),
                    lineWidth: 2
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .drawingGroup()
            .accessibilityHidden(true)
        }
        .frame(width: baseDiameter * maxScale, height: baseDiameter * maxScale)
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
