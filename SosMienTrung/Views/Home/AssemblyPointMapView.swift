import SwiftUI
import MapKit
import CoreLocation

struct AssemblyPointMapView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var locationManager = LocationManager()

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 16.4, longitude: 107.1),
        span: MKCoordinateSpan(latitudeDelta: 4.6, longitudeDelta: 4.6)
    )
    @State private var assemblyPoints: [AssemblyPoint] = []
    @State private var selectedAssemblyPointID: Int?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoadedOnce = false

    private let service = RescueTeamService.shared

    private var mapItems: [AssemblyPointMapItem] {
        assemblyPoints.compactMap { point in
            guard let coordinate = point.coordinate else { return nil }
            return AssemblyPointMapItem(assemblyPoint: point, coordinate: coordinate)
        }
    }

    private var selectedAssemblyPoint: AssemblyPoint? {
        let fallbackID = selectedAssemblyPointID ?? mapItems.first?.id
        return assemblyPoints.first(where: { $0.id == fallbackID })
    }

    var body: some View {
        ZStack {
            Map(
                coordinateRegion: $region,
                interactionModes: .all,
                showsUserLocation: true,
                annotationItems: mapItems
            ) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    Button {
                        selectAssemblyPoint(item.assemblyPoint)
                    } label: {
                        AssemblyPointMarkerView(
                            name: item.assemblyPoint.name,
                            isSelected: item.id == selectedAssemblyPointID,
                            hasActiveEvent: item.assemblyPoint.hasActiveEvent
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .ignoresSafeArea()

            if isLoading {
                ProgressView("Đang tải điểm lánh nạn...")
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            }

            VStack(spacing: DS.Spacing.md) {
                headerCard

                if let errorMessage {
                    errorBanner(errorMessage)
                }

                Spacer()

                if let selectedAssemblyPoint {
                    AssemblyPointDetailCard(
                        assemblyPoint: selectedAssemblyPoint,
                        onClose: { selectedAssemblyPointID = nil },
                        onOpenDirections: { openDirections(to: selectedAssemblyPoint) }
                    )
                } else if isLoading == false && mapItems.isEmpty {
                    emptyStateCard
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.md)
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .task {
            guard hasLoadedOnce == false else { return }
            hasLoadedOnce = true
            await loadAssemblyPoints()
        }
        .onAppear {
            locationManager.requestPermission()
        }
    }

    private var headerCard: some View {
        HStack(spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Bản đồ lánh nạn")
                    .font(DS.Typography.title2)
                    .foregroundColor(DS.Colors.text)

                Text(headerSubtitle)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            headerButton(systemName: "location.fill") {
                centerOnCurrentLocation()
            }

            headerButton(systemName: "arrow.clockwise") {
                Task { await loadAssemblyPoints() }
            }

            headerButton(systemName: "xmark") {
                dismiss()
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: DS.Border.thin)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    }

    private var headerSubtitle: String {
        if isLoading {
            return "Đang đồng bộ các điểm lánh nạn từ máy chủ"
        }

        if mapItems.isEmpty {
            return "Chưa có điểm lánh nạn khả dụng để hiển thị"
        }

        return "\(mapItems.count) điểm đang hiển thị trên Apple Maps"
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Chưa có điểm lánh nạn")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)

            Text("Máy chủ chưa trả về điểm có toạ độ hợp lệ để ghim trên Apple Maps.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)

            Button {
                Task { await loadAssemblyPoints() }
            } label: {
                Text("Tải lại")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .foregroundColor(.white)
                    .background(DS.Colors.info)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.medium,
            backgroundColor: DS.Colors.surface,
            radius: DS.Radius.md
        )
    }

    private func headerButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(DS.Colors.text)
                .frame(width: 40, height: 40)
                .background(DS.Colors.surface.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .stroke(DS.Colors.borderSubtle, lineWidth: DS.Border.thin)
                )
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(DS.Colors.warning)

            Text(message)
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Colors.warning.opacity(0.36), lineWidth: DS.Border.thin)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    @MainActor
    private func loadAssemblyPoints() async {
        isLoading = true
        errorMessage = nil

        do {
            let points = try await service.getAllAssemblyPoints(pageSize: 50)
            assemblyPoints = points

            if let firstVisiblePoint = mapItems.first {
                if mapItems.contains(where: { $0.id == selectedAssemblyPointID }) == false {
                    selectedAssemblyPointID = firstVisiblePoint.id
                }
                region = makeRegion(for: mapItems.map(\.coordinate))
            } else {
                selectedAssemblyPointID = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func selectAssemblyPoint(_ assemblyPoint: AssemblyPoint) {
        selectedAssemblyPointID = assemblyPoint.id

        guard let coordinate = assemblyPoint.coordinate else { return }
        let focusedLatitudeDelta = max(region.span.latitudeDelta * 0.45, 0.22)
        let focusedLongitudeDelta = max(region.span.longitudeDelta * 0.45, 0.22)

        withAnimation(.easeInOut(duration: 0.22)) {
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: focusedLatitudeDelta,
                    longitudeDelta: focusedLongitudeDelta
                )
            )
        }
    }

    private func centerOnCurrentLocation() {
        locationManager.requestLocation { location in
            guard let coordinate = location?.coordinate else { return }

            withAnimation(.easeInOut(duration: 0.22)) {
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                )
            }
        }
    }

    private func openDirections(to assemblyPoint: AssemblyPoint) {
        guard let coordinate = assemblyPoint.coordinate else { return }

        let destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        destination.name = assemblyPoint.name

        MKMapItem.openMaps(
            with: [MKMapItem.forCurrentLocation(), destination],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        )
    }

    private func makeRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return region
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)

        let minLatitude = latitudes.min() ?? first.latitude
        let maxLatitude = latitudes.max() ?? first.latitude
        let minLongitude = longitudes.min() ?? first.longitude
        let maxLongitude = longitudes.max() ?? first.longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )

        let latitudeDelta = max((maxLatitude - minLatitude) * 1.5, 0.22)
        let longitudeDelta = max((maxLongitude - minLongitude) * 1.5, 0.22)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeDelta,
                longitudeDelta: longitudeDelta
            )
        )
    }
}

private struct AssemblyPointMapItem: Identifiable {
    let assemblyPoint: AssemblyPoint
    let coordinate: CLLocationCoordinate2D

    var id: Int { assemblyPoint.id }
}

private struct AssemblyPointMarkerView: View {
    let name: String
    let isSelected: Bool
    let hasActiveEvent: Bool

    private var tintColor: Color {
        hasActiveEvent ? DS.Colors.danger : DS.Colors.warning
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            if isSelected {
                Text(name)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Colors.background.opacity(0.94))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(DS.Colors.borderSubtle, lineWidth: DS.Border.thin)
                    )
            }

            Image(systemName: hasActiveEvent ? "exclamationmark.triangle.fill" : "house.fill")
                .font(.system(size: isSelected ? 17 : 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: isSelected ? 42 : 36, height: isSelected ? 42 : 36)
                .background(tintColor)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
        }
    }
}

private struct AssemblyPointDetailCard: View {
    let assemblyPoint: AssemblyPoint
    let onClose: () -> Void
    let onOpenDirections: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            previewImage

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(assemblyPoint.name)
                            .font(DS.Typography.headline)
                            .foregroundColor(DS.Colors.text)
                            .multilineTextAlignment(.leading)

                        Text(assemblyPoint.code)
                            .font(DS.Typography.mono)
                            .foregroundColor(DS.Colors.textSecondary)
                    }

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(DS.Colors.textMuted)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: DS.Spacing.xs) {
                    statusPill

                    if assemblyPoint.hasActiveEvent {
                        infoPill(text: "Có sự kiện", color: DS.Colors.danger)
                    }
                }

                if let maxCapacity = assemblyPoint.maxCapacity {
                    Label("Sức chứa tối đa: \(maxCapacity) người", systemImage: "person.3.fill")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.textSecondary)
                }

                if let updatedText = formattedLastUpdated(assemblyPoint.lastUpdatedAt) {
                    Label(updatedText, systemImage: "clock")
                        .font(DS.Typography.subheadline)
                        .foregroundColor(DS.Colors.textSecondary)
                }

                Button(action: onOpenDirections) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "map")
                        Text("Mở chỉ đường bằng Apple Maps")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(DS.Typography.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.info)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surface.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: DS.Border.thin)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
    }

    @ViewBuilder
    private var previewImage: some View {
        let imageFrame = CGSize(width: 104, height: 132)

        if let urlText = assemblyPoint.imageUrl,
           let url = URL(string: urlText) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholderImage(frame: imageFrame)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .clipped()
                case .failure:
                    placeholderImage(frame: imageFrame)
                @unknown default:
                    placeholderImage(frame: imageFrame)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        } else {
            placeholderImage(frame: imageFrame)
        }
    }

    private var statusPill: some View {
        infoPill(
            text: assemblyPoint.status?.uppercased() ?? "UNKNOWN",
            color: assemblyPoint.hasActiveEvent ? DS.Colors.danger : DS.Colors.success
        )
    }

    private func infoPill(text: String, color: Color) -> some View {
        Text(text)
            .font(DS.Typography.eyebrow)
            .tracking(1)
            .foregroundColor(color)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func placeholderImage(frame: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [DS.Colors.warning.opacity(0.9), DS.Colors.accent.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "house.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: frame.width, height: frame.height)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    }

    private func formattedLastUpdated(_ rawValue: String?) -> String? {
        guard let rawValue,
              rawValue.isEmpty == false else {
            return nil
        }

        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoWithoutFraction = ISO8601DateFormatter()
        isoWithoutFraction.formatOptions = [.withInternetDateTime]

        guard let date = isoWithFraction.date(from: rawValue) ?? isoWithoutFraction.date(from: rawValue) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return "Cập nhật: \(formatter.string(from: date))"
    }
}
