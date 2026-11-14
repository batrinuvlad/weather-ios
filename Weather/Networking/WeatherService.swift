protocol WeatherService: Sendable {
    func fetchForecast(for location: String) async throws -> WeatherForecast
}
