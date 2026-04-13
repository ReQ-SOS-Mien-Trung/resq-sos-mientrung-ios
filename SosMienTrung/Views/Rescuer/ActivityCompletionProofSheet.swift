import SwiftUI
import UIKit

struct ActivityCompletionProofSheet: View {
    let activity: Activity
    let isSubmitting: Bool
    let onSubmit: (UIImage?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var proofImage: UIImage?
    @State private var isSubmittingLocal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                IncidentFormSection(
                    title: "Hoàn thành bước nhiệm vụ",
                    subtitle: "Bạn có thể đính kèm ảnh minh chứng để hỗ trợ kiểm chứng sau nhiệm vụ."
                ) {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        if let step = activity.step {
                            IncidentContextRow(
                                icon: "number.circle.fill",
                                title: "Bước",
                                value: "Bước \(step)"
                            )
                        }

                        if let localizedType = activity.localizedActivityType, localizedType.isEmpty == false {
                            IncidentContextRow(
                                icon: "tag.fill",
                                title: "Loại bước",
                                value: localizedType
                            )
                        }

                        if let description = activity.description, description.isEmpty == false {
                            IncidentContextRow(
                                icon: "list.bullet.rectangle",
                                title: "Công việc",
                                value: description
                            )
                        }

                        IncidentInlineNotice(
                            icon: "checkmark.shield",
                            text: "Ảnh là tùy chọn. Nếu không có ảnh, bạn vẫn có thể hoàn thành bước ngay."
                        )
                    }
                }

                ActivityProofCaptureSection(proofImage: $proofImage)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Colors.background)
        .navigationTitle("Hoàn thành bước")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Đóng") {
                    dismiss()
                }
                .disabled(isSubmissionLocked)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DS.Spacing.sm) {
                IncidentSubmitButton(
                    title: "Hoàn thành bước",
                    isEnabled: true,
                    isLoading: isSubmissionLocked
                ) {
                    guard isSubmissionLocked == false else { return }
                    isSubmittingLocal = true

                    Task { @MainActor in
                        let didSucceed = await onSubmit(proofImage)
                        if didSucceed {
                            dismiss()
                        } else {
                            isSubmittingLocal = false
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.md)
            .background(.ultraThinMaterial)
        }
    }

    private var isSubmissionLocked: Bool {
        isSubmitting || isSubmittingLocal
    }
}
