import Foundation

struct WeatherForecast: Decodable, Equatable, Sendable {
    let resolvedAddress: String
    let timezone: String
    let currentConditions: CurrentConditions
    let days: [DailyForecast]

    var forecastDays: [DailyForecast] { Array(days.prefix(7)) }

    func remainingHoursToday(at now: Date) -> [HourlyForecast] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let day = days.first(where: { calendar.isDate($0.date, inSameDayAs: now) }),
              let currentHour = calendar.dateInterval(of: .hour, for: now) else { return [] }
        return (day.hours ?? []).filter {
            $0.date >= currentHour.start && calendar.isDate($0.date, inSameDayAs: now)
        }.sorted { $0.timestamp < $1.timestamp }
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timezone) ?? TimeZone(secondsFromGMT: 0)!
    }
}

struct CurrentConditions: Decodable, Equatable, Sendable {
    let temperature: Double?
    let feelsLike: Double?
    let windSpeed: Double?
    let conditions: String?
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case temperature = "temp"
        case feelsLike = "feelslike"
        case windSpeed = "windspeed"
        case conditions, icon
    }
}

struct DailyForecast: Decodable, Equatable, Identifiable, Sendable {
    let timestamp: TimeInterval
    let high: Double?
    let low: Double?
    let hours: [HourlyForecast]?
    let conditions: String?
    let icon: String?

    var id: TimeInterval { timestamp }
    var date: Date { Date(timeIntervalSince1970: timestamp) }

    enum CodingKeys: String, CodingKey {
        case timestamp = "datetimeEpoch"
        case high = "tempmax"
        case low = "tempmin"
        case conditions, icon, hours
    }
}

struct HourlyForecast: Decodable, Equatable, Identifiable, Sendable {
    let timestamp: TimeInterval
    let temperature: Double?
    let conditions: String?
    let icon: String?

    var id: TimeInterval { timestamp }
    var date: Date { Date(timeIntervalSince1970: timestamp) }

    enum CodingKeys: String, CodingKey {
        case timestamp = "datetimeEpoch"
        case temperature = "temp"
        case conditions, icon
    }
}
