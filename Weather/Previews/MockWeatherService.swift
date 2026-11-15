#if DEBUG
import Foundation

// Preview/demo support only. No URLSession or live networking is used here.
actor MockWeatherService: WeatherService {
    enum Scenario: Sendable {
        case idle, loading, success, offline, rateLimited, invalidResponse, retrySuccess
    }

    private let scenario: Scenario
    private(set) var requestCount = 0

    init(_ scenario: Scenario) {
        self.scenario = scenario
    }

    func fetchForecast(for location: String) async throws -> WeatherForecast {
        requestCount += 1
        switch scenario {
        case .idle, .loading:
            // Idle should disable the view's automatic load. If requested, it suspends too.
            // Sleep yields rather than blocking a thread, and cancellation exits immediately.
            while true {
                try await Task.sleep(for: .seconds(3600))
            }
        case .offline:
            throw WeatherError.offline
        case .rateLimited:
            throw WeatherError.rateLimited
        case .invalidResponse:
            throw WeatherError.invalidResponse
        case .retrySuccess where requestCount == 1:
            throw WeatherError.offline
        case .success, .retrySuccess:
            return try Self.sampleForecast()
        }
    }

    static func sampleForecast() throws -> WeatherForecast {
        // The same fixture is a resource of both the app and non-hosted test bundle.
        let bundle = Bundle(for: MockWeatherBundleMarker.self)
        guard let url = bundle.url(forResource: "weather", withExtension: "json") else {
            throw WeatherError.invalidResponse
        }
        return try JSONDecoder().decode(WeatherForecast.self, from: Data(contentsOf: url))
    }
}

private final class MockWeatherBundleMarker: NSObject {}
#endif
