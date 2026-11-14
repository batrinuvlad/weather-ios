import XCTest
@testable import Weather

final class WeatherServiceTests: XCTestCase {
    private var session: URLSession!
    private var service: VisualCrossingWeatherService!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: configuration)
        service = VisualCrossingWeatherService(session: session)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        StubURLProtocol.handler = nil
        service = nil
        session = nil
        super.tearDown()
    }

    func testRequestIsKeylessMetricAndReturnsDecodedForecast() async throws {
        let data = try WeatherFixture.data()
        StubURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            XCTAssertEqual(url.host, "weather.visualcrossing.com")
            XCTAssertEqual(url.lastPathComponent, "London,UK")
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            XCTAssertEqual(query, ["include": "days,current", "unitGroup": "metric"])
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Encoding"), "gzip")
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let forecast = try await service.fetchForecast(for: "London,UK")
        XCTAssertEqual(forecast, try WeatherFixture.forecast())
    }

    func testLocationIsAnInputAndIsEncodedAsOnePathComponent() async throws {
        let data = try WeatherFixture.data()
        StubURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            XCTAssertEqual(url.lastPathComponent, "New York,US")
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        _ = try await service.fetchForecast(for: "New York,US")
    }

    func testHTTPErrorsAreCheckedBeforeDecodingPlainTextBody() async {
        for (status, expected) in [(400, WeatherError.httpStatus(400)), (429, .rateLimited), (500, .httpStatus(500))] {
            respond(status: status, data: Data("Not JSON".utf8))
            await assertFailure(expected)
        }
    }

    func testMalformedSuccessResponseIsRecoverableError() async {
        respond(status: 200, data: Data("Not JSON".utf8))
        await assertFailure(.invalidResponse)
    }

    func testMissingCurrentConditionsIsRecoverableError() async {
        respond(status: 200, data: Data("""
        {"resolvedAddress":"Example","timezone":"UTC","days":[]}
        """.utf8))
        await assertFailure(.invalidResponse)
    }

    func testFewerThanSevenDaysIsRecoverableError() async {
        respond(status: 200, data: Data("""
        {"resolvedAddress":"Example","timezone":"UTC","currentConditions":{},"days":[]}
        """.utf8))
        await assertFailure(.invalidResponse)
    }

    func testOfflineError() async {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await assertFailure(.offline)
    }

    func testTimeoutError() async {
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        await assertFailure(.transport)
    }

    func testCancellationRemainsCancellation() async {
        StubURLProtocol.handler = { _ in throw URLError(.cancelled) }
        do {
            _ = try await service.fetchForecast(for: "Example")
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testBlankLocationFailsWithoutSendingRequest() async {
        StubURLProtocol.handler = { _ in
            XCTFail("Blank location must not send a request")
            throw URLError(.badURL)
        }
        do {
            _ = try await service.fetchForecast(for: "  ")
            XCTFail("Expected invalid location")
        } catch {
            XCTAssertEqual(error as? WeatherError, .invalidLocation)
        }
    }

    private func respond(status: Int, data: Data) {
        StubURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, data)
        }
    }

    private func assertFailure(_ expected: WeatherError, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await service.fetchForecast(for: "Example")
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? WeatherError, expected, file: file, line: line)
        }
    }
}

// XCTest runs this class's methods serially. Every request is intercepted, including unexpected ones.
private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw URLError(.resourceUnavailable)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
