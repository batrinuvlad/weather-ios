import Foundation

// This is the unmodified successful response fetched on 14 November 2026.
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
