# weather-ios

A single-screen SwiftUI weather application for iPhone and iPad, powered by the Visual Crossing Timeline API. London (`London,UK`) is the fixed initial location, with no search or device-location access. Application types and dependencies remain location-agnostic.

## Features

All six mandatory requirements are implemented:

- Load on launch and display the API's `resolvedAddress`.
- Show current temperature, feels-like temperature, conditions text, and wind speed.
- Show seven daily forecasts, **starting today**, with weekday, high/low temperatures, condition text, and icons.
- Show loading and recoverable error states, including offline, HTTP 429, and decoding failures; every error offers Retry.
- Display the exact linked attribution: [Weather data provided by Visual Crossing Weather](https://www.visualcrossing.com/).
- Include unit tests for decoding, presentation, networking, and view-model behavior.

Implemented optional features:

- **°C / °F toggle:** local conversion across current, feels-like, daily, and hourly temperatures; wind remains in km/h.
- **Hourly forecast for today:** a horizontal list from the current hour onward, using the location's timezone; missing hours show an unavailable message.
- **Pull to refresh:** fetch all sections together and display the last successful completion time. Failed refreshes retain the displayed forecast and timestamp, with an inline error and Retry.

## Requirements and getting started

- **Xcode 27.2 (27B52)**, confirmed in the development environment.
- **iOS 17.0+**, Swift (Swift 5 language mode), and SwiftUI.
- No third-party dependencies, account, API key, or secret configuration is required. The app uses Visual Crossing's keyless endpoint.

Open `Weather.xcodeproj`, select the shared **Weather** scheme and an installed iOS simulator, then press **Cmd + R**. No signing setup is needed for the simulator. For a physical device, select your signing team in the app target.

For Terminal builds, ensure `xcode-select -p` points to the full Xcode installation and `xcodebuild -version` works:

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

## Architecture and project structure

```text
Weather/
  App/              Entry point and explicit dependency construction
  Models/           Decodable forecast, current, daily, and hourly models
  Networking/       WeatherService, live implementation, and WeatherError
  Screens/Weather/  SwiftUI views, view model, and presentation helpers
  Previews/         Debug-only mock service and named SwiftUI previews
WeatherTests/       Unit tests and Fixtures/weather.json
```

Lightweight MVVM separates rendering, screen state, and networking without repository or use-case layers. This keeps the single-screen assignment readable and testable.

`WeatherApp` injects a `WeatherService` into `WeatherViewModel`. The live `VisualCrossingWeatherService` uses async/await, an injectable `URLSession`, and `JSONDecoder` with `Decodable` models—the decoding part of Codable. It checks HTTP status before decoding because error bodies may be plain text, and advertises gzip support for keyless requests.

The view model uses `@Observable` and `@MainActor`; it manages explicit idle/loading/loaded/failed states and prevents overlapping requests. Cancellation restores the previous state. Services and forecast values conform to `Sendable`. SwiftUI views reuse `WeatherPresentation`, `TemperatureUnit`, daily rows, and the hourly section rather than duplicating formatting or icon mapping.

## Design decisions

- **Location and days:** London is injected configuration rather than a city-specific type. Today plus six days follows the API's forecast order and avoids skipping today's useful high/low values.
- **Dates:** epoch timestamps and the API's named timezone drive weekday/hour formatting and local-day comparisons, including DST. The caption shows “Today” only when appropriate; historical data shows its start date. Unknown timezones fall back to UTC.
- **Presentation:** provider icon identifiers map to built-in SF Symbols, avoiding downloaded artwork. Unknown icons have a fallback; nullable measurements display `—`.
- **Units and hourly data:** one request uses `include=days,current,hours&unitGroup=metric`. Fahrenheit is calculated locally with `F = C × 9/5 + 32`, so unit changes do not consume API allowance. Hourly selection matches the correct local day and includes the current hour.
- **Refresh and errors:** initial failures replace the loading screen with Retry. Refresh failures retain useful data and report the error separately. “Last updated: HH:mm” uses the forecast timezone and changes only after successful fetch completion, not rendering. A small injected clock closure makes tests and previews deterministic.
- **Fixture versus cache:** `WeatherTests/Fixtures/weather.json` is a saved real response from 15 November 2026, shared by tests and mocks. Normal app loading never reads it. The live service bypasses the local HTTP cache with `reloadIgnoringLocalCacheData`; requests occur on initial loading, pull to refresh, or Retry, with no polling. Displayed data is retained in memory during refresh, but there is no persistent offline cache.

## Tests and previews

Run unit tests with **Cmd + U** using the Weather scheme, or from the repository directory:

```sh
# Choose an installed device name from: xcrun simctl list devices available
xcodebuild -project Weather.xcodeproj -scheme Weather \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' \
  test CODE_SIGNING_ALLOWED=NO
```

The tests cover:

- Genuine-response decoding, seven-day selection, nullable fields, icon fallbacks, temperature conversion, and timezone/DST/midnight boundaries.
- Request parameters, HTTP 400/429/500, offline/timeout failures, invalid responses, and cancellation through an injected URLSession with URLProtocol stubs.
- Loading/success/error/Retry transitions, overlapping-load prevention, unit changes without requests, and successful/failed/cancelled refresh timestamps using controlled services and clocks.

Tests make **no live API requests**. They use the saved fixture and mocks and run without hosting the application. Tested source files also belong to the test target; there is no separate framework.

**Last verified validation, 15 November 2026:** 38 tests passed with zero failures on iPhone 17 / iOS 27.2; the Debug app and all seven preview declarations compiled; the Release simulator build passed; a normal simulator launch displayed live weather. These existing results were checked against saved logs, not rerun for this README review. There are no automated UI tests, and no physical-device or iOS 17 runtime validation has been performed.

For previews, open `Weather/Previews/WeatherPreviews.swift` with the Weather scheme in Debug and an iOS simulator selected. Choose **Editor → Canvas**, then Resume. Select **Idle**, **Loading**, **Success**, **Offline**, **Rate Limited (429)**, **Invalid Response**, or **Retry Success**. Interactive mode allows pressing Retry; Retry Success fails once before returning fixture data. The mock and fixed clock avoid live requests, and idle/loading remain visible. Preview compilation was verified; interactive Canvas rendering was not manually exercised.

## What I would improve with more time

1. **Interactive daily forecast:** Allow users to select any day from the seven-day forecast and display detailed weather information for that day, including its hourly forecast. The current conditions section would be replaced by the selected day's details, with an option to return to the current weather view. This would create a more interactive experience, similar to apps like meteoblue.

2. **Location search:** Allow users to search for and switch between locations instead of using the fixed London location. Potentially support saving favorite locations.

3. **Offline support:** Persist the last successful forecast locally, allowing the app to display previously fetched weather data when offline, with a clear indication of when the information was last updated.

4. **UI/UX improvements:** Introduce richer weather visualizations, such as hourly temperature and precipitation charts, and improve the presentation of detailed forecasts.

5. **Accessibility and testing:** Improve VoiceOver and Dynamic Type support, validate the app on physical devices, and expand UI test coverage for unit switching, pull-to-refresh, and error recovery.

6. **Weather alerts:** Display relevant weather alerts when available and improve the handling of missing or stale forecast data.

## What I would change for an App Store release

- **Product differentiation:** Define a clear value proposition and distinctive features that differentiate the application from existing weather apps. Given how crowded this category is, a simple weather forecast app would offer limited value without a compelling differentiator.

- **Release infrastructure:** Set up the App Store Connect configuration, code signing and distribution, CI/CD pipelines, automated builds and tests, and TestFlight distribution for beta testing.

- **Production reliability:** Implement a robust caching strategy, define data freshness and expiration policies, and ensure appropriate handling of API rate limits, availability, and network failures.

- **Privacy and compliance:** Review API licensing and attribution requirements, prepare the App Store privacy disclosures, and introduce privacy-conscious crash reporting and diagnostics.

- **Quality assurance:** Complete accessibility and localization support, expand automated testing across devices and iOS versions, and prepare production assets and App Store metadata.

## AI assistance

OpenAI Codex was used extensively for code generation and implementation, architecture discussions and refinements, tests, debugging, code review, and documentation. This was an AI-assisted implementation, not primarily handwritten code. The generated implementation was inspected, built, and validated through automated tests and simulator checks during the assisted development sessions.

**Developer confirmation before submission:** Personal review and understanding of the generated code, and ownership of the build/test/simulator validation.

## Time spent

**Total implementation time: 3-4 hours*.

**Additional time for optional features: 0.5 - 1 hour*.

Earlier session-duration estimates do not establish the complete development time. These placeholders must be replaced with the developer's honest estimate before submission.
