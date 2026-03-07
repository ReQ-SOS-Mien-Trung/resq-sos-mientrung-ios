import Foundation
import Combine
import UIKit

final class ServerRequestGateway: ObservableObject {
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
        var isUploading: Bool = false
        var uploadEverAttempted: Bool = false  // da tung goi HTTP upload chua
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

    /// Set các requestId đã được server xác nhận — dùng để hiển thị UI
    @Published private(set) var confirmedIds: Set<String> = []

    /// Kiểm tra nhanh một packet đã được server xác nhận chưa
    func isServerConfirmed(_ requestId: String) -> Bool {
        confirmedIds.contains(requestId)
    }

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
            // Nếu ACK này đã được xử lý rồi thì bỏ qua, tránh lặp event
            guard !self.completed.contains(ack.requestId) else { return }

            self.completed.insert(ack.requestId)
            let confirmedId = ack.requestId
            DispatchQueue.main.async { self.confirmedIds.insert(confirmedId) }
            self.pending.removeValue(forKey: ack.requestId)
            if ack.originDeviceId == self.myDeviceId {
                DispatchQueue.main.async {
                    // Nhận ACK từ server qua relay: server đã xác nhận
                    SOSStorageManager.shared.updateStatusWithEvent(
                        id: ack.requestId,
                        status: .delivered,
                        event: SOSSendEvent(type: .serverAcknowledged, note: "Server xác nhận qua Mesh relay")
                    )
                }
            }
        }
    }

    func triggerRetry(reason: TriggerReason) {
        stateQueue.async {
            // Khi ket noi duoc khoi phuc -> reset backoff de retry tuc thi
            switch reason {
            case .networkChange, .peerUpdate:
                let now = Date()
                for key in self.pending.keys {
                    guard var entry = self.pending[key], !entry.isUploading else { continue }
                    entry.nextRetryAt = now
                    // Neu chua tung gui HTTP -> reset attempt ve 0
                    if !entry.uploadEverAttempted {
                        entry.attempt = 0
                    }
                    self.pending[key] = entry
                }
                print("[Gateway] Connectivity event (\(reason)) - reset backoff for \(self.pending.count) pending requests")
            case .meshHeartbeat, .manual:
                break
            }
            self.retryPendingIfPossible(reason: reason)
        }
    }

    // MARK: - Private

    /// Device ID ổn định: ưu tiên Bridgefy UUID, fallback sang vendor ID (giống sendStructuredSOS)
    private var myDeviceId: String {
        BridgefyNetworkManager.shared.currentUserId?.uuidString
            ?? UIDevice.current.identifierForVendor?.uuidString
            ?? MeshManager.shared.myDeviceId
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
        // Tránh gửi cùng một request song song
        guard var entry = pending[envelope.requestId], !entry.isUploading else {
            print("[Gateway] ⏭ Skip duplicate upload for \(envelope.requestId) – already in-flight")
            return
        }
        entry.isUploading = true
        entry.uploadEverAttempted = true
        pending[envelope.requestId] = entry

        // Capture isLocalOrigin trước khi vào Task (myDeviceId có thể thay đổi sau khi BT bật)
        let isLocalOrigin = entry.isLocalOrigin

        Task {
            let success = await self.performUpload(for: envelope, isLocalOrigin: isLocalOrigin)
            self.stateQueue.async {
                // Reset cờ trước khi xử lý kết quả
                if var e = self.pending[envelope.requestId] {
                    e.isUploading = false
                    self.pending[envelope.requestId] = e
                }
                self.handleUploadResult(for: envelope, success: success, ackTransport: ackTransport, isLocalOrigin: isLocalOrigin)
            }
        }
    }

    private func handleUploadResult(for envelope: ServerRequestEnvelope, success: Bool, ackTransport: TransportSource?, isLocalOrigin: Bool) {
        if success {
            completed.insert(envelope.requestId)
            let confirmedId = envelope.requestId
            DispatchQueue.main.async { self.confirmedIds.insert(confirmedId) }
            pending.removeValue(forKey: envelope.requestId)

            // Gửi ACK ngược lại nếu đây là packet relay (không phải của mình)
            if let ackTransport = ackTransport, !isLocalOrigin {
                sendAck(for: envelope, via: ackTransport)
            }

            // Cập nhật status nếu đây là SOS của mình
            if isLocalOrigin {
                DispatchQueue.main.async {
                    // Gateway retry thành công: đã gửi lên server
                    SOSStorageManager.shared.updateStatusWithEvent(
                        id: envelope.requestId,
                        status: .sent,
                        event: SOSSendEvent(type: .sentViaNetwork, note: "Gửi qua Internet (retry tự động)")
                    )
                }
            }
            return
        }

        scheduleRetry(for: envelope)
    }

    private func performUpload(for envelope: ServerRequestEnvelope, isLocalOrigin: Bool) async -> Bool {
        // Nếu packet không phải từ thiết bị này → relay, truyền userId gốc để BE biết
        // Dùng isLocalOrigin thay vì so sánh myDeviceId (vì myDeviceId có thể thay đổi sau khi BT bật)
        let isRelay = !isLocalOrigin
        let originalUserId: String? = isRelay ? envelope.sosPacket?.senderInfo?.userId
            ?? envelope.sosEnhanced?.senderInfo?.userId
            : nil

        switch envelope.type {
        case .sosBasic:
            guard let packet = envelope.sosPacket else { return false }

            // ── LOG CHI TIẾT KHI RELAY ──────────────────────
            print("""
[Gateway] 📤 Uploading \(isRelay ? "RELAYED" : "OWN") sosBasic
  packetId      : \(packet.packetId)
  originId      : \(packet.originId)           ← Bridgefy UUID thiết bị gốc
  myDeviceId    : \(myDeviceId)                ← Bridgefy UUID thiết bị relay (mình)
  isRelay       : \(isRelay)
  hopCount      : \(packet.hopCount)
  path          : \(packet.path)
  senderInfo
    device_id   : \(packet.senderInfo?.deviceId ?? "nil")
    user_id     : \(packet.senderInfo?.userId ?? "nil")  ← phải là userId của người gửi gốc
    user_name   : \(packet.senderInfo?.userName ?? "nil")
  mySession
    userId(BE)  : \(AuthSessionStore.shared.session?.userId ?? "nil")  ← userId của máy relay
  relayingFor   : \(originalUserId ?? "nil (own packet, not relay)")
""")
            // ─────────────────────────────────────────────────

            return await APIService.shared.uploadSOS(packet: packet, relayingFor: originalUserId)
        case .sosEnhanced:
            guard let packet = envelope.sosEnhanced else { return false }

            print("""
[Gateway] 📤 Uploading \(isRelay ? "RELAYED" : "OWN") sosEnhanced
  packetId      : \(packet.packetId)
  originId      : \(packet.originId)
  myDeviceId    : \(myDeviceId)
  isRelay       : \(isRelay)
  hopCount      : \(packet.hopCount)
  path          : \(packet.path)
  senderInfo
    device_id   : \(packet.senderInfo?.deviceId ?? "nil")
    user_id     : \(packet.senderInfo?.userId ?? "nil")
  mySession
    userId(BE)  : \(AuthSessionStore.shared.session?.userId ?? "nil")
  relayingFor   : \(originalUserId ?? "nil (own packet, not relay)")
""")

            return await APIService.shared.uploadSOS(enhanced: packet, relayingFor: originalUserId)
        }
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
        // Tối thiểu 10 giây sau khi thất bại (lớn hơn timeout request 15s là vô nghĩa nếu < 15s)
        // Dùng exponential: 10, 20, 40, 60, 60, ... (giây)
        let baseDelay = max(10.0, pow(2.0, Double(attempt + 2)))
        let delay = min(baseDelay, 60.0)
        return Date().addingTimeInterval(delay)
    }

    private func retryPendingIfPossible(reason: TriggerReason) {
        let now = Date()
        // Chỉ retry các request đã đến thời điểm và không đang upload
        let entries = pending.values.filter { $0.nextRetryAt <= now && !$0.isUploading }
        guard !entries.isEmpty else { return }

        for entry in entries {
            if networkMonitor.isConnected {
                print("[Gateway] 🔄 Retry attempt \(entry.attempt) for \(entry.envelope.requestId)")
                uploadIfPossible(entry.envelope, ackTransport: entry.lastReceiveTransport)
            } else {
                // Chi relay qua mesh, KHONG tang attempt (chua thuc su gui HTTP)
                relayIfNeeded(entry.envelope, excluding: entry.lastReceiveTransport)
                // Cho 10s co dinh roi thu relay lai
                guard var e = pending[entry.envelope.requestId] else { continue }
                e.nextRetryAt = Date().addingTimeInterval(10.0)
                pending[entry.envelope.requestId] = e
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
