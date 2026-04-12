import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private var pendingRequestCompletion: ((CLLocation?) -> Void)?
    private var pendingRequestNeedsFreshLocation = false
    private var pendingRequestStartedAt: Date?
    private var pendingRequestTimeoutWorkItem: DispatchWorkItem?
    
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
    private let continuousDesiredAccuracy = kCLLocationAccuracyNearestTenMeters
    private let continuousDistanceFilter: CLLocationDistance = 25
    private let preciseRequestDesiredAccuracy = kCLLocationAccuracyBest
    private let freshLocationTargetAccuracy: CLLocationAccuracy = 50
    
    override init() {
        super.init()
        manager.delegate = self
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .other
        applyContinuousTrackingConfiguration()
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation(forceFresh: Bool = false, completion: @escaping (CLLocation?) -> Void) {
        let status = manager.authorizationStatus

        switch status {
        case .notDetermined:
            pendingRequestCompletion = completion
            pendingRequestNeedsFreshLocation = forceFresh
            pendingRequestStartedAt = forceFresh ? Date() : nil
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            pendingRequestCompletion = completion
            pendingRequestNeedsFreshLocation = forceFresh
            pendingRequestStartedAt = forceFresh ? Date() : nil
            isFetchingLocation = true
            if forceFresh {
                applyPreciseRequestConfiguration()
                manager.startUpdatingLocation()
                scheduleFreshLocationTimeout()
            } else {
                restorePreferredTrackingConfiguration()
                invalidatePendingRequestTimeout()
            }
            manager.requestLocation()
        default:
            completion(nil)
        }
    }
    
    // MARK: - Continuous Location Updates
    
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
        
        applyContinuousTrackingConfiguration()
        isFetchingLocation = true
        manager.startUpdatingLocation()
        print("📍 [Location] Started continuous updates")
    }
    
    /// Dừng cập nhật vị trí liên tục — gọi khi đóng SOS form
    func stopContinuousUpdates() {
        continuousUpdateRefCount = max(0, continuousUpdateRefCount - 1)
        guard continuousUpdateRefCount == 0 else { return } // Vẫn còn caller khác
        
        manager.stopUpdatingLocation()
        applyContinuousTrackingConfiguration()
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
                if pendingRequestNeedsFreshLocation {
                    isFetchingLocation = true
                    applyPreciseRequestConfiguration()
                    manager.startUpdatingLocation()
                    scheduleFreshLocationTimeout()
                }
                manager.requestLocation()
            }
            // Nếu đang chờ continuous updates → bắt đầu ngay
            if self.continuousUpdateRefCount > 0 {
                self.applyContinuousTrackingConfiguration()
                self.isFetchingLocation = true
                manager.startUpdatingLocation()
                print("📍 [Location] Authorization granted, starting continuous updates")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            let pendingNeedsFreshLocation = self.pendingRequestNeedsFreshLocation
            if pendingNeedsFreshLocation,
               let startedAt = self.pendingRequestStartedAt,
               location.timestamp < startedAt {
                return
            }

            let isFirstFix = self.currentLocation == nil
            self.currentLocation = location
            self.locationError = nil
            self.isFetchingLocation = false
            self.retryTimer?.invalidate()
            self.retryTimer = nil
            self.retryCount = 0
            
            if isFirstFix {
                print("📍 [Location] First fix: \(location.coordinate.latitude), \(location.coordinate.longitude) (±\(Int(location.horizontalAccuracy))m)")
            }
            
            if let completion = self.pendingRequestCompletion {
                if pendingNeedsFreshLocation,
                   self.isAccurateEnoughForFreshRequest(location) == false {
                    return
                }
                self.finishPendingRequest(with: location, completion: completion)
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
                self.finishPendingRequest(with: self.currentLocation, completion: completion) // Trả về location cũ nếu có
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

    private func scheduleFreshLocationTimeout() {
        invalidatePendingRequestTimeout()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, let completion = self.pendingRequestCompletion else { return }
            self.finishPendingRequest(with: self.currentLocation, completion: completion)
        }

        pendingRequestTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }

    private func invalidatePendingRequestTimeout() {
        pendingRequestTimeoutWorkItem?.cancel()
        pendingRequestTimeoutWorkItem = nil
    }

    private func finishPendingRequest(with location: CLLocation?, completion: @escaping (CLLocation?) -> Void) {
        pendingRequestCompletion = nil
        pendingRequestNeedsFreshLocation = false
        pendingRequestStartedAt = nil
        invalidatePendingRequestTimeout()
        restorePreferredTrackingConfiguration()

        if continuousUpdateRefCount == 0 {
            manager.stopUpdatingLocation()
        }

        completion(location)
    }

    private func applyContinuousTrackingConfiguration() {
        manager.desiredAccuracy = continuousDesiredAccuracy
        manager.distanceFilter = continuousDistanceFilter
    }

    private func applyPreciseRequestConfiguration() {
        manager.desiredAccuracy = preciseRequestDesiredAccuracy
        manager.distanceFilter = kCLDistanceFilterNone
    }

    private func restorePreferredTrackingConfiguration() {
        applyContinuousTrackingConfiguration()
    }

    private func isAccurateEnoughForFreshRequest(_ location: CLLocation) -> Bool {
        location.horizontalAccuracy > 0 && location.horizontalAccuracy <= freshLocationTargetAccuracy
    }
}
