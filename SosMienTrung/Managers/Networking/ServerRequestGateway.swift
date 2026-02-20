import Foundation
import Combine

final class ServerRequestGateway {
    static let shared = ServerRequestGateway()

    enum TransportSource {
        case bridgefyMesh
        case wifiDirect
    }

    enum TriggerReason {
        case networkChange
        case meshHeartbeat
        case peerUpdate
        case manual
    }

    private struct PendingRequest {
        var envelope: ServerRequestEnvelope
        var attempt: Int
        var nextRetryAt: Date
        var lastReceiveTransport: TransportSource?
        var isLocalOrigin: Bool
    }

    private let networkMonitor = NetworkMonitor.shared
    private let sosRelayService = SOSRelayService.shared
    private let stateQueue = DispatchQueue(label: "server.request.gateway.state")

    private var pending: [String: PendingRequest] = [:]
    private var completed: Set<String> = []
    private var processed: Set<String> = []
    private var cancellables: Set<AnyCancellable> = []
    private var retryTimer: DispatchSourceTimer?
    private var isStarted = false

    private let maxHopCount = 10

    private init() {}

    func start() {
        guard !isStarted else { return }
        isStarted = true
        setupNetworkObserver()
        setupWiFiDirect()
        startRetryTimer()
    }

    func submitSOSBasic(_ packet: SOSPacket) {
        let envelope = ServerRequestEnvelope.basicSOS(packet)
        submit(envelope)
    }

    func submitSOSEnhanced(_ packet: SOSPacketEnhanced) {
        let envelope = ServerRequestEnvelope.enhancedSOS(packet)
        submit(envelope)
    }

    func handleIncomingRequest(_ envelope: ServerRequestEnvelope, transport: TransportSource) {
        stateQueue.async {
            if self.completed.contains(envelope.requestId) {
                self.sendAck(for: envelope, via: transport)
                return
            }

            if self.processed.contains(envelope.requestId) {
                return
            }

            self.processed.insert(envelope.requestId)

            let isLocalOrigin = envelope.originDeviceId == self.myDeviceId

            self.pending[envelope.requestId] = PendingRequest(
                envelope: envelope,
                attempt: 0,
                nextRetryAt: Date(),
                lastReceiveTransport: transport,
                isLocalOrigin: isLocalOrigin
            )

            if self.networkMonitor.isConnected {
                self.uploadIfPossible(envelope, ackTransport: transport)
            } else {
                self.relayIfNeeded(envelope, excluding: transport)
                self.scheduleRetry(for: envelope)
            }
        }
    }

    func handleIncomingAck(_ ack: ServerRequestAck, transport: TransportSource) {
        stateQueue.async {
            self.completed.insert(ack.requestId)
            self.pending.removeValue(forKey: ack.requestId)
            if ack.originDeviceId == self.myDeviceId {
                DispatchQueue.main.async {
                    SOSStorageManager.shared.updateStatus(id: ack.requestId, status: .delivered)
                }
            }
        }
    }

    func triggerRetry(reason: TriggerReason) {
        stateQueue.async {
            self.retryPendingIfPossible(reason: reason)
        }
    }

    // MARK: - Private

    private var myDeviceId: String {
        BridgefyNetworkManager.shared.currentUserId?.uuidString ?? MeshManager.shared.myDeviceId
    }

    private func submit(_ envelope: ServerRequestEnvelope) {
        stateQueue.async {
            if self.completed.contains(envelope.requestId) {
                return
            }

            self.processed.insert(envelope.requestId)

            let isLocalOrigin = envelope.originDeviceId == self.myDeviceId
            let pendingEntry = PendingRequest(
                envelope: envelope,
                attempt: 0,
                nextRetryAt: Date(),
                lastReceiveTransport: nil,
                isLocalOrigin: isLocalOrigin
            )
            self.pending[envelope.requestId] = pendingEntry

            if self.networkMonitor.isConnected {
                self.uploadIfPossible(envelope, ackTransport: nil)
            } else {
                self.relayIfNeeded(envelope, excluding: nil)
                self.scheduleRetry(for: envelope)
            }
        }
    }

    private func uploadIfPossible(_ envelope: ServerRequestEnvelope, ackTransport: TransportSource?) {
        Task {
            let success = await self.performUpload(for: envelope)
            self.stateQueue.async {
                self.handleUploadResult(for: envelope, success: success, ackTransport: ackTransport)
            }
        }
    }

    private func handleUploadResult(for envelope: ServerRequestEnvelope, success: Bool, ackTransport: TransportSource?) {
        if success {
            completed.insert(envelope.requestId)
            pending.removeValue(forKey: envelope.requestId)

            if let ackTransport = ackTransport, envelope.originDeviceId != myDeviceId {
                sendAck(for: envelope, via: ackTransport)
            }

            if envelope.originDeviceId == myDeviceId {
                DispatchQueue.main.async {
                    SOSStorageManager.shared.updateStatus(id: envelope.requestId, status: .delivered)
                }
            }
            return
        }

        scheduleRetry(for: envelope)
    }

    private func performUpload(for envelope: ServerRequestEnvelope) async -> Bool {
        switch envelope.type {
        case .sosBasic:
            guard let packet = envelope.sosPacket else { return false }
            return await sosRelayService.uploadSOS(packet)
        case .sosEnhanced:
            guard let packet = envelope.sosEnhanced else { return false }
            return await uploadEnhancedSOS(packet)
        }
    }

    private func uploadEnhancedSOS(_ packet: SOSPacketEnhanced) async -> Bool {
        // Convert to unified SOSPacket and upload
        let unifiedPacket = packet.toBasicPacket()
        return await APIService.shared.uploadSOS(packet: unifiedPacket)
    }

    private func relayIfNeeded(_ envelope: ServerRequestEnvelope, excluding transport: TransportSource?) {
        guard envelope.hopCount < maxHopCount else {
            return
        }

        let relayed = envelope.relayed(by: myDeviceId)

        if transport != .bridgefyMesh {
            BridgefyNetworkManager.shared.sendServerRequest(relayed)
        }

        if transport != .wifiDirect {
            sendViaWiFiDirect(relayed)
        }
    }

    private func sendAck(for envelope: ServerRequestEnvelope, via transport: TransportSource) {
        let ack = ServerRequestAck(
            requestId: envelope.requestId,
            originDeviceId: envelope.originDeviceId,
            success: true,
            timestamp: Int64(Date().timeIntervalSince1970)
        )

        switch transport {
        case .bridgefyMesh:
            BridgefyNetworkManager.shared.sendServerAck(ack)
        case .wifiDirect:
            sendAckViaWiFiDirect(ack)
        }
    }

    private func sendViaWiFiDirect(_ envelope: ServerRequestEnvelope) {
        let payload = MeshPayload(serverRequest: envelope)
        if let data = try? JSONEncoder().encode(payload) {
            WiFiDirectManager.shared.send(data)
        }
    }

    private func sendAckViaWiFiDirect(_ ack: ServerRequestAck) {
        let payload = MeshPayload(serverAck: ack)
        if let data = try? JSONEncoder().encode(payload) {
            WiFiDirectManager.shared.send(data)
        }
    }

    private func scheduleRetry(for envelope: ServerRequestEnvelope) {
        guard var entry = pending[envelope.requestId] else { return }
        entry.attempt += 1
        entry.nextRetryAt = nextRetryDate(for: entry.attempt)
        entry.envelope = envelope
        pending[envelope.requestId] = entry
    }

    private func nextRetryDate(for attempt: Int) -> Date {
        let baseDelay = max(2.0, pow(2.0, Double(attempt)))
        let delay = min(baseDelay, 60.0)
        return Date().addingTimeInterval(delay)
    }

    private func retryPendingIfPossible(reason: TriggerReason) {
        let now = Date()
        let entries = pending.values.filter { $0.nextRetryAt <= now }
        guard !entries.isEmpty else { return }

        for entry in entries {
            if networkMonitor.isConnected {
                uploadIfPossible(entry.envelope, ackTransport: entry.lastReceiveTransport)
            } else {
                relayIfNeeded(entry.envelope, excluding: entry.lastReceiveTransport)
                scheduleRetry(for: entry.envelope)
            }
        }
    }

    private func startRetryTimer() {
        guard retryTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: stateQueue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in
            self?.retryPendingIfPossible(reason: .manual)
        }
        timer.resume()
        retryTimer = timer
    }

    private func setupNetworkObserver() {
        networkMonitor.$isConnected
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.triggerRetry(reason: .networkChange)
            }
            .store(in: &cancellables)
    }

    private func setupWiFiDirect() {
        WiFiDirectManager.shared.onReceiveData = { [weak self] data, _ in
            guard let self = self else { return }
            if let payload = try? JSONDecoder().decode(MeshPayload.self, from: data) {
                switch payload.meshType {
                case .serverRequest:
                    if let request = payload.serverRequest {
                        self.handleIncomingRequest(request, transport: .wifiDirect)
                    }
                case .serverAck:
                    if let ack = payload.serverAck {
                        self.handleIncomingAck(ack, transport: .wifiDirect)
                    }
                default:
                    break
                }
            }
        }

        WiFiDirectManager.shared.onPeersChanged = { [weak self] _ in
            self?.triggerRetry(reason: .peerUpdate)
        }

        WiFiDirectManager.shared.start()
    }
}
