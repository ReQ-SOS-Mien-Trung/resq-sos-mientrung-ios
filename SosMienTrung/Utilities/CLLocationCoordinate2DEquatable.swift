import CoreLocation

// Make CLLocationCoordinate2D Equatable so it can be used with SwiftUI's onChange(_:perform:)
// Note: This extension adds Equatable conformance for local use only.
// If _LocationEssentials introduces this conformance, this may cause issues.
extension CLLocationCoordinate2D: Equatable {
    nonisolated public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
