import Foundation
import MapKit

class LocationAnnotation: NSObject, MKAnnotation, Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    let userId: UUID
    let timestamp: Date
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String? = nil, userId: UUID, timestamp: Date = Date()) {
        self.id = UUID()
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.userId = userId
        self.timestamp = timestamp
        super.init()
    }
}
