import Foundation
import Observation

@Observable
@MainActor
final class WeatherViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(WeatherForecast)
        case failed(WeatherError)
    }

    private(set) var state: State = .idle
    var temperatureUnit: TemperatureUnit = .celsius
    private(set) var lastUpdated: Date?
    private(set) var refreshError: WeatherError?
    private(set) var isLoading = false
    private let now: () -> Date
    var currentDate: Date { now() }

    private let service: any WeatherService
    private let location: String

    init(service: any WeatherService, location: String, now: @escaping () -> Date = Date.init) {
        self.now = now
        self.service = service
        self.location = location
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await load()
    }

    func load() async {
        guard !isLoading else { return }
        let previousState = state
        let previousError = refreshError
        isLoading = true
        refreshError = nil
        switch state {
        case .loaded: break // Keep the forecast visible while refreshing.
        default: state = .loading
        }
        defer { isLoading = false }
        do {
            let forecast = try await service.fetchForecast(for: location)
            try Task.checkCancellation()
            state = .loaded(forecast)
            lastUpdated = now()
        } catch is CancellationError {
            state = previousState
            refreshError = previousError
        } catch {
            let weatherError = error as? WeatherError ?? .transport
            if case .loaded = previousState {
                refreshError = weatherError
            } else {
                state = .failed(weatherError)
            }
        }
    }
}
