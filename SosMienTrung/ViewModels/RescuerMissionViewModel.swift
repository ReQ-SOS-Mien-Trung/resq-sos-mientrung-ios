import Foundation
import Combine
import CoreLocation

@MainActor
final class RescuerMissionViewModel: ObservableObject {
    @Published var team: RescueTeam?
    @Published var missions: [Mission] = []
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var isLoadingActivities = false
    @Published var hasLoadedActivities = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var loadingCount = 0
    private let locationManager = LocationManager()

    func refreshDashboard() {
        errorMessage = nil
        loadTeam()
        loadMissions()
    }

    func loadTeam() {
        beginLoading()
        Task {
            defer { endLoading() }
            do {
                team = try await RescueTeamService.shared.getMyTeam()
            } catch {
                errorMessage = "Không thể tải thông tin team: \(error.localizedDescription)"
            }
        }
    }

    func checkIn() {
        guard let currentTeam = team else { return }
        guard let assemblyPointId = currentTeam.assemblyPointId else {
            errorMessage = "Không tìm thấy assemblyPointId để check-in. Vui lòng đồng bộ lại dữ liệu team."
            return
        }

        errorMessage = nil
        successMessage = nil
        beginLoading()

        Task {
            defer { endLoading() }
            do {
                let eventId = try await RescueTeamService.shared.resolveCheckInEventId(
                    assemblyPointId: assemblyPointId,
                    preferredEventId: currentTeam.eventId
                )
                let coordinates = await resolveCheckInCoordinates()
                let response = try await RescueTeamService.shared.checkIn(
                    eventId: eventId,
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude
                )
                team = try await RescueTeamService.shared.getMyTeam()
                successMessage = response.message ?? "Check-in thành công"
            } catch let serviceError as RescueTeamService.RescueTeamServiceError {
                errorMessage = "Check-in thất bại: \(serviceError.localizedDescription)"
            } catch {
                errorMessage = "Check-in thất bại: \(error.localizedDescription)"
            }
        }
    }

    private func resolveCheckInCoordinates() async -> (latitude: Double, longitude: Double) {
        if let coordinates = locationManager.coordinates {
            return coordinates
        }

        let location: CLLocation? = await withCheckedContinuation { continuation in
            locationManager.requestLocation { resolved in
                continuation.resume(returning: resolved)
            }
        }

        guard let location else {
            // Keep request compatible with backend contract even if GPS fix is unavailable.
            return (latitude: 0, longitude: 0)
        }

        return (location.coordinate.latitude, location.coordinate.longitude)
    }

    func loadMissions() {
        beginLoading()
        Task {
            defer { endLoading() }
            do {
                missions = try await MissionService.shared.getMyTeamMissions()
            } catch {
                errorMessage = "Không thể tải danh sách nhiệm vụ: \(error.localizedDescription)"
            }
        }
    }

    func loadActivities(missionId: Int) {
        errorMessage = nil
        isLoadingActivities = true
        hasLoadedActivities = false
        Task {
            defer {
                isLoadingActivities = false
                hasLoadedActivities = true
            }
            do {
                activities = try await MissionService.shared.getActivities(missionId: missionId)
            } catch {
                errorMessage = "Không thể tải danh sách hoạt động: \(error.localizedDescription)"
            }
        }
    }

    func updateActivity(missionId: Int, activityId: Int, status: String) {
        errorMessage = nil
        successMessage = nil
        isLoadingActivities = true
        Task {
            defer {
                isLoadingActivities = false
                hasLoadedActivities = true
            }
            do {
                try await MissionService.shared.updateActivityStatus(missionId: missionId, activityId: activityId, status: status)
                activities = try await MissionService.shared.getActivities(missionId: missionId)
                successMessage = "Đã cập nhật: \(status)"
            } catch {
                errorMessage = "Cập nhật thất bại: \(error.localizedDescription)"
            }
        }
    }

    private func beginLoading() {
        loadingCount += 1
        isLoading = true
    }

    private func endLoading() {
        loadingCount = max(loadingCount - 1, 0)
        isLoading = loadingCount > 0
    }
}
