import SwiftUI
import WebKit

/// Bản đồ thiên tai - nhúng trực tiếp OpenWeatherMap
struct SOSMapView: View {
    @Environment(\.dismiss) var dismiss
    
    // Vị trí mặc định (Việt Nam)
    private let defaultLat = 16.0
    private let defaultLon = 106.7
    private let defaultZoom = 5
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack(alignment: .topTrailing) {
                // WebView nhúng OpenWeatherMap
                OpenWeatherMapWebView(
                    lat: defaultLat,
                    lon: defaultLon,
                    zoom: defaultZoom
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Dismiss button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .padding(.top, isLandscape ? 16 : 50)
                .padding(.trailing, 16)
            }
        }
        .ignoresSafeArea(.all)
        .background(Color.black)
    }
}

/// WebView nhúng trực tiếp OpenWeatherMap weathermap
struct OpenWeatherMapWebView: UIViewRepresentable {
    let lat: Double
    let lon: Double
    let zoom: Int
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Cho phép JavaScript
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false // Tắt scroll để tránh nhảy
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = false
        
        // Load OpenWeatherMap
        let urlString = "https://openweathermap.org/weathermap?basemap=map&cities=false&layer=temperature&lat=\(lat)&lon=\(lon)&zoom=\(zoom)"
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Không cần update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ OpenWeatherMap loaded")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ OpenWeatherMap failed: \(error)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ OpenWeatherMap provisional navigation failed: \(error)")
        }
    }
}

#Preview {
    SOSMapView()
}