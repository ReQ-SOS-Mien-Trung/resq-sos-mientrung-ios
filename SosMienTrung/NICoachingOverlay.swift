//
//  NICoachingOverlay.swift
//  SosMienTrung
//
//  Coaching overlay adapted from Apple's "Finding Devices with Precision" sample
//

import SwiftUI
import NearbyInteraction

// Extensions for `FindingMode` that display messages and guidance
extension FindingMode {
    func moveMessage() -> String {
        switch self {
        case .exhibit: 
            return "Di chuyển điện thoại lên xuống để xem vị trí."
        case .visitor: 
            return "Di chuyển điện thoại lên xuống để tìm người khác."
        }
    }

    func guidanceWhenNoDistance() -> String {
        switch self {
        case .exhibit: 
            return "Đang tìm kiếm..."
        case .visitor: 
            return "Đang tìm người cần cứu..."
        }
    }
    
    func guidanceWhenNoAngle() -> String {
        switch self {
        case .exhibit: 
            return "Di chuyển sang hai bên."
        case .visitor: 
            return "Di chuyển đến vị trí khác."
        }
    }
    
    func guidanceWhenInGoodMeasurement() -> String {
        switch self {
        case .exhibit: 
            return "Đi đến vị trí đó."
        case .visitor: 
            return "Tiến đến gặp người cần cứu."
        }
    }
    
    func generateGuidance(with nearbyObject: NINearbyObject?) -> String {
        guard let object = nearbyObject, object.distance != nil else {
            return guidanceWhenNoDistance()
        }
        guard object.horizontalAngle != nil else {
            return guidanceWhenNoAngle()
        }
        return guidanceWhenInGoodMeasurement()
    }
}

// An overlay view for coaching or directing the person using the app.
struct NICoachingOverlay: View {
    let findingMode: FindingMode

    // Variables observed from NearbyInteractionManager
    var isConverged: Bool = false
    var measurementQuality: MeasurementQualityEstimator.MeasurementQuality?
    var distance: Float?
    var horizontalAngle: Float?
    var showCoachingOverlay: Bool = true
    var showUpdownText: Bool = false
    
    // State variable for image animation.
    @State var animateSymbol = false

    var body: some View {
        VStack(spacing: 20) {
            // Scale the image based on distance, if available.
            let rate: Float = showCoachingOverlay ? 1 : 0.3
            let dist = distance ?? 0.5
            let distanceScale = dist.scale(minRange: 0.15, maxRange: 1.0, minDomain: 0.5, maxDomain: 2.0)
            let imageScale = ((horizontalAngle == nil) ? 0.5 : distanceScale) * rate
            let maxScale: Float = 1.3   // Giới hạn zoom để không tràn card
            let clampedScale = min(imageScale, maxScale)
            
            // Show the distance, if there's any.
            let distString = distance == nil
            ? ""
            : String(format: "Khoảng cách: %.2f m", dist)
            
            // Text to display for guiding the person to move their iPhone up and down.
            let upDownText = showUpdownText ? findingMode.moveMessage() : ""
            
            // Display an image to help guide the person using the app.
            let img = Image(systemName: displayImageName())
            let baseVisitorSize: CGFloat = 180
            let baseExhibitSize: CGFloat = 240
            let maxImageSize: CGFloat = 280  // Giới hạn kích thước tối đa trong card
            let visitorSize = min(baseVisitorSize * CGFloat(clampedScale), maxImageSize)
            let exhibitSize = min(baseExhibitSize * CGFloat(clampedScale), maxImageSize)

            if #available(iOS 17, *), findingMode == .visitor, measurementQuality == .unknown {
                img.resizable()
                    .frame(width: visitorSize, height: visitorSize, alignment: .center)
                    // Rotate the image by the horizontal angle, when available.
                    .rotationEffect(imageAngle(orientationRadians: horizontalAngle))
                    .symbolEffect(.bounce, options: .repeating, value: animateSymbol)
                    .onAppear(perform: {
                        animateSymbol = true
                    })
            } else {
                img.resizable()
                    .frame(width: exhibitSize, height: exhibitSize, alignment: .center)
                    // Rotate the image by the horizontal angle, when available.
                    .rotationEffect(.init(radians: Double(horizontalAngle ?? 0.0)))
            }

            // A view that provides guidance with distance text and suggestions on moving the device.
            VStack(spacing: 8) {
                Text(distString)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .frame(alignment: .center)
                
                Text(generateGuidance())
                    .font(.subheadline.weight(.semibold))
                    .frame(alignment: .center)
                
                if !upDownText.isEmpty {
                    Text(upDownText)
                        .font(.subheadline)
                        .frame(alignment: .center)
                }
            }
            .opacity(showCoachingOverlay ? 1 : 0)
        }
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 2)
        .animation(.smooth, value: showCoachingOverlay)
    }
    
    // Generate guidance based on current distance/angle state
    func generateGuidance() -> String {
        guard distance != nil else {
            return findingMode.guidanceWhenNoDistance()
        }
        guard horizontalAngle != nil else {
            return findingMode.guidanceWhenNoAngle()
        }
        return findingMode.guidanceWhenInGoodMeasurement()
    }
    
    // The image to use for displaying guidance and direction.
    func displayImageName() -> String {
        if distance == nil {
            return "sparkle.magnifyingglass"
        }
        
        if horizontalAngle == nil {
            return "move.3d"
        }
        
        if findingMode == .exhibit {
            return "arrow.up.circle"
        } else {
            if #available(iOS 17, *), measurementQuality == nil || measurementQuality == .unknown {
                return "wave.3.right"
            } else {
                return "arrow.up.circle"
            }
        }
    }

    //  Rotation angle for animated `wave` image.
    func imageAngle(orientationRadians: Float?) -> Angle {
        // The angular correction to make the images point upwards on the screen.
        let imageRotationOffset = Angle(degrees: -90)
        return Angle(radians: Double(orientationRadians ?? 0)) + imageRotationOffset
    }
}

// Helper extension for scaling - from Apple's "Finding Devices with Precision"
extension Float {
    func scale(minRange: Float, maxRange: Float, minDomain: Float, maxDomain: Float) -> Float {
        return minDomain + (maxDomain - minDomain) * (max(minRange, min(self, maxRange)) - minRange) / (maxRange - minRange)
    }
}
