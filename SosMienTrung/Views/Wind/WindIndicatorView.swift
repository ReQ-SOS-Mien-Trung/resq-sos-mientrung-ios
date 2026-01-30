import SwiftUI

/// A small view that displays a rotated arrow showing wind direction (arrow points TOWARD where wind is going)
struct WindIndicatorView: View {
    let windSpeed: Double?
    let windDegFrom: Int?

    init(windSpeed: Double?, windDegFrom: Int?) {
        self.windSpeed = windSpeed
        self.windDegFrom = windDegFrom
        print("🌬️ [DEBUG] WindIndicatorView init: speed=\(windSpeed ?? -1), degFrom=\(windDegFrom ?? -1)")
    }

    var body: some View {
        HStack(spacing: 8) {
            // Use system arrow and rotate to indicate wind TO direction.
            let toDeg = Double(((windDegFrom ?? 0) + 180) % 360)
            Image(systemName: "arrow.up")
                .resizable()
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(toDeg))
                .foregroundColor(.white)
                .shadow(radius: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hướng gió")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
                if let sp = windSpeed {
                    Text(String(format: "%.1f m/s", sp))
                        .font(.subheadline).bold()
                        .foregroundColor(.white)
                } else {
                    Text("N/A")
                        .font(.subheadline).bold()
                        .foregroundColor(.white)
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
    }
}

struct WindIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WindIndicatorView(windSpeed: 5.2, windDegFrom: 90)
                .previewLayout(.sizeThatFits)
                .padding()
        }
    }
}
