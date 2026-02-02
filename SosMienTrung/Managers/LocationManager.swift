import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pendingRequestCompletion: ((CLLocation?) -> Void)?
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: Error?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // Cập nhật khi di chuyển 10m
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
            manager.requestLocation()
        default:
            completion(nil)
        }
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

        if status == .authorizedWhenInUse || status == .authorizedAlways,
           pendingRequestCompletion != nil {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = location
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
            print("Location error: \(error.localizedDescription)")
            if let completion = self.pendingRequestCompletion {
                self.pendingRequestCompletion = nil
                completion(nil)
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
}
