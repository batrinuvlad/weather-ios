#if DEBUG
import SwiftUI

#Preview("Idle") {
    WeatherView(
        model: WeatherViewModel(
            service: MockWeatherService(.idle),
            location: "Sample",
            now: { MockWeatherService.sampleDate }
        ),
        automaticallyLoads: false
    )
}

#Preview("Loading") {
    WeatherView(model: WeatherViewModel(
        service: MockWeatherService(.loading),
        location: "Sample",
        now: { MockWeatherService.sampleDate }
    ))
}

#Preview("Success") {
    WeatherView(model: WeatherViewModel(
        service: MockWeatherService(.success),
        location: "Sample",
        now: { MockWeatherService.sampleDate }
    ))
}

#Preview("Offline") {
    WeatherView(model: WeatherViewModel(
        service: MockWeatherService(.offline),
        location: "Sample",
        now: { MockWeatherService.sampleDate }
    ))
}

#Preview("Rate Limited (429)") {
    WeatherView(model: WeatherViewModel(
        service: MockWeatherService(.rateLimited),
        location: "Sample",
        now: { MockWeatherService.sampleDate }
    ))
}

#Preview("Invalid Response") {
    WeatherView(model: WeatherViewModel(
        service: MockWeatherService(.invalidResponse),
        location: "Sample",
        now: { MockWeatherService.sampleDate }
    ))
}

#Preview("Retry Success") {
    WeatherView(model: WeatherViewModel(
        service: MockWeatherService(.retrySuccess),
        location: "Sample",
        now: { MockWeatherService.sampleDate }
    ))
}
#endif
