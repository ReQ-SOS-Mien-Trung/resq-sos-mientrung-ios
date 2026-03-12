//
//  SOSSignalManager.swift
//  SosMienTrung
//
//  Phát tín hiệu SOS bằng đèn flash, nhấp nháy màn hình và âm thanh
//  Morse code: ... --- ... (S O S)
//

import SwiftUI
import Combine
import AVFoundation
import MediaPlayer

// MARK: - SOS Signal Manager

final class SOSSignalManager: ObservableObject {

    static let shared = SOSSignalManager()

    @Published var isActive = false
    @Published var screenFlash = false

    // Morse unit = 0.15 s → dit=0.15s, dah=0.45s
    private let unit: TimeInterval = 0.15

    // SOS: ...  ---  ...
    // Each element: (isOn, numberOfUnits)
    // Intra-char gap = 1u, inter-char gap = 3u, word gap = 7u
    private let sosSequence: [(Bool, Double)] = [
        // S: . . .
        (true, 1), (false, 1),
        (true, 1), (false, 1),
        (true, 1), (false, 3),   // inter-char gap
        // O: - - -
        (true, 3), (false, 1),
        (true, 3), (false, 1),
        (true, 3), (false, 3),   // inter-char gap
        // S: . . .
        (true, 1), (false, 1),
        (true, 1), (false, 1),
        (true, 1), (false, 7),   // word gap before repeat
    ]

    private var currentIndex = 0
    private var workItem: DispatchWorkItem?

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let sampleRate: Double = 44100
    private let toneFrequency: Double = 2800   // Hz — cao, chói như còi báo động
    private let harmonic: Double = 4200        // Hz — overtone tăng độ sắc

    private init() {
        setupAudioEngine()
    }

    // MARK: - Public API

    func start() {
        guard !isActive else { return }
        isActive = true
        currentIndex = 0
        setupAudioSession()
        if !audioEngine.isRunning { try? audioEngine.start() }
        if !playerNode.isPlaying { playerNode.play() }
        UIScreen.main.brightness = 1.0
        processNextEvent()
    }

    func stop() {
        workItem?.cancel()
        workItem = nil
        isActive = false
        DispatchQueue.main.async { self.screenFlash = false }
        setTorch(on: false)
        playerNode.stop()
    }

    // MARK: - Private

    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        try? audioEngine.start()
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
        // Đẩy system volume lên tối đa qua MPVolumeView slider
        let volumeView = MPVolumeView(frame: .zero)
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                slider.value = 1.0
            }
        }
    }

    private func processNextEvent() {
        guard isActive else { return }

        if currentIndex >= sosSequence.count { currentIndex = 0 }

        let (isOn, units) = sosSequence[currentIndex]
        let duration = unit * units

        DispatchQueue.main.async { self.screenFlash = isOn }
        setTorch(on: isOn)
        if isOn { scheduleBeep(duration: duration) }

        currentIndex += 1

        let item = DispatchWorkItem { [weak self] in self?.processNextEvent() }
        workItem = item
        DispatchQueue.global(qos: .userInteractive).asyncAfter(
            deadline: .now() + duration,
            execute: item
        )
    }

    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if on {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {}
    }

    private func scheduleBeep(duration: TimeInterval) {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData?.pointee else { return }

        buffer.frameLength = frameCount
        let ramp = min(Int(sampleRate * 0.008), Int(frameCount) / 4)

        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let f1 = Float(sin(2 * Double.pi * toneFrequency * t))
            let f2 = Float(sin(2 * Double.pi * harmonic * t)) * 0.4
            let raw = (f1 + f2) / 1.4   // normalise
            let env: Float
            if i < ramp {
                env = Float(i) / Float(ramp)
            } else if i > Int(frameCount) - ramp {
                env = Float(Int(frameCount) - i) / Float(ramp)
            } else {
                env = 1.0
            }
            channelData[i] = raw * env * 1.0
        }

        if !audioEngine.isRunning { try? audioEngine.start() }
        if !playerNode.isPlaying { playerNode.play() }
        playerNode.scheduleBuffer(buffer)
    }
}

// MARK: - SOS Signal View

struct SOSSignalView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = SOSSignalManager.shared

    var body: some View {
        ZStack {
            // Background & screen flash layer
            Group {
                if manager.screenFlash {
                    Color.white.ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
            .animation(.none, value: manager.screenFlash)

            VStack(spacing: 28) {

                // MARK: Top bar
                HStack {
                    Button {
                        manager.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(flashAwareColor)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // MARK: SOS icon
                ZStack {
                    Circle()
                        .fill(manager.isActive
                              ? (manager.screenFlash ? Color.black.opacity(0.15) : Color.red.opacity(0.2))
                              : Color.red.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .scaleEffect(manager.screenFlash ? 1.12 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: manager.screenFlash)

                    Image(systemName: "sos.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(manager.screenFlash ? .black : .red)
                        .animation(.none, value: manager.screenFlash)
                }

                // MARK: Title
                Text("Tín hiệu SOS")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(flashAwareColor)

                // MARK: Morse code display
                HStack(spacing: 6) {
                    ForEach(morseSymbols, id: \.id) { symbol in
                        MorseSymbolView(symbol: symbol)
                    }
                }

                // MARK: Description
                Text("Flash đèn, nhấp nháy màn hình và phát âm thanh\ntheo mã Morse SOS (••• ––– •••)")
                    .font(.system(size: 14))
                    .foregroundColor(flashAwareColor.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // MARK: Start / Stop button
                Button {
                    if manager.isActive { manager.stop() } else { manager.start() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: manager.isActive ? "stop.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(manager.isActive ? "DỪNG TÍN HIỆU" : "BẮT ĐẦU TÍN HIỆU SOS")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(1.5)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(manager.isActive ? Color.gray : Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 32)
                }
                .animation(.easeInOut(duration: 0.2), value: manager.isActive)

                Text("Chức năng này phát tín hiệu cầu cứu để thu hút sự chú ý\nkhi gặp nguy hiểm và thiếu phương tiện liên lạc.")
                    .font(.system(size: 12))
                    .foregroundColor(flashAwareColor.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
        .onDisappear { manager.stop() }
    }

    private var flashAwareColor: Color {
        manager.screenFlash ? .black : .white
    }

    private var morseSymbols: [MorseSymbol] {
        [
            MorseSymbol(id: 0, isDit: true),
            MorseSymbol(id: 1, isDit: true),
            MorseSymbol(id: 2, isDit: true),
            MorseSymbol(id: 3, isDit: nil),  // spacer
            MorseSymbol(id: 4, isDit: false),
            MorseSymbol(id: 5, isDit: false),
            MorseSymbol(id: 6, isDit: false),
            MorseSymbol(id: 7, isDit: nil),  // spacer
            MorseSymbol(id: 8, isDit: true),
            MorseSymbol(id: 9, isDit: true),
            MorseSymbol(id: 10, isDit: true),
        ]
    }
}

// MARK: - Morse Symbol Model

private struct MorseSymbol: Identifiable {
    let id: Int
    let isDit: Bool?  // true=dot, false=dash, nil=space
}

// MARK: - Morse Symbol View

private struct MorseSymbolView: View {
    let symbol: MorseSymbol

    var body: some View {
        if let isDit = symbol.isDit {
            if isDit {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.red)
                    .frame(width: 28, height: 10)
            }
        } else {
            Spacer().frame(width: 8)
        }
    }
}

#if swift(>=5.9)
@available(iOS 17, *)
#Preview {
    SOSSignalView()
}
#endif
