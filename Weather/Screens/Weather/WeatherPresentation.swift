import Foundation

// Formatting stays next to the screen so the decoded models remain presentation-independent.
enum WeatherPresentation {
    static func temperature(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return value.formatted(.number.precision(.fractionLength(0))) + "°C"
    }

    static func windSpeed(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return value.formatted(.number.precision(.fractionLength(0))) + " km/h"
    }

    static func conditions(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Conditions unavailable"
        }
        return value
    }

    static func weekday(for date: Date, timeZone: TimeZone, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    static func symbol(for icon: String?) -> String {
        switch icon {
        case "clear-day": "sun.max.fill"
        case "clear-night": "moon.stars.fill"
        case "partly-cloudy-day": "cloud.sun.fill"
        case "partly-cloudy-night": "cloud.moon.fill"
        case "cloudy": "cloud.fill"
        case "rain": "cloud.rain.fill"
        case "snow": "cloud.snow.fill"
        case "fog": "cloud.fog.fill"
        case "wind": "wind"
        default: "questionmark.circle"
        }
    }
}
