import SwiftUI

struct WeatherView: View {
    @State private var model: WeatherViewModel
    private let automaticallyLoads: Bool

    init(model: WeatherViewModel, automaticallyLoads: Bool = true) {
        self.automaticallyLoads = automaticallyLoads
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    content
                    Link("Weather data provided by Visual Crossing Weather",
                         destination: URL(string: "https://www.visualcrossing.com/")!)
                        .font(.footnote)
                }
                .padding()
                .frame(maxWidth: 600, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Weather")
            .task {
                if automaticallyLoads {
                    await model.loadIfNeeded()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            ContentUnavailableView("Weather not loaded", systemImage: "cloud",
                                   description: Text("No weather request has started."))
        case .loading:
            ProgressView("Loading weather…")
                .frame(maxWidth: .infinity, minHeight: 220)
        case .failed(let error):
            ContentUnavailableView {
                Label("Weather unavailable", systemImage: "exclamationmark.icloud")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("Retry") {
                    Task { await model.load() }
                }
                .buttonStyle(.borderedProminent)
            }
        case .loaded(let forecast):
            Text(forecast.resolvedAddress)
                .font(.title2.bold())
            currentConditions(forecast.currentConditions)
            VStack(alignment: .leading, spacing: 16) {
                Text("Seven-day forecast")
                    .font(.headline)
                if let firstDay = forecast.forecastDays.first {
                    Text(WeatherPresentation.forecastPeriod(starting: firstDay.date, timeZone: forecast.timeZone))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(forecast.forecastDays) { day in
                    ForecastDayRow(day: day, timeZone: forecast.timeZone)
                    if day.id != forecast.forecastDays.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func currentConditions(_ current: CurrentConditions) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Now")
                .font(.headline)
            HStack(spacing: 16) {
                Image(systemName: WeatherPresentation.symbol(for: current.icon))
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text(WeatherPresentation.temperature(current.temperature))
                    .font(.largeTitle.bold())
            }
            Text(WeatherPresentation.conditions(current.conditions))
            Text("Feels like \(WeatherPresentation.temperature(current.feelsLike))")
                .foregroundStyle(.secondary)
            Label("Wind \(WeatherPresentation.windSpeed(current.windSpeed))", systemImage: "wind")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}
