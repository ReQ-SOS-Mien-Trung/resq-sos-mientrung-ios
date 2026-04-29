import SwiftUI
import MapKit
import CoreLocation

struct ActivityRouteSheetView: View {
    private enum RouteOriginKind {
        case device
        case team

        var label: String {
            switch self {
            case .device:
                return L10n.Route.deviceGPS
            case .team:
                return L10n.Route.teamLocation
            }
        }
    }

    let missionId: Int
    let activity: Activity
    let fallbackOriginCoordinate: CLLocationCoordinate2D?
    let fallbackOriginLabel: String?

    @StateObject private var locationManager = LocationManager.shared
    @State private var selectedVehicle = "bike"
    @State private var route: ActivityRoute?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var originKind: RouteOriginKind = .device
    @State private var originAddress: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                header

                if isLoading {
                    loadingCard
                } else if let errorMessage {
                    errorCard(message: errorMessage)
                } else if let route, let originCoordinate {
                    routeMapCard(route: route, originCoordinate: originCoordinate)
                    routeSummaryCard(route: route)
                } else {
                    errorCard(message: "Chưa có dữ liệu lộ trình cho bước này.")
                }
            }
            .padding(DS.Spacing.md)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Colors.background)
        .task(id: refreshKey) {
            await loadRoute()
        }
        .task(id: originLookupKey) {
            await updateOriginAddress()
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startContinuousUpdates()
        }
        .onDisappear {
            locationManager.stopContinuousUpdates()
        }
        .onChange(of: currentDeviceCoordinateKey) { _ in
            guard originKind == .team, isLoading == false else { return }
            Task {
                await loadRoute(forceRefresh: true)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(activity.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(DS.Colors.text)

            if let description = activity.description,
               description.isEmpty == false {
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: DS.Spacing.sm) {
                Picker("Phương tiện", selection: $selectedVehicle) {
                    Text("Xe máy").tag("bike")
                    Text("Ô tô").tag("car")
                }
                .pickerStyle(.segmented)

                Button {
                    Task {
                        await loadRoute(forceRefresh: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DS.Colors.accent)
                        .frame(width: 36, height: 36)
                        .background(DS.Colors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }

            originInfoCard
        }
    }

    private var originInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: originKind == .device ? "location.fill" : "person.3.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(originKind == .device ? DS.Colors.success : DS.Colors.info)

                Text("Điểm xuất phát")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(DS.Colors.text)

                Spacer(minLength: 0)

                Text(originKind.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(originKind == .device ? DS.Colors.success : DS.Colors.info)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((originKind == .device ? DS.Colors.success : DS.Colors.info).opacity(0.12))
                    .clipShape(Capsule())
            }

            if let originAddress,
               originAddress.isEmpty == false {
                Text(originAddress)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.text)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(originDisplayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
        .padding(DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((originKind == .device ? DS.Colors.success : DS.Colors.info).opacity(0.22), lineWidth: 1)
        )
    }

    private var loadingCard: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProgressView()
            Text("Đang tải lộ trình từ hệ thống...")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sharpCard(
            borderColor: DS.Colors.borderSubtle,
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 16
        )
    }

    private func errorCard(message: String) -> some View {
        let displayMessage = friendlyErrorMessage(for: message)
        let isSystemError = message.contains("API_KEY_UNAUTHORIZED") || message.contains("HTTP 500")

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: 12) {
                Image(systemName: isSystemError ? "gearshape.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSystemError ? DS.Colors.info : DS.Colors.warning)
                    .frame(width: 44, height: 44)
                    .background((isSystemError ? DS.Colors.info : DS.Colors.warning).opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Không tải được lộ trình")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DS.Colors.text)

                    Text(isSystemError ? "Lỗi hệ thống" : "Vấn đề kết nối")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor((isSystemError ? DS.Colors.info : DS.Colors.warning).opacity(0.8))
                }
            }

            Text(displayMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DS.Spacing.sm) {
                Button {
                    Task {
                        await loadRoute(forceRefresh: true)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                        Text("Thử lại")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(DS.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                if isSystemError {
                    Button {
                        // Action for reporting error if needed
                    } label: {
                        Text("Báo cáo lỗi")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DS.Colors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(DS.Colors.borderSubtle.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSystemError ? DS.Colors.info.opacity(0.15) : DS.Colors.warning.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
    }

    private func friendlyErrorMessage(for message: String) -> String {
        let lowercased = message.lowercased()

        if lowercased.contains("api_key_unauthorized") {
            return "Dịch vụ bản đồ Goong chưa được ủy quyền (sai API Key). Vui lòng thông báo cho quản trị viên để cập nhật lại cấu hình hệ thống."
        }

        if lowercased.contains("rate limit") || lowercased.contains("429") {
            return "Hệ thống đang quá tải yêu cầu lộ trình. Vui lòng đợi khoảng 20 giây trước khi nhấn thử lại."
        }

        if lowercased.contains("zero_results") {
            return "Không tìm thấy lộ trình khả dụng đến địa điểm này. Có thể do địa hình không hỗ trợ loại phương tiện đã chọn."
        }

        if lowercased.contains("not_found") {
            return "Không tìm thấy thông tin tọa độ của điểm xuất phát hoặc điểm đến."
        }

        if lowercased.contains("timeout") {
            return "Kết nối mạng quá chậm, không thể tải dữ liệu lộ trình từ máy chủ."
        }

        if lowercased.contains("http 403") {
            return "Bạn không có quyền truy cập dữ liệu lộ trình này hoặc cấu hình API Key đang bị từ chối."
        }

        // Check if it looks like a raw JSON string that failed to decode
        if message.contains("{") && message.contains(":") {
            return "Đã xảy ra lỗi không xác định từ máy chủ khi tính toán lộ trình."
        }

        return message
    }

    private func routeMapCard(route: ActivityRoute, originCoordinate: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Bản đồ lộ trình")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(DS.Colors.text)

            ActivityBackendRouteMapView(
                origin: originCoordinate,
                destination: destinationCoordinate(route: route),
                destinationTitle: destinationTitle,
                encodedPolylines: encodedPolylines(route: route),
                waypointCoordinates: waypointCoordinates(route: route)
            )
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderColor: DS.Colors.borderSubtle,
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 18
        )
    }

    private func routeSummaryCard(route: ActivityRoute) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                ActivityRouteMetricChip(
                    icon: "road.lanes",
                    title: "Quãng đường",
                    value: distanceText(route),
                    color: DS.Colors.info
                )
                ActivityRouteMetricChip(
                    icon: "clock",
                    title: "Thời gian",
                    value: durationText(route),
                    color: DS.Colors.warning
                )
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                pointSummaryBlock(
                    title: "Điểm đến",
                    systemImage: "flag.checkered",
                    tint: DS.Colors.accent,
                    detail: destinationTitle
                )

                if let summary = route.route?.summary,
                   summary.isEmpty == false {
                    pointSummaryBlock(
                        title: "Tóm tắt tuyến đường",
                        systemImage: "map",
                        tint: DS.Colors.info,
                        detail: summary
                    )
                }
            }

            if let steps = route.route?.steps,
               steps.isEmpty == false {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Các chặng chính")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DS.Colors.text)

                    ForEach(Array(steps.prefix(5).enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: DS.Spacing.sm) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(DS.Colors.info)
                                .frame(width: 22, height: 22)
                                .background(DS.Colors.info.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.instruction?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? step.instruction! : "Tiếp tục di chuyển")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(DS.Colors.text)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text([step.distanceText, step.durationText].compactMap { $0 }.joined(separator: " • "))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DS.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderColor: DS.Colors.borderSubtle,
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 18
        )
    }

    private var refreshKey: String {
        "\(activity.id)|\(selectedVehicle)|\(fallbackOriginCoordinate?.latitude ?? 0)|\(fallbackOriginCoordinate?.longitude ?? 0)"
    }

    private var originLookupKey: String {
        guard let originCoordinate else { return "none" }
        return String(format: "%.6f,%.6f|%@", originCoordinate.latitude, originCoordinate.longitude, originKind.label)
    }

    private var currentDeviceCoordinate: CLLocationCoordinate2D? {
        guard let coordinate = locationManager.currentLocation?.coordinate,
              isUsableCoordinate(coordinate) else {
            return nil
        }

        return coordinate
    }

    private var currentDeviceCoordinateKey: String {
        guard let coordinate = currentDeviceCoordinate else { return "device:none" }
        return String(format: "device:%.6f,%.6f", coordinate.latitude, coordinate.longitude)
    }

    private var originCoordinate: CLLocationCoordinate2D? {
        if originKind == .device,
           let currentDeviceCoordinate {
            return currentDeviceCoordinate
        }

        if let route {
            let coordinate = CLLocationCoordinate2D(
                latitude: route.originLatitude,
                longitude: route.originLongitude
            )
            if isUsableCoordinate(coordinate) {
                return coordinate
            }
        }

        return fallbackOriginCoordinate
    }

    private var destinationTitle: String {
        if let depotName = activity.depotName?.trimmingCharacters(in: .whitespacesAndNewlines),
           depotName.isEmpty == false {
            return depotName
        }

        if let step = activity.step {
            return L10n.Route.destinationStep(String(step))
        }

        return activity.title
    }

    @MainActor
    private func loadRoute(forceRefresh: Bool = false) async {
        if isLoading { return }

        isLoading = true
        errorMessage = nil
        if forceRefresh {
            route = nil
        }

        do {
            let origin = try await resolveOriginCoordinate()
            let fetchedRoute = try await MissionService.shared.getActivityRoute(
                missionId: missionId,
                activityId: activity.id,
                originLat: origin.latitude,
                originLng: origin.longitude,
                vehicle: selectedVehicle,
                bypassCache: forceRefresh
            )

            route = fetchedRoute
            if fetchedRoute.route == nil, encodedPolylines(route: fetchedRoute).isEmpty {
                errorMessage = L10n.Route.activityMissingRouteData
            }
        } catch {
            if isTaskCancellation(error) {
                isLoading = false
                return
            }

            errorMessage = L10n.Route.activityLoadFailed(error.localizedDescription)
            route = nil
        }

        isLoading = false
    }

    private func resolveOriginCoordinate() async throws -> CLLocationCoordinate2D {
        if let currentDeviceCoordinate {
            originKind = .device
            return currentDeviceCoordinate
        }

        let location: CLLocation? = await withCheckedContinuation { continuation in
            locationManager.requestLocation(forceFresh: true) { resolved in
                continuation.resume(returning: resolved)
            }
        }

        if let location,
           isUsableCoordinate(location.coordinate) {
            originKind = .device
            return location.coordinate
        }

        if let fallbackOriginCoordinate,
           isUsableCoordinate(fallbackOriginCoordinate) {
            originKind = .team
            return fallbackOriginCoordinate
        }

        throw ActivityRouteSheetError.locationUnavailable
    }

    private func updateOriginAddress() async {
        guard let originCoordinate else {
            originAddress = nil
            return
        }

        if originKind == .team,
           let fallbackOriginLabel,
           fallbackOriginLabel.isEmpty == false {
            originAddress = fallbackOriginLabel
            return
        }

        do {
            originAddress = compactAddress(try await GeocodingService.shared.reverseGeocode(originCoordinate))
        } catch {
            originAddress = nil
        }
    }

    private var originDisplayText: String {
        guard let originCoordinate else {
            return L10n.Route.unknownOrigin
        }

        return String(format: "%.6f, %.6f", originCoordinate.latitude, originCoordinate.longitude)
    }

    private func destinationCoordinate(route: ActivityRoute) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: route.destinationLatitude,
            longitude: route.destinationLongitude
        )
    }

    private func waypointCoordinates(route: ActivityRoute) -> [CLLocationCoordinate2D] {
        []
    }

    private func encodedPolylines(route: ActivityRoute) -> [String] {
        var polylines: [String] = []

        if let overview = route.route?.overviewPolyline,
           overview.isEmpty == false {
            polylines.append(overview)
        }

        let stepPolylines = route.route?.steps?.compactMap { step in
            step.polyline?.isEmpty == false ? step.polyline : nil
        } ?? []

        for polyline in stepPolylines where polylines.contains(polyline) == false {
            polylines.append(polyline)
        }

        return polylines
    }

    private func distanceText(_ route: ActivityRoute) -> String {
        if let text = route.route?.totalDistanceText,
           text.isEmpty == false {
            return text
        }

        let meters = route.route?.totalDistanceMeters ?? route.distance ?? 0
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }

        if meters > 0 {
            return String(format: "%.0f m", meters)
        }

        return "-"
    }

    private func durationText(_ route: ActivityRoute) -> String {
        if let text = route.route?.totalDurationText,
           text.isEmpty == false {
            return text
        }

        let seconds = route.route?.totalDurationSeconds ?? route.duration ?? 0
        guard seconds > 0 else { return L10n.Route.dash }

        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let remains = minutes % 60

        if hours > 0 {
            return L10n.Route.hoursMinutes(String(hours), String(remains))
        }

        return L10n.Route.minutesOnly(String(minutes))
    }

    private func pointSummaryBlock(
        title: String,
        systemImage: String,
        tint: Color,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundColor(tint)
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(DS.Colors.textSecondary)

            Text(detail)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DS.Colors.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func compactAddress(_ rawAddress: String) -> String {
        let parts = rawAddress
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return parts.joined(separator: ", ")
    }

    private func isUsableCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        (-90...90).contains(coordinate.latitude)
        && (-180...180).contains(coordinate.longitude)
        && !(abs(coordinate.latitude) < 0.000001 && abs(coordinate.longitude) < 0.000001)
    }

    private func isTaskCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError,
           urlError.code == .cancelled {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

private enum ActivityRouteSheetError: LocalizedError {
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return L10n.Route.activityLocationUnavailable
        }
    }
}

private struct ActivityRouteMetricChip: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(DS.Colors.textSecondary)

            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
    }
}

private struct ActivityBackendRouteMapView: UIViewRepresentable {
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let destinationTitle: String
    let encodedPolylines: [String]
    let waypointCoordinates: [CLLocationCoordinate2D]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.isPitchEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.render(
            on: mapView,
            origin: origin,
            destination: destination,
            destinationTitle: destinationTitle,
            encodedPolylines: encodedPolylines,
            waypointCoordinates: waypointCoordinates
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private var lastRenderKey: String?

        func render(
            on mapView: MKMapView,
            origin: CLLocationCoordinate2D,
            destination: CLLocationCoordinate2D,
            destinationTitle: String,
            encodedPolylines: [String],
            waypointCoordinates: [CLLocationCoordinate2D]
        ) {
            let waypointKey = waypointCoordinates
                .map { String(format: "%.6f,%.6f", $0.latitude, $0.longitude) }
                .joined(separator: "|")
            let renderKey = "\(origin.latitude),\(origin.longitude)|\(destination.latitude),\(destination.longitude)|\(destinationTitle)|\(encodedPolylines.joined(separator: "|"))|\(waypointKey)"
            guard renderKey != lastRenderKey else { return }
            lastRenderKey = renderKey

            mapView.removeOverlays(mapView.overlays)
            let nonUserAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(nonUserAnnotations)

            var overlays: [MKPolyline] = encodedPolylines.compactMap { encoded in
                let coordinates = ActivityRoutePolylineDecoder.decode(encoded)
                guard coordinates.count > 1 else { return nil }
                var mutableCoordinates = coordinates
                let polyline = MKPolyline(coordinates: &mutableCoordinates, count: mutableCoordinates.count)
                polyline.title = "route"
                return polyline
            }

            if overlays.isEmpty {
                var points = [origin, destination]
                let fallback = MKPolyline(coordinates: &points, count: points.count)
                fallback.title = "fallback"
                overlays = [fallback]
            }

            mapView.addOverlays(overlays)

            let originAnnotation = MKPointAnnotation()
            originAnnotation.coordinate = origin
            originAnnotation.title = "Điểm xuất phát"

            let destinationAnnotation = MKPointAnnotation()
            destinationAnnotation.coordinate = destination
            destinationAnnotation.title = destinationTitle

            let waypointAnnotations = waypointCoordinates.enumerated().map { index, coordinate in
                let annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = "Điểm trung gian \(index + 1)"
                return annotation
            }

            let allAnnotations = [originAnnotation, destinationAnnotation] + waypointAnnotations
            mapView.addAnnotations(allAnnotations)

            let routeRect = overlays.reduce(MKMapRect.null) { partial, overlay in
                partial.union(overlay.boundingMapRect)
            }

            let annotationRect = allAnnotations.reduce(routeRect) { partial, annotation in
                let point = MKMapPoint(annotation.coordinate)
                let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
                return partial.union(pointRect)
            }

            let insets = UIEdgeInsets(top: 50, left: 35, bottom: 50, right: 35)
            if annotationRect.isNull == false {
                mapView.setVisibleMapRect(annotationRect, edgePadding: insets, animated: true)
            } else {
                mapView.showAnnotations(allAnnotations, animated: true)
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let routeLine = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: routeLine)
            renderer.lineJoin = .round
            renderer.lineCap = .round

            if routeLine.title == "fallback" {
                renderer.strokeColor = .systemTeal
                renderer.lineWidth = 4
                renderer.lineDashPattern = [5, 3]
            } else {
                renderer.strokeColor = .systemOrange
                renderer.lineWidth = 5
            }

            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "ActivityRouteAnnotation"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            view.canShowCallout = true

            let annotationTitle = (annotation.title ?? nil) ?? ""
            if annotationTitle == "Điểm xuất phát" {
                view.markerTintColor = .systemGreen
                view.glyphImage = UIImage(systemName: "location.north.line.fill")
            } else if annotationTitle.hasPrefix("Điểm trung gian") {
                view.markerTintColor = .systemOrange
                view.glyphImage = UIImage(systemName: "mappin.and.ellipse")
            } else {
                view.markerTintColor = .systemRed
                view.glyphImage = UIImage(systemName: "flag.checkered")
            }

            view.glyphText = nil
            return view
        }
    }
}

private enum ActivityRoutePolylineDecoder {
    static func decode(_ encodedPolyline: String) -> [CLLocationCoordinate2D] {
        guard encodedPolyline.isEmpty == false else { return [] }

        let bytes = Array(encodedPolyline.utf8)
        var coordinates: [CLLocationCoordinate2D] = []
        var index = 0
        var latitude = 0
        var longitude = 0

        while index < bytes.count {
            var byte: UInt8
            var shift = 0
            var result = 0

            repeat {
                byte = bytes[index] - 63
                index += 1
                result |= Int(byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20 && index < bytes.count

            let latitudeDelta = (result & 1) == 0 ? (result >> 1) : ~(result >> 1)
            latitude += latitudeDelta

            shift = 0
            result = 0

            repeat {
                byte = bytes[index] - 63
                index += 1
                result |= Int(byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20 && index < bytes.count

            let longitudeDelta = (result & 1) == 0 ? (result >> 1) : ~(result >> 1)
            longitude += longitudeDelta

            coordinates.append(
                CLLocationCoordinate2D(
                    latitude: Double(latitude) / 1_00000.0,
                    longitude: Double(longitude) / 1_00000.0
                )
            )
        }

        return coordinates
    }
}
