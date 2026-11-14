import Foundation

enum WeatherError: Error, Equatable, LocalizedError {
    case invalidLocation
    case offline
    case rateLimited
    case httpStatus(Int)
    case invalidResponse
    case transport

    var errorDescription: String? {
        switch self {
        case .invalidLocation:
            "The weather location could not be requested. Please try again."
        case .offline:
            "You appear to be offline. Check your internet connection and try again."
        case .rateLimited:
            "The free weather allowance has been reached. Please wait a little before trying again."
        case .httpStatus(let status):
            "The weather service returned an error (HTTP \(status)). Please try again later."
        case .invalidResponse:
            "The weather response could not be read. Please try again."
        case .transport:
            "Could not connect to the weather service. Please try again."
        }
    }
}
