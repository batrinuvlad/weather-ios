import Foundation

enum TemperatureUnit: String, CaseIterable, Sendable {
    case celsius = "°C"
    case fahrenheit = "°F"

    func converted(_ celsius: Double) -> Double {
        switch self {
        case .celsius: celsius
        case .fahrenheit: celsius * 9 / 5 + 32
        }
    }
}
