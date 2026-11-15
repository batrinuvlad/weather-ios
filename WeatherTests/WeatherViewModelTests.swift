import XCTest

@MainActor
final class WeatherViewModelTests: XCTestCase {
    func testInitialLoadTransitionsThroughLoadingToSuccess() async throws {
        let forecast = try WeatherFixture.forecast()
        let service = ControlledWeatherService()
        let model = WeatherViewModel(service: service, location: "Example,Country")
        XCTAssertEqual(model.state, .idle)

        let load = Task { await model.loadIfNeeded() }
        await service.waitUntilRequested()
        XCTAssertEqual(model.state, .loading)
        XCTAssertEqual(service.locations, ["Example,Country"])

        service.complete(with: .success(forecast))
        await load.value
        XCTAssertEqual(model.state, .loaded(forecast))

        await model.loadIfNeeded()
        XCTAssertEqual(service.locations.count, 1, "Reappearing must not refetch automatically")
    }

    func testFailureThenRetryTransitionsBackToSuccess() async throws {
        let forecast = try WeatherFixture.forecast()
        for error in [WeatherError.offline, .rateLimited, .invalidResponse] {
            let service = ControlledWeatherService()
            let model = WeatherViewModel(service: service, location: "Example")
            let firstLoad = Task { await model.load() }
            await service.waitUntilRequested()
            service.complete(with: .failure(error))
            await firstLoad.value
            XCTAssertEqual(model.state, .failed(error))

            let retry = Task { await model.load() }
            await service.waitUntilRequested()
            XCTAssertEqual(model.state, .loading)
            service.complete(with: .success(forecast))
            await retry.value
            XCTAssertEqual(model.state, .loaded(forecast))
            XCTAssertEqual(service.locations.count, 2)
        }
    }

    func testOverlappingLoadsAreIgnored() async throws {
        let service = ControlledWeatherService()
        let model = WeatherViewModel(service: service, location: "Example")
        let firstLoad = Task { await model.load() }
        await service.waitUntilRequested()
        await model.load()
        XCTAssertEqual(service.locations.count, 1)
        service.complete(with: .success(try WeatherFixture.forecast()))
        await firstLoad.value
    }

    func testCancelledLoadReturnsToIdleAndCanLoadAgain() async throws {
        let forecast = try WeatherFixture.forecast()
        let service = ControlledWeatherService()
        let model = WeatherViewModel(service: service, location: "Example")
        let load = Task { await model.loadIfNeeded() }
        await service.waitUntilRequested()
        load.cancel()
        service.complete(with: .success(forecast))
        await load.value
        XCTAssertEqual(model.state, .idle)

        let retry = Task { await model.loadIfNeeded() }
        await service.waitUntilRequested()
        service.complete(with: .success(forecast))
        await retry.value
        XCTAssertEqual(model.state, .loaded(forecast))
    }

    func testUnexpectedErrorGetsUserFacingFallback() async {
        let service = ControlledWeatherService()
        let model = WeatherViewModel(service: service, location: "Example")
        let load = Task { await model.load() }
        await service.waitUntilRequested()
        service.complete(with: .failure(URLError(.unknown)))
        await load.value
        XCTAssertEqual(model.state, .failed(.transport))
    }
}

@MainActor
private final class ControlledWeatherService: WeatherService {
    private(set) var locations: [String] = []
    private var pending: CheckedContinuation<WeatherForecast, Error>?
    private var requestObserver: CheckedContinuation<Void, Never>?

    func fetchForecast(for location: String) async throws -> WeatherForecast {
        locations.append(location)
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            requestObserver?.resume()
            requestObserver = nil
        }
    }

    // Synchronize tests with the suspended request without sleeps or live networking.
    func waitUntilRequested() async {
        if pending != nil { return }
        await withCheckedContinuation { requestObserver = $0 }
    }

    func complete(with result: Result<WeatherForecast, Error>) {
        let continuation = pending
        pending = nil
        continuation?.resume(with: result)
    }
}
