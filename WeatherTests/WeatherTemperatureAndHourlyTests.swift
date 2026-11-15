import XCTest

final class WeatherTemperatureAndHourlyTests: XCTestCase {
    func testTemperatureConversionAndFormatting() {
        XCTAssertEqual(TemperatureUnit.fahrenheit.converted(0), 32)
        XCTAssertEqual(TemperatureUnit.fahrenheit.converted(100), 212)
        XCTAssertEqual(TemperatureUnit.fahrenheit.converted(-40), -40)
        XCTAssertEqual(TemperatureUnit.celsius.converted(12.5), 12.5)
        let locale = Locale(identifier: "en_GB")
        XCTAssertEqual(WeatherPresentation.temperature(0, unit: .celsius, locale: locale), "0°C")
        XCTAssertEqual(WeatherPresentation.temperature(0, unit: .fahrenheit, locale: locale), "32°F")
        XCTAssertEqual(WeatherPresentation.temperature(10.6, unit: .celsius, locale: locale), "11°C")
        XCTAssertEqual(WeatherPresentation.temperature(nil, unit: .fahrenheit), "—")
        XCTAssertEqual(WeatherPresentation.temperature(.nan, unit: .fahrenheit), "—")
        XCTAssertEqual(WeatherPresentation.temperature(.infinity), "—")
    }

    func testGenuineHourlyFixtureDecodesAndIncludesCurrentHour() throws {
        let forecast = try WeatherFixture.forecast()
        let first = try XCTUnwrap(forecast.days.first)
        XCTAssertEqual(first.hours?.count, 24)
        XCTAssertEqual(first.hours?.first?.temperature, 2.7)
        XCTAssertEqual(first.hours?.first?.conditions, "Overcast")
        XCTAssertEqual(first.hours?.first?.icon, "cloudy")
        let remaining = forecast.remainingHoursToday(at: date("2026-11-15T16:37:00Z"))
        XCTAssertEqual(remaining.count, 8)
        XCTAssertEqual(remaining.first?.date, date("2026-11-15T16:00:00Z"))
        XCTAssertEqual(remaining.last?.date, date("2026-11-15T23:00:00Z"))
    }

    func testLocalMidnightSelectsCorrectDayRatherThanFirstDayOrUTCDay() throws {
        let forecast = try sample(timezone: "Asia/Tokyo", days: [
            ("2026-07-03T15:00:00Z", ["2026-07-04T14:00:00Z"]),
            ("2026-07-04T15:00:00Z", ["2026-07-04T15:00:00Z", "2026-07-04T16:00:00Z",
                                      "2026-07-05T15:00:00Z"])
        ])
        let remaining = forecast.remainingHoursToday(at: date("2026-07-04T15:30:00Z"))
        XCTAssertEqual(remaining.map(\.date), [date("2026-07-04T15:00:00Z"), date("2026-07-04T16:00:00Z")])
        XCTAssertEqual(WeatherPresentation.time(remaining[0].date, timeZone: forecast.timeZone), "00:00")
    }

    func testLastHourOfDayDoesNotIncludeTomorrow() throws {
        let forecast = try sample(timezone: "America/New_York", days: [
            ("2026-07-04T04:00:00Z", ["2026-07-05T02:00:00Z", "2026-07-05T03:00:00Z"]),
            ("2026-07-05T04:00:00Z", ["2026-07-05T04:00:00Z"])
        ])
        let remaining = forecast.remainingHoursToday(at: date("2026-07-05T03:59:00Z"))
        XCTAssertEqual(remaining.map(\.date), [date("2026-07-05T03:00:00Z")])
        XCTAssertEqual(WeatherPresentation.time(remaining[0].date, timeZone: forecast.timeZone), "23:00")
    }

    func testRepeatedDSTHourUsesAbsoluteTimestamps() throws {
        let forecast = try sample(timezone: "Europe/London", days: [
            ("2026-10-24T23:00:00Z", ["2026-10-25T00:00:00Z", "2026-10-25T01:00:00Z",
                                      "2026-10-25T02:00:00Z"])
        ])
        // Both 00:00Z and 01:00Z display as 01:00 locally. Only the second remains now.
        XCTAssertEqual(forecast.remainingHoursToday(at: date("2026-10-25T01:30:00Z")).map(\.date),
                       [date("2026-10-25T01:00:00Z"), date("2026-10-25T02:00:00Z")])
    }

    func testSpringDSTGapAndMissingLocalDay() throws {
        let forecast = try sample(timezone: "Europe/London", days: [
            ("2026-03-29T00:00:00Z", ["2026-03-29T00:00:00Z", "2026-03-29T01:00:00Z",
                                      "2026-03-29T02:00:00Z"])
        ])
        let remaining = forecast.remainingHoursToday(at: date("2026-03-29T01:30:00Z"))
        XCTAssertEqual(remaining.map(\.date), [date("2026-03-29T01:00:00Z"), date("2026-03-29T02:00:00Z")])
        XCTAssertEqual(WeatherPresentation.time(remaining[0].date, timeZone: forecast.timeZone), "02:00")
        XCTAssertTrue(forecast.remainingHoursToday(at: date("2026-03-30T12:00:00Z")).isEmpty)
    }

    func testMissingNullAndEmptyHoursDecodeGracefully() throws {
        for suffix in ["", ",\"hours\":null", ",\"hours\":[]"] {
            let data = Data("""
            {"resolvedAddress":"Example","timezone":"UTC","currentConditions":{},
             "days":[{"datetimeEpoch":1794700800\(suffix)}]}
            """.utf8)
            let forecast = try JSONDecoder().decode(WeatherForecast.self, from: data)
            XCTAssertTrue(forecast.remainingHoursToday(at: date("2026-11-15T12:00:00Z")).isEmpty)
        }
    }

    func testNullableHourlyMeasurementsHaveFallbacks() throws {
        let data = Data("""
        {"datetimeEpoch":1794700800,"temp":null,"conditions":null,"icon":"unknown"}
        """.utf8)
        let hour = try JSONDecoder().decode(HourlyForecast.self, from: data)
        XCTAssertEqual(WeatherPresentation.temperature(hour.temperature, unit: .fahrenheit), "—")
        XCTAssertEqual(WeatherPresentation.symbol(for: hour.icon), "questionmark.circle")
        XCTAssertEqual(WeatherPresentation.conditions(hour.conditions), "Conditions unavailable")
    }

    private func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }

    private func sample(timezone: String, days: [(String, [String])]) throws -> WeatherForecast {
        let object: [String: Any] = [
            "resolvedAddress": "Example", "timezone": timezone, "currentConditions": [:],
            "days": days.map { day -> [String: Any] in
                ["datetimeEpoch": date(day.0).timeIntervalSince1970,
                 "hours": day.1.map { ["datetimeEpoch": date($0).timeIntervalSince1970] }]
            }
        ]
        return try JSONDecoder().decode(WeatherForecast.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
