import SwiftUI

@main
struct WeatherApp: App {
    var body: some Scene {
        WindowGroup {
            // Hosted unit tests must not launch the live screen or consume the API allowance.
            if ProcessInfo.processInfo.environment["WEATHER_UNIT_TESTS"] == "1" {
                Color.clear
            } else {
                WeatherView(model: WeatherViewModel(
                    service: VisualCrossingWeatherService(),
                    location: "London,UK"
                ))
            }
        }
    }
}
