//
//  VoiceSOSAgentView.swift
//  SosMienTrung
//
//  Voice SOS Agent UI — cuộc hội thoại voice giữa user và AI.
//  Hiển thị transcript, collected info, sóng âm animation, và trạng thái gửi SOS.
//

import SwiftUI

struct VoiceSOSAgentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VoiceSOSAgentViewModel

    init(bridgefyManager: BridgefyNetworkManager) {
        _viewModel = StateObject(wrappedValue: VoiceSOSAgentViewModel(bridgefyManager: bridgefyManager))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    voiceSOSHeader
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.top, DS.Spacing.sm)

                    // Conversation & info
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: DS.Spacing.sm) {
                                // On-device AI availability / permission request
                                if !viewModel.isOnDeviceAIAvailable && viewModel.conversationState == .idle {
                                    unavailableCard
                                } else if !viewModel.isAuthorized && viewModel.conversationState == .idle {
                                    permissionCard
                                }

                                // Chat messages
                                ForEach(viewModel.messages) { message in
                                    VoiceMessageBubble(message: message)
                                        .id(message.id)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                }

                                // Real-time transcription (while listening)
                                if viewModel.conversationState == .listeningUser,
                                   !viewModel.currentTranscription.isEmpty {
                                    liveTranscriptionBubble
                                        .id("live-transcription")
                                }

                                // Processing indicator
                                if viewModel.conversationState == .processingResponse {
                                    processingIndicator
                                        .id("processing")
                                }

                                // Collected info card
                                if !viewModel.collectedDraft.summaryLines.isEmpty || !viewModel.collectedDraft.missingFieldLabels.isEmpty {
                                    collectedInfoCard
                                        .id("info-card")
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }

                                // Success card
                                if case .completed(let success) = viewModel.conversationState, success {
                                    successCard
                                        .id("success")
                                        .transition(.scale.combined(with: .opacity))
                                }

                                Color.clear.frame(height: 180)
                            }
                            .padding(.vertical, DS.Spacing.sm)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.messages.count)
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            if let lastId = viewModel.messages.last?.id {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: viewModel.currentTranscription) { _ in
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo("live-transcription", anchor: .bottom)
                            }
                        }
                    }

                    // Bottom control area
                    bottomControlArea
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await viewModel.requestPermissions()
                }
            }
            .onDisappear {
                viewModel.stopConversation()
            }
        }
    }

    // MARK: - Header

    private var voiceSOSHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Button {
                    viewModel.stopConversation()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DS.Colors.text)
                        .frame(width: 36, height: 36)
                        .background(DS.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .stroke(DS.Colors.border, lineWidth: DS.Border.thin)
                        )
                }

                Spacer()

                stateIndicator
            }

            HStack(spacing: DS.Spacing.xs) {
                EyebrowLabel(text: "VOICE")
                Text("SOS Agent")
                    .font(DS.Typography.title2)
                    .foregroundColor(DS.Colors.text)
            }

            EditorialDivider(height: DS.Border.thick)
        }
    }

    private var stateIndicator: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(stateColor.opacity(0.4))
                        .frame(width: 16, height: 16)
                        .opacity(isStateAnimating ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isStateAnimating)
                )

            Text(stateLabel)
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(DS.Colors.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(DS.Colors.borderSubtle, lineWidth: DS.Border.thin))
    }

    private var stateColor: Color {
        switch viewModel.conversationState {
        case .idle: return DS.Colors.textMuted
        case .aiSpeaking: return DS.Colors.assistant
        case .listeningUser: return DS.Colors.success
        case .processingResponse: return DS.Colors.warning
        case .confirming: return DS.Colors.info
        case .sendingSOS: return DS.Colors.danger
        case .completed: return DS.Colors.success
        case .error: return DS.Colors.danger
        }
    }

    private var isStateAnimating: Bool {
        switch viewModel.conversationState {
        case .aiSpeaking, .listeningUser, .processingResponse, .sendingSOS:
            return true
        default:
            return false
        }
    }

    private var stateLabel: String {
        switch viewModel.conversationState {
        case .idle: return "Sẵn sàng"
        case .aiSpeaking: return "AI đang nói..."
        case .listeningUser: return "Đang nghe..."
        case .processingResponse: return "Đang xử lý..."
        case .confirming: return "Xác nhận"
        case .sendingSOS: return "Đang gửi SOS..."
        case .completed: return "Hoàn tất"
        case .error: return "Lỗi"
        }
    }

    // MARK: - Permission Card

    private var unavailableCard: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 36))
                .foregroundColor(DS.Colors.warning)

            Text("Voice SOS không khả dụng")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)

            Text(viewModel.aiUnavailableMessage)
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.Spacing.lg)
        .sharpCard()
        .padding(.horizontal, DS.Spacing.md)
    }

    private var permissionCard: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "mic.badge.xmark")
                .font(.system(size: 36))
                .foregroundColor(DS.Colors.warning)

            Text("Cần quyền truy cập")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.text)

            Text("Voice SOS cần quyền nhận dạng giọng nói và microphone để hoạt động. Vui lòng cấp quyền trong Cài đặt.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("MỞ CÀI ĐẶT")
                    .font(DS.Typography.headline)
                    .tracking(1)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
        .padding(DS.Spacing.lg)
        .sharpCard()
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Live Transcription

    private var liveTranscriptionBubble: some View {
        HStack {
            Spacer(minLength: 60)
            HStack(spacing: DS.Spacing.xs) {
                Text(viewModel.currentTranscription)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text.opacity(0.6))
                    .italic()

                ProgressView()
                    .scaleEffect(0.7)
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(DS.Colors.accent.opacity(0.3), lineWidth: DS.Border.thin)
            )
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Processing Indicator

    private var processingIndicator: some View {
        HStack {
            HStack(spacing: DS.Spacing.xs) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Đang phân tích...")
                    .font(DS.Typography.subheadline)
                    .foregroundColor(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.sm)
            .background(DS.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .stroke(DS.Colors.borderSubtle, lineWidth: DS.Border.thin)
            )
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Collected Info Card

    private var collectedInfoCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "checklist")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(DS.Colors.accent)
                Text("THÔNG TIN ĐÃ GOM")
                    .font(DS.Typography.caption)
                    .tracking(2)
                    .foregroundColor(DS.Colors.accent)
            }

            ForEach(Array(viewModel.collectedDraft.summaryLines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: DS.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DS.Colors.success)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.label)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textSecondary)
                        Text(line.value)
                            .font(DS.Typography.body)
                            .foregroundColor(DS.Colors.text)
                    }
                }
            }

            if !viewModel.collectedDraft.missingFieldLabels.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("CẦN BỔ SUNG")
                        .font(DS.Typography.caption)
                        .tracking(1.5)
                        .foregroundColor(DS.Colors.warning)

                    ForEach(viewModel.collectedDraft.missingFieldLabels, id: \.self) { label in
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(DS.Colors.warning)
                            Text(label)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.textSecondary)
                        }
                    }
                }
                .padding(.top, DS.Spacing.xs)
            }

            if let countdown = viewModel.autoSendCountdown {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DS.Colors.danger)
                    Text("Tự gửi SOS sau \(countdown)s nếu không có phản hồi")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.danger)
                }
                .padding(.top, DS.Spacing.xxs)
            } else {
                Text(viewModel.collectedDraft.readyToSend ? "Đủ thông tin - sẵn sàng gửi SOS" : "AI đang gom thông tin từ lời nói...")
                    .font(DS.Typography.caption)
                    .foregroundColor(viewModel.collectedDraft.readyToSend ? DS.Colors.success : DS.Colors.textSecondary)
            }
        }
        .padding(DS.Spacing.md)
        .sharpCard(borderColor: DS.Colors.accent.opacity(0.3))
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Success Card

    private var successCard: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(DS.Colors.success)

            Text("SOS ĐÃ GỬI")
                .font(DS.Typography.headline)
                .tracking(2)
                .foregroundColor(DS.Colors.text)

            Text(viewModel.sosSentToServer
                 ? "Tín hiệu SOS đã được gửi trực tiếp lên server."
                 : "SOS đang chờ gửi lên server. Hệ thống sẽ tự gửi khi có mạng.")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.stopConversation()
                dismiss()
            } label: {
                Text("ĐÓNG")
                    .font(DS.Typography.headline)
                    .tracking(1)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.success)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
        .padding(DS.Spacing.lg)
        .sharpCard(borderColor: DS.Colors.success.opacity(0.5))
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Bottom Control Area

    private var bottomControlArea: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Mic button area
            switch viewModel.conversationState {
            case .idle:
                startButton

            case .aiSpeaking:
                aiSpeakingIndicator

            case .listeningUser:
                listeningControl

            case .processingResponse:
                EmptyView()

            case .sendingSOS:
                sendingIndicator

            case .completed:
                EmptyView()

            case .error(let msg):
                errorView(msg)

            case .confirming:
                EmptyView()
            }
        }
        .padding(DS.Spacing.md)
        .background(
            DS.Colors.surface
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -4)
        )
        .overlay(
            Rectangle().frame(height: DS.Border.thin).foregroundColor(DS.Colors.border),
            alignment: .top
        )
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            viewModel.startConversation()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20, weight: .bold))
                Text(viewModel.isOnDeviceAIAvailable ? "BẮT ĐẦU HỘI THOẠI SOS" : "VOICE SOS KHÔNG KHẢ DỤNG")
                    .font(DS.Typography.headline)
                    .tracking(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.danger)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .disabled(!viewModel.isAuthorized || !viewModel.isOnDeviceAIAvailable)
        .opacity(viewModel.isAuthorized && viewModel.isOnDeviceAIAvailable ? 1.0 : 0.5)
    }

    // MARK: - AI Speaking Indicator

    private var aiSpeakingIndicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            SoundWaveView(isAnimating: true, color: DS.Colors.assistant)
                .frame(height: 32)

            Text("AI đang nói...")
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.textSecondary)

            Spacer()

            Button {
                viewModel.speechSynthesis.stopSpeaking()
                viewModel.manualStartListening()
            } label: {
                Text("Bỏ qua")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.accent)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .stroke(DS.Colors.accent, lineWidth: DS.Border.thin)
                    )
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Listening Control

    private var listeningControl: some View {
        VStack(spacing: DS.Spacing.sm) {
            SoundWaveView(isAnimating: true, color: DS.Colors.success)
                .frame(height: 40)

            HStack(spacing: DS.Spacing.lg) {
                // Cancel button
                Button {
                    viewModel.stopConversation()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DS.Colors.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(DS.Colors.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))
                }

                // Main mic button
                Button {
                    viewModel.manualStopListening()
                } label: {
                    ZStack {
                        Circle()
                            .fill(DS.Colors.danger)
                            .frame(width: 72, height: 72)
                            .shadow(color: DS.Colors.danger.opacity(0.4), radius: 8, x: 0, y: 4)

                        Circle()
                            .stroke(DS.Colors.danger.opacity(0.3), lineWidth: 2)
                            .frame(width: 88, height: 88)
                            .scaleEffect(pulseScale)
                            .opacity(pulseOpacity)
                            .animation(
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                value: pulseScale
                            )

                        Image(systemName: "mic.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // Dummy spacer for symmetry
                Color.clear.frame(width: 48, height: 48)
            }

            Text("Nhấn nút mic khi nói xong")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textSecondary)

            if viewModel.canSkipAndSend {
                Button {
                    viewModel.skipAndSend()
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "paperplane.fill")
                        Text("Bỏ qua và gửi SOS")
                    }
                    .font(DS.Typography.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.danger)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
            }
        }
    }

    private var pulseScale: CGFloat {
        viewModel.conversationState == .listeningUser ? 1.15 : 1.0
    }

    private var pulseOpacity: Double {
        viewModel.conversationState == .listeningUser ? 0.6 : 0
    }

    // MARK: - Sending Indicator

    private var sendingIndicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProgressView()
            Text("Đang gửi SOS...")
                .font(DS.Typography.headline)
                .foregroundColor(DS.Colors.danger)
        }
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(message)
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.danger)
                .multilineTextAlignment(.center)

            Button {
                viewModel.startConversation()
            } label: {
                Text("THỬ LẠI")
                    .font(DS.Typography.headline)
                    .tracking(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
    }
}

// MARK: - Voice Message Bubble

private struct VoiceMessageBubble: View {
    let message: VoiceMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    Text(message.text)
                        .font(DS.Typography.body)
                        .padding(DS.Spacing.sm)
                        .background(DS.Colors.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 8))
                        Text(timeString)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(DS.Colors.textMuted)
                }
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xxs) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(DS.Colors.assistant)
                        Text("AI")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.assistant)
                    }

                    Text(message.text)
                        .font(DS.Typography.body)
                        .padding(DS.Spacing.sm)
                        .background(DS.Colors.surface)
                        .foregroundColor(DS.Colors.text)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .stroke(DS.Colors.borderSubtle, lineWidth: DS.Border.thin)
                        )

                    Text(timeString)
                        .font(.system(size: 10))
                        .foregroundColor(DS.Colors.textMuted)
                }
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.timestamp)
    }
}

// MARK: - Sound Wave Animation

private struct SoundWaveView: View {
    let isAnimating: Bool
    var color: Color = DS.Colors.accent
    private let barCount = 7

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                SoundWaveBar(
                    isAnimating: isAnimating,
                    delay: Double(index) * 0.1,
                    color: color
                )
            }
        }
    }
}

private struct SoundWaveBar: View {
    let isAnimating: Bool
    let delay: Double
    var color: Color

    @State private var height: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 4, height: height)
            .onAppear {
                if isAnimating {
                    startAnimation()
                }
            }
            .onChange(of: isAnimating) { animating in
                if animating {
                    startAnimation()
                } else {
                    height = 4
                }
            }
    }

    private func startAnimation() {
        withAnimation(
            .easeInOut(duration: 0.4)
            .repeatForever(autoreverses: true)
            .delay(delay)
        ) {
            height = CGFloat.random(in: 12...32)
        }
    }
}

// MARK: - Preview

#if swift(>=5.9)
@available(iOS 17, *)
#Preview {
    VoiceSOSAgentView(bridgefyManager: BridgefyNetworkManager.shared)
}
#endif
