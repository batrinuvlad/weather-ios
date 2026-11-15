#if DEBUG
import XCTest

@MainActor
final class MockWeatherServiceTests: XCTestCase {
    func testSuccessUsesTheGenuineFixture() async throws {
        let service = MockWeatherService(.success)
        let model = WeatherViewModel(service: service, location: "Ignored by mock")
        XCTAssertEqual(model.state, .idle)
        let initialRequests = await service.requestCount
        XCTAssertEqual(initialRequests, 0)

        await model.loadIfNeeded()

        XCTAssertEqual(model.state, .loaded(try WeatherFixture.forecast()))
    }

    func testErrorScenariosRemainRecoverableAfterRetry() async {
        for (scenario, error) in [
            (MockWeatherService.Scenario.offline, WeatherError.offline),
            (.rateLimited, .rateLimited),
            (.invalidResponse, .invalidResponse)
        ] {
            let service = MockWeatherService(scenario)
            let model = WeatherViewModel(service: service, location: "Sample")
            await model.loadIfNeeded()
            XCTAssertEqual(model.state, .failed(error))
            await model.load()
            XCTAssertEqual(model.state, .failed(error))
            let requests = await service.requestCount
            XCTAssertEqual(requests, 2)
        }
    }

    func testRetrySuccessFailsOnceThenLoadsFixture() async throws {
        let service = MockWeatherService(.retrySuccess)
        let model = WeatherViewModel(service: service, location: "Sample")
        await model.loadIfNeeded()
        XCTAssertEqual(model.state, .failed(.offline))

        await model.load()

        XCTAssertEqual(model.state, .loaded(try WeatherFixture.forecast()))
        let requests = await service.requestCount
        XCTAssertEqual(requests, 2)
    }

    func testPersistentLoadingSuspendsUntilCancelled() async {
        let service = MockWeatherService(.loading)
        let model = WeatherViewModel(service: service, location: "Sample")
        let load = Task { await model.loadIfNeeded() }
        // Wait for entry into the mock without a timed sleep or real networking.
        while await service.requestCount == 0 { await Task.yield() }
        XCTAssertEqual(model.state, .loading)

        load.cancel()
        await load.value

        XCTAssertEqual(model.state, .idle)
    }
}
#endif
