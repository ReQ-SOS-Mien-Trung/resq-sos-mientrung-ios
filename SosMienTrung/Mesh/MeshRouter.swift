import Foundation

final class MeshRouter {
    static let shared = MeshRouter(meshManager: MeshManager.shared)

    private let meshManager: MeshManager

    init(meshManager: MeshManager) {
        self.meshManager = meshManager
    }

    func processHeartbeat(senderId: String, senderLevel: Int) {
        processHeartbeat(senderId: senderId, senderLevel: senderLevel, battery: 0, rssi: 0)
    }

    func processHeartbeat(senderId: String, senderLevel: Int, battery: Int, rssi: Int) {
        let payload = HeartbeatPayload(senderId: senderId, level: senderLevel, battery: battery)
        meshManager.processHeartbeat(payload: payload, rssi: rssi)
        retryOfflineQueueIfPossible()
    }

    func processHeartbeat(_ payload: HeartbeatPayload, rssi: Int) {
        meshManager.processHeartbeat(payload: payload, rssi: rssi)
        retryOfflineQueueIfPossible()
    }

    func handleSOSPacket(_ packet: SOSPacket) {
        guard meshManager.registerPacket(packet.packetId) else {
            print("[Mesh] SOS duplicate ignored: packetId=\(packet.packetId).")
            return
        }

        var forwardedPacket = packet
        forwardedPacket.path.append(meshManager.myDeviceId)
        forwardedPacket.hopCount += 1

        print("[Mesh] SOS accepted: packetId=\(packet.packetId) hopCount=\(forwardedPacket.hopCount) level=\(meshManager.currentLevel()).")
        routeForwardedPacket(forwardedPacket)
    }

    func sendOrRelaySOS(_ packet: SOSPacket) {
        handleSOSPacket(packet)
    }

    func retryOfflineQueueIfPossible(limit: Int? = nil) {
        let batch = meshManager.dequeueOfflineBatch(limit: limit)
        guard !batch.isEmpty else { return }
        print("[Mesh] Retrying offline queue: count=\(batch.count).")
        for packet in batch {
            routeForwardedPacket(packet)
        }
    }

    private func routeForwardedPacket(_ packet: SOSPacket) {
        let currentLevel = meshManager.currentLevel()

        if currentLevel == 0 {
            print("[Mesh] Gateway upload: packetId=\(packet.packetId).")
            APIService.shared.uploadSOS(packet: packet) { _ in }
            return
        }

        if let nextHop = meshManager.bestNextHop(for: currentLevel) {
            print("[Mesh] Relay to next hop \(nextHop.id) level=\(nextHop.level) rssi=\(nextHop.rssi) for packetId=\(packet.packetId).")
            meshManager.transport.sendSOS(packet, to: nextHop.id)
        } else {
            print("[Mesh] No next hop; queueing packetId=\(packet.packetId) at level=\(currentLevel).")
            meshManager.enqueueOffline(packet)
        }
    }
}
