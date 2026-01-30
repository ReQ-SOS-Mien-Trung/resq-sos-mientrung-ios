import Foundation
import Combine

final class SOSRelayService: ObservableObject {
    static let shared = SOSRelayService()

    private let mockServerURL = "https://690cc857a6d92d83e84f5f9e.mockapi.io/api/ResQ/SOS"

    @Published var pendingPackets: [SOSPacket] = []
    @Published var isUploading: Bool = false

    private let networkMonitor = NetworkMonitor.shared

    private init() {}

    /// Upload SOS packet lên Mock server
    func uploadSOS(_ packet: SOSPacket) async -> Bool {
        guard networkMonitor.isConnected else {
            print("📴 No network - cannot upload SOS directly")
            return false
        }

        guard let url = URL(string: mockServerURL) else {
            print("❌ Invalid mock server URL")
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(packet)

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 Uploading SOS to server:")
                print(jsonString)
            }

            request.httpBody = jsonData

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("✅ SOS uploaded successfully to server")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📥 Server response: \(responseString)")
                    }
                    return true
                } else {
                    print("❌ Server returned status: \(httpResponse.statusCode)")
                    return false
                }
            }
        } catch {
            print("❌ Failed to upload SOS: \(error.localizedDescription)")
        }

        return false
    }

    /// Queue packet để gửi khi có mạng
    func queueForRelay(_ packet: SOSPacket) {
        if !pendingPackets.contains(where: { $0.packetId == packet.packetId }) {
            pendingPackets.append(packet)
            print("📦 SOS packet queued for relay: \(packet.packetId)")
        }
    }

    /// Xử lý pending packets khi có mạng
    func processPendingPackets() async {
        guard networkMonitor.isConnected else { return }
        guard !pendingPackets.isEmpty else { return }

        isUploading = true
        var successfulIds: [String] = []

        for packet in pendingPackets {
            let success = await uploadSOS(packet)
            if success {
                successfulIds.append(packet.packetId)
            }
        }

        // Remove successfully uploaded packets
        await MainActor.run {
            pendingPackets.removeAll { successfulIds.contains($0.packetId) }
            isUploading = false
        }

        print("📊 Processed \(successfulIds.count)/\(pendingPackets.count + successfulIds.count) pending SOS packets")
    }
}
