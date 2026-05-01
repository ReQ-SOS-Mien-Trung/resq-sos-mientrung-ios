import SwiftUI
import UIKit
import PhotosUI

struct ActivityProofCaptureSection: View {
    @Binding var proofImage: UIImage?
    var title: String
    var subtitle: String

    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showImageSourceSheet = false

    init(
        proofImage: Binding<UIImage?>,
        title: String = "Ảnh minh chứng (tùy chọn)",
        subtitle: String = "Ảnh sẽ được tải lên để lưu minh chứng hoàn thành bước nhiệm vụ."
    ) {
        _proofImage = proofImage
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        IncidentFormSection(
            title: title,
            subtitle: subtitle
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if let proofImage {
                    Image(uiImage: proofImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
                        )
                }

                if canSelectImageSource {
                    VStack(spacing: DS.Spacing.xs) {
                        Button {
                            showImageSourceSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text(proofImage == nil ? "Chọn ảnh minh chứng" : "Đổi ảnh minh chứng")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DS.Colors.info)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DS.Colors.info.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(DS.Colors.info.opacity(0.25), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        if proofImage != nil {
                            Button {
                                self.proofImage = nil
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Gỡ ảnh đã chọn")
                                }
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(DS.Colors.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(DS.Colors.accent.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(DS.Colors.accent.opacity(0.25), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
 else {
                    IncidentInlineNotice(
                        icon: "photo",
                        text: "Thiết bị hiện không hỗ trợ camera hoặc thư viện ảnh. Bạn vẫn có thể hoàn thành bước mà không đính kèm ảnh.",
                        tone: DS.Colors.warning
                    )
                }
            }
        }
        .confirmationDialog("Ảnh minh chứng", isPresented: $showImageSourceSheet, titleVisibility: .visible) {
            if canUsePhotoLibrary {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Chọn từ thư viện", systemImage: "photo.on.rectangle")
                }
            }

            if canUseCamera {
                Button {
                    showCameraPicker = true
                } label: {
                    Label("Chụp từ camera", systemImage: "camera")
                }
            }

            Button("Huỷ", role: .cancel) { }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .sheet(isPresented: $showCameraPicker) {
            AppCameraPicker(image: $proofImage)
                .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let item = newItem else { return }
            Task {
                await handlePhotoLibrarySelection(item)
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
    }

    private var canUseCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var canUsePhotoLibrary: Bool {
        UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
    }

    private var canSelectImageSource: Bool {
        canUseCamera || canUsePhotoLibrary
    }

    @MainActor
    private func handlePhotoLibrarySelection(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }

        proofImage = image
    }
}
