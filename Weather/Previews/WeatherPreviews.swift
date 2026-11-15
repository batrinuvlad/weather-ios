#if DEBUG
import SwiftUI

#Preview("Idle") {
    WeatherView(
        model: WeatherViewModel(service: MockWeatherService(.idle), location: "Sample"),
        automaticallyLoads: false
    )
}

#Preview("Loading") {
    WeatherView(model: WeatherViewModel(service: MockWeatherService(.loading), location: "Sample"))
}

#Preview("Success") {
    WeatherView(model: WeatherViewModel(service: MockWeatherService(.success), location: "Sample"))
}

#Preview("Offline") {
    WeatherView(model: WeatherViewModel(service: MockWeatherService(.offline), location: "Sample"))
}

#Preview("Rate Limited (429)") {
    WeatherView(model: WeatherViewModel(service: MockWeatherService(.rateLimited), location: "Sample"))
}

#Preview("Invalid Response") {
    WeatherView(model: WeatherViewModel(service: MockWeatherService(.invalidResponse), location: "Sample"))
}

#Preview("Retry Success") {
    WeatherView(model: WeatherViewModel(service: MockWeatherService(.retrySuccess), location: "Sample"))
}
#endif
