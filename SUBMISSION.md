# Aurora — App Store submission sheet

Everything below is paste-ready. Nothing here is a guess: each answer is derived
from the actual source in this repo, and the derivation is stated next to it.

- **Build in flight: version `1.0.12`, build number `7`.** Commit `a45633a`, CI run
  30588506772, job "Sign & upload to TestFlight: **success**" — verified 2026-07-30.
  (The commit *message* says 1.0.11 because that was the manual bump; this repo's
  pre-push auto-version hook advanced it one more to **1.0.12** inside the same commit,
  and CI stamps `CURRENT_PROJECT_VERSION` from the run number, which was 7. Select
  **1.0.12 (7)** in App Store Connect.)
- Bundle ID: `com.assiamah.aurora` · Team `QGMAWHX827`
- Watch app: `com.assiamah.aurora.watchkitapp` · Widget: `com.assiamah.aurora.widgets`

> **The only real gate:** App Store Connect → **Business → Agreements, Tax, and Banking**
> → accept the **Paid Applications** agreement. Until that is "Active", the app cannot
> ship with a paywall and no price can be attached. ~2 minutes. Do it first.

---

## 1. URLs (live, verified HTTP 200)

| Field | Value |
|---|---|
| Privacy Policy URL | `https://aurora-app-69q.pages.dev/privacy` |
| Support URL | `https://aurora-app-69q.pages.dev/support` |
| Marketing URL (optional) | `https://aurora-app-69q.pages.dev/` |

Deployed to Cloudflare Pages project `aurora-app` on 2026-07-30. Source lives in
`/Users/djsly/money-hunt/4-get-aurora-out-of-testflight-and-onto-th/site/`.
Redeploy with: `wrangler pages deploy site --project-name aurora-app --branch main`.

Note: Cloudflare Pages strips `.html`, so use the extensionless URLs above.
`/privacy.html` 308-redirects to `/privacy` — Apple's validator prefers the final URL.

---

## 2. App Privacy — exact answers

**Verified, not assumed.** `grep -rn -E 'Analytics|Firebase|Amplitude|Sentry|AppsFlyer|Mixpanel|Adjust|Branch' --include='*.swift' .`
returned **no matches** (exit 1). `project.yml` declares **no `packages:` block** — there are
zero Swift Package / CocoaPods dependencies. The complete set of imports across every
`.swift` file in the repo is Apple-only:

```
ActivityKit, CoreLocation, CoreMotion, Foundation, MapKit, StoreKit,
SwiftUI, UIKit, UserNotifications, WatchConnectivity, WatchKit, WidgetKit
```

**So: no third-party SDK exists in Aurora. There is nothing to disclose on anyone else's behalf.**

### Answer these exactly

**"Do you or your third-party partners collect data from this app?" → Yes**

Then tick **only** these:

| Screen | Answer |
|---|---|
| Data types | **Location → Precise Location** and **Location → Coarse Location**. Nothing else. |
| Precise Location — how used | **App Functionality** only. (Not Analytics, not Product Personalization, not Advertising.) |
| Precise Location — linked to identity? | **No** |
| Precise Location — used for tracking? | **No** |
| Coarse Location — how used | **App Functionality** only |
| Coarse Location — linked to identity? | **No** |
| Coarse Location — used for tracking? | **No** |
| Contact Info / Identifiers / Usage Data / Diagnostics / Purchases / Health / Contacts / Search History / Browsing History / Sensitive Info / Financial Info / User Content / Other Data | **Not collected** — leave every one unticked |

**Why Location and only Location:** `project.yml` declares
`NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`,
and `UIBackgroundModes: [location]`, and `Aurora/Sources/` uses `CoreLocation` for
station proximity and geofencing. Purpose is App Functionality (counting stops and
firing the get-off alert), it is never tied to an account (there is no account), and
it is never used for tracking (there is no ad network and no data broker).

**Why "Purchases" is not ticked:** StoreKit 2 purchases are processed by Apple.
Aurora never receives or stores payment data; entitlement is read from Apple's signed
transaction record on device (`Aurora/Sources/Store.swift`).

**Why "Diagnostics" / "Usage Data" are not ticked:** no crash reporter, no analytics.

<details>
<summary>Footnote: a stricter reading would let you answer "Data Not Collected" entirely</summary>

Apple's rule is that data processed only on device and never sent off device is *not*
"collected". Aurora makes exactly two outbound requests, both verified by grepping every
`URLSession` / `URLRequest` in the repo (`Aurora/Sources/GTFSRealtime.swift`):

- `GET https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs`
- `GET https://www.panynj.gov/bin/portauthority/ridepath.json`

Both are plain GETs with no body and no query parameters carrying location. Location
never leaves the device. So "Data Not Collected" would be technically defensible.

**Recommendation: disclose Location anyway, as laid out above.** Over-disclosing has
never caused a rejection; under-disclosing while the app shows two location permission
prompts and a background-location indicator is exactly the mismatch reviewers flag.
The cost is one "Data Not Linked to You: Location" line on the product page.
</details>

---

## 3. Export compliance

**Uses encryption? → No.**

Verified: `project.yml` sets `ITSAppUsesNonExemptEncryption: false` in the Aurora target's
Info.plist properties, so the answer is already baked into the build and App Store Connect
will not ask again. Aurora uses only HTTPS to public transit feeds — exempt.

---

## 4. Age rating

Answer **No / None** to every question in the questionnaire. Result: **4+**.

| Question group | Answer |
|---|---|
| Violence (cartoon, realistic, prolonged) | None |
| Sexual content, nudity | None |
| Profanity, crude humor | None |
| Alcohol, tobacco, drug use or references | None |
| Simulated gambling / contests | None |
| Horror / fear themes | None |
| Mature / suggestive themes | None |
| Medical / treatment information | None |
| Unrestricted web access | **No** |
| Does the app contain user-generated content? | **No** |
| Does the app include in-app purchases? | **Yes** (this does not change the 4+ rating) |
| Age Assurance / age verification in app | **No** |

Primary category: **Navigation**. Secondary category: **Travel**.

---

## 5. Listing copy — paste these verbatim

### App Name (30 max) — 24 chars
```
Aurora: NYC Subway Stops
```

### Subtitle (30 max) — 26 chars
```
Never miss your stop again
```

### Keywords (100 max, no spaces after commas) — 95 chars
```
mta,path,train,arrivals,transit,metro,commute,stop,alert,tracker,realtime,nyc,watch,subway,ride
```
Do not add spaces. Every space costs a character and Apple counts them.

### Promotional Text (170 max) — 152 chars
```
Aurora counts your stops in the Dynamic Island and taps your wrist when it's time to get off. Live MTA and PATH arrivals, no account, works underground.
```
This field can be edited any time without a new build — use it for service alerts.

### Description
```
Aurora tells you when to get off.

Pick your line, your boarding station, and where you're going. Aurora counts the stops down for you — on the Lock Screen, in the Dynamic Island, and on your wrist — so you can read, doze, or stare at nothing without missing your station.

NEVER MISS YOUR STOP
A Live Activity in the Dynamic Island shows the line bullet, the next stop, and how many stops remain, with a progress bar in the expanded view. Your Apple Watch buzzes one stop early with a big "GET OFF", then taps repeatedly when you arrive. Time-sensitive notifications ring through the Lock Screen.

WORKS UNDERGROUND
Most transit apps go blind in a tunnel. Aurora doesn't. Geofence region monitoring wakes the app at your destination even if iOS suspended it, and an accelerometer-based stop detector (CoreMotion) keeps counting stations where GPS dies. GPS advances you station-by-station, forward only, at 450 m proximity.

LIVE ARRIVALS, NO ACCOUNT
Real arrival times straight from the MTA's GTFS-Realtime feeds, decoded on your device. No sign-in, no API key, no server, no waiting. PATH arrivals come from the Port Authority's own live feed.

GET ON THE RIGHT TRAIN
Before you board, Aurora shows the direction, the terminus, live next-train times, and the first stop you should see after boarding — "if the platform sign disagrees, cross over." The uptown/downtown mistake, solved.

THE WHOLE SYSTEM
All 24 subway routes and 496 stations in true track order, plus PATH. Station data refreshes itself weekly from the official MTA dataset, so new stations and reroutes show up without an app update.

APPLE WATCH APP
A giant stops-remaining number, the line bullet, and haptics. Glance at your wrist instead of unlocking your phone in a crowded car.

PRIVATE BY DESIGN
No account. No analytics. No advertising. No third-party SDKs of any kind. Your location is used on your device to count stops and is never uploaded — Aurora doesn't even have a server.

FREE AND PRO
The free plan tracks 3 trips a week, and demo mode is always free. Aurora Pro removes the limit: $1.99/month, $12.99/year, or $29.99 once for lifetime.

Aurora is an independent app and is not affiliated with, endorsed by, or sponsored by the Metropolitan Transportation Authority or the Port Authority of New York and New Jersey.
```

### What's New (version 1.0.12)
```
First public release.

- Live Activity stop countdown in the Dynamic Island and on the Lock Screen
- Apple Watch app with a GET OFF wrist tap one stop before your station
- Live MTA and PATH arrival times, decoded on device, no account needed
- Keeps counting underground with geofences and motion-based stop detection
- Right-platform check before you board: direction, terminus, and first stop
- All 24 routes, 496 stations, refreshed weekly from the official MTA dataset
```

### Copyright
```
2026 Sylvester Assiamah
```

### Review notes (App Review Information → Notes)
```
No account or login is required — every feature is reachable on launch.

To evaluate trip tracking indoors without riding the subway, open the app and
enable Demo Mode on the planner screen. It simulates a ride, advancing one
station every 6 seconds, and drives the Live Activity and the Watch haptics
exactly as a real trip does.

Live arrival times come from the MTA's public keyless GTFS-Realtime feeds and
the Port Authority's public ridepath.json. If those feeds are momentarily down,
the app shows no arrival times rather than fabricated ones; this does not
affect trip tracking.

Location is requested for stop counting and the get-off alert. Background
location ("Always") is what allows the alert to fire with the phone locked or
in a tunnel. No location data leaves the device.
```

---

## 6. Pricing

| Product ID (from `Aurora/Sources/Store.swift`) | Type | Price |
|---|---|---|
| `aurora.pro.monthly` | Auto-renewable subscription | **$1.99 / month** |
| `aurora.pro.yearly` | Auto-renewable subscription | **$12.99 / year** |
| `aurora.pro.lifetime` | Non-consumable | **$29.99 one time** |

App price itself: **Free** (paywall is in-app).

> ⚠️ **Order matters on the API path.** Per this repo's `NOTES.md`, `POST /v1/subscriptionPrices`
> returns `409 ENTITY_ERROR.RELATIONSHIP.INVALID` until the subscription has a
> `subscriptionAvailability` first. Correct sequence:
> 1. `POST /v1/subscriptionAvailabilities` (all 175 territories, `availableInNewTerritories: true`)
> 2. `POST /v1/subscriptionPrices` (relationships: subscription + subscriptionPricePoint **only**)
>
> The lifetime non-consumable is standalone: `POST /v1/inAppPurchasePriceSchedules`
> with the `${placeholder}` included-object pattern.
>
> A script that does all of this in the right order is ready to run:
> ```sh
> cd /Users/djsly/money-hunt/4-get-aurora-out-of-testflight-and-onto-th/scripts
> export ASC_KEY_ID=KB93R49B9J
> export ASC_ISSUER_ID=<your issuer uuid>
> python3 asc_pricing.py            # dry run — reads only, prints the plan
> python3 asc_pricing.py --apply    # writes availabilities then prices
> ```
> Doing it by hand in the web UI works too and is about 3 minutes; the UI hides the
> ordering problem. Use the script if the UI 409s on you.

Also confirm each subscription and the lifetime IAP has: a localized display name,
a description, a review screenshot, and **Cleared for Sale**. Subscriptions must be
submitted *with* the app version the first time, or the paywall shows empty products.

---

## 7. Screenshots

Generated by `.github/workflows/screenshots.yml` and dimension-checked with `sips`.
Files: `/Users/djsly/money-hunt/4-get-aurora-out-of-testflight-and-onto-th/screenshots/`

| Set | Size | Files |
|---|---|---|
| iPhone 6.9" (required) | 1320 × 2868 | `iphone-6.9/1-planner.png`, `2-trip.png`, `3-onboarding.png` |
| Apple Watch (required — you ship a watchOS target) | 410 × 502 | `watch/4-watch-trip-ultra-410x502.png` |
| Apple Watch alternate slot | 416 × 496 | `watch/4-watch-trip-46mm-416x496.png` |

The CI watch simulator captures at 422 × 514 (Apple Watch Ultra 3), which App Store
Connect does not accept; the two files above are `sips` resamples to accepted sizes.
Details in `screenshots/README.md`.

Run the gate before uploading — it asserts every dimension, every character limit,
and that both URLs are live, and exits non-zero if anything is off:

```sh
bash /Users/djsly/money-hunt/4-get-aurora-out-of-testflight-and-onto-th/scripts/verify.sh
```

Apple derives the 6.5" and 6.1" sets from the 6.9" upload automatically — you only
need to upload the 6.9" set and the Watch set.

---

## 8. Order of operations in App Store Connect

1. **Business → Agreements, Tax, and Banking → Paid Applications → accept.** Nothing works until this reads Active.
2. App Information: name, subtitle, category Navigation / Travel, **Privacy Policy URL** (§1).
3. App Privacy → answer per §2 → Publish.
4. Pricing and Availability → app **Free**, all territories.
5. In-App Purchases / Subscriptions → confirm the three products and attach prices per §6.
6. Prepare for Submission (1.0.12): paste §5 copy, upload screenshots (§7), set **Support URL** (§1).
7. Build → select **1.0.12 (7)**. If it is still "Processing", wait — it usually clears in 10–30 minutes.
8. Export compliance → **No** (§3). Age rating → 4+ (§4). Review notes → §5.
9. Submit for Review.
