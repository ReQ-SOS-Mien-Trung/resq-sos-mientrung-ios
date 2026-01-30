import Foundation

struct KeyManager {
    /// Safely retrieves the OpenWeather API key from the `Keys.plist` file.
    static var openWeatherMap: String {
        // Find the Keys.plist file in the main app bundle.
        guard let url = Bundle.main.url(forResource: "Keys", withExtension: "plist") else {
            print("FATAL ERROR: Keys.plist not found in the app bundle. Make sure it's added to the project and target.")
            return ""
        }
        
        // Read the data from the file.
        guard let data = try? Data(contentsOf: url) else {
            print("FATAL ERROR: Could not read data from Keys.plist.")
            return ""
        }
        
        // Deserialize the plist data into a dictionary.
        guard let keys = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            print("FATAL ERROR: Could not deserialize Keys.plist.")
            return ""
        }
        
        // Extract the API key string.
        guard let apiKey = keys["OPENWEATHER_API_KEY"] as? String else {
            print("FATAL ERROR: 'OPENWEATHER_API_KEY' not found in Keys.plist.")
            return ""
        }
        
        // Warn the user if they are still using the placeholder key.
        if apiKey == "YOUR_OPENWEATHER_API_KEY" {
            print("⚠️ WARNING: The OpenWeatherMap API key is still the placeholder value in Keys.plist. Weather overlays will not work.")
        }
        
        return apiKey
    }
    
    /// Safely retrieves the Bridgefy API key from the `Keys.plist` file.
    static var bridgefy: String {
        guard let url = Bundle.main.url(forResource: "Keys", withExtension: "plist") else {
            print("FATAL ERROR: Keys.plist not found in the app bundle.")
            return ""
        }
        
        guard let data = try? Data(contentsOf: url) else {
            print("FATAL ERROR: Could not read data from Keys.plist.")
            return ""
        }
        
        guard let keys = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            print("FATAL ERROR: Could not deserialize Keys.plist.")
            return ""
        }
        
        guard let apiKey = keys["BRIDGEFY_API_KEY"] as? String else {
            print("FATAL ERROR: 'BRIDGEFY_API_KEY' not found in Keys.plist.")
            return ""
        }
        
        if apiKey == "YOUR_BRIDGEFY_API_KEY" {
            print("⚠️ WARNING: The Bridgefy API key is still the placeholder value in Keys.plist. Mesh networking will not work.")
        }
        
        return apiKey
    }
}
