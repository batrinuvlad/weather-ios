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

The forecast shows **today plus the next six days**: the first seven entries returned by the forecast endpoint. Weekdays use epoch timestamps and the response's timezone, including daylight-saving rules. An unknown timezone falls back to UTC. Missing measurements display `—`, missing condition text displays “Conditions unavailable”, and unknown icons use a fallback SF Symbol. Temperatures are rounded for display; all requests use metric units (°C, km/h).

The app loads once when the screen first appears and retries only on user action. It does not poll. It requests `include=days,current&unitGroup=metric`, without a key. Gzip support is explicit because the keyless endpoint requires it; URLSession decompresses the response. The exact required attribution links to https://www.visualcrossing.com/.

## Verification and API usage

- Simulator build succeeded. **20 unit tests passed, 0 failures**, on iPhone 17 / iOS 27.2.
- Tests cover genuine-response decoding, seven-day selection, nulls/unknown icons, timezone formatting, request parameters, HTTP 400/429/500, malformed/incomplete responses, offline/timeout errors, cancellation, and view-model loading/success/error/retry transitions.
- Tests make **no real API requests**. Service tests intercept requests with URLProtocol; view-model tests use a controlled stub. The shared scheme sets `WEATHER_UNIT_TESTS=1`, which suppresses the live screen in the hosted unit-test app.
- `WeatherTests/Fixtures/weather.json` is the unmodified successful keyless response saved on **14 November 2026**. The first curl attempt returned HTTP 400 requiring gzip; the gzip retry succeeded. One further app launch verified real URLSession loading and the rendered screen. Other verification uses the fixture.
- iOS 17 is the deployment target, but runtime verification used the installed iOS 27.2 simulator. No physical-device or iOS 17 runtime test was performed. There are no automated UI tests.

## Time and AI assistance

Implementation and verification took approximately **15 minutes of AI-assisted elapsed work**, following an earlier inspection/planning session. This is not an estimate of unaided development time. The work stayed within the assignment's four-to-six-hour maximum.

OpenAI Codex assisted with inspecting the brief and starter, proposing the architecture, implementing the app and Xcode test configuration, writing tests and this README, and running builds/tests. The implementation and architectural tradeoffs should be reviewed and understood before submission and the live interview.

## With more time, in priority order

1. Verify on an iOS 17 device/runtime, audit VoiceOver and larger text sizes, and add a small UI test for failure → Retry → success.
2. Add pull to refresh and a last-updated time, then preserve the last successful forecast offline with an explicit stale-data label.
3. Add a Celsius/Fahrenheit toggle, followed by hourly conditions if useful. Location remains fixed unless the requirements change.

## For an App Store release

Add release assets and signing, broader device/accessibility/localization testing, and a privacy review covering location queries sent to the provider. Reassess the provider's attribution terms, shared-IP allowance, reliability, and production usage agreement. Add an appropriate freshness/cache policy and privacy-conscious diagnostics. Any future paid API credentials would require a suitable backend rather than shipping a secret in the app. The assignment PDF and local secrets are excluded from Git.
