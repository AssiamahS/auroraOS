# Aurora

NYC subway navigator for iPhone + Apple Watch.

- Pick a line, boarding station, and destination on the map (real MTA station data, all 24 routes, 496 stations in track order).
- Start the trip: a **Live Activity in the Dynamic Island** shows the line bullet, next stop, and stops remaining, with a progress bar in the expanded view.
- The **Apple Watch app** mirrors the countdown with a giant stops-remaining number and **vibrates your wrist** when you're one stop away ("GET OFF"), then taps repeatedly on arrival.
- GPS tracks progress station-by-station (450 m proximity, forward-only). Demo mode simulates a ride every 6 s for testing indoors.

## Structure

- `Aurora/` — iOS app (SwiftUI + MapKit + CoreLocation + ActivityKit)
- `AuroraWidgets/` — widget extension hosting the Live Activity / Dynamic Island UI
- `AuroraWatch/` — watchOS app (WatchConnectivity + WKInterfaceDevice haptics)
- `Shared/` — models shared across targets (`TripModels`, `TripActivityAttributes`, `RouteStyle`)
- `data/mta_stations.csv` — source dataset (data.ny.gov MTA Subway Stations); regenerate `Aurora/Resources/Stations.json` from it

## Build

XcodeGen project (`project.yml` is the source of truth):

```sh
xcodegen generate
xcodebuild -project Aurora.xcodeproj -scheme Aurora -destination 'generic/platform=iOS Simulator' build
```

CI builds the simulator target on every push and uploads signed builds to TestFlight from `main`.
