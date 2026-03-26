import SwiftUI
import Foundation
import PhotosUI
import UIKit

struct CoordinatorChatRoomView: View {
    @ObservedObject var vm: VictimChatViewModel
    @State private var showPreview = false
    @State private var showImageSourceSheet = false
    @State private var showPhotoPicker = false
    @State private var showCameraPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pickedCameraImage: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBanner

            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(vm.chatService.messages) { msg in
                            CoordinatorMessageBubble(
                                message: msg,
                                currentUserId: AuthSessionStore.shared.session?.userId
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(DS.Spacing.sm)
                }
                .onChange(of: vm.chatService.messages.count) { _ in
                    if let last = vm.chatService.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Input bar
            inputBar
        }
        .background(DS.Colors.background)
        .navigationTitle("Chat hỗ trợ")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Gửi ảnh", isPresented: $showImageSourceSheet, titleVisibility: .visible) {
            Button {
                showPhotoPicker = true
            } label: {
                Label("Chọn từ thư viện", systemImage: "photo.on.rectangle")
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
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
            ChatCameraPicker(image: $pickedCameraImage)
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
        .onChange(of: pickedCameraImage) { image in
            guard let image else { return }
            Task {
                await vm.sendImage(image)
                await MainActor.run {
                    pickedCameraImage = nil
                }
            }
        }
    }

    // MARK: - Status banner

    @ViewBuilder
    private var statusBanner: some View {
        if vm.phase == .waitingCoordinator {
            HStack(spacing: DS.Spacing.xs) {
                ProgressView().scaleEffect(0.7)
                Text("Đang chờ nhân viên hỗ trợ tham gia...")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.warning)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.warning.opacity(0.12))
        } else if vm.chatService.conversationStatus == .coordinatorActive {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DS.Colors.success)
                    .font(.caption)
                Text("Đã kết nối với Coordinator")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.success)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.success.opacity(0.1))
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: DS.Spacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.xs) {
                    markdownWrapButton(title: "B", token: "**")
                    markdownWrapButton(title: "I", token: "*")
                    markdownSnippetButton(title: "Link", snippet: "[van ban](https://)")
                    markdownSnippetButton(title: "Quote", snippet: "> ")
                    markdownSnippetButton(title: "Code", snippet: "`code`")
                    markdownSnippetButton(title: "Image", snippet: "![mo ta anh](https://)")

                    Button {
                        showPreview.toggle()
                    } label: {
                        Image(systemName: showPreview ? "eye.slash" : "eye")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DS.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(DS.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.xs)
                                    .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
                            )
                    }
                }
            }

            if showPreview && !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                MarkdownRichText(content: vm.inputText, textColor: DS.Colors.text)
                    .font(DS.Typography.body)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }

            if vm.isUploadingImage {
                HStack(spacing: DS.Spacing.xs) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Đang tải ảnh lên...")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                    Spacer()
                }
            }

            HStack(spacing: DS.Spacing.sm) {
                Button {
                    showImageSourceSheet = true
                } label: {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(DS.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
                        )
                }
                .disabled(vm.isUploadingImage)

                ResQTextField(placeholder: "Nhập tin nhắn...", text: $vm.inputText)
                    .onSubmit { vm.sendMessage() }

                Button(action: vm.sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(canSend ? .white : DS.Colors.textTertiary)
                        .frame(width: 40, height: 40)
                        .background(canSend ? DS.Colors.accent : DS.Colors.surface)
                        .overlay(
                            Rectangle()
                                .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
                        )
                }
                .disabled(!canSend)
            }
        }
        .padding(DS.Spacing.sm)
        .background(DS.Colors.background)
        .shadow(color: DS.Colors.border, radius: 1, y: -1)
    }

    private var canSend: Bool {
        !vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func handlePhotoLibrarySelection(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                await MainActor.run {
                    vm.errorMessage = "Không thể đọc ảnh từ thư viện"
                }
                return
            }
            await vm.sendImage(image)
        } catch {
            await MainActor.run {
                vm.errorMessage = "Không thể chọn ảnh: \(error.localizedDescription)"
            }
        }
    }

    private func markdownWrapButton(title: String, token: String) -> some View {
        Button {
            let trimmed = vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                vm.inputText = "\(token)\(token)"
            } else {
                vm.inputText = "\(token)\(vm.inputText)\(token)"
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(DS.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(DS.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xs)
                        .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
                )
        }
    }

    private func markdownSnippetButton(title: String, snippet: String) -> some View {
        Button {
            if vm.inputText.isEmpty {
                vm.inputText = snippet
            } else {
                vm.inputText += " \(snippet)"
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DS.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(DS.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xs)
                        .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
                )
        }
    }
}

private struct ChatCameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: ChatCameraPicker

        init(_ parent: ChatCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let captured = info[.originalImage] as? UIImage {
                parent.image = captured
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Message Bubble

struct CoordinatorMessageBubble: View {
    let message: CoordinatorChatMessage
    let currentUserId: String?

    private var isFromMe: Bool {
        message.messageType == CoordinatorMessageType.userMessage.rawValue
            && message.senderId == currentUserId
    }
    private var isAI: Bool     { message.messageType == CoordinatorMessageType.aiMessage.rawValue }
    private var isSystem: Bool { message.messageType == CoordinatorMessageType.systemMessage.rawValue }
    var body: some View {
        if isSystem {
            // System message: centered pill
            MarkdownRichText(content: message.content, textColor: DS.Colors.textSecondary)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.surface)
                .clipShape(Capsule())
                .frame(maxWidth: .infinity)
        } else {
            HStack(alignment: .bottom, spacing: DS.Spacing.xs) {
                if isFromMe { Spacer(minLength: 60) }

                VStack(alignment: isFromMe ? .trailing : .leading, spacing: 2) {
                    if !isFromMe {
                        Text(message.senderName ?? (isAI ? "AI Hỗ trợ" : "Coordinator"))
                            .font(DS.Typography.caption)
                            .foregroundColor(isAI ? DS.Colors.info : DS.Colors.accent)
                    }
                    MarkdownRichText(
                        content: message.content,
                        textColor: isFromMe ? .white : DS.Colors.text
                    )
                        .font(DS.Typography.body)
                        .padding(DS.Spacing.sm)
                        .background(bubbleColor)
                        .foregroundColor(isFromMe ? .white : DS.Colors.text)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }

                if !isFromMe { Spacer(minLength: 60) }
            }
        }
    }

    private var bubbleColor: Color {
        if isFromMe { return DS.Colors.accent }
        if isAI     { return DS.Colors.info.opacity(0.15) }
        return DS.Colors.surface
    }
}

private struct MarkdownRichText: View {
    let content: String
    let textColor: Color

    private var segments: [MarkdownSegment] {
        MarkdownSegment.parse(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let text):
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
                        Text(attributed)
                            .foregroundColor(textColor)
                            .tint(textColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .image(let url, let alt):
                    VStack(alignment: .leading, spacing: 4) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 120)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                Text("Khong tai duoc anh")
                                    .foregroundColor(textColor.opacity(0.8))
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        if !alt.isEmpty {
                            Text(alt)
                                .font(.caption)
                                .foregroundColor(textColor.opacity(0.8))
                        }
                    }
                }
            }
        }
    }
}

private enum MarkdownSegment {
    case text(String)
    case image(url: URL, alt: String)

    static func parse(_ markdown: String) -> [MarkdownSegment] {
        let pattern = #"!\[([^\]]*)\]\(([^\s\)]+)(?:\s+\"[^\"]*\")?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(markdown)]
        }

        let nsString = markdown as NSString
        let matches = regex.matches(in: markdown, range: NSRange(location: 0, length: nsString.length))

        guard !matches.isEmpty else {
            return [.text(markdown)]
        }

        var result: [MarkdownSegment] = []
        var cursor = 0

        for match in matches {
            if match.range.location > cursor {
                let prefix = nsString.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                result.append(.text(prefix))
            }

            let alt = nsString.substring(with: match.range(at: 1))
            let urlString = nsString.substring(with: match.range(at: 2))

            if let url = URL(string: urlString), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                result.append(.image(url: url, alt: alt))
            } else {
                let full = nsString.substring(with: match.range)
                result.append(.text(full))
            }

            cursor = match.range.location + match.range.length
        }

        if cursor < nsString.length {
            let suffix = nsString.substring(with: NSRange(location: cursor, length: nsString.length - cursor))
            result.append(.text(suffix))
        }

        return result
    }
}
