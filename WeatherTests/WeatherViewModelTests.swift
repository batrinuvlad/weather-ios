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

    func testUnitSwitchingDoesNotFetchOrMutateMetricForecast() async throws {
        let service = ControlledWeatherService()
        let model = WeatherViewModel(service: service, location: "Example")
        XCTAssertEqual(model.temperatureUnit, .celsius)
        let forecast = try WeatherFixture.forecast()
        let load = Task { await model.load() }
        await service.waitUntilRequested()
        service.complete(with: .success(forecast))
        await load.value

        model.temperatureUnit = .fahrenheit
        model.temperatureUnit = .celsius
        model.temperatureUnit = .fahrenheit

        XCTAssertEqual(service.locations.count, 1)
        XCTAssertEqual(model.state, .loaded(forecast))
        XCTAssertTrue(WeatherPresentation.windSpeed(forecast.currentConditions.windSpeed).hasSuffix("km/h"))
    }

    func testSuccessfulRefreshRetainsDataWhileLoadingAndUpdatesCompletionTime() async throws {
        let service = ControlledWeatherService()
        let first = try WeatherFixture.forecast()
        let second = WeatherForecast(resolvedAddress: "Updated location", timezone: first.timezone,
                                     currentConditions: first.currentConditions, days: first.days)
        var time = Date(timeIntervalSince1970: 1000)
        let model = WeatherViewModel(service: service, location: "Example", now: { time })
        XCTAssertNil(model.lastUpdated)
        let initialLoad = Task { await model.load() }
        await service.waitUntilRequested()
        service.complete(with: .success(first))
        await initialLoad.value
        XCTAssertEqual(model.lastUpdated, time)

        let refresh = Task { await model.load() }
        await service.waitUntilRequested()
        XCTAssertEqual(model.state, .loaded(first))
        XCTAssertTrue(model.isLoading)
        XCTAssertEqual(model.lastUpdated, Date(timeIntervalSince1970: 1000))
        await model.load() // An overlapping refresh must not send a third request.
        XCTAssertEqual(service.locations.count, 2)
        time = Date(timeIntervalSince1970: 2000)
        service.complete(with: .success(second))
        await refresh.value

        XCTAssertEqual(model.state, .loaded(second))
        XCTAssertEqual(model.lastUpdated, time)
        XCTAssertNil(model.refreshError)
        XCTAssertFalse(model.isLoading)
    }

    func testFailedRefreshPreservesForecastAndTimestampAndCanRetry() async throws {
        let service = ControlledWeatherService()
        let forecast = try WeatherFixture.forecast()
        var time = Date(timeIntervalSince1970: 1000)
        let model = WeatherViewModel(service: service, location: "Example", now: { time })
        let initialLoad = Task { await model.load() }
        await service.waitUntilRequested()
        service.complete(with: .success(forecast))
        await initialLoad.value

        for error in [WeatherError.offline, .rateLimited, .invalidResponse] {
            let refresh = Task { await model.load() }
            await service.waitUntilRequested()
            time = Date(timeIntervalSince1970: 2000)
            service.complete(with: .failure(error))
            await refresh.value
            XCTAssertEqual(model.state, .loaded(forecast))
            XCTAssertEqual(model.refreshError, error)
            XCTAssertEqual(model.lastUpdated, Date(timeIntervalSince1970: 1000))
            XCTAssertFalse(model.isLoading)
        }
        let retry = Task { await model.load() }
        await service.waitUntilRequested()
        XCTAssertNil(model.refreshError)
        service.complete(with: .success(forecast))
        await retry.value
        XCTAssertNil(model.refreshError)
        XCTAssertEqual(model.lastUpdated, time)
    }

    func testCancelledRefreshPreservesForecastAndTimestamp() async throws {
        let service = ControlledWeatherService()
        let forecast = try WeatherFixture.forecast()
        let completed = Date(timeIntervalSince1970: 1000)
        let model = WeatherViewModel(service: service, location: "Example", now: { completed })
        let load = Task { await model.load() }
        await service.waitUntilRequested()
        service.complete(with: .success(forecast))
        await load.value
        let refresh = Task { await model.load() }
        await service.waitUntilRequested()
        refresh.cancel()
        service.complete(with: .success(forecast))
        await refresh.value
        XCTAssertEqual(model.state, .loaded(forecast))
        XCTAssertEqual(model.lastUpdated, completed)
        XCTAssertNil(model.refreshError)
        XCTAssertFalse(model.isLoading)
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
