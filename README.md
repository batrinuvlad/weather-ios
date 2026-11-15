# weather-ios

A single-screen SwiftUI weather app for iPhone and iPad with a temperature toggle, hourly forecast, and pull to refresh, using the keyless Visual Crossing Timeline API. The initial location is `London,UK`; the screen displays the API's `resolvedAddress`.

## Build and run

- Built and tested with **Xcode 27.2 (27B52)**. Minimum deployment target: **iOS 17.0**. No third-party dependencies, API key, or account is required.
- Open `Weather.xcodeproj`, select the shared **Weather** scheme and an iOS simulator, then Run (⌘R).
- Run unit tests with ⌘U. For a physical device, select your signing team in the app target first.
- Check `xcode-select -p` points to `/Applications/Xcode.app/Contents/Developer` and `xcodebuild -version` works.

From the repository directory:

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO

# Replace the device name if needed; see xcrun simctl list devices available.
xcodebuild -project Weather.xcodeproj -scheme Weather \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test CODE_SIGNING_ALLOWED=NO
```

## Organization and decisions

- `App/WeatherApp.swift` explicitly constructs the service and view model and supplies the fixed initial location.
- `Models/` contains small `Decodable` structs. Only fields used by the screen are decoded, with coding keys for readable Swift names. Nullable measurements are optional.
- `Networking/` contains the `WeatherService` protocol, its `VisualCrossingWeatherService` implementation, and recoverable errors. `URLSession` is injected for tests. HTTP status is checked before JSON decoding because error bodies may be plain text.
- `Screens/Weather/` contains the SwiftUI screen, an `@Observable`, `@MainActor` view model, presentation helpers, a daily forecast row, and an hourly forecast section. The view model exposes idle/loading/loaded/failed states and prevents overlapping requests. Initial-load errors offer Retry. Refresh keeps the previous forecast visible; failures show an inline error with Retry, preserving the successful timestamp. Cancellation restores the previous state.
- `WeatherTests/` contains the genuine response fixture, decoding/presentation tests, URLProtocol service tests, and deterministic view-model tests.

This small MVVM structure keeps state out of the view and makes networking replaceable in tests. Models decode directly; there is no repository, use-case layer, generic API client, or separate mapping model. Swift 5 language mode uses complete concurrency checking, with explicit main-actor isolation for screen state.

The forecast shows **today plus the next six days**: the first seven entries returned by the forecast endpoint. Weekdays use epoch timestamps and the response's timezone, including daylight-saving rules. The caption only says “Today” if the first day matches the current calendar day in the API timezone; historical/stale data shows its start date. An unknown timezone falls back to UTC. Missing measurements display `—`, missing condition text displays “Conditions unavailable”, and unknown icons use a fallback SF Symbol. Temperatures are rounded for display; all requests use metric units (°C, km/h).

The app loads once when the screen first appears; subsequent requests come from pull to refresh or Retry. It does not poll. It requests `include=days,current,hours&unitGroup=metric`, without a key. Gzip support is explicit because the keyless endpoint requires it; URLSession decompresses the response. The exact required attribution links to https://www.visualcrossing.com/.

## Verification and API usage

- Debug app compilation and the Release simulator build succeeded. **38 unit tests passed, 0 failures**, on iPhone 17 / iOS 27.2. All seven preview declarations compiled; interactive Canvas rendering was not manually exercised. Automated tests make no live API requests. Optional-feature validation fetched one updated hourly fixture and used one normal simulator launch; the app still injects the real Visual Crossing service.
- Tests cover genuine-response decoding, seven-day selection, nulls/unknown icons, timezone formatting across DST changes, the timezone-aware Today caption, temperature conversion and unit changes without requests, hourly selection at midnight/DST boundaries, successful/failed/cancelled refresh timestamps, mock scenarios, request parameters, HTTP 400/429/500, malformed/incomplete responses, offline/timeout errors, cancellation, and view-model loading/success/error/retry transitions.
- Tests make **no real API requests**. Service tests intercept requests with URLProtocol; view-model tests use a controlled stub. The test target has no host application: Xcode runs it in its test runner, without launching `WeatherApp`. The tested production files and debug mock have membership in both targets and compile directly into the test bundle; there are no source copies or extra framework. Consequently, tests do not need `@testable import Weather`. When adding a new production dependency to these tests, include its source in the test target too. App startup contains no test-specific logic.
- `WeatherTests/Fixtures/weather.json` is the unmodified successful keyless response saved on **15 November 2026**, updated with `include=days,current,hours` in one gzip-enabled request. The original daily-only fixture was replaced rather than duplicated.
- iOS 17 is the deployment target, but runtime verification used the installed iOS 27.2 simulator. No physical-device or iOS 17 runtime test was performed. There are no automated UI tests.

## SwiftUI Previews and simulator demonstrations

Open `Weather/Previews/WeatherPreviews.swift` with the **Weather** scheme, **Debug** configuration, and an iOS simulator selected. Choose **Editor → Canvas** (⌥⌘Return), then **Resume** if paused. Select the named preview in the canvas; use its live/interactive mode to press Retry. All seven `#Preview` declarations compile as part of the Debug app build.

| Preview / mock scenario | Behavior |
| --- | --- |
| Idle / `.idle` | No request; the view uses `automaticallyLoads: false`. |
| Loading / `.loading` | Suspends until cancelled, keeping the spinner visible. |
| Success / `.success` | Decodes the saved, fixed November 2026 JSON fixture. |
| Offline / `.offline` | Offline message with Retry. |
| Rate Limited (429) / `.rateLimited` | Allowance message with Retry. |
| Invalid Response / `.invalidResponse` | Unreadable-response message with Retry. |
| Retry Success / `.retrySuccess` | First request fails offline; pressing Retry loads the fixture. |

`Previews/MockWeatherService.swift` is a Debug-only actor. Its mutable request counter is actor-isolated, without unsafe concurrency annotations. The existing `WeatherTests/Fixtures/weather.json` is shared as a resource of both targets; no fixture copy or new API request is needed. Previews inject a fixed clock matching the fixture, keeping the hourly selection and last-updated time deterministic. Creating a new mock resets retry behavior. Reopening/restarting a preview resets its model. Persistent loading uses cancellable asynchronous sleep, not a blocked thread.

For a simulator demo, temporarily change **only the service argument** in `App/WeatherApp.swift`:

```swift
WeatherView(model: WeatherViewModel(
    service: MockWeatherService(.success), // or .loading, .offline, .rateLimited,
                                          // .invalidResponse, .retrySuccess
    location: "London,UK",
    now: { MockWeatherService.sampleDate } // Keeps the fixture’s hourly section deterministic.
))
```

For idle, use:

```swift
WeatherView(
    model: WeatherViewModel(service: MockWeatherService(.idle), location: "London,UK"),
    automaticallyLoads: false
)
```

Stop and Run again after each edit. Restore `service: VisualCrossingWeatherService()` and omit the mock `now` closure and `automaticallyLoads` to return to normal live loading. These edits are examples, not production configuration; the checked-in app still injects the live service. No launch arguments or debug menu are required.

## Interview notes: loading, caching, and state

- **Live versus fixture:** `WeatherApp` injects `VisualCrossingWeatherService`; `fetchForecast(for:)` calls the Visual Crossing Timeline endpoint. Only the injected mock and unit tests read JSON from the bundle. The app keeps its current forecast in view-model state, with no custom memory/disk cache or offline fallback.
- **HTTP caching and freshness:** the live service uses `URLSession.shared`, with an explicit `reloadIgnoringLocalCacheData` request policy. Initial load, pull to refresh, and Retry submit a network request instead of reading the local HTTP cache. Unit selection makes no request. There is no timer or automatic polling. See [Apple's caching documentation](https://developer.apple.com/documentation/foundation/accessing-cached-data).
- **Protocol and concurrency:** `WeatherService` specifies one async throwing method. The live struct, mock actor, or test stub can be passed explicitly into the view model. `Sendable` requires conforming services/results to be safe across concurrency boundaries; it does not start a thread or make arbitrary mutation safe. The actor protects the mock's counter; immutable forecast values are Sendable.
- **Observation:** `@Observable` tracks reads of `state`. `WeatherView` keeps the model reference in `@State`; a change to a state read by its body causes SwiftUI to update the relevant UI. `@MainActor` serializes model access and UI state changes on the main actor. Awaiting the service suspends work rather than blocking the UI.
- **Lifecycle and errors:** `.task` calls `loadIfNeeded()` on appearance and is cancelled when SwiftUI removes the view. The model only starts automatically from idle and ignores overlapping loads. Successful data stays loaded on reappearance. Cancellation restores the prior state without an error; a cancelled refresh keeps the loaded forecast and timestamp. Offline, 429, malformed data, and other failures become user-facing errors. The Retry button creates a Task calling `load()`; the button's Task is separate from the lifecycle `.task`.
- **Dates:** `WeatherPresentation.weekday` uses epoch timestamps and `TimeZone(identifier: forecast.timezone)` with `DateFormatter`. `forecastPeriod` compares dates with a Gregorian Calendar set to that same timezone, not the device timezone or a fixed UTC offset. DST changes are handled by Foundation's timezone rules. The screen does not run a midnight timer; pull to refresh for a new forecast day. Fixtures retain their historical dates deliberately.
- **Icons:** `WeatherPresentation.symbol(for:)` maps clear-day/night → sun/moon, partly-cloudy-day/night → cloud.sun/cloud.moon, cloudy → cloud, rain → cloud.rain, snow → cloud.snow, fog → cloud.fog, and wind → wind. The configured symbols use `.fill` where appropriate. Unknown/nil icons use `questionmark.circle`; condition text remains visible. Nullable measurements display `—`.

## Time and AI assistance

Initial implementation and verification took approximately **15 minutes of AI-assisted elapsed work**, following an earlier inspection/planning session. The test-host cleanup and interview-preview preparation were separate follow-ups. This optional-feature pass added approximately **10–15 minutes of AI-assisted work**, including the hourly fixture, focused tests, builds, simulator run, and documentation. These are phase estimates, not an estimate of unaided development time. The work stayed within the assignment's four-to-six-hour maximum.

OpenAI Codex assisted with inspecting the brief and starter, proposing the architecture, implementing the app and Xcode test configuration, writing tests and this README, and running builds/tests. The implementation and architectural tradeoffs should be reviewed and understood before submission and the live interview.

## Optional features

- **Temperature:** the segmented °C/°F control defaults to Celsius and changes `WeatherViewModel.temperatureUnit`. `TemperatureUnit` converts Celsius with `F = C × 9/5 + 32`; the single `WeatherPresentation.temperature` helper formats current, feels-like, daily, and hourly values. Stored/API values remain metric, and wind always reads km/h. The selection lasts for the screen's lifetime and resets on a new app launch.
- **Hourly:** the same request includes `days,current,hours`. `HourlyForecast` decodes only epoch, temperature, conditions, and icon. `WeatherForecast.remainingHoursToday(at:)` first selects the location's local calendar day, then includes the current hour and later hours from that day, sorted by epoch. This also handles repeated/missing DST hours. Missing/null/empty hours show an unavailable message. All items reuse the shared temperature and SF Symbol helpers.
- **Refresh:** the scroll view uses native [`.refreshable`](https://developer.apple.com/documentation/swiftui/view/refreshable(action:)), calling the existing `load()` method. `isLoading` prevents overlapping requests. Existing data remains visible, and a refresh failure adds an inline error and Retry. `lastUpdated` changes only after successful completion and displays HH:mm in the forecast timezone. One simple injected `now` closure makes timestamp tests and previews deterministic; production uses `Date.init`.

## With more time, in priority order

1. Verify on an iOS 17 device/runtime, audit VoiceOver and larger text sizes, and add UI tests for the toggle, pull to refresh, and failure → Retry → success.
2. If required, persist the last successful forecast across launches with an explicit age/stale label. Currently retention only lasts within the screen's lifetime.

## For an App Store release

Add release assets and signing, broader device/accessibility/localization testing, and a privacy review covering location queries sent to the provider. Reassess the provider's attribution terms, shared-IP allowance, reliability, and production usage agreement. Add an appropriate freshness/cache policy and privacy-conscious diagnostics. Any future paid API credentials would require a suitable backend rather than shipping a secret in the app. The assignment PDF and local secrets are excluded from Git.
