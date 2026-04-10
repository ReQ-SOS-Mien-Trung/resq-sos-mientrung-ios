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
    @State private var selectedImagePreview: ChatImagePreview?
    @State private var showQuickDispatchSheet = false
    
    private var visibleMessages: [CoordinatorChatMessage] {
        vm.chatService.messages.filter { message in
            let isAiMessage = message.messageType == CoordinatorMessageType.aiMessage.rawValue
            let structuredContent = SosStructuredChatParser.content(from: message.content)
            let hasStructuredSosCard =
                SosQuickDispatchCardPayload.decode(from: message.content) != nil
                || structuredContent != nil

            // Sau khi đã vào room chat hỗ trợ, chỉ giữ lại thẻ SOS đã chọn hỗ trợ.
            if structuredContent?.source == .sosList {
                return false
            }

            return !isAiMessage || hasStructuredSosCard
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBanner

            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        ForEach(visibleMessages) { msg in
                            CoordinatorMessageBubble(
                                message: msg,
                                currentUserId: AuthSessionStore.shared.session?.userId,
                                onImageTap: { url, alt in
                                    selectedImagePreview = ChatImagePreview(url: url, alt: alt)
                                }
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(DS.Spacing.sm)
                }
                .onChange(of: visibleMessages.count) { _ in
                    if let last = visibleMessages.last {
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
        .onAppear {
            CoordinatorChatVisibilityState.shared.enter(conversationId: vm.conversationId)
            Task {
                await vm.loadQuickDispatchSosRequestsIfNeeded()
            }
        }
        .onDisappear {
            CoordinatorChatVisibilityState.shared.leave()
        }
        .onChange(of: vm.conversationId) { newConversationId in
            guard CoordinatorChatVisibilityState.shared.isChatVisible else { return }
            CoordinatorChatVisibilityState.shared.update(conversationId: newConversationId)
        }
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
            AppCameraPicker(image: $pickedCameraImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showQuickDispatchSheet) {
            quickDispatchSheet
        }
        .fullScreenCover(item: $selectedImagePreview) { preview in
            ChatImagePreviewView(preview: preview)
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
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.xs) {
                    ProgressView().scaleEffect(0.7)
                    Text("Đang chờ nhân viên hỗ trợ tham gia...")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.warning)
                    Spacer()
                }

                if let linkedSosId = vm.linkedSosRequestId {
                    Text("SOS #\(linkedSosId) đã liên kết. Khi cần mới bấm nút tia sét để gửi card.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.warning.opacity(0.12))
        } else if vm.chatService.conversationStatus == .coordinatorActive {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DS.Colors.success)
                        .font(.caption)
                    Text("Đã kết nối với Người điều phối")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.success)
                    Spacer()
                }

                if let linkedSosId = vm.linkedSosRequestId {
                    Text("SOS #\(linkedSosId) đã sẵn sàng. Bấm nút tia sét khi bạn muốn gửi card SOS.")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
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
                MarkdownRichText(content: vm.inputText, textColor: DS.Colors.text, onImageTap: { _, _ in })
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
                    showQuickDispatchSheet = true
                } label: {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DS.Colors.danger)
                        .frame(width: 40, height: 40)
                        .background(DS.Colors.danger.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
                        )
                }
                        .accessibilityLabel("Gửi card SOS")
                        .accessibilityHint("Chỉ gửi khi bạn bấm nút này")

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

    private var quickDispatchSheet: some View {
        NavigationStack {
            Group {
                if vm.sosRequests.isEmpty {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(DS.Colors.textTertiary)

                        Text("Chưa có yêu cầu SOS để gửi nhanh")
                            .font(DS.Typography.headline)
                            .foregroundColor(DS.Colors.text)

                        Text("Tạo SOS mới hoặc tải lại danh sách để chia sẻ thẻ SOS trong chat.")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.lg)

                        Button {
                            Task {
                                await vm.loadQuickDispatchSosRequestsIfNeeded(forceReload: true)
                            }
                        } label: {
                            Text("Tải lại danh sách SOS")
                                .font(DS.Typography.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.sm)
                                .background(DS.Colors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(DS.Spacing.md)
                } else {
                    List(vm.sosRequests) { sos in
                        Button {
                            vm.sendSosQuickDispatchCard(sos)
                            showQuickDispatchSheet = false
                        } label: {
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                HStack {
                                    Text("SOS #\(sos.id)")
                                        .font(DS.Typography.headline)
                                        .foregroundColor(DS.Colors.text)
                                    Spacer()
                                    Text("Bấm để gửi card")
                                        .font(DS.Typography.caption)
                                        .foregroundColor(DS.Colors.accent)
                                }

                                Text(sos.msg)
                                    .font(DS.Typography.caption)
                                    .foregroundColor(DS.Colors.textSecondary)
                                    .lineLimit(2)

                                HStack(spacing: DS.Spacing.xs) {
                                    if let localizedType = SosDisplayFormatter.localizedType(sos.sosType) {
                                        Text(localizedType)
                                            .font(DS.Typography.caption)
                                            .foregroundColor(DS.Colors.textSecondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(DS.Colors.surface)
                                            .clipShape(Capsule())
                                    }

                                    let statusColor = SosStatusPresentation.color(for: sos.status)
                                    Text(SosDisplayFormatter.localizedStatus(sos.status))
                                        .font(DS.Typography.caption)
                                        .foregroundColor(statusColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(statusColor.opacity(0.15))
                                        .clipShape(Capsule())

                                    if let wait = sos.waitTimeMinutes {
                                        Text("\(wait) phút")
                                            .font(DS.Typography.caption)
                                            .foregroundColor(DS.Colors.textSecondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(DS.Colors.surface)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("SOS Quick Dispatch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        showQuickDispatchSheet = false
                    }
                }
            }
        }
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

// MARK: - Message Bubble

struct CoordinatorMessageBubble: View {
    let message: CoordinatorChatMessage
    let currentUserId: String?
    let onImageTap: (URL, String) -> Void

    private var isFromMe: Bool {
        message.messageType == CoordinatorMessageType.userMessage.rawValue
            && message.senderId == currentUserId
    }
    private var isAI: Bool     { message.messageType == CoordinatorMessageType.aiMessage.rawValue }
    private var isSystem: Bool { message.messageType == CoordinatorMessageType.systemMessage.rawValue }
    private var sosQuickDispatchPayload: SosQuickDispatchCardPayload? {
        SosQuickDispatchCardPayload.decode(from: message.content)
    }
    private var legacyStructuredContent: SosStructuredChatContent? {
        SosStructuredChatParser.content(from: message.content)
    }
    private var hasStructuredSosContent: Bool {
        sosQuickDispatchPayload != nil || legacyStructuredContent != nil
    }

    var body: some View {
        if isSystem {
            // System message: centered pill
            MarkdownRichText(content: message.content, textColor: DS.Colors.textSecondary, onImageTap: { _, _ in })
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
                    if !isFromMe && !hasStructuredSosContent {
                        Text(message.senderName ?? (isAI ? "AI Hỗ trợ" : "Người điều phối"))
                            .font(DS.Typography.caption)
                            .foregroundColor(isAI ? DS.Colors.info : DS.Colors.accent)
                    }

                    if let payload = sosQuickDispatchPayload {
                        SosQuickDispatchMessageCard(payload: payload, isFromMe: isFromMe)
                    } else if let legacyStructuredContent {
                        SosStructuredMessageGroup(content: legacyStructuredContent, isFromMe: isFromMe)
                    } else {
                        MarkdownRichText(
                            content: message.content,
                            textColor: isFromMe ? .white : DS.Colors.text,
                            onImageTap: onImageTap
                        )
                            .font(DS.Typography.body)
                            .padding(DS.Spacing.sm)
                            .background(bubbleColor)
                            .foregroundColor(isFromMe ? .white : DS.Colors.text)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                    }
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

private struct SosStructuredChatDetail: Identifiable {
    let label: String
    let value: String

    var id: String { "\(label)-\(value)" }
}

private enum SosStructuredChatSource: String {
    case sosList
    case sosSelected
}

private struct SosStructuredChatContent {
    let source: SosStructuredChatSource
    let cards: [SosStructuredChatCard]
    let note: String?
}

private struct SosStructuredChatCard: Identifiable {
    let source: SosStructuredChatSource
    let sosRequestId: Int
    let status: String?
    let priority: String?
    let sosType: String?
    let summary: String?
    let details: [SosStructuredChatDetail]

    var id: String { "\(source.rawValue)-\(sosRequestId)" }
}

private enum SosStructuredChatParser {
    static func content(from content: String) -> SosStructuredChatContent? {
        if let listContent = parseSosListContent(from: content) {
            return listContent
        }

        if let selectedContent = parseSelectedSosContent(from: content) {
            return selectedContent
        }

        return nil
    }

    private static func parseSosListContent(from content: String) -> SosStructuredChatContent? {
        guard content.localizedCaseInsensitiveContains("danh sách yêu cầu sos") else {
            return nil
        }

        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
        let pattern = #"(?ms)\*\*(\d+)\.\s*\[ID:\s*(\d+)\]\*\*\s*([A-Za-z_]+)?\s*\n\s*Trạng\s*thái:\s*([^\n]+)\n\s*Nội\s*dung:\s*([^\n]+)(?:\n\s*Gửi\s*lúc:\s*([^\n]+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let matches = regex.matches(in: normalized, options: [], range: nsRange)

        let cards = matches.compactMap { match -> SosStructuredChatCard? in
            guard let idText = value(at: 2, in: match, source: normalized),
                  let sosRequestId = Int(idText) else {
                return nil
            }

            let statusLine = value(at: 4, in: match, source: normalized)
            let contentLine = value(at: 5, in: match, source: normalized)
            let parsedBody = parseSummaryAndDetails(from: contentLine)

            var details = parsedBody.details
            if let sentAt = value(at: 6, in: match, source: normalized) {
                details.append(SosStructuredChatDetail(label: "Gửi lúc", value: sentAt))
            }

            return SosStructuredChatCard(
                source: .sosList,
                sosRequestId: sosRequestId,
                status: extractStatus(from: statusLine),
                priority: extractPriority(from: statusLine),
                sosType: value(at: 3, in: match, source: normalized),
                summary: parsedBody.summary,
                details: Array(details.prefix(5))
            )
        }

        guard !cards.isEmpty else { return nil }

        let note = capture(#"Vui\s*lòng[^\n]*(?:\n[^\n]+)*"#, in: normalized)
        return SosStructuredChatContent(source: .sosList, cards: cards, note: note)
    }

    private static func parseSelectedSosContent(from content: String) -> SosStructuredChatContent? {
        guard content.localizedCaseInsensitiveContains("đã chọn yêu cầu sos") else {
            return nil
        }

        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")

        guard let idText = capture(#"sos\s*\*?\*?\s*#\s*(\d+)"#, in: normalized),
              let sosRequestId = Int(idText) else {
            return nil
        }

        let sosType = capture(#"\(\s*([A-Za-z_]+)\s*\)"#, in: normalized)
        let bodyLine = capture(#"Nội\s*dung:\s*([^\n]+)"#, in: normalized)
        let parsedBody = parseSummaryAndDetails(from: bodyLine)
        let note = capture(#"(Một\s+Coordinator[\s\S]*)$"#, in: normalized)

        let card = SosStructuredChatCard(
            source: .sosSelected,
            sosRequestId: sosRequestId,
            status: "Đã chọn hỗ trợ",
            priority: nil,
            sosType: sosType,
            summary: parsedBody.summary,
            details: Array(parsedBody.details.prefix(6))
        )

        return SosStructuredChatContent(source: .sosSelected, cards: [card], note: note)
    }

    private static func capture(_ pattern: String, in content: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        guard let match = regex.firstMatch(in: content, options: [], range: nsRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }

        let value = content[range].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func detail(label: String, value: String?) -> SosStructuredChatDetail? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return SosStructuredChatDetail(label: label, value: value)
    }

    private static func parseSummaryAndDetails(from raw: String?) -> (summary: String?, details: [SosStructuredChatDetail]) {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return (nil, [])
        }

        let parts = raw
            .split(separator: "|", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var summary: String?
        var details: [SosStructuredChatDetail] = []

        for part in parts {
            if let separatorIndex = part.firstIndex(of: ":") {
                let label = String(part[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(part[part.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let detail = detail(label: label, value: value) {
                    details.append(detail)
                }
            } else if summary == nil {
                summary = cleanSummary(part)
            }
        }

        return (summary, details)
    }

    private static func extractStatus(from raw: String?) -> String? {
        guard let raw else { return nil }
        let parts = raw.split(separator: "|", omittingEmptySubsequences: true)
        guard let first = parts.first else { return raw }
        return first.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractPriority(from raw: String?) -> String? {
        capture(#"ưu\s*tiên:\s*(.+)$"#, in: raw ?? "")
    }

    private static func value(at index: Int, in match: NSTextCheckingResult, source: String) -> String? {
        guard match.numberOfRanges > index,
              let range = Range(match.range(at: index), in: source) else {
            return nil
        }
        let value = source[range].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func cleanSummary(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        if raw.hasPrefix("[") && raw.hasSuffix("]") {
            return nil
        }

        return raw
    }
}

private enum SosStatusPresentation {
    static func color(for rawStatus: String?) -> Color {
        switch SosDisplayFormatter.normalizedKey(rawStatus) {
        case "pending", "waiting", "queued", "new":
            return DS.Colors.warning
        case "approved", "accepted", "inprogress", "ongoing", "processing":
            return DS.Colors.info
        case "resolved", "closed", "completed", "done":
            return DS.Colors.success
        case "rejected", "declined", "cancelled", "canceled", "cancel":
            return DS.Colors.danger
        default:
            return DS.Colors.textSecondary
        }
    }
}

private struct SosStructuredMessageGroup: View {
    let content: SosStructuredChatContent
    let isFromMe: Bool

    private var headerTitle: String {
        switch content.source {
        case .sosList:
            return content.cards.count > 1 ? "Danh sách yêu cầu SOS" : "Yêu cầu SOS"
        case .sosSelected:
            return "AI hỗ trợ"
        }
    }

    private var subheaderTitle: String? {
        switch content.source {
        case .sosList:
            return nil
        case .sosSelected:
            return "Yêu cầu SOS đã chọn"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: content.source == .sosSelected ? "sparkles" : "shippingbox.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(content.source == .sosSelected ? DS.Colors.info : DS.Colors.danger)
                Text(headerTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DS.Colors.textSecondary)
                if content.cards.count > 1 {
                    Text("\(content.cards.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(DS.Colors.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DS.Colors.background)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 4)

            if let subheaderTitle {
                Text(subheaderTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.text)
                    .padding(.horizontal, 4)
            }

            ForEach(content.cards) { card in
                SosStructuredInfoCard(card: card, isFromMe: isFromMe)
            }

            if let note = content.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                Text(localizedCoordinatorTerm(in: note))
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: 300, alignment: isFromMe ? .trailing : .leading)
    }

    private func localizedCoordinatorTerm(in text: String) -> String {
        text.replacingOccurrences(of: "Coordinator", with: "Người điều phối")
    }
}

private struct SosStructuredInfoCard: View {
    let card: SosStructuredChatCard
    let isFromMe: Bool

    private var localizedStatus: String? {
        guard let status = card.status else { return nil }
        return SosDisplayFormatter.localizedStatus(status)
    }

    private var localizedType: String? {
        SosDisplayFormatter.localizedType(card.sosType)
    }

    private var localizedPriority: String? {
        guard let priority = SosDisplayFormatter.localizedPriority(card.priority) else {
            return nil
        }
        return "Ưu tiên \(priority)"
    }

    private var borderColor: Color {
        switch card.source {
        case .sosList:
            return DS.Colors.info.opacity(0.28)
        case .sosSelected:
            return DS.Colors.success.opacity(0.34)
        }
    }

    private var backgroundColor: Color {
        switch card.source {
        case .sosList:
            return DS.Colors.info.opacity(0.09)
        case .sosSelected:
            return DS.Colors.success.opacity(0.10)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .top, spacing: DS.Spacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SOS #\(card.sosRequestId)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(DS.Colors.text)

                    if let summary = card.summary {
                        Text(summary)
                            .font(DS.Typography.subheadline)
                            .foregroundColor(DS.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                if let localizedStatus {
                    statusPill(localizedStatus)
                }
            }

            HStack(spacing: DS.Spacing.xs) {
                if let localizedType {
                    metaPill(icon: "cross.case.fill", text: localizedType)
                }
                if let localizedPriority {
                    metaPill(icon: "flag.fill", text: localizedPriority)
                }
            }

            if !card.details.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(card.details) { detail in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(detail.label + ":")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(DS.Colors.textSecondary)
                            Text(detail.value)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(DS.Colors.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(DS.Spacing.sm)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(borderColor, lineWidth: DS.Border.thin)
        )
    }

    private func statusPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(SosStatusPresentation.color(for: card.status))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(SosStatusPresentation.color(for: card.status).opacity(0.14))
            .clipShape(Capsule())
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(DS.Colors.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(DS.Colors.surface)
        .clipShape(Capsule())
    }
}

private struct SosQuickDispatchMessageCard: View {
    let payload: SosQuickDispatchCardPayload
    let isFromMe: Bool

    private var localizedStatus: String {
        SosDisplayFormatter.localizedStatus(payload.status)
    }

    private var summaryText: String {
        payload.summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var compactLocationText: String? {
        guard let latitude = payload.latitude, let longitude = payload.longitude else {
            return nil
        }
        return String(format: "%.4f, %.4f", latitude, longitude)
    }

    private var typeLabel: String? {
        SosDisplayFormatter.localizedType(payload.sosType)
    }

    private var priorityLabel: String? {
        guard let localizedPriority = SosDisplayFormatter.localizedPriority(payload.priorityLevel) else {
            return nil
        }
        return "Ưu tiên \(localizedPriority)"
    }

    private var waitLabel: String? {
        guard let wait = payload.waitTimeMinutes else { return nil }
        return "\(wait) phút"
    }

    private var senderLabel: String? {
        guard let sender = payload.sharedByName?.trimmingCharacters(in: .whitespacesAndNewlines), !sender.isEmpty else {
            return nil
        }
        return sender
    }

    private var statusAccentColor: Color {
        SosStatusPresentation.color(for: payload.status)
    }

    private var cardBorderColor: Color {
        isFromMe ? DS.Colors.accent.opacity(0.45) : DS.Colors.border
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                thumbnail

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("SOS #\(payload.sosRequestId)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(DS.Colors.text)
                            .lineLimit(1)

                        Spacer(minLength: 2)
                        statusBadge
                    }

                    if let typeLabel {
                        Text(typeLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    if !summaryText.isEmpty {
                        Text(summaryText)
                            .font(DS.Typography.subheadline)
                            .foregroundColor(DS.Colors.text)
                            .lineLimit(2)
                    }

                    HStack(spacing: DS.Spacing.xs) {
                        if let priorityLabel {
                            metadataPill(icon: "flag.fill", text: priorityLabel)
                        }
                        if let waitLabel {
                            metadataPill(icon: "clock.fill", text: waitLabel)
                        }
                    }

                    if let compactLocationText {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(compactLocationText)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                        }
                        .foregroundColor(DS.Colors.textSecondary)
                    }
                }
            }
            .padding(DS.Spacing.sm)

            Divider()
                .overlay(DS.Colors.borderSubtle)

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.accent)

                Text("Thẻ SOS chia sẻ nhanh")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                if let senderLabel {
                    Text(senderLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DS.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(DS.Colors.accent.opacity(0.08))
        }
        .background(DS.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(cardBorderColor, lineWidth: DS.Border.thin)
        )
        .frame(maxWidth: 285, alignment: isFromMe ? .trailing : .leading)
    }

    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: DS.Radius.md)
            .fill(DS.Colors.danger.opacity(0.12))
            .frame(width: 64, height: 64)
            .overlay {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(DS.Colors.danger)
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(statusAccentColor)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    )
                    .padding(4)
            }
    }

    private var statusBadge: some View {
        Text(localizedStatus)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(statusAccentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusAccentColor.opacity(0.14))
            .clipShape(Capsule())
    }

    private func metadataPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(DS.Colors.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(DS.Colors.background)
        .clipShape(Capsule())
    }
}

private struct MarkdownRichText: View {
    let content: String
    let textColor: Color
    let onImageTap: (URL, String) -> Void

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
                        Button {
                            onImageTap(url, alt)
                        } label: {
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
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(Circle())
                                    .padding(8)
                            }
                        }
                        .buttonStyle(.plain)

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

private struct ChatImagePreview: Identifiable {
    let url: URL
    let alt: String

    var id: String { url.absoluteString }
}

private struct ChatImagePreviewView: View {
    let preview: ChatImagePreview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            VStack(spacing: DS.Spacing.md) {
                Spacer(minLength: 0)

                AsyncImage(url: preview.url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .failure:
                        VStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "photo")
                                .font(.system(size: 30, weight: .semibold))
                            Text("Khong tai duoc anh")
                                .font(DS.Typography.body)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, DS.Spacing.md)

                if !preview.alt.isEmpty {
                    Text(preview.alt)
                        .font(DS.Typography.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.lg)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, DS.Spacing.xl)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .padding(.top, DS.Spacing.lg)
            .padding(.trailing, DS.Spacing.md)
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
