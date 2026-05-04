import Foundation
import Combine
import SignalRClient

struct MissionRealtimeUpdate: Decodable {
    let entityId: Int?
    let entityType: String?
    let action: String?
    let status: String?
    let changedAt: String?
    let missionId: Int
    let clusterId: Int?
}

struct MissionActivityRealtimeUpdate: Decodable {
    let entityId: Int?
    let entityType: String?
    let action: String?
    let status: String?
    let changedAt: String?
    let activityId: Int
    let missionId: Int?
    let depotId: Int?
}

struct MissionExecutionAffectedActivity: Decodable {
    let missionActivityId: Int
    let orderIndex: Int?
    let isPrimary: Bool?
    let step: Int?
    let activityType: String?
    let status: String?
}

struct MissionExecutionProgressRealtimeUpdate: Decodable {
    let entityId: Int?
    let entityType: String?
    let action: String?
    let status: String?
    let changedAt: String?
    let eventId: String?
    let missionId: Int
    let activityId: Int?
    let missionTeamId: Int?
    let rescueTeamId: Int?
    let depotId: Int?
    let step: Int?
    let activityType: String?
    let previousStatus: String?
    let requestedStatus: String?
    let effectiveStatus: String?
    let imageUrl: String?
    let changedBy: String?
    let clientMutationId: String?
    let syncOutcome: String?
    let incidentId: Int?
    let incidentScope: String?
    let affectedActivities: [MissionExecutionAffectedActivity]?
    let note: String?
    let safetyLatestCheckInAt: String?
    let safetyTimeoutAt: String?
    let safetyStatus: String?
    let requeryRecommended: Bool?
}

struct MissionRealtimeActivityStatusUpdate {
    let missionId: Int
    let activityId: Int
    let status: String
    let changedAt: String?
}

@MainActor
final class MissionRealtimeService: ObservableObject {
    @Published private(set) var isConnected = false
    @Published var errorMessage: String?

    var onMissionUpdate: ((MissionRealtimeUpdate) -> Void)?
    var onActivityStatusUpdate: ((MissionRealtimeActivityStatusUpdate) -> Void)?
    var onRefreshRecommended: (() -> Void)?

    private var connection: HubConnection?
    private var connectionDelegate: MissionRealtimeConnectionDelegateProxy?
    private var activeAccessToken: String?
    private var subscribedMissionId: Int?
    private let baseURL: String

    init(baseURL: String? = nil) {
        self.baseURL = baseURL ?? AppConfig.baseURLString
    }

    func connect(missionId: Int) {
        subscribedMissionId = missionId

        Task { @MainActor [weak self] in
            await self?.connectIfNeeded()
        }
    }

    func disconnect() {
        unsubscribeActiveMission()
        connection?.stop()
        connection = nil
        connectionDelegate = nil
        activeAccessToken = nil
        subscribedMissionId = nil
        isConnected = false
        errorMessage = nil
        onMissionUpdate = nil
        onActivityStatusUpdate = nil
        onRefreshRecommended = nil
    }

    private func connectIfNeeded() async {
        guard AuthSessionStore.shared.hasAuthenticatedSession else {
            disconnect()
            return
        }

        do {
            let token = try await AuthSessionStore.shared.validAccessToken()

            if connection != nil, activeAccessToken == token {
                if isConnected == false {
                    connection?.start()
                }
                subscribeActiveMission()
                return
            }

            let missionId = subscribedMissionId
            let missionUpdateHandler = onMissionUpdate
            let activityStatusHandler = onActivityStatusUpdate
            let refreshHandler = onRefreshRecommended
            disconnect()
            subscribedMissionId = missionId
            onMissionUpdate = missionUpdateHandler
            onActivityStatusUpdate = activityStatusHandler
            onRefreshRecommended = refreshHandler

            guard let url = makeHubURL(accessToken: token) else {
                errorMessage = "URL realtime nhiệm vụ không hợp lệ."
                return
            }

            activeAccessToken = token

            let connection = HubConnectionBuilder(url: url)
                .withLogging(minLogLevel: .warning)
                .withHubConnectionDelegate(delegate: makeConnectionDelegate())
                .withAutoReconnect()
                .build()

            self.connection = connection
            registerHandlers(for: connection)
            connection.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func registerHandlers(for connection: HubConnection) {
        connection.on(method: "ReceiveMissionUpdate") { [weak self] argumentExtractor in
            Task { @MainActor [weak self] in
                guard let self else { return }

                do {
                    let payload = try argumentExtractor.getArgument(type: MissionRealtimeUpdate.self)
                    guard payload.missionId == self.subscribedMissionId else { return }
                    self.onMissionUpdate?(payload)
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        connection.on(method: "ReceiveMissionActivityUpdate") { [weak self] argumentExtractor in
            Task { @MainActor [weak self] in
                guard let self else { return }

                do {
                    let payload = try argumentExtractor.getArgument(type: MissionActivityRealtimeUpdate.self)
                    guard let missionId = payload.missionId,
                          missionId == self.subscribedMissionId,
                          let status = payload.status else { return }

                    self.onActivityStatusUpdate?(
                        MissionRealtimeActivityStatusUpdate(
                            missionId: missionId,
                            activityId: payload.activityId,
                            status: status,
                            changedAt: payload.changedAt
                        )
                    )
                    self.onRefreshRecommended?()
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        connection.on(method: "ReceiveMissionExecutionProgress") { [weak self] argumentExtractor in
            Task { @MainActor [weak self] in
                guard let self else { return }

                do {
                    let payload = try argumentExtractor.getArgument(type: MissionExecutionProgressRealtimeUpdate.self)
                    guard payload.missionId == self.subscribedMissionId else { return }

                    if let activityId = payload.activityId,
                       let status = payload.effectiveStatus ?? payload.status {
                        self.onActivityStatusUpdate?(
                            MissionRealtimeActivityStatusUpdate(
                                missionId: payload.missionId,
                                activityId: activityId,
                                status: status,
                                changedAt: payload.changedAt
                            )
                        )
                    }

                    for activity in payload.affectedActivities ?? [] {
                        guard let status = activity.status else { continue }
                        self.onActivityStatusUpdate?(
                            MissionRealtimeActivityStatusUpdate(
                                missionId: payload.missionId,
                                activityId: activity.missionActivityId,
                                status: status,
                                changedAt: payload.changedAt
                            )
                        )
                    }

                    if payload.requeryRecommended == true {
                        self.onRefreshRecommended?()
                    }
                } catch {
                    self.errorMessage = error.localizedDescription
                }
            }
        }

        connection.on(method: "Error") { [weak self] (message: String) in
            Task { @MainActor [weak self] in
                self?.errorMessage = message
            }
        }
    }

    private func subscribeActiveMission() {
        guard let missionId = subscribedMissionId else { return }

        connection?.invoke(method: "SubscribeMissionActivities", missionId) { [weak self] error in
            if let error {
                Task { @MainActor [weak self] in
                    self?.errorMessage = error.localizedDescription
                }
            }
        }

        connection?.invoke(method: "SubscribeMissionExecution", missionId) { [weak self] error in
            if let error {
                Task { @MainActor [weak self] in
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func unsubscribeActiveMission() {
        guard let missionId = subscribedMissionId else { return }

        connection?.invoke(method: "UnsubscribeMissionActivities", missionId) { _ in }
        connection?.invoke(method: "UnsubscribeMissionExecution", missionId) { _ in }
    }

    private func makeHubURL(accessToken: String) -> URL? {
        guard var components = URLComponents(string: "\(baseURL)/hubs/admin-operations") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "access_token", value: accessToken)
        ]
        return components.url
    }

    private func makeConnectionDelegate() -> MissionRealtimeConnectionDelegateProxy {
        let delegate = MissionRealtimeConnectionDelegateProxy(owner: self)
        connectionDelegate = delegate
        return delegate
    }

    fileprivate func connectionDidOpen() {
        isConnected = true
        errorMessage = nil
        subscribeActiveMission()
    }

    fileprivate func connectionDidFailToOpen(error: Error) {
        isConnected = false
        errorMessage = error.localizedDescription
    }

    fileprivate func connectionDidClose(error: Error?) {
        isConnected = false
        if let error {
            errorMessage = error.localizedDescription
        }
    }

    fileprivate func connectionWillReconnect(error: Error) {
        isConnected = false
        errorMessage = error.localizedDescription
    }

    fileprivate func connectionDidReconnect() {
        isConnected = true
        errorMessage = nil
        subscribeActiveMission()
        onRefreshRecommended?()
    }
}

private final class MissionRealtimeConnectionDelegateProxy: HubConnectionDelegate {
    weak var owner: MissionRealtimeService?

    init(owner: MissionRealtimeService) {
        self.owner = owner
    }

    func connectionDidOpen(hubConnection: HubConnection) {
        Task { @MainActor [weak owner] in
            owner?.connectionDidOpen()
        }
    }

    func connectionDidFailToOpen(error: Error) {
        Task { @MainActor [weak owner] in
            owner?.connectionDidFailToOpen(error: error)
        }
    }

    func connectionDidClose(error: Error?) {
        Task { @MainActor [weak owner] in
            owner?.connectionDidClose(error: error)
        }
    }

    func connectionWillReconnect(error: Error) {
        Task { @MainActor [weak owner] in
            owner?.connectionWillReconnect(error: error)
        }
    }

    func connectionDidReconnect() {
        Task { @MainActor [weak owner] in
            owner?.connectionDidReconnect()
        }
    }
}
