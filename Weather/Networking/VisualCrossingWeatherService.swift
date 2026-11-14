import Foundation

struct VisualCrossingWeatherService: WeatherService {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchForecast(for location: String) async throws -> WeatherForecast {
        guard !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WeatherError.invalidLocation
        }
        let endpoint = URL(string: "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline")!
        var components = URLComponents(url: endpoint.appendingPathComponent(location), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "include", value: "days,current"),
            URLQueryItem(name: "unitGroup", value: "metric")
        ]
        guard let url = components.url else { throw WeatherError.invalidLocation }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        // Keyless requests require gzip. URLSession decompresses the response automatically.
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            if (error as? URLError)?.code == .notConnectedToInternet {
                throw WeatherError.offline
            }
            throw WeatherError.transport
        }
        guard let response = response as? HTTPURLResponse else {
            throw WeatherError.invalidResponse
        }
        switch response.statusCode {
        case 200..<300: break
        case 429: throw WeatherError.rateLimited
        default: throw WeatherError.httpStatus(response.statusCode)
        }

        let forecast: WeatherForecast
        do {
            forecast = try JSONDecoder().decode(WeatherForecast.self, from: data)
        } catch {
            throw WeatherError.invalidResponse
        }
        // A structurally valid but incomplete forecast cannot fulfill the screen's requirements.
        guard !forecast.resolvedAddress.isEmpty, forecast.days.count >= 7 else {
            throw WeatherError.invalidResponse
        }
        return forecast
    }
}
