import SwiftUI

struct ChatBotView: View {
    @StateObject private var service = ChatBotService()
    @State private var messageText = ""
    @State private var messages: [BotChatMessage] = []
    @State private var scrollToId: UUID?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Editorial header
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    EyebrowLabel(text: "TRỢ LÝ")
                    Text("An Toàn")
                        .font(DS.Typography.largeTitle)
                        .foregroundColor(DS.Colors.text)
                    EditorialDivider(height: DS.Border.thick)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: DS.Spacing.sm) {
                            ForEach(messages) { message in
                                BotMessageBubble(message: message)
                                    .id(message.id)
                            }

                            if service.isProcessing {
                                HStack {
                                    ProgressView()
                                        .padding(DS.Spacing.sm)
                                        .background(DS.Colors.surface)
                                        .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                                    Spacer()
                                }
                                .padding(.horizontal, DS.Spacing.md)
                                .id("processing")
                            }

                            Color.clear.frame(height: 70)
                        }
                        .padding(.vertical, DS.Spacing.sm)
                    }
                    .onChange(of: scrollToId) { newId in
                        if let id = newId {
                            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: service.isProcessing) { processing in
                        if processing {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("processing", anchor: .bottom) }
                            }
                        }
                    }
                }

                // Input bar
                HStack(spacing: DS.Spacing.sm) {
                    ResQTextField(placeholder: "Hỏi về an toàn lũ lụt...", text: $messageText)
                        .focused($isFocused)
                        .disabled(service.isProcessing)

                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(messageText.isEmpty || service.isProcessing ? DS.Colors.textTertiary : .white)
                            .frame(width: 40, height: 40)
                            .background(messageText.isEmpty || service.isProcessing ? DS.Colors.surface : DS.Colors.accent)
                            .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                    }
                    .disabled(messageText.isEmpty || service.isProcessing)
                }
                .padding(DS.Spacing.sm)
                .background(DS.Colors.surface)
                .overlay(Rectangle().frame(height: DS.Border.thin).foregroundColor(DS.Colors.border), alignment: .top)
            }
            .background(DS.Colors.background)
            .navigationBarHidden(true)
            .onAppear {
                if messages.isEmpty {
                    let welcome = BotChatMessage(text: "Xin chào! Tôi là trợ lý ảo hỗ trợ thông tin về thiên tai và an toàn. Tôi có thể giúp gì cho bạn?", isUser: false)
                    messages.append(welcome)
                }
            }
            .onTapGesture { isFocused = false }
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Dismiss keyboard first
        isFocused = false
        
        let userMsg = BotChatMessage(text: text, isUser: true)
        messages.append(userMsg)
        messageText = ""
        scrollToId = userMsg.id
        service.isProcessing = true
        
        // Capture service reference for async context
        let chatService = service
        
        Task {
            do {
                let response = try await chatService.sendMessage(text)
                let botMsg = BotChatMessage(text: response, isUser: false)
                messages.append(botMsg)
                scrollToId = botMsg.id
            } catch {
                let errorMsg = BotChatMessage(text: "Xin lỗi, tôi gặp sự cố khi xử lý yêu cầu. Vui lòng thử lại.", isUser: false)
                messages.append(errorMsg)
                scrollToId = errorMsg.id
            }
            service.isProcessing = false
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

struct BotChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

struct BotMessageBubble: View {
    let message: BotChatMessage
    
    private var formattedText: AttributedString {
        do {
            return try AttributedString(markdown: message.text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch {
            return AttributedString(message.text)
        }
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
                Text(message.text)
                    .font(DS.Typography.body)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.accent)
                    .foregroundColor(.white)
            } else {
                Text(formattedText)
                    .font(DS.Typography.body)
                    .padding(DS.Spacing.sm)
                    .background(DS.Colors.surface)
                    .foregroundColor(DS.Colors.text)
                    .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
    }
}

// Extension to allow specific corner rounding if not already present
extension View {
    func botCornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(BotRoundedCorner(radius: radius, corners: corners))
    }
}

struct BotRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
