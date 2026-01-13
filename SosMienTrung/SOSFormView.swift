import SwiftUI

struct SOSFormView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @Environment(\.dismiss) var dismiss

    @State private var sosMessage: String = ""
    @State private var isSending: Bool = false
    @State private var showSuccess: Bool = false

    private let quickMessages = [
        "Gãy chân, cần cứu hộ",
        "Bị mắc kẹt, cần giúp đỡ",
        "Cần thức ăn và nước uống",
        "Bị thương, cần y tế",
        "Nhà sập, có người bị kẹt"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                TelegramBackground()
                Color.black.opacity(0.35).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Network status
                        HStack {
                            Circle()
                                .fill(networkMonitor.isConnected ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            Text(networkMonitor.isConnected ? "Có kết nối mạng" : "Không có mạng - sẽ gửi qua Mesh")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)

                        // Location info
                        if let coords = bridgefyManager.locationManager.coordinates {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                Text(String(format: "%.6f, %.6f", coords.latitude, coords.longitude))
                                    .font(.caption)
                                    .monospaced()
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        } else {
                            HStack {
                                Image(systemName: "location.slash")
                                    .foregroundColor(.orange)
                                Text("Đang lấy vị trí...")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }

                        // Quick message buttons
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Chọn nhanh:")
                                .font(.headline)
                                .foregroundColor(.white)

                            ForEach(quickMessages, id: \.self) { message in
                                Button {
                                    sosMessage = message
                                } label: {
                                    HStack {
                                        Text(message)
                                            .foregroundColor(.white)
                                        Spacer()
                                        if sosMessage == message {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding()
                                    .background(sosMessage == message ? Color.red.opacity(0.3) : Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }

                        // Custom message input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hoặc nhập tin nhắn:")
                                .font(.headline)
                                .foregroundColor(.white)

                            TextField("Mô tả tình huống của bạn...", text: $sosMessage, axis: .vertical)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .lineLimit(3...6)
                        }

                        Spacer(minLength: 20)

                        // Send button
                        Button {
                            sendSOS()
                        } label: {
                            HStack {
                                if isSending {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text("GỬI TÍN HIỆU SOS")
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(sosMessage.isEmpty ? Color.gray : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }
                        .disabled(sosMessage.isEmpty || isSending)
                    }
                    .padding()
                }
            }
            .navigationTitle("Gửi SOS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Đã gửi SOS!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if networkMonitor.isConnected {
                    Text("Tin hiệu SOS đã được gửi trực tiếp lên server và broadcast đến các thiết bị gần đó.")
                } else {
                    Text("Tin hiệu SOS đã được gửi qua mạng Mesh. Khi có thiết bị có kết nối mạng nhận được, họ sẽ relay lên server giúp bạn.")
                }
            }
        }
    }

    private func sendSOS() {
        guard !sosMessage.isEmpty else { return }
        isSending = true

        Task {
            await bridgefyManager.sendSOSWithUpload(sosMessage)

            await MainActor.run {
                isSending = false
                showSuccess = true
            }
        }
    }
}

#Preview {
    SOSFormView(bridgefyManager: BridgefyNetworkManager.shared)
}
