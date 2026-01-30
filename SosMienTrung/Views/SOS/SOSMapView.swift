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
            // CSS zoom level - nhỏ hơn = thu nhỏ nội dung web
            let zoomLevel = isLandscape ? 0.7 : 0.75
            
            ZStack(alignment: .topTrailing) {
                // WebView nhúng OpenWeatherMap
                OpenWeatherMapWebView(
                    lat: defaultLat,
                    lon: defaultLon,
                    zoom: defaultZoom,
                    cssZoom: zoomLevel
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
    let cssZoom: Double
    
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
        
        // Lưu cssZoom vào coordinator
        context.coordinator.cssZoom = cssZoom
        
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
        var cssZoom: Double = 0.75
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ OpenWeatherMap loaded")
            
            // Inject CSS để thu nhỏ và ẩn các thành phần không cần thiết
            let hideElementsJS = """
            (function() {
                var zoomLevel = \(cssZoom);
                
                // CSS ẩn tất cả elements không cần thiết + zoom
                var style = document.createElement('style');
                style.id = 'custom-hide-style';
                style.innerHTML = `
                    /* Thu nhỏ toàn bộ trang để vừa màn hình */
                    html {
                        zoom: ${zoomLevel} !important;
                        -webkit-text-size-adjust: 100%;
                    }
                    
                    body {
                        transform-origin: top left;
                        overflow: hidden !important;
                    }
                    
                    /* Ẩn banner cam "old version" - aggressive */
                    body > div:first-child,
                    body > div:nth-child(1),
                    div[style*="rgb(235"],
                    div[style*="235, 110"],
                    div[style*="sticky"],
                    [class*="sticky"],
                    [class*="Sticky"],
                    [class*="banner"],
                    [class*="Banner"],
                    [class*="notification-bar"],
                    [class*="alert-bar"] {
                        display: none !important;
                        visibility: hidden !important;
                        height: 0 !important;
                        max-height: 0 !important;
                        overflow: hidden !important;
                        opacity: 0 !important;
                        pointer-events: none !important;
                    }
                    
                    /* Ẩn hamburger menu - target mọi button có icon 3 gạch */
                    button[class*="burger"],
                    button[class*="Burger"],
                    button[class*="menu"],
                    button[class*="Menu"],
                    div[class*="burger"],
                    div[class*="Burger"],
                    [class*="hamburger"],
                    [class*="Hamburger"],
                    [class*="nav-toggle"],
                    [class*="NavToggle"],
                    [class*="mobile-menu"],
                    [class*="MobileMenu"],
                    [aria-label*="menu"],
                    [aria-label*="Menu"],
                    [data-testid*="menu"],
                    [data-testid*="burger"] {
                        display: none !important;
                        visibility: hidden !important;
                        opacity: 0 !important;
                    }
                    
                    /* Ẩn header, logo, login */
                    header, .header, [class*="Header"],
                    [class*="Logo"], [class*="logo"],
                    [class*="Login"], [class*="login"],
                    [class*="Sign"], [class*="sign"],
                    a[href*="login"], a[href*="sign"],
                    footer, .footer, [class*="Footer"] {
                        display: none !important;
                    }
                    
                    /* Ẩn cookie notice */
                    [class*="cookie"], [class*="Cookie"],
                    [class*="consent"], [class*="Consent"],
                    [class*="gdpr"], [class*="GDPR"] {
                        display: none !important;
                    }
                    
                    /* Map full screen */
                    body {
                        padding-top: 0 !important;
                        margin-top: 0 !important;
                    }
                    
                    #map, .leaflet-container {
                        top: 0 !important;
                        position: fixed !important;
                        width: 100vw !important;
                        height: 100vh !important;
                    }
                `;
                
                if (!document.getElementById('custom-hide-style')) {
                    document.head.appendChild(style);
                }
                
                // Hàm xóa elements cụ thể
                function removeElements() {
                    // 1. Xóa banner cam bằng cách check màu nền hoặc text
                    var allElements = document.querySelectorAll('body > *');
                    for (var i = 0; i < Math.min(5, allElements.length); i++) {
                        var el = allElements[i];
                        var computed = window.getComputedStyle(el);
                        var bg = computed.backgroundColor;
                        
                        // Check màu cam (rgb(235, 110, 75) hoặc tương tự)
                        if (bg && (bg.includes('235') || bg.includes('eb6e4b'))) {
                            el.remove();
                            continue;
                        }
                        
                        // Check text "old version"
                        if (el.textContent && el.textContent.toLowerCase().includes('old version')) {
                            el.remove();
                            continue;
                        }
                    }
                    
                    // 2. Xóa hamburger menu - tìm buttons ở góc trái trên
                    document.querySelectorAll('button, [role="button"]').forEach(function(btn) {
                        var rect = btn.getBoundingClientRect();
                        // Hamburger thường ở góc trái, y < 300, nhỏ hơn 80px
                        if (rect.left < 120 && rect.top > 80 && rect.top < 300 && rect.width < 80 && rect.height < 80) {
                            // Check có SVG icon không
                            if (btn.querySelector('svg') || btn.querySelector('img')) {
                                btn.style.cssText = 'display:none !important; visibility:hidden !important;';
                            }
                        }
                    });
                    
                    // 3. Xóa theo class name
                    var selectorsToRemove = [
                        '[class*="sticky"]', '[class*="Sticky"]',
                        '[class*="burger"]', '[class*="Burger"]',
                        '[class*="Banner"]', 'header', '[class*="Header"]'
                    ];
                    selectorsToRemove.forEach(function(selector) {
                        try {
                            document.querySelectorAll(selector).forEach(function(el) {
                                // Không xóa map container
                                if (!el.classList.toString().includes('map') && !el.classList.toString().includes('Map')) {
                                    el.style.cssText = 'display:none !important; visibility:hidden !important;';
                                }
                            });
                        } catch(e) {}
                    });
                }
                
                // Chạy nhiều lần để đảm bảo
                removeElements();
                setTimeout(removeElements, 100);
                setTimeout(removeElements, 300);
                setTimeout(removeElements, 500);
                setTimeout(removeElements, 1000);
                setTimeout(removeElements, 2000);
                setTimeout(removeElements, 3000);
                
                // Observer theo dõi DOM changes
                var observer = new MutationObserver(function() {
                    removeElements();
                });
                observer.observe(document.body, { childList: true, subtree: true });
                setTimeout(function() { observer.disconnect(); }, 10000);
            })();
            """
            webView.evaluateJavaScript(hideElementsJS) { _, error in
                if let error = error {
                    print("⚠️ JS injection error: \(error)")
                }
            }
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