import SwiftUI

struct WaitingCoordinatorView: View {
    @ObservedObject var vm: VictimChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Status banner
            VStack(spacing: DS.Spacing.md) {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.top, DS.Spacing.xl)

                Text("Đang chờ Coordinator")
                    .font(DS.Typography.headline)
                    .foregroundColor(DS.Colors.text)

                Text("Vui lòng giữ ứng dụng mở.\nBạn sẽ được kết nối khi có Coordinator sẵn sàng.")
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)

                EditorialDivider(height: DS.Border.thin)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.sm)
            }

            // Tin nhắn AI đã có (nếu có)
            if !vm.chatService.messages.isEmpty {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(vm.chatService.messages) { msg in
                            CoordinatorMessageBubble(
                                message: msg,
                                currentUserId: AuthSessionStore.shared.session?.userId,
                                onImageTap: { _, _ in }
                            )
                        }
                    }
                    .padding()
                }
            } else {
                Spacer()
            }
        }
        .background(DS.Colors.background)
        .navigationTitle("Đang chờ hỗ trợ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
