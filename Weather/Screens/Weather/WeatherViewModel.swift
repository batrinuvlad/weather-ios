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
    private let service: any WeatherService
    private let location: String

    init(service: any WeatherService, location: String) {
        self.service = service
        self.location = location
    }

    func loadIfNeeded() async {
        guard state == .idle else { return }
        await load()
    }

    func load() async {
        guard state != .loading else { return }
        state = .loading
        do {
            let forecast = try await service.fetchForecast(for: location)
            try Task.checkCancellation()
            state = .loaded(forecast)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(error as? WeatherError ?? .transport)
        }
    }
}
