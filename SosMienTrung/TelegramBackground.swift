import SwiftUI

struct TelegramBackground: View {
    @ObservedObject var appearanceManager = AppearanceManager.shared
    
    var body: some View {
        ZStack {
            // Battery saving mode - pure black background
            if appearanceManager.batterySavingMode {
                Color.black
            } else {
                // Background color/gradient
                if appearanceManager.useGradient {
                    LinearGradient(
                        colors: [appearanceManager.backgroundColor, appearanceManager.gradientEndColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    appearanceManager.backgroundColor
                }
                
                // Pattern overlay using ImagePaint
                if appearanceManager.selectedPattern != .none {
                    Rectangle()
                        .fill(
                            ImagePaint(
                                image: Image(appearanceManager.selectedPattern.rawValue),
                                scale: appearanceManager.patternScale
                            )
                        )
                        .opacity(appearanceManager.patternOpacity)
                }
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    func telegramPatternBackground() -> some View {
        background(TelegramBackground())
    }
}
