import SwiftUI
import MultipeerConnectivity
import simd

struct TrackingView: View {
    let peer: MCPeerID
    @ObservedObject var nearbyManager: NearbyInteractionManager
    @ObservedObject var headingManager: HeadingManager

    // Computed properties
    private var distance: Float? {
        nearbyManager.smoothedDistance ?? nearbyManager.latestDistance
    }

    private var direction: simd_float3? {
        nearbyManager.smoothedDirection ?? nearbyManager.latestDirection
    }

    private var backgroundColor: Color {
        guard let distance else { return .orange }
        if distance < 3 { return .green }
        if distance < 10 { return .yellow }
        return .red
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Tracking \(peer.displayName)")
                .foregroundStyle(.black)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Arrow compass view
            compassView

            // Distance display
            distanceView

            // Direction text
            if let dir = direction {
                Text(directionDescription(from: dir))
                    .font(.subheadline.bold())
                    .foregroundStyle(.black.opacity(0.8))
            }

            Text("Di chuyển chậm và giữ hai thiết bị hướng về nhau.")
                .font(.caption)
                .foregroundStyle(.black.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }

    // MARK: - Compass View
    private var compassView: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.black.opacity(0.15))
                .frame(width: 200, height: 200)

            // Compass ring
            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: 3)
                .frame(width: 180, height: 180)

            // Cardinal directions
            ForEach(["N", "E", "S", "W"], id: \.self) { cardinal in
                Text(cardinal)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .offset(y: -80)
                    .rotationEffect(.degrees(cardinalAngle(cardinal)))
            }

            // Arrow or loading
            if let dir = direction {
                // Mũi tên
                VStack(spacing: 0) {
                    Triangle()
                        .fill(.white)
                        .frame(width: 50, height: 60)
                        .shadow(color: .black.opacity(0.3), radius: 4)

                    Rectangle()
                        .fill(.white)
                        .frame(width: 14, height: 35)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
                .rotationEffect(.degrees(calculateArrowAngle(from: dir)))
                .animation(.easeOut(duration: 0.2), value: calculateArrowAngle(from: dir))
            } else {
                // Loading
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Đang định vị...")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }

            // Center dot
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
        }
    }

    // MARK: - Distance View
    private var distanceView: some View {
        Group {
            if let dist = distance {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", dist))
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                    Text("m")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.black.opacity(0.7))
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.black)
                    Text("Đang định vị...")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.black)
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func cardinalAngle(_ cardinal: String) -> Double {
        switch cardinal {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }

    private func calculateArrowAngle(from direction: simd_float3) -> Double {
        // NearbyInteraction direction vector:
        // X: positive = right, negative = left
        // Z: positive = behind, negative = in front
        let x = Double(direction.x)
        let z = Double(direction.z)

        // atan2(x, -z): góc từ hướng phía trước (-Z) xoay sang phải (+X)
        let radians = atan2(x, -z)
        return radians * 180.0 / .pi
    }

    private func directionDescription(from direction: simd_float3) -> String {
        let angle = calculateArrowAngle(from: direction)
        let normalized = angle < 0 ? angle + 360 : angle

        switch normalized {
        case 337.5..<360, 0..<22.5:
            return "📍 Phía trước"
        case 22.5..<67.5:
            return "↗️ Trước bên phải"
        case 67.5..<112.5:
            return "➡️ Bên phải"
        case 112.5..<157.5:
            return "↘️ Sau bên phải"
        case 157.5..<202.5:
            return "⬇️ Phía sau"
        case 202.5..<247.5:
            return "↙️ Sau bên trái"
        case 247.5..<292.5:
            return "⬅️ Bên trái"
        case 292.5..<337.5:
            return "↖️ Trước bên trái"
        default:
            return ""
        }
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
