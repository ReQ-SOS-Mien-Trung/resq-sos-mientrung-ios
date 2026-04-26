//
//  VoiceSOSAgentViewModel.swift
//  SosMienTrung
//
//  Orchestrates the dynamic Voice SOS flow:
//  AI asks -> victim speaks freely -> on-device model updates structured draft
//  -> ask once for missing essentials or send with available information.
//

import Foundation
import Combine
import CoreLocation
import AVFoundation
import UIKit

// MARK: - Conversation State

enum VoiceConversationState: Equatable {
    case idle
    case aiSpeaking
    case listeningUser
    case processingResponse
    case confirming
    case sendingSOS
    case completed(success: Bool)
    case error(String)
}

// MARK: - Voice Message

struct VoiceMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp = Date()
}

// MARK: - ViewModel

@MainActor
final class VoiceSOSAgentViewModel: ObservableObject {

    // MARK: - Published State

    @Published var conversationState: VoiceConversationState = .idle
    @Published var messages: [VoiceMessage] = []
    @Published var collectedDraft = VoiceSOSDraft.empty
    @Published var currentTranscription: String = ""
    @Published var isAuthorized: Bool = false
    @Published var sosSentToServer: Bool = false
    @Published private(set) var autoSendCountdown: Int?
    @Published private(set) var aiAvailability: VoiceSOSAIAvailability

    var isOnDeviceAIAvailable: Bool {
        aiAvailability.isAvailable
    }

    var aiUnavailableMessage: String {
        aiAvailability.message ?? "Voice SOS cần AI trên thiết bị khả dụng."
    }

    var canSkipAndSend: Bool {
        followUpCount > 0 &&
            conversationState != .sendingSOS &&
            conversationState != .completed(success: true)
    }

    // MARK: - Services

    let speechRecognition = SpeechRecognitionService()
    let speechSynthesis = SpeechSynthesisService()
    private let localProvider: VoiceSOSUnderstandingProvider
    private let onlineProvider = GeminiVoiceSOSUnderstandingProvider()
    
    private var currentProvider: VoiceSOSUnderstandingProvider {
        if NetworkMonitor.shared.isConnected {
            return onlineProvider
        }
        return localProvider
    }

    // MARK: - Dependencies

    private let bridgefyManager: BridgefyNetworkManager
    private let locationManager: LocationManager
    private let availabilityProvider: () -> VoiceSOSAIAvailability
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Conversation Data

    private var conversationHistory: [VoiceConversationTurn] = []
    private var followUpCount = 0
    private let maxFollowUps = 3
    private var pendingSendAfterAISpeech = false
    private var hasStartedSending = false
    private var autoSendCountdownTask: Task<Void, Never>?

    // MARK: - Init

    convenience init(bridgefyManager: BridgefyNetworkManager) {
        self.init(
            bridgefyManager: bridgefyManager,
            understandingProvider: FoundationModelsVoiceSOSUnderstandingProvider(),
            aiAvailability: VoiceSOSAvailability.current(),
            availabilityProvider: { VoiceSOSAvailability.current() }
        )
    }

    init(
        bridgefyManager: BridgefyNetworkManager,
        understandingProvider: VoiceSOSUnderstandingProvider,
        aiAvailability: VoiceSOSAIAvailability,
        availabilityProvider: @escaping () -> VoiceSOSAIAvailability
    ) {
        self.bridgefyManager = bridgefyManager
        self.locationManager = bridgefyManager.locationManager
        self.localProvider = understandingProvider
        self.aiAvailability = aiAvailability
        self.availabilityProvider = availabilityProvider

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        speechRecognition.$transcribedText
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentTranscription)

        speechRecognition.onSpeechFinished = { [weak self] text in
            Task { @MainActor in
                await self?.handleUserFinishedSpeaking(text)
            }
        }

        speechSynthesis.onFinishedSpeaking = { [weak self] in
            Task { @MainActor in
                self?.handleAIFinishedSpeaking()
            }
        }
    }

    // MARK: - Authorization

    func requestPermissions() async {
        aiAvailability = availabilityProvider()
        guard aiAvailability.isAvailable else {
            isAuthorized = false
            return
        }

        let speechAuthorized = await speechRecognition.requestAuthorization()

        let micAuthorized: Bool
        if #available(iOS 17.0, *) {
            micAuthorized = await AVAudioApplication.requestRecordPermission()
        } else {
            micAuthorized = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        isAuthorized = speechAuthorized && micAuthorized
    }

    // MARK: - Start / Stop Conversation

    func startConversation() {
        aiAvailability = availabilityProvider()
        guard aiAvailability.isAvailable else {
            conversationState = .error(aiUnavailableMessage)
            return
        }

        guard isAuthorized else {
            conversationState = .error("Chưa được cấp quyền sử dụng microphone và nhận dạng giọng nói.")
            return
        }

        cancelAutoSendCountdown()
        messages.removeAll()
        conversationHistory.removeAll()
        collectedDraft = .empty
        currentTranscription = ""
        followUpCount = 0
        pendingSendAfterAISpeech = false
        hasStartedSending = false
        sosSentToServer = false

        locationManager.startContinuousUpdates()

        aiSpeak("Vui lòng mô tả tình huống hiện tại của bạn để gửi yêu cầu cứu hộ")
    }

    func stopConversation() {
        cancelAutoSendCountdown()
        speechRecognition.stopListening()
        speechSynthesis.stopSpeaking()
        locationManager.stopContinuousUpdates()
        conversationState = .idle
    }

    // MARK: - AI Speaking

    private func aiSpeak(_ text: String) {
        conversationState = .aiSpeaking

        let aiMessage = VoiceMessage(text: text, isUser: false)
        messages.append(aiMessage)
        conversationHistory.append(VoiceConversationTurn(role: "ai", text: text))

        speechSynthesis.speak(text)
    }

    // MARK: - Event Handlers

    private func handleAIFinishedSpeaking() {
        if case .completed = conversationState { return }
        if case .sendingSOS = conversationState { return }

        if pendingSendAfterAISpeech {
            pendingSendAfterAISpeech = false
            sendSOS()
            return
        }

        startListeningToUser()
    }

    private func startListeningToUser() {
        conversationState = .listeningUser
        currentTranscription = ""
        speechRecognition.startListening()

        if followUpCount > 0 {
            startAutoSendCountdown(seconds: 10)
        } else {
            cancelAutoSendCountdown()
        }
    }

    private func handleUserFinishedSpeaking(_ text: String) async {
        cancelAutoSendCountdown()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await handleEmptySpeech()
            return
        }

        let userMessage = VoiceMessage(text: trimmed, isUser: true)
        messages.append(userMessage)
        conversationHistory.append(VoiceConversationTurn(role: "user", text: trimmed))
        currentTranscription = ""
        conversationState = .processingResponse

        do {
            let updatedDraft = try await currentProvider.updateDraft(
                conversationHistory: conversationHistory,
                currentDraft: collectedDraft
            )
            collectedDraft = updatedDraft.grounded(in: userConversationTexts)
            continueAfterDraftUpdate()
        } catch {
            print("Voice SOS AI Error: \(error)")
            if followUpCount >= maxFollowUps {
                pendingSendAfterAISpeech = true
                aiSpeak("Mình gặp chút lỗi khi phân tích thông tin, nhưng mình sẽ gửi SOS ngay với những gì đã ghi nhận.")
            } else {
                followUpCount += 1
                aiSpeak("Mình chưa nghe rõ thông tin cứu hộ, bạn hãy nói lại giúp mình số người và tình hình hiện tại nhé.")
            }
        }
    }

    private func continueAfterDraftUpdate() {
        if canAutomaticallySendCurrentDraft {
            pendingSendAfterAISpeech = true
            aiSpeak("Mình đã gom đủ thông tin khẩn cấp. SOS đang được gửi.")
            return
        }

        if followUpCount < maxFollowUps {
            followUpCount += 1
            aiSpeak(collectedDraft.followUpQuestion ?? "Bạn bổ sung nhanh giúp mình số người và nhu cầu hỗ trợ chính.")
            return
        }

        pendingSendAfterAISpeech = true
        aiSpeak("Mình sẽ gửi SOS với thông tin hiện có.")
    }

    private func handleEmptySpeech() async {
        if followUpCount > 0 {
            skipAndSend()
        } else {
            startListeningToUser()
        }
    }

    // MARK: - Auto-send / Skip

    func skipAndSend() {
        guard conversationState != .sendingSOS else { return }
        if case .completed = conversationState { return }

        cancelAutoSendCountdown()
        speechRecognition.stopListening()
        pendingSendAfterAISpeech = true
        aiSpeak("Mình sẽ gửi SOS với thông tin hiện có.")
    }

    private func startAutoSendCountdown(seconds: Int) {
        cancelAutoSendCountdown()
        autoSendCountdownTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for remaining in stride(from: seconds, through: 0, by: -1) {
                guard !Task.isCancelled else { return }
                self.autoSendCountdown = remaining
                if remaining > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }

            guard !Task.isCancelled else { return }
            guard self.conversationState == .listeningUser,
                  self.followUpCount > 0,
                  self.currentTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.autoSendCountdown = nil
                return
            }

            self.skipAndSend()
        }
    }

    private func cancelAutoSendCountdown() {
        autoSendCountdownTask?.cancel()
        autoSendCountdownTask = nil
        autoSendCountdown = nil
    }

    // MARK: - Send SOS

    private func sendSOS() {
        guard !hasStartedSending else { return }
        hasStartedSending = true
        cancelAutoSendCountdown()
        conversationState = .sendingSOS

        Task { @MainActor in
            let formData = buildSOSFormData()
            let serverReached = await bridgefyManager.sendStructuredSOS(formData)

            sosSentToServer = serverReached
            conversationState = .completed(success: true)
            locationManager.stopContinuousUpdates()

            let resultText: String
            if serverReached {
                resultText = "SOS đã được gửi thành công lên máy chủ. Đội cứu hộ sẽ nhận được thông tin của bạn."
            } else {
                resultText = "SOS đã được phát qua Mesh Network. Hệ thống sẽ tự gửi lên máy chủ khi có kết nối mạng."
            }

            messages.append(VoiceMessage(text: resultText, isUser: false))
            speechSynthesis.speak(resultText)
        }
    }

    // MARK: - Build SOSFormData

    private func buildSOSFormData() -> SOSFormData {
        collectedDraft.makeSOSFormData(
            autoInfo: makeAutoInfo(),
            conversationUserTexts: userConversationTexts,
            applyDefaults: true
        )
    }

    private var userConversationTexts: [String] {
        conversationHistory
            .filter { $0.role == "user" }
            .map(\.text)
    }

    private var canAutomaticallySendCurrentDraft: Bool {
        let groundedDraft = collectedDraft.grounded(in: userConversationTexts)
        return groundedDraft.readyToSend &&
            groundedDraft.missingFields.isEmpty &&
            groundedDraft.followUpQuestion == nil
    }

    private func makeAutoInfo() -> AutoCollectedInfo {
        let location = locationManager.currentLocation
        return AutoCollectedInfo(
            deviceId: bridgefyManager.currentUserId?.uuidString
                ?? UIDevice.current.identifierForVendor?.uuidString
                ?? UUID().uuidString,
            userId: AuthSessionStore.shared.session?.userId,
            userName: UserProfile.shared.currentUser?.name,
            userPhone: UserProfile.shared.currentUser?.phoneNumber,
            timestamp: Date(),
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            accuracy: location?.horizontalAccuracy,
            isOnline: NetworkMonitor.shared.isConnected,
            batteryLevel: getBatteryLevel()
        )
    }

    private func getBatteryLevel() -> Int? {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        guard level >= 0 else { return nil }
        return Int(level * 100)
    }

    // MARK: - Manual Mic Control

    func manualStartListening() {
        guard conversationState != .aiSpeaking,
              conversationState != .sendingSOS else { return }

        speechSynthesis.stopSpeaking()
        startListeningToUser()
    }

    func manualStopListening() {
        let capturedText = currentTranscription
        speechRecognition.stopListening()

        Task { @MainActor [weak self] in
            await self?.handleUserFinishedSpeaking(capturedText)
        }
    }
}
