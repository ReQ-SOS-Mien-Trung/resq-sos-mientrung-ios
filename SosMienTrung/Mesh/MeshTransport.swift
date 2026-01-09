import Foundation

protocol MeshTransport {
    func broadcastHeartbeat(_ payload: HeartbeatPayload)
    func sendSOS(_ packet: SOSPacket, to peerId: String)
}

final class BridgefyTransport: MeshTransport {
    static let shared = BridgefyTransport()
    private let encoder = JSONEncoder()

    private init() {}

    func broadcastHeartbeat(_ payload: HeartbeatPayload) {
        send(envelope: MeshEnvelope.heartbeat(payload), to: nil)
    }

    func sendSOS(_ packet: SOSPacket, to peerId: String) {
        send(envelope: MeshEnvelope.sos(packet), to: peerId)
    }

    private func send(envelope: MeshEnvelope, to peerId: String?) {
        guard let data = try? encoder.encode(envelope) else {
            print("[Mesh] Failed to encode mesh envelope.")
            return
        }
        BridgefyNetworkManager.shared.sendMeshData(data, to: peerId)
    }
}
