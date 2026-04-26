import Foundation
import Combine
import CoreLocation
import UIKit

protocol MissionActivityRemoteService {
    func getMyTeamMissions() async throws -> [Mission]
    func getActivities(missionId: Int) async throws -> [Activity]
    func getMyTeamActivities(missionId: Int) async throws -> [Activity]
    func updateActivityStatus(missionId: Int, activityId: Int, status: String, imageUrl: String?) async throws
    func updateMissionStatus(missionId: Int, status: String) async throws
}

protocol NetworkStatusProviding {
    var isConnected: Bool { get }
}

extension MissionService: MissionActivityRemoteService {}
extension NetworkMonitor: NetworkStatusProviding {}

@MainActor
final class RescuerMissionViewModel: ObservableObject {
    private enum CheckInLocationError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            L10n.RescuerMission.currentLocationUnavailable()
        }
    }

    @Published var team: RescueTeam?
    @Published var isLoadingTeam = false
    @Published var noTeamMessage: String?
    @Published var isUpdatingTeamAvailability = false
    @Published var isLeavingTeam = false
    @Published var missions: [Mission] = []
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var isLoadingActivities = false
    @Published var hasLoadedActivities = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published private(set) var currentTeamActivities: [Activity] = []
    @Published private(set) var currentTeamMissionTeamIds: Set<Int> = []
    @Published private(set) var pendingActivityUpdates: [PendingMissionActivityUpdate] = []
    @Published private(set) var activeActivitySubmissionIds: Set<Int> = []

    private var loadingCount = 0
    private let missionService: any MissionActivityRemoteService
    private let networkStatusProvider: any NetworkStatusProviding
    private let missionActivitySyncStore: MissionActivitySyncStore
    private let locationManager: LocationManager
    private let activityProofUploader = CloudinaryImageUploader.resQ(folder: "activities")
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

    func startLocationTracking() {
        locationManager.requestPermission()
        locationManager.startContinuousUpdates()
    }

    func stopLocationTracking() {
        locationManager.stopContinuousUpdates()
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
                        noTeamMessage = L10n.RescueTeam.notAssignedYet
                    } else {
                        noTeamMessage = message
                    }
                    return
                }

                errorMessage = serviceError.localizedDescription
            } catch {
                team = nil
                errorMessage = L10n.RescuerMission.cannotLoadTeamInfo(error.localizedDescription)
            }
        }
    }

    func checkIn() {
        guard let currentTeam = team else { return }
        guard let assemblyPointId = currentTeam.assemblyPointId else {
            errorMessage = L10n.RescuerMission.missingAssemblyPointId
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
                let coordinates = try await resolveCheckInCoordinates()
                let response = try await RescueTeamService.shared.checkIn(
                    eventId: eventId,
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude
                )
                team = try await RescueTeamService.shared.getMyTeam()
                successMessage = response.message ?? L10n.Common.checkInSucceeded
            } catch let serviceError as RescueTeamService.RescueTeamServiceError {
                errorMessage = L10n.RescuerMission.checkInFailed(serviceError.localizedDescription)
            } catch {
                errorMessage = L10n.RescuerMission.checkInFailed(error.localizedDescription)
            }
        }
    }

    private func resolveCheckInCoordinates() async throws -> (latitude: Double, longitude: Double) {
        let location: CLLocation? = await withCheckedContinuation { continuation in
            locationManager.requestLocation(forceFresh: true) { resolved in
                continuation.resume(returning: resolved)
            }
        }

        guard let resolvedLocation = location ?? locationManager.currentLocation else {
            throw CheckInLocationError.unavailable
        }

        guard resolvedLocation.coordinate.latitude != 0 || resolvedLocation.coordinate.longitude != 0 else {
            throw CheckInLocationError.unavailable
        }

        print(
            "[CheckIn] Resolved location lat=\(resolvedLocation.coordinate.latitude), lon=\(resolvedLocation.coordinate.longitude), accuracy=\(resolvedLocation.horizontalAccuracy), timestamp=\(resolvedLocation.timestamp)"
        )

        return (resolvedLocation.coordinate.latitude, resolvedLocation.coordinate.longitude)
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
                successMessage = message ?? L10n.RescuerMission.teamAvailable
            } catch let serviceError as RescueTeamService.RescueTeamServiceError {
                errorMessage = serviceError.localizedDescription
            } catch {
                errorMessage = L10n.RescuerMission.cannotUpdateTeamStatus(error.localizedDescription)
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
                successMessage = message ?? L10n.RescuerMission.teamUnavailable
            } catch let serviceError as RescueTeamService.RescueTeamServiceError {
                errorMessage = serviceError.localizedDescription
            } catch {
                errorMessage = L10n.RescuerMission.cannotUpdateTeamStatus(error.localizedDescription)
            }
        }
    }

    var isTeamAssignedOrOnMission: Bool {
        ["assigned", "onmission"].contains(normalizedTeamStatus(team?.status))
    }

    var canLeaveCurrentTeam: Bool {
        team != nil && isTeamAssignedOrOnMission == false
    }

    func leaveCurrentTeam() {
        guard team != nil else { return }
        guard isLeavingTeam == false else { return }
        guard canLeaveCurrentTeam else {
            errorMessage = L10n.RescuerMission.cannotLeaveTeamDuringAssignedOrOnMission
            return
        }

        errorMessage = nil
        successMessage = nil
        isLeavingTeam = true
        beginLoading()

        Task {
            defer {
                isLeavingTeam = false
                endLoading()
            }

            do {
                let message = try await RescueTeamService.shared.leaveMyTeam()
                team = nil
                missions = []
                activities = []
                currentTeamActivities = []
                currentTeamMissionTeamIds = []
                noTeamMessage = L10n.RescueTeam.notAssignedYet
                successMessage = message ?? L10n.RescuerMission.leaveTeamSucceeded
            } catch let serviceError as RescueTeamService.RescueTeamServiceError {
                errorMessage = serviceError.localizedDescription
            } catch {
                errorMessage = L10n.RescuerMission.cannotLeaveTeam(error.localizedDescription)
            }
        }
    }

    func removeTeamMember(userId: String) {
        guard let teamId = team?.id else { return }
        errorMessage = nil
        successMessage = nil
        beginLoading()

        Task {
            defer { endLoading() }
            do {
                let message = try await RescueTeamService.shared.removeTeamMember(teamId: teamId, userId: userId)
                successMessage = message ?? "Đã xóa thành viên khỏi đội."
                team = try await RescueTeamService.shared.getMyTeam()
            } catch let serviceError as RescueTeamService.RescueTeamServiceError {
                errorMessage = serviceError.localizedDescription
            } catch {
                errorMessage = "Không thể xóa thành viên: \(error.localizedDescription)"
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
                errorMessage = L10n.RescuerMission.cannotLoadMissions(error.localizedDescription)
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
                try await refreshActivityScopes(missionId: missionId)
            } catch {
                errorMessage = L10n.RescuerMission.cannotLoadActivities(error.localizedDescription)
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

        Task {
            _ = await submitActivityStatus(
                missionId: missionId,
                activityId: activityId,
                status: status,
                knownActivities: knownActivities,
                imageUrl: nil
            )
        }
    }

    func completeActivity(
        missionId: Int,
        activityId: Int,
        knownActivities: [Activity] = [],
        proofImage: UIImage?
    ) async -> Bool {
        guard beginActivitySubmission(activityId) else {
            return false
        }
        defer { endActivitySubmission(activityId) }

        errorMessage = nil
        successMessage = nil

        do {
            let proofImageURL = try await uploadProofImageIfNeeded(proofImage)
            return await submitActivityStatus(
                missionId: missionId,
                activityId: activityId,
                status: ActivityStatus.succeed.rawValue,
                knownActivities: knownActivities,
                imageUrl: proofImageURL
            )
        } catch {
            errorMessage = L10n.RescuerMission.activityStatusUpdateFailed(error.localizedDescription)
            hasLoadedActivities = true
            return false
        }
    }

    func confirmPickup(
        missionId: Int,
        activityId: Int,
        bufferUsages: [MissionPickupBufferUsageRequest],
        proofImage: UIImage? = nil
    ) async -> Bool {
        guard beginActivitySubmission(activityId) else {
            return false
        }
        defer { endActivitySubmission(activityId) }

        errorMessage = nil
        successMessage = nil
        isLoadingActivities = true

        defer {
            isLoadingActivities = false
            hasLoadedActivities = true
        }

        do {
            let proofImageURL = try await uploadProofImageIfNeeded(proofImage)

            _ = try await MissionService.shared.confirmActivityPickup(
                missionId: missionId,
                activityId: activityId,
                bufferUsages: bufferUsages
            )
            try await refreshActivityScopes(missionId: missionId)

            let shouldPatchStatus = proofImageURL != nil
                || latestActivityStatus(activityId: activityId) != .succeed

            if shouldPatchStatus {
                try await updateActivityStatusAllowingDuplicateCompletion(
                    missionId: missionId,
                    activityId: activityId,
                    status: ActivityStatus.succeed.rawValue,
                    imageUrl: proofImageURL
                )

                try await refreshActivityScopes(missionId: missionId)
            }

            successMessage = L10n.RescuerMission.supplyPickupConfirmed
            return true
        } catch {
            errorMessage = L10n.RescuerMission.supplyPickupFailed(error.localizedDescription)
            return false
        }
    }

    func confirmDelivery(
        missionId: Int,
        activityId: Int,
        actualDeliveredItems: [MissionActualDeliveredItemRequest],
        deliveryNote: String?,
        proofImage: UIImage? = nil
    ) async -> Bool {
        guard beginActivitySubmission(activityId) else {
            return false
        }
        defer { endActivitySubmission(activityId) }

        errorMessage = nil
        successMessage = nil
        isLoadingActivities = true

        defer {
            isLoadingActivities = false
            hasLoadedActivities = true
        }

        do {
            let proofImageURL = try await uploadProofImageIfNeeded(proofImage)

            let response = try await MissionService.shared.confirmActivityDelivery(
                missionId: missionId,
                activityId: activityId,
                actualDeliveredItems: actualDeliveredItems,
                deliveryNote: deliveryNote
            )
            try await refreshActivityScopes(missionId: missionId)

            let deliveryStatusKey = normalizedActivityStatusKey(response.status)
            let shouldPatchStatus = proofImageURL != nil || deliveryStatusKey != "succeed"

            if shouldPatchStatus {
                try await updateActivityStatusAllowingDuplicateCompletion(
                    missionId: missionId,
                    activityId: activityId,
                    status: ActivityStatus.succeed.rawValue,
                    imageUrl: proofImageURL
                )

                try await refreshActivityScopes(missionId: missionId)
            }

            successMessage = response.message
            return true
        } catch {
            errorMessage = L10n.RescuerMission.supplyDeliveryFailed(error.localizedDescription)
            return false
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
            successMessage = L10n.RescuerMission.missionStatusUpdated
            return true
        } catch {
            errorMessage = L10n.RescuerMission.missionStatusUpdateFailed(error.localizedDescription)
            return false
        }
    }

    func effectiveActivities(missionId: Int, fallback: [Activity] = []) -> [Activity] {
        let source = baseActivities(fallback: fallback)
        let merged = missionActivitySyncStore.effectiveActivities(base: source, missionId: missionId)
        return sortActivities(merged)
    }

    func effectiveCurrentTeamActivities(
        missionId: Int,
        fallback: [Activity] = [],
        fallbackMissionTeamId: Int? = nil
    ) -> [Activity] {
        let source = baseCurrentTeamActivities(
            fallback: fallback,
            fallbackMissionTeamId: fallbackMissionTeamId
        )
        let merged = missionActivitySyncStore.effectiveActivities(base: source, missionId: missionId)
        return sortActivities(merged)
    }

    func belongsToCurrentTeam(_ activity: Activity, fallbackMissionTeamId: Int? = nil) -> Bool {
        let missionTeamIds = resolvedCurrentTeamMissionTeamIds(fallbackMissionTeamId: fallbackMissionTeamId)
        guard missionTeamIds.isEmpty == false else { return false }

        guard let missionTeamId = activity.missionTeamId else {
            return false
        }

        return missionTeamIds.contains(missionTeamId)
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

    private func submitActivityStatus(
        missionId: Int,
        activityId: Int,
        status: String,
        knownActivities: [Activity],
        imageUrl: String?
    ) async -> Bool {
        guard missionActivitySyncStore.hasPendingUpdate(missionId: missionId, activityId: activityId) == false else {
            errorMessage = L10n.RescuerMission.activityWaitingServerSync
            hasLoadedActivities = true
            return false
        }

        if networkStatusProvider.isConnected == false {
            if imageUrl != nil {
                errorMessage = L10n.RescuerMission.proofImageRequiresConnection
                hasLoadedActivities = true
                return false
            }

            let baseActivities = baseActivities(fallback: knownActivities)
            guard let baseActivity = baseActivities.first(where: { $0.id == activityId }) else {
                errorMessage = L10n.RescuerMission.missingLocalActivity
                hasLoadedActivities = true
                return false
            }

            let queued = missionActivitySyncStore.enqueue(
                missionId: missionId,
                activityId: activityId,
                targetStatus: status,
                baseServerStatus: baseActivity.status
            )

            guard queued != nil else {
                errorMessage = L10n.RescuerMission.cannotSaveOfflineAction
                hasLoadedActivities = true
                return false
            }

            if activities.isEmpty, baseActivities.isEmpty == false {
                activities = sortActivities(baseActivities)
            }

            hasLoadedActivities = true
            successMessage = L10n.RescuerMission.offlineSavedWaitingSync
            return true
        }

        isLoadingActivities = true
        defer {
            isLoadingActivities = false
            hasLoadedActivities = true
        }

        do {
            try await missionService.updateActivityStatus(
                missionId: missionId,
                activityId: activityId,
                status: status,
                imageUrl: imageUrl
            )
            try await refreshActivityScopes(missionId: missionId)
            successMessage = L10n.RescuerMission.activityStatusUpdated
            return true
        } catch {
            errorMessage = L10n.RescuerMission.activityStatusUpdateFailed(error.localizedDescription)
            return false
        }
    }

    private func latestActivityStatus(activityId: Int) -> ActivityStatus? {
        if let status = currentTeamActivities.first(where: { $0.id == activityId })?.activityStatus {
            return status
        }

        return activities.first(where: { $0.id == activityId })?.activityStatus
    }

    private func updateActivityStatusAllowingDuplicateCompletion(
        missionId: Int,
        activityId: Int,
        status: String,
        imageUrl: String?
    ) async throws {
        do {
            try await missionService.updateActivityStatus(
                missionId: missionId,
                activityId: activityId,
                status: status,
                imageUrl: imageUrl
            )
        } catch {
            guard status.caseInsensitiveCompare(ActivityStatus.succeed.rawValue) == .orderedSame,
                  isDuplicateStatusTransitionError(error, status: status) else {
                throw error
            }

            // Confirmation endpoints may already complete the activity server-side.
        }
    }

    private func isDuplicateStatusTransitionError(_ error: Error, status: String) -> Bool {
        let target = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard target.isEmpty == false else { return false }

        let rawMessage: String
        if let serviceError = error as? MissionServiceError {
            switch serviceError {
            case .httpStatus(_, let message):
                rawMessage = message ?? serviceError.localizedDescription
            case .invalidResponse:
                rawMessage = serviceError.localizedDescription
            }
        } else {
            rawMessage = error.localizedDescription
        }

        let normalizedMessage = rawMessage.lowercased()
        let singleQuoteMatch = "'\(target)'"
        let doubleQuoteMatch = "\"\(target)\""
        let singleQuoteCount = normalizedMessage.components(separatedBy: singleQuoteMatch).count - 1
        let doubleQuoteCount = normalizedMessage.components(separatedBy: doubleQuoteMatch).count - 1

        return singleQuoteCount >= 2 || doubleQuoteCount >= 2
    }

    private func uploadProofImageIfNeeded(_ proofImage: UIImage?) async throws -> String? {
        guard let proofImage else {
            return nil
        }

        guard networkStatusProvider.isConnected else {
            throw URLError(.notConnectedToInternet)
        }

        return try await activityProofUploader.upload(image: proofImage, fileNamePrefix: "activity")
    }

    private func beginActivitySubmission(_ activityId: Int) -> Bool {
        guard activeActivitySubmissionIds.contains(activityId) == false else {
            return false
        }

        activeActivitySubmissionIds.insert(activityId)
        return true
    }

    private func endActivitySubmission(_ activityId: Int) {
        activeActivitySubmissionIds.remove(activityId)
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

    private func baseCurrentTeamActivities(
        fallback: [Activity],
        fallbackMissionTeamId: Int?
    ) -> [Activity] {
        if currentTeamActivities.isEmpty == false {
            return currentTeamActivities
        }

        guard let fallbackMissionTeamId else { return [] }
        let source = baseActivities(fallback: fallback)
        return source.filter { $0.missionTeamId == fallbackMissionTeamId }
    }

    private func resolvedCurrentTeamMissionTeamIds(fallbackMissionTeamId: Int?) -> Set<Int> {
        if currentTeamMissionTeamIds.isEmpty == false {
            return currentTeamMissionTeamIds
        }

        if let fallbackMissionTeamId {
            return Set([fallbackMissionTeamId])
        }

        return []
    }

    private func refreshActivityScopes(missionId: Int) async throws {
        async let fullMissionActivitiesRequest = missionService.getActivities(missionId: missionId)
        async let myTeamActivitiesRequest = missionService.getMyTeamActivities(missionId: missionId)

        let fullMissionActivities = try await fullMissionActivitiesRequest
        activities = sortActivities(fullMissionActivities)

        let myTeamActivities = (try? await myTeamActivitiesRequest) ?? []
        currentTeamActivities = sortActivities(myTeamActivities)
        currentTeamMissionTeamIds = Set(myTeamActivities.compactMap(\.missionTeamId))
    }

    private func beginLoading() {
        loadingCount += 1
        isLoading = true
    }

    private func endLoading() {
        loadingCount = max(loadingCount - 1, 0)
        isLoading = loadingCount > 0
    }

    private func normalizedTeamStatus(_ status: String?) -> String {
        (status ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}

@MainActor
final class RescuerAssemblyEventsViewModel: ObservableObject {
    enum AssemblyEventAction {
        case checkIn
        case checkOut
    }

    private enum CheckInLocationError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            L10n.RescuerMission.currentLocationUnavailable()
        }
    }

    @Published var events: [AssemblyPointEvent] = []
    @Published var isLoading = false
    @Published var loadingEventId: Int?
    @Published var loadingAction: AssemblyEventAction?
    @Published private(set) var teamStatus: String?
    @Published private(set) var checkedOutEventIds: Set<Int> = []
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private(set) var pageNumber = 1
    private(set) var pageSize = 10
    private let locationManager: LocationManager

    var isTeamAssignedOrOnMission: Bool {
        ["assigned", "onmission"].contains(normalizedTeamStatus(teamStatus))
    }

    init(locationManager: LocationManager? = nil) {
        self.locationManager = locationManager ?? .shared
    }

    func hasCheckedOut(event: AssemblyPointEvent) -> Bool {
        event.hasCheckedOut || checkedOutEventIds.contains(event.eventId)
    }

    func startLocationTracking() {
        locationManager.requestPermission()
        locationManager.startContinuousUpdates()
    }

    func stopLocationTracking() {
        locationManager.stopContinuousUpdates()
    }

    func refresh(pageNumber: Int = 1, pageSize: Int = 10) {
        self.pageNumber = pageNumber
        self.pageSize = pageSize
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }

            do {
                let team = try await RescueTeamService.shared.getMyTeam()
                teamStatus = team.status
            } catch {
                teamStatus = nil
            }

            do {
                let fetchedEvents = try await RescueTeamService.shared.getMyUpcomingAssemblyPointEvents()
                events = fetchedEvents

                let backendCheckedOutEventIds = Set(
                    fetchedEvents
                        .filter(\.hasCheckedOut)
                        .map(\.eventId)
                )
                checkedOutEventIds.formUnion(backendCheckedOutEventIds)

                let visibleEventIds = Set(fetchedEvents.map(\.eventId))
                checkedOutEventIds = checkedOutEventIds.intersection(visibleEventIds)
            } catch {
                errorMessage = L10n.RescuerMission.cannotLoadAssemblyEvents(error.localizedDescription)
            }
        }
    }

    func checkIn(event: AssemblyPointEvent) {
        guard loadingEventId == nil else { return }
        guard event.isCheckedIn == false else { return }
        guard hasCheckedOut(event: event) == false else { return }
        guard event.assemblyEventStatus != .completed else { return }

        errorMessage = nil
        successMessage = nil
        loadingEventId = event.eventId
        loadingAction = .checkIn

        Task {
            defer {
                loadingEventId = nil
                loadingAction = nil
            }
            do {
                let coordinates = try await resolveCheckInCoordinates()
                let response = try await RescueTeamService.shared.checkIn(
                    eventId: event.eventId,
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude
                )
                successMessage = response.message ?? L10n.Common.checkInSucceeded
                refresh(pageNumber: pageNumber, pageSize: pageSize)
            } catch let serviceError as RescueTeamService.RescueTeamServiceError {
                errorMessage = L10n.RescuerMission.checkInFailed(serviceError.localizedDescription)
            } catch {
                errorMessage = L10n.RescuerMission.checkInFailed(error.localizedDescription)
            }
        }
    }

    func checkOut(event: AssemblyPointEvent) {
        guard loadingEventId == nil else { return }
        guard event.isCheckedIn else { return }

        errorMessage = nil
        successMessage = nil
        loadingEventId = event.eventId
        loadingAction = .checkOut

        Task {
            defer {
                loadingEventId = nil
                loadingAction = nil
            }
            do {
                let coordinates = try await resolveCheckInCoordinates()
                let response = try await RescueTeamService.shared.checkOut(
                    eventId: event.eventId,
                    latitude: coordinates.latitude,
                    longitude: coordinates.longitude
                )
                checkedOutEventIds.insert(event.eventId)
                successMessage = response.message ?? L10n.Common.checkOutSucceeded
                refresh(pageNumber: pageNumber, pageSize: pageSize)
            } catch let serviceError as RescueTeamService.RescueTeamServiceError {
                errorMessage = L10n.RescuerMission.checkOutFailed(serviceError.localizedDescription)
            } catch {
                errorMessage = L10n.RescuerMission.checkOutFailed(error.localizedDescription)
            }
        }
    }

    private func resolveCheckInCoordinates() async throws -> (latitude: Double, longitude: Double) {
        let location: CLLocation? = await withCheckedContinuation { continuation in
            locationManager.requestLocation(forceFresh: true) { resolved in
                continuation.resume(returning: resolved)
            }
        }

        guard let resolvedLocation = location ?? locationManager.currentLocation else {
            throw CheckInLocationError.unavailable
        }

        guard resolvedLocation.coordinate.latitude != 0 || resolvedLocation.coordinate.longitude != 0 else {
            throw CheckInLocationError.unavailable
        }

        print(
            "[AssemblyCheckIn] Resolved location lat=\(resolvedLocation.coordinate.latitude), lon=\(resolvedLocation.coordinate.longitude), accuracy=\(resolvedLocation.horizontalAccuracy), timestamp=\(resolvedLocation.timestamp)"
        )

        return (resolvedLocation.coordinate.latitude, resolvedLocation.coordinate.longitude)
    }

    private func normalizedTeamStatus(_ status: String?) -> String {
        (status ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}
