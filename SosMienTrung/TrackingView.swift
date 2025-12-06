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
        // We treat (x, z) as a 2D vector and use atan2(x, z) to get the yaw
        // between device-forward (positive z) and the peer; degrees feed SwiftUI rotation.
        let horizontal = simd_float2(direction.x, direction.z)
        let magnitude = simd_length(horizontal)
        guard magnitude > .leastNonzeroMagnitude else { return 0 }
        let normalized = horizontal / magnitude
        let radians = atan2(Double(normalized.x), Double(normalized.y))
        return radians * 180 / .pi
    }
}
