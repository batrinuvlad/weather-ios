import Foundation

// This is the unmodified successful response fetched on 15 November 2026 (including hours).
enum WeatherFixture {
    static func data() throws -> Data {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        let url = bundle.url(forResource: "weather", withExtension: "json")!
        return try Data(contentsOf: url)
    }

    static func forecast() throws -> WeatherForecast {
        try JSONDecoder().decode(WeatherForecast.self, from: data())
    }
}

private final class FixtureBundleMarker: NSObject {}
