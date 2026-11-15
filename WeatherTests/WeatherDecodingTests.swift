import XCTest

final class WeatherDecodingTests: XCTestCase {
    func testGenuineResponseDecodesRequiredFieldsAndSelectsTodayPlusSixDays() throws {
        let forecast = try WeatherFixture.forecast()

        XCTAssertEqual(forecast.resolvedAddress, "London, England, United Kingdom")
        XCTAssertEqual(forecast.timezone, "Europe/London")
        XCTAssertEqual(forecast.currentConditions.temperature, 6.8)
        XCTAssertEqual(forecast.currentConditions.feelsLike, 6.8)
        XCTAssertEqual(forecast.currentConditions.windSpeed, 3.4)
        XCTAssertEqual(forecast.currentConditions.conditions, "Partially cloudy")
        XCTAssertEqual(forecast.days.count, 8)
        XCTAssertEqual(forecast.forecastDays.count, 7)
        XCTAssertEqual(forecast.forecastDays.first?.timestamp, 1794614400)
        XCTAssertEqual(forecast.forecastDays.first?.high, 7.1)
        XCTAssertEqual(forecast.forecastDays.first?.low, -0.7)
        XCTAssertEqual(forecast.forecastDays.last, forecast.days[6])
    }

    func testNullAndMissingMeasurementsHaveSafeDisplayFallbacks() throws {
        let data = Data("""
        {
          "resolvedAddress": "Example", "timezone": "Etc/UTC",
          "currentConditions": {"temp": null, "feelslike": null, "conditions": null},
          "days": [{"datetimeEpoch": 1794614400, "tempmax": null, "icon": "future-icon"}]
        }
        """.utf8)
        let forecast = try JSONDecoder().decode(WeatherForecast.self, from: data)

        XCTAssertNil(forecast.currentConditions.temperature)
        XCTAssertNil(forecast.currentConditions.windSpeed)
        XCTAssertEqual(WeatherPresentation.temperature(forecast.currentConditions.temperature), "—")
        XCTAssertEqual(WeatherPresentation.windSpeed(forecast.currentConditions.windSpeed), "—")
        XCTAssertEqual(WeatherPresentation.conditions(forecast.currentConditions.conditions), "Conditions unavailable")
        XCTAssertEqual(WeatherPresentation.symbol(for: forecast.days[0].icon), "questionmark.circle")
        XCTAssertEqual(WeatherPresentation.symbol(for: nil), "questionmark.circle")
        XCTAssertNil(forecast.days[0].low)
    }

    func testWeekdayUsesResponseTimezoneRatherThanDeviceTimezone() throws {
        let forecast = try WeatherFixture.forecast()
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-04T23:30:00Z"))
        let locale = Locale(identifier: "en_GB")

        XCTAssertEqual(WeatherPresentation.weekday(for: date, timeZone: forecast.timeZone, locale: locale), "Sunday")
        XCTAssertEqual(WeatherPresentation.weekday(for: date, timeZone: TimeZone(secondsFromGMT: 0)!, locale: locale), "Saturday")
    }

    func testInvalidTimezoneFallsBackToUTC() throws {
        let data = Data("""
        {"resolvedAddress":"Example","timezone":"unknown/timezone","currentConditions":{},"days":[]}
        """.utf8)
        let forecast = try JSONDecoder().decode(WeatherForecast.self, from: data)
        XCTAssertEqual(forecast.timeZone.secondsFromGMT(), 0)
    }

    func testMalformedJSONFailsDecoding() {
        XCTAssertThrowsError(try JSONDecoder().decode(WeatherForecast.self, from: Data("invalid".utf8)))
    }
}
