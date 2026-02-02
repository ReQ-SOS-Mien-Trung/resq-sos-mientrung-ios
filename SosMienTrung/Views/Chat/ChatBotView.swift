import SwiftUI

struct ChatBotView: View {
    @StateObject private var service = ChatBotService()
    @State private var messageText = ""
    @State private var messages: [BotChatMessage] = []
    @State private var scrollToId: UUID?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                TelegramBackground()
                
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(messages) { message in
                                    BotMessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                if service.isProcessing {
                                    HStack {
                                        ProgressView()
                                            .padding(10)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(10)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .id("processing")
                                }
                                
                                // Bottom padding for floating input
                                Color.clear.frame(height: 80)
                            }
                            .padding(.vertical)
                        }
                        .onChange(of: scrollToId) { _, newId in
                            if let id = newId {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: service.isProcessing) { _, processing in
                            if processing {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        proxy.scrollTo("processing", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Floating Input Area - Liquid Glass Effect
                VStack {
                    Spacer()
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            TextField("Hỏi về an toàn lũ lụt...", text: $messageText)
                                .foregroundColor(.primary)
                                .focused($isFocused)
                                .disabled(service.isProcessing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        
                        // Send Button - Simple Style
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(messageText.isEmpty || service.isProcessing ? .gray : .white)
                                .frame(width: 44, height: 44)
                                .background(
                                    messageText.isEmpty || service.isProcessing ?
                                    AnyShapeStyle(.ultraThinMaterial) :
                                    AnyShapeStyle(Color.blue)
                                )
                                .clipShape(Circle())
                        }
                        .disabled(messageText.isEmpty || service.isProcessing)
                        .animation(.easeInOut(duration: 0.2), value: messageText.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Trợ lý An toàn")
            .navigationBarTitleDisplayMode(.inline)
            // Nếu target iOS 16+, có thể ẩn nền thanh điều hướng để pattern lộ rõ:
            // .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                if messages.isEmpty {
                    // Initial greeting
                    let welcome = BotChatMessage(text: "Xin chào! Tôi là trợ lý ảo hỗ trợ thông tin về thiên tai và an toàn. Tôi có thể giúp gì cho bạn?", isUser: false)
                    messages.append(welcome)
                }
            }
            .onTapGesture {
                isFocused = false
            }
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
    
    // Parse markdown to AttributedString
    private var formattedText: AttributedString {
        do {
            let attributedString = try AttributedString(markdown: message.text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            return attributedString
        } catch {
            return AttributedString(message.text)
        }
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.text)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .botCornerRadius(15, corners: [.topLeft, .topRight, .bottomLeft])
            } else {
                Text(formattedText)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .botCornerRadius(15, corners: [.topLeft, .topRight, .bottomRight])
                Spacer()
            }
        }
        .padding(.horizontal)
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
