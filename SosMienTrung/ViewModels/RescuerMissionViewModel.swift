import Foundation
import Combine
import CoreLocation

protocol MissionActivityRemoteService {
    func getMyTeamMissions() async throws -> [Mission]
    func getMyTeamActivities(missionId: Int) async throws -> [Activity]
    func updateActivityStatus(missionId: Int, activityId: Int, status: String) async throws
    func updateMissionStatus(missionId: Int, status: String) async throws
}

protocol NetworkStatusProviding {
    var isConnected: Bool { get }
}

extension MissionService: MissionActivityRemoteService {}
extension NetworkMonitor: NetworkStatusProviding {}

@MainActor
final class RescuerMissionViewModel: ObservableObject {
    @Published var team: RescueTeam?
    @Published var isLoadingTeam = false
    @Published var noTeamMessage: String?
    @Published var isUpdatingTeamAvailability = false
    @Published var missions: [Mission] = []
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var isLoadingActivities = false
    @Published var hasLoadedActivities = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published private(set) var pendingActivityUpdates: [PendingMissionActivityUpdate] = []

    private var loadingCount = 0
    private let missionService: any MissionActivityRemoteService
    private let networkStatusProvider: any NetworkStatusProviding
    private let missionActivitySyncStore: MissionActivitySyncStore
    private let locationManager: LocationManager
    private var cancellables: Set<AnyCancellable> = []

    init(
        missionService: (any MissionActivityRemoteService)? = nil,
        networkStatusProvider: (any NetworkStatusProviding)? = nil,
        missionActivitySyncStore: MissionActivitySyncStore? = nil,
        locationManager: LocationManager? = nil
    ) {
        let resolvedMissionService = missionService ?? MissionService.shared
        let resolvedNetworkStatusProvider = networkStatusProvider ?? NetworkMonitor.shared
        let resolvedMissionActivitySyncStore = missionActivitySyncStore ?? .shared
        let resolvedLocationManager = locationManager ?? LocationManager()

        self.missionService = resolvedMissionService
        self.networkStatusProvider = resolvedNetworkStatusProvider
        self.missionActivitySyncStore = resolvedMissionActivitySyncStore
        self.locationManager = resolvedLocationManager
        self.pendingActivityUpdates = resolvedMissionActivitySyncStore.updates

        resolvedMissionActivitySyncStore.$updates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updates in
                self?.pendingActivityUpdates = updates
            }
            .store(in: &cancellables)
    }

    func refreshDashboard() {
        errorMessage = nil
        loadTeam()
        loadMissions()
    }

    func loadTeam() {
        beginLoading()
        isLoadingTeam = true
        noTeamMessage = nil
        Task {
            defer {
                isLoadingTeam = false
                endLoading()
            }
            do {
                team = try await RescueTeamService.shared.getMyTeam()
            } catch let serviceError as RescueTeamService.RescueTeamServiceError {
                team = nil

                if case .httpError(let status, let message) = serviceError, status == 404 {
                    // 404 from /my means rescuer is not assigned to any team yet.
                    if message.isEmpty {
                        noTeamMessage = "Bạn chưa được phân vào đội cứu hộ."
                    } else {
                        noTeamMessage = message
                    }
                    return
                }

                errorMessage = serviceError.localizedDescription
            } catch {
                team = nil
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

    func setTeamAvailable() {
        guard let currentTeam = team else { return }
        guard isUpdatingTeamAvailability == false else { return }

        errorMessage = nil
        successMessage = nil
        isUpdatingTeamAvailability = true
        beginLoading()

        Task {
            defer {
                isUpdatingTeamAvailability = false
                endLoading()
            }
            do {
                let message = try await RescueTeamService.shared.setTeamAvailable(teamId: currentTeam.id)
                team = try await RescueTeamService.shared.getMyTeam()
                successMessage = message ?? "Đội đã sẵn sàng nhận nhiệm vụ"
            } catch let serviceError as RescueTeamService.RescueTeamServiceError {
                errorMessage = serviceError.localizedDescription
            } catch {
                errorMessage = "Không thể cập nhật trạng thái đội: \(error.localizedDescription)"
            }
        }
    }

    func setTeamUnavailable() {
        guard let currentTeam = team else { return }
        guard isUpdatingTeamAvailability == false else { return }

        errorMessage = nil
        successMessage = nil
        isUpdatingTeamAvailability = true
        beginLoading()

        Task {
            defer {
                isUpdatingTeamAvailability = false
                endLoading()
            }
            do {
                let message = try await RescueTeamService.shared.setTeamUnavailable(teamId: currentTeam.id)
                team = try await RescueTeamService.shared.getMyTeam()
                successMessage = message ?? "Đội đã chuyển sang trạng thái không sẵn sàng"
            } catch let serviceError as RescueTeamService.RescueTeamServiceError {
                errorMessage = serviceError.localizedDescription
            } catch {
                errorMessage = "Không thể cập nhật trạng thái đội: \(error.localizedDescription)"
            }
        }
    }

    func loadMissions() {
        beginLoading()
        Task {
            defer { endLoading() }
            do {
                missions = try await missionService.getMyTeamMissions()
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
                let fetched = try await missionService.getMyTeamActivities(missionId: missionId)
                activities = sortActivities(fetched)
            } catch {
                errorMessage = "Không thể tải danh sách hoạt động: \(error.localizedDescription)"
            }
        }
    }

    func updateActivity(
        missionId: Int,
        activityId: Int,
        status: String,
        knownActivities: [Activity] = []
    ) {
        errorMessage = nil
        successMessage = nil

        guard missionActivitySyncStore.hasPendingUpdate(missionId: missionId, activityId: activityId) == false else {
            errorMessage = "Hoạt động này đang chờ đồng bộ máy chủ."
            hasLoadedActivities = true
            return
        }

        if networkStatusProvider.isConnected == false {
            let baseActivities = baseActivities(fallback: knownActivities)
            guard let baseActivity = baseActivities.first(where: { $0.id == activityId }) else {
                errorMessage = "Không tìm thấy hoạt động để lưu cục bộ."
                hasLoadedActivities = true
                return
            }

            let queued = missionActivitySyncStore.enqueue(
                missionId: missionId,
                activityId: activityId,
                targetStatus: status,
                baseServerStatus: baseActivity.status
            )

            guard queued != nil else {
                errorMessage = "Không thể lưu thao tác offline cho hoạt động này."
                hasLoadedActivities = true
                return
            }

            if activities.isEmpty, baseActivities.isEmpty == false {
                activities = sortActivities(baseActivities)
            }

            hasLoadedActivities = true
            successMessage = "Đã lưu cục bộ. Hoạt động đang chờ đồng bộ máy chủ."
            return
        }

        isLoadingActivities = true
        Task {
            defer {
                isLoadingActivities = false
                hasLoadedActivities = true
            }
            do {
                try await missionService.updateActivityStatus(missionId: missionId, activityId: activityId, status: status)
                let refreshed = try await missionService.getMyTeamActivities(missionId: missionId)
                activities = sortActivities(refreshed)
                successMessage = "Đã cập nhật: \(status)"
            } catch {
                errorMessage = "Cập nhật thất bại: \(error.localizedDescription)"
            }
        }
    }

    func updateMissionStatus(missionId: Int, status: String) async -> Bool {
        errorMessage = nil
        successMessage = nil
        beginLoading()

        defer { endLoading() }

        do {
            try await missionService.updateMissionStatus(missionId: missionId, status: status)
            missions = try await missionService.getMyTeamMissions()
            successMessage = "Đã cập nhật trạng thái nhiệm vụ"
            return true
        } catch {
            errorMessage = "Không thể cập nhật trạng thái nhiệm vụ: \(error.localizedDescription)"
            return false
        }
    }

    func effectiveActivities(missionId: Int, fallback: [Activity] = []) -> [Activity] {
        let source = baseActivities(fallback: fallback)
        let merged = missionActivitySyncStore.effectiveActivities(base: source, missionId: missionId)
        return sortActivities(merged)
    }

    func pendingSyncState(missionId: Int, activityId: Int) -> MissionActivitySyncState? {
        missionActivitySyncStore.syncState(for: missionId, activityId: activityId)
    }

    func hasPendingSync(missionId: Int, activityId: Int) -> Bool {
        missionActivitySyncStore.hasPendingUpdate(missionId: missionId, activityId: activityId)
    }

    func pendingSyncCount(for missionId: Int) -> Int {
        missionActivitySyncStore.pendingCount(for: missionId)
    }

    func triggerMissionActivitySync(reason: MissionActivitySyncTriggerReason) {
        missionActivitySyncStore.triggerDeferredSync(reason: reason)
    }

    private func sortActivities(_ items: [Activity]) -> [Activity] {
        items.sorted { lhs, rhs in
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

    private func baseActivities(fallback: [Activity]) -> [Activity] {
        activities.isEmpty ? fallback : activities
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

@MainActor
final class RescuerAssemblyEventsViewModel: ObservableObject {
    @Published var events: [AssemblyPointEvent] = []
    @Published var isLoading = false
    @Published var loadingEventId: Int?
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private(set) var pageNumber = 1
    private(set) var pageSize = 10
    private let locationManager = LocationManager()

    func refresh(pageNumber: Int = 1, pageSize: Int = 10) {
        self.pageNumber = pageNumber
        self.pageSize = pageSize
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                let response = try await RescueTeamService.shared.getMyAssemblyPointEvents(
                    pageNumber: pageNumber,
                    pageSize: pageSize
                )
                events = response.items
            } catch {
                errorMessage = "Không thể tải danh sách sự kiện tập kết: \(error.localizedDescription)"
            }
        }
    }

    func checkIn(event: AssemblyPointEvent) {
        guard loadingEventId == nil else { return }
        guard event.isCheckedIn == false else { return }

        errorMessage = nil
        successMessage = nil
        loadingEventId = event.eventId

        Task {
            defer { loadingEventId = nil }
            do {
                let coordinates = await resolveCheckInCoordinates()
                let response = try await RescueTeamService.shared.checkIn(
                    eventId: event.eventId,
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude
                )
                successMessage = response.message ?? "Check-in thành công"
                refresh(pageNumber: pageNumber, pageSize: pageSize)
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
            return (latitude: 0, longitude: 0)
        }

        return (location.coordinate.latitude, location.coordinate.longitude)
    }
}
