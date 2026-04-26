//
//  SpeechRecognitionService.swift
//  SosMienTrung
//
//  Apple Speech wrapper — nhận dạng giọng nói tiếng Việt on-device.
//  Sử dụng SFSpeechRecognizer với locale vi-VN, ưu tiên xử lý on-device
//  khi thiết bị hỗ trợ (supportsOnDeviceRecognition).
//

import Foundation
import Speech
import AVFoundation
import Combine

final class SpeechRecognitionService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var transcribedText: String = ""
    @Published var isListening: Bool = false
    @Published var error: SpeechError?
    @Published var isOnDeviceAvailable: Bool = false

    // MARK: - Types

    enum SpeechError: LocalizedError {
        case notAuthorized
        case recognizerUnavailable
        case audioEngineError(String)
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Chưa được cấp quyền nhận dạng giọng nói."
            case .recognizerUnavailable:
                return "Bộ nhận dạng giọng nói tiếng Việt không khả dụng."
            case .audioEngineError(let msg):
                return "Lỗi audio: \(msg)"
            case .recognitionFailed(let msg):
                return "Nhận dạng thất bại: \(msg)"
            }
        }
    }

    // MARK: - Callbacks

    /// Called when the user stops speaking (silence detected or recognition final).
    var onSpeechFinished: ((String) -> Void)?

    // MARK: - Private Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// Timer phát hiện im lặng: nếu không có cập nhật transcription trong khoảng thời gian này,
    /// coi như user đã nói xong.
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 2.5

    /// Lưu transcription cuối cùng để so sánh silence detection.
    private var lastTranscription: String = ""
    private var lastTranscriptionUpdate: Date = Date()

    // MARK: - Init

    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "vi-VN"))
        super.init()
        self.speechRecognizer?.delegate = self

        // Check on-device support
        if let recognizer = speechRecognizer {
            isOnDeviceAvailable = recognizer.supportsOnDeviceRecognition
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        continuation.resume(returning: true)
                    case .denied, .restricted, .notDetermined:
                        self.error = .notAuthorized
                        continuation.resume(returning: false)
                    @unknown default:
                        self.error = .notAuthorized
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    // MARK: - Start Listening

    func startListening() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            error = .recognizerUnavailable
            return
        }

        // Cancel any ongoing task
        stopListening()

        // Configure audio session — sử dụng .playAndRecord để tránh conflict
        // khi chuyển đổi giữa TTS (.playback) và STT (.record).
        // Đây là root cause của crash "0 Hz sample rate" khi audio session
        // chưa kịp transition xong giữa 2 category.
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.duckOthers, .defaultToSpeaker, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = .audioEngineError(error.localizedDescription)
            return
        }

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        // Ưu tiên on-device nếu thiết bị hỗ trợ
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        // Cấu hình cho context phù hợp
        request.taskHint = .dictation

        self.recognitionRequest = request

        // Reset state
        transcribedText = ""
        lastTranscription = ""
        lastTranscriptionUpdate = Date()
        self.error = nil

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcribedText = text
                    self.lastTranscription = text
                    self.lastTranscriptionUpdate = Date()
                }

                if result.isFinal {
                    DispatchQueue.main.async {
                        self.finishListening(finalText: text)
                    }
                }
            }

            if let error {
                // Ignore cancellation errors (user-initiated stop)
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                    // User cancelled — not a real error
                    return
                }
                if nsError.code == 1110 { // No speech detected
                    DispatchQueue.main.async {
                        self.finishListening(finalText: self.transcribedText)
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.error = .recognitionFailed(error.localizedDescription)
                    self.stopListening()
                }
            }
        }

        // Lấy format từ input node — PHẢI validate trước khi install tap.
        // Sau khi chuyển audio session category, input node có thể trả format
        // với sample rate = 0 Hz nếu hardware chưa sẵn sàng.
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Validate format: sample rate và channel count phải > 0
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            print("⚠️ [STT] Invalid recording format: \(recordingFormat.sampleRate) Hz, \(recordingFormat.channelCount) ch. Retrying after delay...")

            // Retry sau 300ms — cho phép audio session hoàn tất transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.retryStartListening(attempt: 1)
            }
            return
        }

        installTapAndStart(inputNode: inputNode, format: recordingFormat)
    }

    /// Retry logic khi format không hợp lệ (tối đa 3 lần).
    private func retryStartListening(attempt: Int) {
        guard attempt <= 3 else {
            self.error = .audioEngineError("Không thể khởi tạo microphone sau nhiều lần thử. Vui lòng thử lại.")
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            print("⚠️ [STT] Retry #\(attempt): format still invalid (\(recordingFormat.sampleRate) Hz). Retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.retryStartListening(attempt: attempt + 1)
            }
            return
        }

        print("✅ [STT] Retry #\(attempt): format valid (\(recordingFormat.sampleRate) Hz, \(recordingFormat.channelCount) ch)")
        installTapAndStart(inputNode: inputNode, format: recordingFormat)
    }

    /// Install audio tap và start engine — chỉ gọi khi format đã được validate.
    private func installTapAndStart(inputNode: AVAudioInputNode, format: AVAudioFormat) {
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard buffer.frameLength > 0 else { return }
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isListening = true
            }
            startSilenceTimer()
        } catch {
            self.error = .audioEngineError(error.localizedDescription)
        }
    }

    // MARK: - Stop Listening

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        DispatchQueue.main.async {
            self.isListening = false
        }
    }

    // MARK: - Silence Detection

    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.isListening else { return }

            let elapsed = Date().timeIntervalSince(self.lastTranscriptionUpdate)

            // Chỉ kích hoạt silence timeout nếu đã có ít nhất 1 từ
            if !self.transcribedText.isEmpty && elapsed >= self.silenceTimeout {
                DispatchQueue.main.async {
                    self.finishListening(finalText: self.transcribedText)
                }
            }
        }
    }

    private func finishListening(finalText: String) {
        let trimmed = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
        stopListening()
        if !trimmed.isEmpty {
            onSpeechFinished?(trimmed)
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if !available {
                self.error = .recognizerUnavailable
            }
            self.isOnDeviceAvailable = speechRecognizer.supportsOnDeviceRecognition
        }
    }
}
