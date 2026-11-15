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
            .refreshable { await model.load() }
            .scrollBounceBehavior(.always, axes: .vertical)
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
            if let lastUpdated = model.lastUpdated {
                Text("Last updated: \(WeatherPresentation.time(lastUpdated, timeZone: forecast.timeZone))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let error = model.refreshError {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Couldn’t refresh. Showing previously loaded weather.")
                        .font(.subheadline.bold())
                    Text(error.localizedDescription)
                        .font(.subheadline)
                    Button("Retry") { Task { await model.load() } }
                        .disabled(model.isLoading)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
            }
            currentConditions(forecast.currentConditions)
            HourlyForecastSection(
                hours: forecast.remainingHoursToday(at: model.currentDate),
                timeZone: forecast.timeZone,
                temperatureUnit: model.temperatureUnit
            )
            VStack(alignment: .leading, spacing: 16) {
                Text("Seven-day forecast")
                    .font(.headline)
                if let firstDay = forecast.forecastDays.first {
                    Text(WeatherPresentation.forecastPeriod(starting: firstDay.date, timeZone: forecast.timeZone, now: model.currentDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(forecast.forecastDays) { day in
                    ForecastDayRow(day: day, timeZone: forecast.timeZone, temperatureUnit: model.temperatureUnit)
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
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 12) {
            Text("Now")
                .font(.headline)
            Picker("Temperature unit", selection: $model.temperatureUnit) {
                ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            HStack(spacing: 16) {
                Image(systemName: WeatherPresentation.symbol(for: current.icon))
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text(WeatherPresentation.temperature(current.temperature, unit: model.temperatureUnit))
                    .font(.largeTitle.bold())
            }
            Text(WeatherPresentation.conditions(current.conditions))
            Text("Feels like \(WeatherPresentation.temperature(current.feelsLike, unit: model.temperatureUnit))")
                .foregroundStyle(.secondary)
            Label("Wind \(WeatherPresentation.windSpeed(current.windSpeed))", systemImage: "wind")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}
