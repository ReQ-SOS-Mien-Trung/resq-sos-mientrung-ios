import Foundation
import Combine

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
        guard let teamId = team?.id else { return }
        errorMessage = nil
        successMessage = nil
        beginLoading()
        Task {
            defer { endLoading() }
            do {
                _ = try await RescueTeamService.shared.checkIn(teamId: teamId)
                team = try await RescueTeamService.shared.getMyTeam()
                successMessage = "Check-in thành công!"
            } catch {
                errorMessage = "Check-in thất bại: \(error.localizedDescription)"
            }
        }
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
