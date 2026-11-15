# weather-ios

A single-screen SwiftUI weather app for iPhone and iPad, using the keyless Visual Crossing Timeline API. The initial location is `London,UK`; the screen displays the API's `resolvedAddress`.

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
- `Screens/Weather/` contains the SwiftUI screen, an `@Observable`, `@MainActor` view model, presentation helpers, and one extracted forecast row. The view model exposes idle/loading/loaded/failed states and prevents overlapping requests. Cancellation returns to idle; ordinary errors offer Retry.
- `WeatherTests/` contains the genuine response fixture, decoding/presentation tests, URLProtocol service tests, and deterministic view-model tests.

This small MVVM structure keeps state out of the view and makes networking replaceable in tests. Models decode directly; there is no repository, use-case layer, generic API client, or separate mapping model. Swift 5 language mode uses complete concurrency checking, with explicit main-actor isolation for screen state.

The forecast shows **today plus the next six days**: the first seven entries returned by the forecast endpoint. Weekdays use epoch timestamps and the response's timezone, including daylight-saving rules. The caption only says “Today” if the first day matches the current calendar day in the API timezone; historical/stale data shows its start date. An unknown timezone falls back to UTC. Missing measurements display `—`, missing condition text displays “Conditions unavailable”, and unknown icons use a fallback SF Symbol. Temperatures are rounded for display; all requests use metric units (°C, km/h).

The app loads once when the screen first appears and retries only on user action. It does not poll. It requests `include=days,current&unitGroup=metric`, without a key. Gzip support is explicit because the keyless endpoint requires it; URLSession decompresses the response. The exact required attribution links to https://www.visualcrossing.com/.

## Verification and API usage

- Debug app compilation and the Release simulator build succeeded. **26 unit tests passed, 0 failures**, on iPhone 17 / iOS 27.2. All seven preview declarations compiled; interactive Canvas rendering was not manually exercised. This interview-preparation validation made no live API requests, and the app still injects the real Visual Crossing service.
- Tests cover genuine-response decoding, seven-day selection, nulls/unknown icons, timezone formatting across DST changes, the timezone-aware Today caption, mock scenarios, request parameters, HTTP 400/429/500, malformed/incomplete responses, offline/timeout errors, cancellation, and view-model loading/success/error/retry transitions.
- Tests make **no real API requests**. Service tests intercept requests with URLProtocol; view-model tests use a controlled stub. The test target has no host application: Xcode runs it in its test runner, without launching `WeatherApp`. The tested production files and debug mock have membership in both targets and compile directly into the test bundle; there are no source copies or extra framework. Consequently, tests do not need `@testable import Weather`. When adding a new production dependency to these tests, include its source in the test target too. App startup contains no test-specific logic.
- `WeatherTests/Fixtures/weather.json` is the unmodified successful keyless response saved on **14 November 2026**. The first curl attempt returned HTTP 400 requiring gzip; the gzip retry succeeded. A normal app launch verified real URLSession loading and the rendered screen after initial implementation, and another after the non-hosted test configuration change. Other verification uses the fixture.
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

`Previews/MockWeatherService.swift` is a Debug-only actor. Its mutable request counter is actor-isolated, without unsafe concurrency annotations. The existing `WeatherTests/Fixtures/weather.json` is shared as a resource of both targets; no fixture copy or new API request is needed. Creating a new mock resets retry behavior. Reopening/restarting a preview resets its model. Persistent loading uses cancellable asynchronous sleep, not a blocked thread.

For a simulator demo, temporarily change **only the service argument** in `App/WeatherApp.swift`:

```swift
WeatherView(model: WeatherViewModel(
    service: MockWeatherService(.success), // or .loading, .offline, .rateLimited,
                                          // .invalidResponse, .retrySuccess
    location: "London,UK"
))
```

For idle, use:

```swift
WeatherView(
    model: WeatherViewModel(service: MockWeatherService(.idle), location: "London,UK"),
    automaticallyLoads: false
)
```

Stop and Run again after each edit. Restore `service: VisualCrossingWeatherService()` and omit `automaticallyLoads` to return to normal live loading. These edits are examples, not production configuration; the checked-in app still injects the live service. No launch arguments or debug menu are required.

## Interview notes: loading, caching, and state

- **Live versus fixture:** `WeatherApp` injects `VisualCrossingWeatherService`; `fetchForecast(for:)` calls the Visual Crossing Timeline endpoint. Only the injected mock and unit tests read JSON from the bundle. The app keeps its current forecast in view-model state, with no custom memory/disk cache or offline fallback.
- **HTTP caching:** the live service uses `URLSession.shared` and the default `useProtocolCachePolicy`. Apple's shared `URLCache` may supply or revalidate a response according to HTTP cache headers. Relaunching creates a new model and submits a URL request; it does not guarantee a new server response. See [Apple's shared session documentation](https://developer.apple.com/documentation/foundation/urlsession/shared).
- **Fresh request:** stop and Run to trigger initial loading again; Retry calls `WeatherViewModel.load()` after errors. There is no refresh action on the success screen. To deliberately bypass the local HTTP cache during a live demo, temporarily replace `var request = URLRequest(url: url)` in the service with `var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)`, then stop and Run. Restore the original line afterward. This makes a real network request and can consume the free allowance. Do not repeatedly run the live app to explore states; use the mock.
- **Protocol and concurrency:** `WeatherService` specifies one async throwing method. The live struct, mock actor, or test stub can be passed explicitly into the view model. `Sendable` requires conforming services/results to be safe across concurrency boundaries; it does not start a thread or make arbitrary mutation safe. The actor protects the mock's counter; immutable forecast values are Sendable.
- **Observation:** `@Observable` tracks reads of `state`. `WeatherView` keeps the model reference in `@State`; a change to a state read by its body causes SwiftUI to update the relevant UI. `@MainActor` serializes model access and UI state changes on the main actor. Awaiting the service suspends work rather than blocking the UI.
- **Lifecycle and errors:** `.task` calls `loadIfNeeded()` on appearance and is cancelled when SwiftUI removes the view. The model only starts automatically from idle and ignores overlapping loads. Successful data stays loaded on reappearance. Cancellation returns to idle without an error. Offline, 429, malformed data, and other failures become user-facing errors. The Retry button creates a Task calling `load()`; the button's Task is separate from the lifecycle `.task`.
- **Dates:** `WeatherPresentation.weekday` uses epoch timestamps and `TimeZone(identifier: forecast.timezone)` with `DateFormatter`. `forecastPeriod` compares dates with a Gregorian Calendar set to that same timezone, not the device timezone or a fixed UTC offset. DST changes are handled by Foundation's timezone rules. The screen does not run a midnight timer; relaunch for a new forecast day. Fixtures retain their historical dates deliberately.
- **Icons:** `WeatherPresentation.symbol(for:)` maps clear-day/night → sun/moon, partly-cloudy-day/night → cloud.sun/cloud.moon, cloudy → cloud, rain → cloud.rain, snow → cloud.snow, fog → cloud.fog, and wind → wind. The configured symbols use `.fill` where appropriate. Unknown/nil icons use `questionmark.circle`; condition text remains visible. Nullable measurements display `—`.

## Time and AI assistance

Initial implementation and verification took approximately **15 minutes of AI-assisted elapsed work**, following an earlier inspection/planning session. This is not an estimate of unaided development time. The work stayed within the assignment's four-to-six-hour maximum.

OpenAI Codex assisted with inspecting the brief and starter, proposing the architecture, implementing the app and Xcode test configuration, writing tests and this README, and running builds/tests. The implementation and architectural tradeoffs should be reviewed and understood before submission and the live interview.

## With more time, in priority order

1. Verify on an iOS 17 device/runtime, audit VoiceOver and larger text sizes, and add a small UI test for failure → Retry → success.
2. Add pull to refresh and a last-updated time, then preserve the last successful forecast offline with an explicit stale-data label.
3. Add a Celsius/Fahrenheit toggle, followed by hourly conditions if useful. Location remains fixed unless the requirements change.

## For an App Store release

Add release assets and signing, broader device/accessibility/localization testing, and a privacy review covering location queries sent to the provider. Reassess the provider's attribution terms, shared-IP allowance, reliability, and production usage agreement. Add an appropriate freshness/cache policy and privacy-conscious diagnostics. Any future paid API credentials would require a suitable backend rather than shipping a secret in the app. The assignment PDF and local secrets are excluded from Git.
