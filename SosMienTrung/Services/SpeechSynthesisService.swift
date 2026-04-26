//
//  SpeechSynthesisService.swift
//  SosMienTrung
//
//  AVSpeechSynthesizer wrapper — text-to-speech tiếng Việt.
//  Ưu tiên chọn giọng chất lượng cao nhất (Premium > Enhanced > Default).
//

import Foundation
import AVFoundation
import Combine

final class SpeechSynthesisService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isSpeaking: Bool = false

    // MARK: - Callbacks

    /// Called when the synthesizer finishes speaking the current utterance.
    var onFinishedSpeaking: (() -> Void)?

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var selectedVoice: AVSpeechSynthesisVoice?

    // MARK: - Init

    override init() {
        super.init()
        synthesizer.delegate = self
        selectBestVietnameseVoice()
    }

    // MARK: - Voice Selection

    /// Chọn giọng tiếng Việt chất lượng cao nhất có sẵn trên thiết bị.
    private func selectBestVietnameseVoice() {
        let vietnameseVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("vi") }

        // Ưu tiên quality cao nhất
        // AVSpeechSynthesisVoiceQuality: .default = 1, .enhanced = 2, .premium = 3
        let sorted = vietnameseVoices.sorted { $0.quality.rawValue > $1.quality.rawValue }

        if let best = sorted.first {
            selectedVoice = best
            print("🗣️ [TTS] Selected Vietnamese voice: \(best.name) (quality: \(best.quality.rawValue))")
        } else {
            // Fallback: dùng default Vietnamese voice
            selectedVoice = AVSpeechSynthesisVoice(language: "vi-VN")
            print("🗣️ [TTS] Using default Vietnamese voice")
        }
    }

    // MARK: - Public API

    /// Nói một đoạn text. Nếu đang nói, dừng utterance hiện tại trước.
    func speak(_ text: String) {
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Configure audio session for playback
        configureAudioSessionForPlayback()

        let utterance = AVSpeechUtterance(string: text)

        // Sử dụng voice đã chọn
        if let voice = selectedVoice {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "vi-VN")
        }

        // Cấu hình tốc độ và pitch cho tự nhiên
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95 // Hơi chậm hơn mặc định
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // Thêm pause nhẹ trước khi nói để tránh cắt đầu
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2

        DispatchQueue.main.async {
            self.isSpeaking = true
        }

        synthesizer.speak(utterance)
    }

    /// Dừng nói ngay lập tức.
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    // MARK: - Audio Session

    private func configureAudioSessionForPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Sử dụng .playAndRecord thay vì .playback thuần túy.
            // Lý do: khi chuyển đổi giữa TTS (.playback) → STT (.record),
            // audio engine input node trả format 0 Hz gây crash.
            // Dùng .playAndRecord cho cả 2 service để tránh conflict category.
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.duckOthers, .defaultToSpeaker, .allowBluetoothA2DP]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [TTS] Audio session config failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechSynthesisService: AVSpeechSynthesizerDelegate {

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.onFinishedSpeaking?()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}
