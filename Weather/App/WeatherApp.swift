import SwiftUI

@main
struct WeatherApp: App {
    var body: some Scene {
        WindowGroup {
            WeatherView(model: WeatherViewModel(
                service: VisualCrossingWeatherService(),
                location: "London,UK"
            ))
        }
    }
}
