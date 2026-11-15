import SwiftUI

struct HourlyForecastSection: View {
    let hours: [HourlyForecast]
    let timeZone: TimeZone
    let temperatureUnit: TemperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hourly forecast for today")
                .font(.headline)
            if hours.isEmpty {
                Text("No remaining hourly forecast is available for today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 24) {
                        ForEach(hours) { hour in
                            VStack(spacing: 10) {
                                Text(WeatherPresentation.time(hour.date, timeZone: timeZone))
                                Image(systemName: WeatherPresentation.symbol(for: hour.icon))
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                    .accessibilityLabel(WeatherPresentation.conditions(hour.conditions))
                                Text(WeatherPresentation.temperature(hour.temperature, unit: temperatureUnit))
                            }
                            .font(.subheadline.monospacedDigit())
                            .fixedSize()
                        }
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}
