import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pendingRequestCompletion: ((CLLocation?) -> Void)?
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: Error?
    @Published var isFetchingLocation: Bool = false
    
    /// Số lần continuous update đang active (dùng refcount để nhiều caller cùng dùng)
    private var continuousUpdateRefCount = 0
    
    /// Retry timer cho one-shot request
    private var retryTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 3
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5 // Cập nhật khi di chuyển 5m
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation(completion: @escaping (CLLocation?) -> Void) {
        let status = manager.authorizationStatus

        switch status {
        case .notDetermined:
            pendingRequestCompletion = completion
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            pendingRequestCompletion = completion
            isFetchingLocation = true
            manager.requestLocation()
        default:
            completion(nil)
        }
    }
    
    // MARK: - Continuous Location Updates (cho SOS form)
    
    /// Bắt đầu cập nhật vị trí liên tục — gọi khi mở SOS form
    func startContinuousUpdates() {
        continuousUpdateRefCount += 1
        guard continuousUpdateRefCount == 1 else { return } // Đã đang update

        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            return
        }
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            print("📍 [Location] Permission not granted, cannot start continuous updates")
            return
        }
        
        isFetchingLocation = true
        manager.startUpdatingLocation()
        print("📍 [Location] Started continuous updates for SOS")
    }
    
    /// Dừng cập nhật vị trí liên tục — gọi khi đóng SOS form
    func stopContinuousUpdates() {
        continuousUpdateRefCount = max(0, continuousUpdateRefCount - 1)
        guard continuousUpdateRefCount == 0 else { return } // Vẫn còn caller khác
        
        manager.stopUpdatingLocation()
        isFetchingLocation = false
        retryTimer?.invalidate()
        retryTimer = nil
        retryCount = 0
        print("📍 [Location] Stopped continuous updates")
    }
    
    func startUpdating() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("Location permission not granted")
            return
        }
        manager.startUpdatingLocation()
    }
    
    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            if pendingRequestCompletion != nil {
                manager.requestLocation()
            }
            // Nếu đang chờ continuous updates → bắt đầu ngay
            if self.continuousUpdateRefCount > 0 {
                self.isFetchingLocation = true
                manager.startUpdatingLocation()
                print("📍 [Location] Authorization granted, starting continuous updates")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            let isFirstFix = self.currentLocation == nil
            self.currentLocation = location
            self.locationError = nil
            self.isFetchingLocation = false
            
            if isFirstFix {
                print("📍 [Location] First fix: \(location.coordinate.latitude), \(location.coordinate.longitude) (±\(Int(location.horizontalAccuracy))m)")
            }
            
            if let completion = self.pendingRequestCompletion {
                self.pendingRequestCompletion = nil
                completion(location)
                return
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error
            self.isFetchingLocation = false
            print("📍 [Location] Error: \(error.localizedDescription)")
            
            if let completion = self.pendingRequestCompletion {
                self.pendingRequestCompletion = nil
                completion(self.currentLocation) // Trả về location cũ nếu có
            }
            
            // Nếu đang continuous mode và chưa có location → retry
            if self.continuousUpdateRefCount > 0 && self.currentLocation == nil {
                self.scheduleRetry()
            }
        }
    }
    
    // MARK: - Retry
    
    private func scheduleRetry() {
        guard retryCount < maxRetries else {
            print("📍 [Location] Max retries reached (\(maxRetries))")
            return
        }
        retryCount += 1
        let delay = TimeInterval(retryCount * 2) // 2s, 4s, 6s
        print("📍 [Location] Scheduling retry #\(retryCount) in \(delay)s...")
        
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.currentLocation == nil && self.continuousUpdateRefCount > 0 {
                self.isFetchingLocation = true
                self.manager.requestLocation()
                print("📍 [Location] Retry #\(self.retryCount) fired")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    var coordinates: (latitude: Double, longitude: Double)? {
        guard let location = currentLocation else { return nil }
        return (location.coordinate.latitude, location.coordinate.longitude)
    }
    
    /// GPS accuracy in meters
    var accuracy: Double? {
        guard let location = currentLocation else { return nil }
        return location.horizontalAccuracy
    }
    
    /// Có vị trí hợp lệ không (không phải 0,0)
    var hasValidLocation: Bool {
        guard let loc = currentLocation else { return false }
        return loc.coordinate.latitude != 0 || loc.coordinate.longitude != 0
    }
}
