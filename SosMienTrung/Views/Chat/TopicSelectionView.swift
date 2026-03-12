import SwiftUI

struct TopicSelectionView: View {
    @ObservedObject var vm: VictimChatViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Header
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    EyebrowLabel(text: "HỖ TRỢ KHẨN CẤP")
                    Text("Chọn\nChủ Đề")
                        .font(DS.Typography.largeTitle)
                        .foregroundColor(DS.Colors.text)
                    EditorialDivider(height: DS.Border.thick)
                }
                .padding(.top, DS.Spacing.md)

                // AI greeting
                if let greeting = vm.aiGreetingMessage {
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 18))
                            .foregroundColor(DS.Colors.info)
                            .frame(width: 32)
                        Text(greeting)
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text)
                    }
                    .padding(DS.Spacing.md)
                    .background(DS.Colors.surface)
                    .overlay(
                        Rectangle()
                            .stroke(DS.Colors.info.opacity(0.4), lineWidth: DS.Border.thin)
                    )
                }

                // Topic list
                if vm.isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding()
                } else {
                    VStack(spacing: DS.Spacing.sm) {
                        ForEach(vm.topicSuggestions) { topic in
                            Button {
                                Task { await vm.selectTopic(topic.topicKey) }
                            } label: {
                                HStack(spacing: DS.Spacing.sm) {
                                    Text(topic.icon ?? "💬")
                                        .font(.title2)
                                        .frame(width: 36)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(topic.label)
                                            .font(DS.Typography.headline)
                                            .foregroundColor(DS.Colors.text)
                                        if let desc = topic.description {
                                            Text(desc)
                                                .font(DS.Typography.caption)
                                                .foregroundColor(DS.Colors.textSecondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(DS.Colors.textTertiary)
                                }
                                .padding(DS.Spacing.md)
                                .background(DS.Colors.surface)
                                .overlay(
                                    Rectangle()
                                        .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, DS.Spacing.md)
        }
        .background(DS.Colors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
