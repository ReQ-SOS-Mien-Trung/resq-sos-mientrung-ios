//
//  WaterEjectManager.swift
//  SosMienTrung
//
//  Tính năng đẩy nước khỏi loa bằng âm thanh tần số cao
//

import SwiftUI
import AVFoundation
import Combine

class WaterEjectManager: ObservableObject {
    static let shared = WaterEjectManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var toneGenerator: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    
    @Published var isPlaying = false
    @Published var progress: Double = 0.0
    
    private var timer: Timer?
    private let duration: TimeInterval = 15.0 // 15 giây
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Phát âm thanh từ file MP3
    func playWaterEjectSound() {
        // Thử load file từ bundle
        if let soundURL = Bundle.main.url(forResource: "water_eject", withExtension: "mp3") {
            playFromFile(url: soundURL)
        } else {
            // Nếu không có file, tạo âm thanh tần số cao
            playGeneratedTone()
        }
    }
    
    private func playFromFile(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isPlaying = true
            startProgressTimer(duration: audioPlayer?.duration ?? duration)
            
        } catch {
            print("Error playing water eject sound: \(error)")
            // Fallback to generated tone
            playGeneratedTone()
        }
    }
    
    // MARK: - Tạo âm thanh tần số cao (165Hz - tương tự Apple Watch)
    private func playGeneratedTone() {
        toneGenerator = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = toneGenerator, let player = playerNode else { return }
        
        engine.attach(player)
        
        let sampleRate: Double = 44100
        let frequency: Double = 165 // Tần số để đẩy nước
        let amplitude: Float = 1.0
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        let data = buffer.floatChannelData![0]
        
        // Tạo sóng với tần số thay đổi để đẩy nước hiệu quả
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            // Sweep frequency từ 165Hz đến 200Hz
            let sweepFreq = frequency + (35 * sin(2 * .pi * 0.5 * time))
            data[frame] = amplitude * Float(sin(2 * .pi * sweepFreq * time))
        }
        
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.stopPlaying()
                }
            })
            player.play()
            
            isPlaying = true
            startProgressTimer(duration: duration)
            
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }
    
    private func startProgressTimer(duration: TimeInterval) {
        progress = 0.0
        let interval: TimeInterval = 0.1
        var elapsed: TimeInterval = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            elapsed += interval
            self?.progress = min(elapsed / duration, 1.0)
            
            if elapsed >= duration {
                timer.invalidate()
                self?.stopPlaying()
            }
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        playerNode?.stop()
        toneGenerator?.stop()
        toneGenerator = nil
        playerNode = nil
        
        timer?.invalidate()
        timer = nil
        
        isPlaying = false
        progress = 0.0
    }
}

// MARK: - Water Eject View
struct WaterEjectView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appearanceManager = AppearanceManager.shared
    @StateObject private var waterEjectManager = WaterEjectManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                TelegramBackground()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Icon animation with particles
                    ZStack {
                        // Particle waves flying outward
                        if waterEjectManager.isPlaying {
                            WaterParticlesView()
                        }
                        
                        // Main speaker icon
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 45))
                                .foregroundColor(.blue)
                                .symbolEffect(.variableColor.iterative, options: .repeating, value: waterEjectManager.isPlaying)
                        }
                    }
                    
                    // Title
                    Text("Đẩy nước khỏi loa")
                        .font(.title.bold())
                        .foregroundColor(appearanceManager.textColor)
                    
                    // Description
                    Text("Phát âm thanh tần số cao để đẩy nước ra khỏi loa điện thoại. Giữ điện thoại với loa hướng xuống dưới.")
                        .font(.subheadline)
                        .foregroundColor(appearanceManager.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // Progress bar
                    if waterEjectManager.isPlaying {
                        VStack(spacing: 8) {
                            ProgressView(value: waterEjectManager.progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(height: 8)
                                .padding(.horizontal, 40)
                            
                            Text("\(Int(waterEjectManager.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(appearanceManager.secondaryTextColor)
                        }
                    }
                    
                    Spacer()
                    
                    // Action button
                    Button {
                        if waterEjectManager.isPlaying {
                            waterEjectManager.stopPlaying()
                        } else {
                            waterEjectManager.playWaterEjectSound()
                        }
                    } label: {
                        HStack {
                            Image(systemName: waterEjectManager.isPlaying ? "stop.fill" : "play.fill")
                            Text(waterEjectManager.isPlaying ? "Dừng" : "Bắt đầu")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(waterEjectManager.isPlaying ? Color.red : Color.blue)
                        .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)
                    
                    // Warning
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Tăng âm lượng lên tối đa để hiệu quả nhất")
                            .font(.caption)
                            .foregroundColor(appearanceManager.secondaryTextColor)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Đẩy nước")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        waterEjectManager.stopPlaying()
                        dismiss()
                    }
                    .foregroundColor(appearanceManager.textColor)
                }
            }
        }
        .onDisappear {
            waterEjectManager.stopPlaying()
        }
    }
}

// MARK: - Water Particles Animation View
struct WaterParticlesView: View {
    let particleCount = 12
    
    var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                WaterParticle(
                    angle: Double(index) * (360.0 / Double(particleCount)),
                    delay: Double(index) * 0.08
                )
            }
        }
    }
}

// MARK: - Single Water Particle
struct WaterParticle: View {
    let angle: Double
    let delay: Double
    
    @State private var isAnimating = false
    
    // Starting distance from center (near the speaker icon edge)
    let startRadius: CGFloat = 50
    let endRadius: CGFloat = 150
    
    var body: some View {
        WaterDropletShape()
            .fill(Color.blue.opacity(isAnimating ? 0 : 0.85))
            .frame(width: isAnimating ? 10 : 16, height: isAnimating ? 22 : 38)
            .rotationEffect(.degrees(angle - 90)) // Point outward from center
            .offset(x: cos(angle * .pi / 180) * (isAnimating ? endRadius : startRadius),
                    y: sin(angle * .pi / 180) * (isAnimating ? endRadius : startRadius))
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.0)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Water Droplet Shape
struct WaterDropletShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Start at the pointed tip (top) - more elongated
        path.move(to: CGPoint(x: width / 2, y: 0))
        
        // Left curve down - narrower body
        path.addQuadCurve(
            to: CGPoint(x: width * 0.15, y: height * 0.55),
            control: CGPoint(x: width * 0.2, y: height * 0.25)
        )
        
        // Bottom rounded part (left to center)
        path.addQuadCurve(
            to: CGPoint(x: width / 2, y: height),
            control: CGPoint(x: 0, y: height * 0.95)
        )
        
        // Bottom rounded part (center to right)
        path.addQuadCurve(
            to: CGPoint(x: width * 0.85, y: height * 0.55),
            control: CGPoint(x: width, y: height * 0.95)
        )
        
        // Right curve back to top - narrower body
        path.addQuadCurve(
            to: CGPoint(x: width / 2, y: 0),
            control: CGPoint(x: width * 0.8, y: height * 0.25)
        )
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Ripple Wave View (Alternative animation)
struct RippleWaveView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.8
    let delay: Double
    
    var body: some View {
        Circle()
            .stroke(Color.blue, lineWidth: 3)
            .frame(width: 100, height: 100)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    scale = 2.5
                    opacity = 0
                }
            }
    }
}

#Preview {
    WaterEjectView()
}
