import SwiftUI

struct SosSelectionView: View {
    @ObservedObject var vm: VictimChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                EyebrowLabel(text: "YÊU CẦU CỦA BẠN")
                Text("Chọn SOS\nCần Hỗ Trợ")
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text)
                EditorialDivider(height: DS.Border.thick)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.sm)

            if vm.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List(vm.sosRequests) { sos in
                    Button {
                        Task { await vm.linkSosRequest(sos.id) }
                    } label: {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            HStack {
                                Text("SOS #\(sos.id)")
                                    .font(DS.Typography.headline)
                                    .foregroundColor(DS.Colors.text)
                                Spacer()
                                Text(sos.status)
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.warning)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(DS.Colors.warning.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }

                            if let type = sos.sosType {
                                Text("Loại: \(type)")
                                    .font(DS.Typography.subheadline)
                                    .foregroundColor(DS.Colors.textSecondary)
                            }

                            Text(sos.msg)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textSecondary)
                                .lineLimit(2)

                            if let wait = sos.waitTimeMinutes {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                    Text("Đã chờ: ~\(wait) phút")
                                        .font(DS.Typography.caption)
                                }
                                .foregroundColor(DS.Colors.textTertiary)
                            }
                        }
                        .padding(.vertical, DS.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .background(DS.Colors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
