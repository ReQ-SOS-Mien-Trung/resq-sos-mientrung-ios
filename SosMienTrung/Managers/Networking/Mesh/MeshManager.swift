import Foundation
import Network
import UIKit

final class MeshManager {
    static let shared = MeshManager()

    private struct State {
        var myLevel: Int = 999
        var hasInternet: Bool = false
        var neighborTable: [String: Neighbor] = [:]
        var processedPacketIds: Set<String> = []
        var offlineQueue: [SOSPacket] = []
    }

    private let stateQueue = DispatchQueue(label: "mesh.manager.state")
    private let monitorQueue = DispatchQueue(label: "mesh.manager.monitor")
    private let heartbeatQueue = DispatchQueue(label: "mesh.manager.heartbeat")

    private let pathMonitor = NWPathMonitor()
    private var heartbeatTimer: DispatchSourceTimer?
    private var isStarted = false

    private let staleInterval: TimeInterval = 60
    private let heartbeatInterval: TimeInterval = 30

    private var state = State()

    let transport: MeshTransport
    private(set) var myDeviceId: String

    private init(transport: MeshTransport = BridgefyTransport.shared) {
        self.transport = transport
        self.myDeviceId = UUID().uuidString
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    func updateMyDeviceId(_ id: String) {
        stateQueue.sync {
            self.myDeviceId = id
        }
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        print("[Mesh] Starting MeshManager.")
        startPathMonitor()
        startHeartbeatTimer()
    }

    func stop() {
        pathMonitor.cancel()
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        isStarted = false
    }

    func currentLevel() -> Int {
        stateQueue.sync { state.myLevel }
    }

    func processHeartbeat(payload: HeartbeatPayload, rssi: Int) {
        let now = Date().timeIntervalSince1970
        stateQueue.sync {
            print("[Mesh] Heartbeat received from \(payload.senderId) level=\(payload.level) rssi=\(rssi).")
            if let neighbor = self.state.neighborTable[payload.senderId] {
                neighbor.update(level: payload.level, rssi: rssi, lastSeen: now)
            } else {
                self.state.neighborTable[payload.senderId] = Neighbor(
                    id: payload.senderId,
                    level: payload.level,
                    rssi: rssi,
                    lastSeen: now
                )
            }

            if !self.state.hasInternet {
                self.recalculateLevelLocked(now: now)
            }
        }
    }

    func bestNextHop(for level: Int) -> Neighbor? {
        let now = Date().timeIntervalSince1970
        return stateQueue.sync {
            self.pruneStaleNeighborsLocked(now: now)
            let candidates = self.state.neighborTable.values.filter { $0.level < level }
            return candidates.sorted {
                if $0.level != $1.level {
                    return $0.level < $1.level
                }
                return $0.rssi > $1.rssi
            }.first
        }
    }

    func registerPacket(_ packetId: String) -> Bool {
        stateQueue.sync {
            if state.processedPacketIds.contains(packetId) {
                return false
            }
            state.processedPacketIds.insert(packetId)
            return true
        }
    }

    func enqueueOffline(_ packet: SOSPacket) {
        stateQueue.sync {
            state.offlineQueue.append(packet)
        }
    }

    func dequeueOfflineBatch(limit: Int? = nil) -> [SOSPacket] {
        stateQueue.sync {
            guard let limit = limit, limit > 0 else {
                let batch = state.offlineQueue
                state.offlineQueue.removeAll()
                return batch
            }

            if limit >= state.offlineQueue.count {
                let batch = state.offlineQueue
                state.offlineQueue.removeAll()
                return batch
            }

            let batch = Array(state.offlineQueue.prefix(limit))
            state.offlineQueue.removeFirst(limit)
            return batch
        }
    }

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let hasInternet = path.status == .satisfied
            let now = Date().timeIntervalSince1970
            self.stateQueue.async {
                let previousLevel = self.state.myLevel
                let previousInternet = self.state.hasInternet
                self.state.hasInternet = hasInternet
                if hasInternet {
                    self.state.myLevel = 0
                } else {
                    self.recalculateLevelLocked(now: now)
                }

                if previousInternet != hasInternet || previousLevel != self.state.myLevel {
                    print("[Mesh] Path update: internet=\(hasInternet) level \(previousLevel) -> \(self.state.myLevel).")
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    private func startHeartbeatTimer() {
        guard heartbeatTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: heartbeatQueue)
        timer.schedule(deadline: .now(), repeating: heartbeatInterval)
        timer.setEventHandler { [weak self] in
            self?.sendHeartbeat()
        }
        timer.resume()
        heartbeatTimer = timer
    }

    private func sendHeartbeat() {
        let level = stateQueue.sync { state.myLevel }
        let payload = HeartbeatPayload(
            senderId: myDeviceId,
            level: level,
            battery: currentBatteryPercent()
        )
        print("[Mesh] Heartbeat send: level=\(payload.level) battery=\(payload.battery).")
        transport.broadcastHeartbeat(payload)
    }

    private func currentBatteryPercent() -> Int {
        let batteryLevel = UIDevice.current.batteryLevel
        guard batteryLevel >= 0 else { return 0 }
        return Int(batteryLevel * 100)
    }

    private func recalculateLevelLocked(now: TimeInterval) {
        pruneStaleNeighborsLocked(now: now)
        if let minLevel = state.neighborTable.values.map({ $0.level }).min() {
            state.myLevel = minLevel + 1
        } else {
            state.myLevel = 999
        }
        print("[Mesh] Level recalculated: \(state.myLevel).")
    }

    private func pruneStaleNeighborsLocked(now: TimeInterval) {
        state.neighborTable = state.neighborTable.filter { now - $0.value.lastSeen <= staleInterval }
    }
}
