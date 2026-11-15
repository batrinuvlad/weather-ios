# weather-ios

## Project

- Swift and SwiftUI iOS weather app; minimum deployment target iOS 17.0.
- Use async/await, URLSession, and Codable. No third-party dependencies without explicit approval.

## Architecture

- Follow the existing lightweight MVVM structure: `App/`, `Models/`, `Networking/`, `Screens/Weather/`, and debug-only `Previews/` under `Weather/`.
- Keep `WeatherService` as the protocol for explicit dependency injection and testing; use `VisualCrossingWeatherService` for live API requests.
- Keep models, networking, view models, and SwiftUI views separate. Use location-agnostic naming except for provider-specific implementations.
- Prefer simple, readable, maintainable Swift. Avoid unnecessary abstractions, repositories, use-case layers, and unrelated refactoring.

## SwiftUI and concurrency

- Use `@Observable` for view models and `@MainActor` for UI-facing state. Respect Swift concurrency isolation and `Sendable` requirements.
- Handle loading, success, errors, and cancellation explicitly; preserve existing refresh and Retry behavior.
- Reuse existing UI components, temperature formatting, icon mapping, and timezone-aware date helpers.

## Networking and testing

- Minimize Visual Crossing requests: its free allowance is limited. Prefer `WeatherTests/Fixtures/weather.json` and `MockWeatherService` for development.
- Unit tests must never make live API requests. Keep the non-hosted test setup; shared source files need test-target membership when required.
- Handle network failures, HTTP 429, decoding errors, and cancellation correctly.
- Run relevant tests after code changes and verify builds when practical. Report only checks actually run.

## Workflow

- Inspect existing code before editing. Make focused changes that follow established conventions; preserve user changes.
- Do not add dependencies or optional features without approval.
- Preserve Git history. Never push to GitHub without explicit approval.
- Do not commit secrets, local build artifacts, or `ios-take-home-brief.pdf`.
- Keep `README.md` accurate, including actual implementation time, validation results, and AI usage disclosure.
