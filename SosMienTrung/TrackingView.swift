import SwiftUI
import MultipeerConnectivity
import simd

struct TrackingView: View {
    let peer: MCPeerID
    @ObservedObject var nearbyManager: NearbyInteractionManager

    var body: some View {
        let distance = nearbyManager.latestDistance
        let direction = nearbyManager.latestDirection
        let color = backgroundColor(for: distance)

        VStack(spacing: 16) {
            Text("Tracking \(peer.displayName)")
                .foregroundStyle(.black)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Color.white.opacity(0.15)
                    .frame(width: 220, height: 220)
                    .cornerRadius(24)
                Image(systemName: "location.north.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 160, height: 160)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(angleForArrow(from: direction)))
                    .shadow(radius: 4)
            }

            if let distance {
                Text(String(format: "%.2fm", distance))
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
            } else {
                Text("Locating...")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.black)
            }

            Text("Move slowly and keep devices facing each other for strongest UWB signal.")
                .font(.caption)
                .foregroundStyle(.black.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
    }

    private func backgroundColor(for distance: Float?) -> Color {
        guard let distance else { return .orange }
        if distance < 3 { return .green }
        if distance < 10 { return .yellow }
        return .red
    }

    private func angleForArrow(from direction: simd_float3?) -> Double {
        guard let direction else { return 0 }
        // Project the 3D direction vector onto the horizontal X-Z plane.
        // X-axis is left/right, Z-axis is forward/back
        // atan2(x, z) gives angle from forward (z-axis) rotating towards right (x-axis)
        let horizontal = simd_float2(direction.x, direction.z)
        let magnitude = simd_length(horizontal)
        guard magnitude > 0.01 else { return 0 } // Threshold to avoid noise
        
        // atan2(x, z) gives the angle in radians
        // Positive x = right, positive z = forward
        let radians = atan2(Double(horizontal.x), Double(horizontal.y))
        let degrees = radians * 180.0 / .pi
        
        // Convert to 0-360 range
        let normalizedDegrees = degrees < 0 ? degrees + 360 : degrees
        return normalizedDegrees
    }
}
