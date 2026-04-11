import SwiftUI

struct CoordinatorChatMainView: View {
    @StateObject private var vm = VictimChatViewModel()
    @Environment(\.dismiss) private var dismiss

    init(preferredConversationId: Int? = nil) {
        _vm = StateObject(wrappedValue: VictimChatViewModel(preferredConversationId: preferredConversationId))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch vm.phase {
                case .loading:
                    loadingView
                case .selectingTopic:
                    TopicSelectionView(vm: vm)
                case .selectingSos:
                    SosSelectionView(vm: vm)
                case .waitingCoordinator, .chatting:
                    CoordinatorChatRoomView(vm: vm)
                }
            }
            .onDisappear {
                vm.cleanup()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DS.Colors.text)
                    }
                }

            }
            .task { await vm.initialize() }
            .alert("Lỗi", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Đang kết nối...")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.background)
    }
}
