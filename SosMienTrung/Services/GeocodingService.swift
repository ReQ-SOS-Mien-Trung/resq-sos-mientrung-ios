import Foundation
import CoreLocation
import MapKit
import Combine

struct GeocodingResult {
    let latitude: Double
    let longitude: Double
    let displayName: String
}

struct AppleMapsAddressSuggestion: Identifiable {
    let title: String
    let subtitle: String
    fileprivate let completion: MKLocalSearchCompletion

    var id: String { "\(title)|\(subtitle)" }
}

enum GeocodingError: LocalizedError {
    case invalidResponse
    case noResults
    case noAddress

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return L10n.Geocoding.invalidResponse
        case .noResults:
            return L10n.Geocoding.noResults
        case .noAddress:
            return L10n.Geocoding.noAddress
        }
    }
}

@MainActor
final class AppleMapsSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var suggestions: [AppleMapsAddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address]
    }

    func updateQuery(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            suggestions = []
            completer.queryFragment = ""
            return
        }

        completer.queryFragment = trimmedQuery
    }

    func clearSuggestions() {
        suggestions = []
        completer.queryFragment = ""
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
            .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map {
                AppleMapsAddressSuggestion(
                    title: $0.title,
                    subtitle: $0.subtitle,
                    completion: $0
                )
            }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
        print("📍 [AppleMapsSearch] Completer error: \(error.localizedDescription)")
    }
}

final class GeocodingService {
    static let shared = GeocodingService()

    private let geocoder = CLGeocoder()

    func geocodeAddress(_ query: String) async throws -> GeocodingResult {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address

        let response = try await MKLocalSearch(request: request).start()
        guard let mapItem = response.mapItems.first else {
            throw GeocodingError.noResults
        }

        return makeResult(from: mapItem)
    }

    func geocodeSuggestion(_ suggestion: AppleMapsAddressSuggestion) async throws -> GeocodingResult {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        request.resultTypes = .address

        let response = try await MKLocalSearch(request: request).start()
        guard let mapItem = response.mapItems.first else {
            throw GeocodingError.noResults
        }

        return makeResult(from: mapItem)
    }

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String {
        let placemarks = try await geocoder.reverseGeocodeLocation(
            CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        )

        guard let placemark = placemarks.first else {
            throw GeocodingError.noResults
        }

        let address = Self.formattedAddress(from: placemark)
        guard !address.isEmpty else {
            throw GeocodingError.noAddress
        }

        return address
    }

    private func makeResult(from mapItem: MKMapItem) -> GeocodingResult {
        let coordinate = mapItem.placemark.coordinate
        let displayName = Self.formattedAddress(from: mapItem.placemark)

        return GeocodingResult(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            displayName: displayName.isEmpty ? (mapItem.name ?? "Apple Maps") : displayName
        )
    }

    private static func formattedAddress(from placemark: CLPlacemark) -> String {
        let rawParts = [
            placemark.name,
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.subLocality,
            placemark.locality,
            placemark.subAdministrativeArea,
            placemark.administrativeArea,
            placemark.country
        ]

        var uniqueParts: [String] = []
        for part in rawParts {
            let trimmed = part?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty, !uniqueParts.contains(trimmed) else { continue }
            uniqueParts.append(trimmed)
        }

        return uniqueParts.joined(separator: ", ")
    }
}
