import Foundation
import Combine

enum MissionActivitySyncState: String, Codable, Equatable {
    case queued
    case syncing
    case failed
    case synced
}

enum MissionActivitySyncTriggerReason: String {
    case networkRestored
    case appDidBecomeActive
    case authSessionChanged
    case manualRefresh
}

struct PendingMissionActivityUpdate: Codable, Identifiable, Equatable {
    let clientMutationId: String
    let userId: String
    let missionId: Int
    let activityId: Int
    let targetStatus: String
    let queuedAt: Date
    let baseServerStatus: String
    var syncState: MissionActivitySyncState

    var id: String { clientMutationId }
    var dedupeKey: String { "\(missionId)-\(activityId)" }
}

struct MissionActivitySyncTransportResult {
    let syncedMutationIds: Set<String>
    let failedMutationIds: Set<String>

    static let empty = MissionActivitySyncTransportResult(
        syncedMutationIds: [],
        failedMutationIds: []
    )
}

protocol MissionActivitySyncTransport {
    func send(
        updates: [PendingMissionActivityUpdate],
        trigger: MissionActivitySyncTriggerReason
    ) async throws -> MissionActivitySyncTransportResult
}

struct NoopMissionActivitySyncTransport: MissionActivitySyncTransport {
    func send(
        updates: [PendingMissionActivityUpdate],
        trigger: MissionActivitySyncTriggerReason
    ) async throws -> MissionActivitySyncTransportResult {
        guard updates.isEmpty == false else { return .empty }

        print(
            """
            [MissionActivitySync] Deferred sync trigger=\(trigger.rawValue) pending=\(updates.count). \
            Bulk backend API is not available yet; keeping items queued locally.
            """
        )

        return .empty
    }
}

final class MissionActivitySyncStore: ObservableObject {
    static let shared = MissionActivitySyncStore()

    @Published private(set) var updates: [PendingMissionActivityUpdate] = []

    private let userDefaults: UserDefaults
    private let activeUserIdProvider: () -> String?
    private let transport: any MissionActivitySyncTransport

    private var sessionObserver: AnyCancellable?
    private var networkObserver: AnyCancellable?

    init(
        userDefaults: UserDefaults = .standard,
        activeUserIdProvider: (() -> String?)? = nil,
        sessionPublisher: AnyPublisher<AuthSession?, Never>? = nil,
        networkPublisher: AnyPublisher<Bool, Never>? = nil,
        transport: any MissionActivitySyncTransport = NoopMissionActivitySyncTransport()
    ) {
        self.userDefaults = userDefaults
        self.activeUserIdProvider = activeUserIdProvider ?? {
            AuthSessionStore.shared.session?.userId
        }
        self.transport = transport

        reloadCurrentUser()

        let resolvedSessionPublisher = sessionPublisher
            ?? AuthSessionStore.shared.$session.eraseToAnyPublisher()
        sessionObserver = resolvedSessionPublisher
            .sink { [weak self] _ in
                guard let self else { return }
                self.reloadCurrentUser()
                self.triggerDeferredSync(reason: .authSessionChanged)
            }

        let resolvedNetworkPublisher = networkPublisher
            ?? NetworkMonitor.shared.$isConnected.eraseToAnyPublisher()
        networkObserver = resolvedNetworkPublisher
            .removeDuplicates()
            .sink { [weak self] isConnected in
                guard isConnected else { return }
                self?.triggerDeferredSync(reason: .networkRestored)
            }
    }

    func reloadCurrentUser() {
        guard let userId = currentUserId() else {
            updates = []
            return
        }

        updates = loadUpdates(for: userId)
    }

    @discardableResult
    func enqueue(
        missionId: Int,
        activityId: Int,
        targetStatus: String,
        baseServerStatus: String
    ) -> PendingMissionActivityUpdate? {
        guard let userId = currentUserId() else { return nil }
        guard pendingUpdate(missionId: missionId, activityId: activityId) == nil else {
            return nil
        }

        let update = PendingMissionActivityUpdate(
            clientMutationId: UUID().uuidString,
            userId: userId,
            missionId: missionId,
            activityId: activityId,
            targetStatus: targetStatus,
            queuedAt: Date(),
            baseServerStatus: baseServerStatus,
            syncState: .queued
        )

        updates = sortUpdates(updates + [update])
        persistCurrentUser()
        return update
    }

    func pendingUpdate(missionId: Int, activityId: Int) -> PendingMissionActivityUpdate? {
        updates.first { update in
            update.missionId == missionId && update.activityId == activityId
        }
    }

    func hasPendingUpdate(missionId: Int, activityId: Int) -> Bool {
        pendingUpdate(missionId: missionId, activityId: activityId) != nil
    }

    func pendingUpdates(for missionId: Int) -> [PendingMissionActivityUpdate] {
        updates.filter { $0.missionId == missionId }
    }

    func pendingCount(for missionId: Int) -> Int {
        pendingUpdates(for: missionId).count
    }

    func syncState(for missionId: Int, activityId: Int) -> MissionActivitySyncState? {
        pendingUpdate(missionId: missionId, activityId: activityId)?.syncState
    }

    func effectiveActivities(base: [Activity], missionId: Int) -> [Activity] {
        let overrides = Dictionary(
            uniqueKeysWithValues: pendingUpdates(for: missionId).map { ($0.activityId, $0.targetStatus) }
        )

        return base.map { activity in
            guard let targetStatus = overrides[activity.id] else {
                return activity
            }

            return activity.replacing(status: targetStatus)
        }
    }

    func triggerDeferredSync(reason: MissionActivitySyncTriggerReason) {
        guard currentUserId() != nil else { return }

        let snapshot = updates
        guard snapshot.isEmpty == false else { return }

        Task { [transport] in
            do {
                _ = try await transport.send(updates: snapshot, trigger: reason)
            } catch {
                print("[MissionActivitySync] Deferred sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func currentUserId() -> String? {
        guard let rawUserId = activeUserIdProvider() else {
            return nil
        }

        let trimmed = rawUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func storageKey(for userId: String) -> String {
        "missionActivitySync.pending.\(userId)"
    }

    private func loadUpdates(for userId: String) -> [PendingMissionActivityUpdate] {
        guard let data = userDefaults.data(forKey: storageKey(for: userId)) else {
            return []
        }

        do {
            let decoded = try JSONDecoder().decode([PendingMissionActivityUpdate].self, from: data)
            let scopedItems = decoded.filter { $0.userId == userId }
            return sortUpdates(scopedItems)
        } catch {
            print("❌ Failed to load mission activity sync queue: \(error)")
            return []
        }
    }

    private func persistCurrentUser() {
        guard let userId = currentUserId() else {
            updates = []
            return
        }

        persist(updates, for: userId)
    }

    private func persist(_ updates: [PendingMissionActivityUpdate], for userId: String) {
        do {
            let data = try JSONEncoder().encode(sortUpdates(updates))
            userDefaults.set(data, forKey: storageKey(for: userId))
        } catch {
            print("❌ Failed to persist mission activity sync queue: \(error)")
        }
    }

    private func sortUpdates(_ updates: [PendingMissionActivityUpdate]) -> [PendingMissionActivityUpdate] {
        updates.sorted { lhs, rhs in
            if lhs.queuedAt != rhs.queuedAt {
                return lhs.queuedAt < rhs.queuedAt
            }

            if lhs.missionId != rhs.missionId {
                return lhs.missionId < rhs.missionId
            }

            return lhs.activityId < rhs.activityId
        }
    }
}
