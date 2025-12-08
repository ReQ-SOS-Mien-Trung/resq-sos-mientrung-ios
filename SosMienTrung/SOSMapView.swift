import SwiftUI
import MapKit

struct SOSMapView: View {
    @StateObject private var locationManager = LocationManager()
    @Binding var messages: [Message]
    
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 16.047079, longitude: 108.206230),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(locationAnnotations) { annotation in
                    Annotation(annotation.title ?? "SOS", coordinate: annotation.coordinate) {
                        VStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                            Text(annotation.title ?? "SOS")
                                .font(.caption)
                                .padding(4)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: centerOnCurrentLocation) {
                        Image(systemName: "location.fill")
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
        }
        .onChange(of: locationManager.currentLocation) { _, newLocation in
            if let location = newLocation {
                centerMap(on: location.coordinate)
            }
        }
    }
    
    private var locationAnnotations: [LocationAnnotation] {
        messages.compactMap { message in
            guard message.hasLocation,
                  let lat = message.latitude,
                  let long = message.longitude else {
                return nil
            }
            
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
            return LocationAnnotation(
                coordinate: coordinate,
                title: message.text,
                subtitle: "SOS - \(message.timestamp.formatted())",
                userId: message.senderId,
                timestamp: message.timestamp
            )
        }
    }
    
    private func centerOnCurrentLocation() {
        if let location = locationManager.currentLocation {
            centerMap(on: location.coordinate)
        }
    }
    
    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        withAnimation {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }
    }
}

// Helper view để hiển thị bản đồ với UIKit (Nếu cần tùy chỉnh nhiều hơn)
struct MapViewRepresentable: UIViewRepresentable {
    @Binding var annotations: [LocationAnnotation]
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Remove old annotations
        mapView.removeAnnotations(mapView.annotations)
        
        // Add new annotations
        mapView.addAnnotations(annotations)
        
        // Update region
        mapView.setRegion(region, animated: true)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is LocationAnnotation else { return nil }
            
            let identifier = "SOSAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.markerTintColor = .red
                annotationView?.glyphImage = UIImage(systemName: "exclamationmark.triangle.fill")
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
    }
}
