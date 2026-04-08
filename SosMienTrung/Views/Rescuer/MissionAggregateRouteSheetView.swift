import SwiftUI
import MapKit
import CoreLocation

struct MissionAggregateRouteSheetView: View {
    let mission: Mission
    @ObservedObject var vm: RescuerMissionViewModel

    @StateObject private var locationManager = LocationManager()
    @State private var selectedVehicle = "bike"
    @State private var teamRoute: MissionTeamRoute?
    @State private var segments: [AggregateRouteSegment] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var originKind: RouteOriginKind = .team
    @State private var originAddress: String?

    private enum RouteOriginKind {
        case team
        case device

        var label: String {
            switch self {
            case .team:
                return "Tọa độ team"
            case .device:
                return "GPS thiết bị"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                header

                if isLoading {
                    loadingCard
                } else if let errorMessage {
                    errorCard(message: errorMessage)
                } else if remainingActivities.isEmpty {
                    doneCard
                } else {
                    routeMapCard
                    routeSummaryCard
                }
            }
            .padding(DS.Spacing.md)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Colors.background)
        .task(id: refreshKey) {
            await loadAggregateRoute()
        }
        .task(id: originLookupKey) {
            await updateOriginAddress()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Điều hướng theo toàn bộ activity còn lại")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(DS.Colors.text)

            HStack(spacing: DS.Spacing.sm) {
                statusPill(title: "Còn lại", value: "\(remainingActivities.count)", color: DS.Colors.info)
                statusPill(title: "Đã xong", value: "\(completedActivitiesCount)", color: DS.Colors.success)
            }

            HStack(spacing: DS.Spacing.sm) {
                Picker("Phương tiện", selection: $selectedVehicle) {
                    Text("Xe máy").tag("bike")
                    Text("Ô tô").tag("car")
                }
                .pickerStyle(.segmented)

                Button {
                    Task {
                        await loadAggregateRoute(forceRefresh: true)
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

                Text("Điểm xuất phát của team")
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
            }

            if originAddress == nil {
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
            Text("Đang tổng hợp lộ trình xuất phát từ vị trí hiện tại của team...")
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
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(DS.Colors.warning)
                Text("Không tải được lộ trình tổng hợp")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(DS.Colors.text)
            }

            Text(message)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)

            Button("Thử lại") {
                Task {
                    await loadAggregateRoute(forceRefresh: true)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DS.Colors.accent)
            .clipShape(Capsule())
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sharpCard(
            borderColor: DS.Colors.warning.opacity(0.25),
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 16
        )
    }

    private var doneCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(DS.Colors.success)
                Text("Tất cả activity đã hoàn tất")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DS.Colors.text)
            }

            Text("Lộ trình sẽ tự cập nhật khi có activity mới được phân công.")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sharpCard(
            borderColor: DS.Colors.success.opacity(0.22),
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 16
        )
    }

    private var routeMapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bản đồ lộ trình tổng hợp")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(DS.Colors.text)

            if let originCoordinate,
               let destinationCoordinate {
                GoongAggregateRouteMapView(
                    origin: originCoordinate,
                    destination: destinationCoordinate,
                    originTitle: mapOriginTitle,
                    encodedPolylines: mapPolylines,
                    waypointCoordinates: waypointCoordinates
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                )
            } else {
                Text("Chưa có dữ liệu tọa độ cho lộ trình.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                    .padding(.vertical, DS.Spacing.sm)
            }
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderColor: DS.Colors.borderSubtle,
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 16
        )
    }

    private var routeSummaryCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                AggregateRouteMetricChip(
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    title: "Tổng quãng đường",
                    value: totalDistanceText,
                    color: DS.Colors.info
                )

                AggregateRouteMetricChip(
                    icon: "clock",
                    title: "Tổng thời gian",
                    value: totalDurationText,
                    color: DS.Colors.warning
                )
            }

            if destinationCoordinate != nil {
                pointSummaryBlock(
                    title: "Điểm đích cuối",
                    systemImage: "flag.checkered",
                    tint: DS.Colors.warning,
                    detail: "Điểm nhiệm vụ cuối"
                )
            }
        }
        .padding(DS.Spacing.md)
        .sharpCard(
            borderColor: DS.Colors.borderSubtle,
            borderWidth: DS.Border.thin,
            shadow: DS.Shadow.none,
            backgroundColor: DS.Colors.surface,
            radius: 16
        )
    }

    private var sourceActivities: [Activity] {
        let source = vm.activities.isEmpty ? (mission.activities ?? []) : vm.activities

        return source.sorted { lhs, rhs in
            switch (lhs.step, rhs.step) {
            case let (l?, r?):
                if l != r { return l < r }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            return lhs.id < rhs.id
        }
    }

    private var remainingActivities: [Activity] {
        sourceActivities.filter {
            $0.activityStatus == .planned || $0.activityStatus == .onGoing
        }
    }

    private var completedActivitiesCount: Int {
        sourceActivities.filter {
            $0.activityStatus == .succeed || $0.activityStatus == .failed || $0.activityStatus == .cancelled
        }.count
    }

    private var refreshKey: String {
        let statusKey = sourceActivities
            .map { "\($0.id)-\($0.status)-\($0.step ?? -1)" }
            .joined(separator: "|")

        let teamKey: String
        if let team = missionTeamCoordinate {
            teamKey = String(format: "%.6f,%.6f", team.latitude, team.longitude)
        } else {
            teamKey = "none"
        }

        let deviceKey = currentDeviceCoordinate == nil ? "none" : "available"

        return "\(selectedVehicle)|\(resolvedMissionTeamId ?? -1)|\(teamKey)|\(deviceKey)|\(statusKey)"
    }

    private var resolvedMissionTeamId: Int? {
        sourceActivities.compactMap { $0.missionTeamId }.first ?? mission.missionTeamId
    }

    private var missionTeamCoordinate: CLLocationCoordinate2D? {
        let team = mission.teams?.first(where: { $0.id == resolvedMissionTeamId })
            ?? mission.teams?.first

        guard let latitude = team?.latitude,
              let longitude = team?.longitude,
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var originDisplayText: String {
        guard let originCoordinate else { return "-" }
        return String(format: "%.6f, %.6f", originCoordinate.latitude, originCoordinate.longitude)
    }

    private var mapOriginTitle: String {
        "Điểm xuất phát (\(originKind.label))"
    }

    private var originLookupKey: String {
        guard let originCoordinate else { return "none" }
        return String(format: "%.6f,%.6f|%@", originCoordinate.latitude, originCoordinate.longitude, originKind.label)
    }

    private var currentDeviceCoordinate: CLLocationCoordinate2D? {
        guard let coordinates = locationManager.coordinates else { return nil }

        let coordinate = CLLocationCoordinate2D(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude
        )

        return isUsableCoordinate(coordinate) ? coordinate : nil
    }

    private var originCoordinate: CLLocationCoordinate2D? {
        if let latitude = teamRoute?.originLatitude,
           let longitude = teamRoute?.originLongitude,
           (-90...90).contains(latitude),
           (-180...180).contains(longitude) {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        if originKind == .device,
           let deviceCoordinate = currentDeviceCoordinate {
            return deviceCoordinate
        }

        guard let first = segments.first else { return missionTeamCoordinate }
        return CLLocationCoordinate2D(latitude: first.route.originLatitude, longitude: first.route.originLongitude)
    }

    private var destinationCoordinate: CLLocationCoordinate2D? {
        if let last = segments.last {
            return CLLocationCoordinate2D(latitude: last.route.destinationLatitude, longitude: last.route.destinationLongitude)
        }

        if let step = teamRoute?.route?.steps?.last {
            return CLLocationCoordinate2D(latitude: step.endLat, longitude: step.endLng)
        }

        if let waypoint = teamRoute?.route?.waypoints?.last {
            return CLLocationCoordinate2D(latitude: waypoint.latitude, longitude: waypoint.longitude)
        }

        if let lastActivity = remainingActivities.last,
           let latitude = lastActivity.targetLatitude,
           let longitude = lastActivity.targetLongitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        return nil
    }

    private var mapPolylines: [String] {
        if let overview = teamRoute?.route?.overviewPolyline,
           overview.isEmpty == false {
            return [overview]
        }

        if let summaryStepPolylines = teamRoute?.route?.steps?.compactMap({ step in
            step.polyline?.isEmpty == false ? step.polyline : nil
        }), summaryStepPolylines.isEmpty == false {
            return summaryStepPolylines
        }

        let preferred = segments.compactMap { segment in
            segment.route.route?.overviewPolyline?.isEmpty == false ? segment.route.route?.overviewPolyline : nil
        }

        if preferred.isEmpty == false {
            return preferred
        }

        return segments.flatMap { segment in
            segment.route.route?.steps?.compactMap { step in
                step.polyline?.isEmpty == false ? step.polyline : nil
            } ?? []
        }
    }

    private var waypointCoordinates: [CLLocationCoordinate2D] {
        if let teamRoute,
           teamRoute.waypoints.isEmpty == false {
            return deduplicatedCoordinates(
                teamRoute.waypoints.compactMap { waypoint in
                    guard (-90...90).contains(waypoint.latitude),
                          (-180...180).contains(waypoint.longitude) else {
                        return nil
                    }
                    return CLLocationCoordinate2D(latitude: waypoint.latitude, longitude: waypoint.longitude)
                }
            )
        }

        return deduplicatedCoordinates(
            segments.compactMap { segment in
                let latitude = segment.route.destinationLatitude
                let longitude = segment.route.destinationLongitude
                guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
                    return nil
                }
                return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
        )
    }

    private var totalDistanceText: String {
        if let text = teamRoute?.route?.totalDistanceText, text.isEmpty == false {
            return text
        }

        if let meters = teamRoute?.route?.totalDistanceMeters, meters > 0 {
            if meters >= 1000 {
                return String(format: "%.2f km", meters / 1000)
            }

            return String(format: "%.0f m", meters)
        }

        let totalMeters = segments.reduce(0.0) { partial, segment in
            partial + (segment.route.route?.totalDistanceMeters ?? 0)
        }

        guard totalMeters > 0 else { return "-" }

        if totalMeters >= 1000 {
            return String(format: "%.2f km", totalMeters / 1000)
        }

        return String(format: "%.0f m", totalMeters)
    }

    private var totalDurationText: String {
        if let text = teamRoute?.route?.totalDurationText, text.isEmpty == false {
            return text
        }

        if let seconds = teamRoute?.route?.totalDurationSeconds, seconds > 0 {
            let totalMinutes = Int(seconds / 60)
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60

            if hours > 0 {
                return "\(hours) giờ \(minutes) phút"
            }

            return "\(minutes) phút"
        }

        let totalSeconds = segments.reduce(0.0) { partial, segment in
            partial + (segment.route.route?.totalDurationSeconds ?? 0)
        }

        guard totalSeconds > 0 else { return "-" }

        let totalMinutes = Int(totalSeconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours) giờ \(minutes) phút"
        }

        return "\(minutes) phút"
    }

    @MainActor
    private func loadAggregateRoute(forceRefresh: Bool = false) async {
        if isLoading { return }

        isLoading = true
        errorMessage = nil
        if forceRefresh {
            teamRoute = nil
            segments = []
        }

        guard remainingActivities.isEmpty == false else {
            teamRoute = nil
            segments = []
            isLoading = false
            return
        }

        guard let missionTeamId = resolvedMissionTeamId else {
            errorMessage = "Không có missionTeamId nên chưa thể lấy lộ trình team."
            teamRoute = nil
            segments = []
            isLoading = false
            return
        }

        do {
            let origin = try await resolveOriginCoordinate()
            let fetchedRoute = try await MissionService.shared.getMissionTeamRoute(
                missionId: mission.id,
                missionTeamId: missionTeamId,
                originLat: origin.latitude,
                originLng: origin.longitude,
                vehicle: selectedVehicle
            )

            if let apiStatus = fetchedRoute.status,
               apiStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "ok" {
                errorMessage = fetchedRoute.errorMessage?.isEmpty == false
                    ? fetchedRoute.errorMessage
                    : "API route team trả về trạng thái không hợp lệ: \(apiStatus)"
                teamRoute = nil
                segments = []
                isLoading = false
                return
            }

            teamRoute = fetchedRoute
            segments = makeSegments(from: fetchedRoute)

            if fetchedRoute.route == nil && segments.isEmpty {
                errorMessage = "API route team chưa trả về dữ liệu lộ trình."
            }
        } catch {
            if isTaskCancellation(error) {
                isLoading = false
                return
            }

            errorMessage = "Không thể tải lộ trình tổng hợp: \(error.localizedDescription)"
            teamRoute = nil
            segments = []
        }

        isLoading = false
    }

    private func makeSegments(from teamRoute: MissionTeamRoute) -> [AggregateRouteSegment] {
        let activityLookup = Dictionary(uniqueKeysWithValues: sourceActivities.map { ($0.id, $0) })

        return teamRoute.activityRoutes.map { route in
            let resolvedTitle = activityLookup[route.activityId]?.title
                ?? localizedActivityTypeDisplay(route.activityType)
                ?? "Hoạt động #\(route.activityId)"

            return AggregateRouteSegment(
                id: route.activityId,
                title: resolvedTitle,
                route: route
            )
        }
    }

    private func resolveOriginCoordinate() async throws -> CLLocationCoordinate2D {
        if let deviceCoordinate = currentDeviceCoordinate {
            originKind = .device
            return deviceCoordinate
        }

        let location: CLLocation? = await withCheckedContinuation { continuation in
            locationManager.requestLocation { resolved in
                continuation.resume(returning: resolved)
            }
        }

        if let location,
           isUsableCoordinate(location.coordinate) {
            originKind = .device
            return location.coordinate
        }

        if let teamCoordinate = missionTeamCoordinate {
            originKind = .team
            return teamCoordinate
        }

        throw MissionAggregateRouteSheetError.locationUnavailable
    }

    private func updateOriginAddress() async {
        guard let originCoordinate else {
            originAddress = nil
            return
        }

        do {
            originAddress = compactAddress(try await GeocodingService.shared.reverseGeocode(originCoordinate))
        } catch {
            originAddress = nil
        }
    }

    private func statusPill(title: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            Text(value)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func deduplicatedCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        var seen = Set<String>()
        var result: [CLLocationCoordinate2D] = []

        for coordinate in coordinates {
            let key = String(format: "%.6f,%.6f", coordinate.latitude, coordinate.longitude)
            if seen.contains(key) {
                continue
            }

            seen.insert(key)
            result.append(coordinate)
        }

        return result
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

        var result: [String] = []
        var normalizedResult: [String] = []

        for part in parts {
            let normalizedPart = normalizedAddressComponent(part)
            if normalizedPart.isEmpty {
                continue
            }

            if normalizedResult.contains(normalizedPart) {
                continue
            }

            // Keep the longer variant when street fragments are repeated with house numbers.
            if let similarIndex = normalizedResult.firstIndex(where: { existing in
                let hasNumericHint = containsDigit(existing) || containsDigit(normalizedPart)
                guard hasNumericHint else { return false }
                return existing.contains(normalizedPart) || normalizedPart.contains(existing)
            }) {
                if normalizedPart.count > normalizedResult[similarIndex].count {
                    result[similarIndex] = part
                    normalizedResult[similarIndex] = normalizedPart
                }

                continue
            }

            // Remove orphan numeric chunks when previous part already includes that number.
            if isNumericOnly(normalizedPart),
               let previous = normalizedResult.last,
               previous.contains(normalizedPart) {
                continue
            }

            result.append(part)
            normalizedResult.append(normalizedPart)
        }

        return result.joined(separator: ", ")
    }

    private func normalizedAddressComponent(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsDigit(_ value: String) -> Bool {
        value.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private func isNumericOnly(_ value: String) -> Bool {
        value.range(of: "^[0-9]+$", options: .regularExpression) != nil
    }
}

private struct AggregateRouteSegment: Identifiable {
    let id: Int
    let title: String
    let route: ActivityRoute

    var distanceText: String {
        if let text = route.route?.totalDistanceText, text.isEmpty == false {
            return text
        }

        let meters = route.route?.totalDistanceMeters ?? 0
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }

        if meters > 0 {
            return String(format: "%.0f m", meters)
        }

        return "-"
    }

    var durationText: String {
        if let text = route.route?.totalDurationText, text.isEmpty == false {
            return text
        }

        let seconds = route.route?.totalDurationSeconds ?? 0
        guard seconds > 0 else { return "-" }

        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let remains = minutes % 60

        if hours > 0 {
            return "\(hours) giờ \(remains) phút"
        }

        return "\(minutes) phút"
    }
}

private struct AggregateRouteMetricChip: View {
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

private struct GoongAggregateRouteMapView: UIViewRepresentable {
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let originTitle: String
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
            originTitle: originTitle,
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
            originTitle: String,
            encodedPolylines: [String],
            waypointCoordinates: [CLLocationCoordinate2D]
        ) {
            let waypointKey = waypointCoordinates
                .map { String(format: "%.6f,%.6f", $0.latitude, $0.longitude) }
                .joined(separator: "|")
            let renderKey = "\(origin.latitude),\(origin.longitude)|\(destination.latitude),\(destination.longitude)|\(originTitle)|\(encodedPolylines.joined(separator: "|"))|\(waypointKey)"
            guard renderKey != lastRenderKey else { return }
            lastRenderKey = renderKey

            mapView.removeOverlays(mapView.overlays)
            let nonUserAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(nonUserAnnotations)

            var overlays: [MKPolyline] = encodedPolylines.compactMap { encoded in
                let coordinates = AggregateRoutePolylineDecoder.decode(encoded)
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
            originAnnotation.title = originTitle

            let destinationAnnotation = MKPointAnnotation()
            destinationAnnotation.coordinate = destination
            destinationAnnotation.title = "Điểm nhiệm vụ cuối"

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

            let identifier = "AggregateRouteAnnotation"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            view.canShowCallout = true

            let annotationTitle = (annotation.title ?? nil) ?? ""
            if annotationTitle.hasPrefix("Điểm xuất phát") {
                view.markerTintColor = .systemGreen
                view.glyphImage = UIImage(systemName: "location.north.line.fill")
                view.glyphText = nil
            } else if annotationTitle == "Điểm nhiệm vụ cuối" {
                view.markerTintColor = .systemRed
                view.glyphImage = UIImage(systemName: "flag.checkered")
                view.glyphText = nil
            } else if annotationTitle.hasPrefix("Điểm trung gian") {
                view.markerTintColor = .systemOrange
                view.glyphImage = UIImage(systemName: "mappin.and.ellipse")
                view.glyphText = nil
            } else {
                view.markerTintColor = .systemBlue
                view.glyphImage = UIImage(systemName: "person.3.fill")
                view.glyphText = nil
            }

            return view
        }
    }
}

private enum AggregateRoutePolylineDecoder {
    static func decode(_ encodedPolyline: String) -> [CLLocationCoordinate2D] {
        guard encodedPolyline.isEmpty == false else { return [] }

        let bytes = Array(encodedPolyline.utf8)
        var coordinates: [CLLocationCoordinate2D] = []
        var index = 0
        var latitude = 0
        var longitude = 0

        while index < bytes.count {
            guard let latitudeDelta = nextComponent(bytes, index: &index),
                  let longitudeDelta = nextComponent(bytes, index: &index) else {
                break
            }

            latitude += latitudeDelta
            longitude += longitudeDelta

            coordinates.append(
                CLLocationCoordinate2D(
                    latitude: Double(latitude) * 1e-5,
                    longitude: Double(longitude) * 1e-5
                )
            )
        }

        return coordinates
    }

    private static func nextComponent(_ bytes: [UInt8], index: inout Int) -> Int? {
        var result = 0
        var shift = 0

        while index < bytes.count {
            let byte = Int(bytes[index]) - 63
            index += 1

            result |= (byte & 0x1F) << shift
            if byte < 0x20 {
                let value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
                return value
            }

            shift += 5
        }

        return nil
    }
}

private enum MissionAggregateRouteSheetError: LocalizedError {
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Chưa lấy được GPS thiết bị và cũng không có tọa độ team để bắt đầu chỉ đường."
        }
    }
}
