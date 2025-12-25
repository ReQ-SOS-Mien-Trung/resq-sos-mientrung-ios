import SwiftUI
import MultipeerConnectivity

struct RescuersView: View {
    @ObservedObject var nearbyManager: NearbyInteractionManager
    @ObservedObject var multipeerSession: MultipeerSession
    @StateObject private var headingManager = HeadingManager()
    @Binding var selectedPeer: MCPeerID?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                header
                peerList

                if let peer = selectedPeer ?? multipeerSession.connectedPeers.first {
                    TrackingView(
                        peer: peer,
                        nearbyManager: nearbyManager,
                        headingManager: headingManager
                    )
                } else {
                    Text("Waiting for nearby rescuers...")
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }

                Spacer()
            }
            .padding()
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RescueFinder")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(nearbyManager.statusMessage)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var peerList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connected Rescuers")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            
            if multipeerSession.connectedPeers.isEmpty {
                Text("Scanning with MultipeerConnectivity...")
                    .foregroundStyle(.yellow)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
            } else {
                ForEach(multipeerSession.connectedPeers, id: \.self) { peer in
                    Button {
                        selectedPeer = peer
                        nearbyManager.setActivePeer(peer)
                    } label: {
                        HStack {
                            Circle()
                                .fill(selectedPeer == peer ? Color.green : Color.blue)
                                .frame(width: 14, height: 14)
                            Text(peer.displayName)
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                            Spacer()
                            if selectedPeer == peer {
                                Text("Tracking")
                                    .foregroundStyle(.green)
                                    .font(.caption.bold())
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(selectedPeer == peer ? 0.16 : 0.1))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}
