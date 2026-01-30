import Foundation

// Minimal Codable models for One Call 3.0 (only fields we need)
struct OneCallResponse: Codable {
    let lat: Double
    let lon: Double
    let timezone: String?
    let current: Current?
}

struct Current: Codable {
    let dt: Int?
    let temp: Double?
    let feels_like: Double?
    let pressure: Int?
    let humidity: Int?
    let clouds: Int?
    let visibility: Int?
    let wind_speed: Double?
    let wind_deg: Int?
}

enum WeatherError: Error {
    case missingAPIKey
    case invalidURL
    case httpError(status: Int, data: Data?)
    case decodeError(Error)
}

final class WeatherService {
    private static let base = "https://api.openweathermap.org/data/3.0/onecall"

    @available(iOS 15.0, *)
    static func fetchOneCall(lat: Double,
                             lon: Double,
                             exclude: [String] = [],
                             units: String? = nil) async throws -> OneCallResponse {
        let apiKey = KeyManager.openWeatherMap
        guard !apiKey.isEmpty, apiKey != "YOUR_OPENWEATHER_API_KEY" else {
            throw WeatherError.missingAPIKey
        }

        var components = URLComponents(string: base)
        var q: [URLQueryItem] = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lon", value: String(lon)),
            URLQueryItem(name: "appid", value: apiKey)
        ]
        if !exclude.isEmpty { q.append(URLQueryItem(name: "exclude", value: exclude.joined(separator: ","))) }
        if let u = units { q.append(URLQueryItem(name: "units", value: u)) }
        components?.queryItems = q

        guard let url = components?.url else { throw WeatherError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw WeatherError.httpError(status: http.statusCode, data: data)
        }
        do {
            return try JSONDecoder().decode(OneCallResponse.self, from: data)
        } catch {
            throw WeatherError.decodeError(error)
        }
    }
}
