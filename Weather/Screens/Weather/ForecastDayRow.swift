import SwiftUI

struct ForecastDayRow: View {
    let day: DailyForecast
    let timeZone: TimeZone
    let temperatureUnit: TemperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(WeatherPresentation.weekday(for: day.date, timeZone: timeZone))
                    .font(.headline)
                Spacer()
                Image(systemName: WeatherPresentation.symbol(for: day.icon))
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
            }
            Text(WeatherPresentation.conditions(day.conditions))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { temperatures }
                VStack(alignment: .leading, spacing: 4) { temperatures }
            }
            .font(.subheadline.monospacedDigit())
        }
    }

    @ViewBuilder
    private var temperatures: some View {
        Text("High \(WeatherPresentation.temperature(day.high, unit: temperatureUnit))")
        Text("Low \(WeatherPresentation.temperature(day.low, unit: temperatureUnit))")
            .foregroundStyle(.secondary)
    }
}
