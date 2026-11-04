# Architecture

Developer notes for Gig Log: a SwiftUI + SwiftData iPhone app (iOS 17+) with a WidgetKit extension for Live Activities.

## Targets

| Target | Folder(s) | Purpose |
|---|---|---|
| **GigLog** (app) | `GigLog/`, `Shared/` | The app |
| **GigLogWidgets** (app extension) | `GigLogWidgets/`, `Shared/` | Lock Screen / Dynamic Island Live Activity |
| **GigLogTests** (unit tests) | `GigLogTests/` | Swift Testing suites, hosted in the app |

Folders are Xcode 16 *synchronized groups*: any file added to a folder is automatically part of that folder's target(s). `Shared/` belongs to both the app and the widget.

- **Bundle ID:** set once in the project-level build setting `APP_BUNDLE_IDENTIFIER`. The app uses it as is; the widget uses `.widgets` and the tests use `.tests`.
- **Version:** `MARKETING_VERSION` (e.g. 1.0.0) and `CURRENT_PROJECT_VERSION` (build). Change them with `scripts/bump-version.sh`. They're shown in **Settings → About**.
- **Info.plist:** most keys come from build settings (`INFOPLIST_KEY_*`). The root `Info.plist` adds `UIBackgroundModes = location` and `NSSupportsLiveActivities`; `GigLogWidgets-Info.plist` declares the WidgetKit extension point.
- **Privacy manifest:** `GigLog/PrivacyInfo.xcprivacy`.
- **Scheme:** `GigLog.xcodeproj/xcshareddata/xcschemes/GigLog.xcscheme` (shared, so ⌘U works on any Mac).

## Source files

| File | Responsibility |
|---|---|
| `GigLogApp.swift` | App entry; `AppData` (store loading, `save`), `Log`, `ExportFiles`, `StoreErrorView` |
| `Models.swift` | SwiftData models, `GigLogSchemaV1` / migration plan, `SettingsKey`, defaults, rate lookup, number parsing |
| `ContentView.swift` | Tab bar; first-launch seeding and one-time maintenance |
| `ShiftControl.swift` | `ShiftControl` (start / resume / errand / finish / discard), `LiveActivityController`, Shortcuts intents |
| `LocationTracker.swift` | `DistanceFilter` (pure, tested) and `LocationTracker` (live updates, background session, route buffer) |
| `RouteMapView.swift` | `RoutePoint` binary format, simplification, segments, MapKit views |
| `ShiftListView.swift` | Shifts tab: period stats, weekly goal, start card, active shift, history |
| `ShiftEditorView.swift` | Add / edit / end-shift form |
| `ExpensesView.swift` | Expenses tab and editor |
| `SummaryView.swift` | Taxes tab, payouts editor, `Totals` |
| `InsightsView.swift` | Swift Charts "best times to drive", `TimeBlock` |
| `SettingsView.swift` | Settings, backup / restore flow, `BackupPasswordView`, `AppInfo` |
| `PhotoField.swift` | Camera capture, downsampled thumbnails, JPEG compression |
| `CSVExport.swift` | CSV text with formula-injection protection |
| `ReportPDF.swift` | Year-end PDF built with `UIGraphicsPDFRenderer` |
| `Backup.swift` | `Backup` (snapshot, encode, restore) and `BackupCrypto` (encryption) |
| `LockGate.swift` | `AppLock`: app-switcher cover and Face ID lock in an overlay window |
| `Shared/ShiftActivity.swift` | `ShiftActivityAttributes`, `ToggleErrandIntent` (LiveActivityIntent) |
| `GigLogWidgets/GigLogWidgets.swift` | Widget bundle and Live Activity UI (incl. "not updating" state) |
| `GigLogWidgets/ShiftControlStub.swift` | No-op `ShiftControl` so the shared intent compiles in the extension |

## Data model (SwiftData)

```
Shift           platform, start, end?, odometerStart?, odometerEnd?,
                miles (business, deducted), commuteMiles (personal/commute, not deducted),
                earnings, tips, notes,
                gpsMiles? (business GPS; nil = GPS not used), personalGPSMiles, isPersonal,
                gpsInterrupted, routePointCount,
                odometerStartPhoto?, odometerEndPhoto?, routeData?   ← external storage
Expense         date, category, amount, note, receiptPhoto?          ← external storage
PlatformPayout  year, platform, amount        (1099 / annual total reported by a platform)
Platform        name, sortOrder
MileageRate     effectiveFrom, rate           (rate in effect from that date)
```

- **Versioning:** the models are registered as `GigLogSchemaV1` with `GigLogMigrationPlan`. Adding a property with a default value is a lightweight change. Renaming or retyping a property needs a `GigLogSchemaV2` and a `MigrationStage`.
- **Store errors:** if the store can't be opened, `AppData` logs the error, uses an empty in-memory store, and the app shows `StoreErrorView`. It never crashes on launch or overwrites the file.
- **Active shift:** a shift with `end == nil`. At most one exists.
- **Deductions:** `miles` is the source of truth; GPS and odometer readings only pre-fill it. Deduction = Σ round₂(`miles × rate(on: start)`), so the CSV and PDF rows add up to the total. The rate is the `MileageRate` with the latest `effectiveFrom ≤ date`; `shiftsWithoutRate` flags shifts with no rate.
- **Money:** stored as `Double`, rounded to cents when entered. SwiftData's `Decimal` support is limited (predicates, sorting), and values this size are exact to the cent after rounding.
- **Numbers:** `parseNumber` follows the user's region ("1,206.25" US, "1.206,25" DE) and ignores a currency symbol.
- **Settings:** stored in `UserDefaults` under the keys in `SettingsKey`. Never use string literals for them.
- **Saving:** `AppData.save(_:)` logs failures through `Log.data` instead of hiding them with `try?`.

## GPS tracking

- `LocationTracker` uses `CLLocationUpdate.liveUpdates(.automotiveNavigation)` with a `CLBackgroundActivitySession`. iOS can relaunch the app to continue a session it ended, and `GigLogApp.init` calls `ShiftControl.resumeIfNeeded()` at launch, before any screen appears. A user swiping the app away still stops it; the Live Activity then turns stale (below).
- Only *When In Use* authorization is requested, through a `CLLocationManager`.
- `DistanceFilter` decides what counts:
  - It skips fixes with accuracy worse than 50 m and out-of-order fixes.
  - Moves smaller than max(10 m, accuracy) are parked drift and are ignored. The previous point is kept, so slow movement still adds up.
  - Jumps faster than 60 m/s are rejected. After 3 in a row it re-anchors, so one bad point can't freeze tracking.
- Miles go to `gpsMiles`, or to `personalGPSMiles` while `isPersonal` is on.
- Every 20 accepted points, buffered route points are appended and the store is saved, so a crash loses at most a few points.
- On resume, if the last recorded point is more than 3 minutes old, the shift gets `gpsInterrupted = true`. The UI then asks for odometer readings.

### Route format

`routeData` is a flat binary array of 32-byte points: `latitude, longitude, unixTime, personalFlag`, each a little-endian `Double`.

- `routePointCount` mirrors the number of points, so lists never load the blob.
- `RoutePoint.last(in:)` reads only the final 32 bytes.
- Map previews draw `RoutePoint.simplified(maxPoints: 300)`; the full view draws up to 2,000. Simplification keeps the first and last points and every business/personal switch.

## Live Activity

- `LiveActivityController` starts the activity when a shift starts (iOS requires the app to be in the foreground). It updates at most every 15 s from location updates, or immediately on mode changes. It ends when the shift finishes or is discarded, and replaces a left-over activity from a different shift.
- Every update sets `staleDate = now + 5 min`. If updates stop (app swiped away), the widget shows "Not updating — open Gig Log" (`context.isStale`).
- The Lock Screen button uses `ToggleErrandIntent: LiveActivityIntent`. The system runs it **in the app process**, where `ShiftControl.toggleErrand()` flips `isPersonal`. The extension compiles a stub `ShiftControl` because it can't access the app's data.

## Shortcuts

- `StartShiftIntent` has `openAppWhenRun = true`, because location updates and Live Activities can only start while the app is in the foreground. The `platform` parameter is matched to a saved platform without regard to case.
- `GigLogShortcuts` (AppShortcutsProvider) exposes **Start Shift** and **Personal Errand** to Siri and Shortcuts.

## Security and privacy

- **App switcher / Face ID (`AppLock`):** whenever the scene isn't active, a cover window (`windowLevel = .alert + 1`) hides everything, including open sheets. With Face ID lock on, the cover stays until `LAContext` succeeds. While locked, the app's own windows are set to `accessibilityElementsHidden`, so VoiceOver can't read behind the lock. Turning the lock on requires a successful authentication.
- **Backups (`BackupCrypto`):** the file layout is `"GIGLOG-BACKUP2" | salt(16) | rounds(UInt32 BE) | AES.GCM combined`.
  - The key is PBKDF2-HMAC-SHA256 (600,000 rounds, via CommonCrypto) of the password.
  - AES-256-GCM authenticates the whole file, so a wrong password and tampering both fail.
  - Files asking for more than 10 million rounds are refused.
  - The plaintext is a binary property list (photos stay raw bytes, not base64).
  - Encoding and encryption run off the main thread.
  - Version 1 (plain JSON) backups can still be restored. Restore deletes and inserts in one transaction, and rolls back on failure.
- **Exports (`ExportFiles`):** CSV, PDF and backup files are written to `tmp/Exports` with complete file protection. The folder is emptied at every launch. CSV fields starting with `= + - @ tab CR` are prefixed with `'`.
- **Photos:** re-rendered on capture, which strips EXIF/GPS metadata. Lists decode 192 px thumbnails (ImageIO) instead of full images.

## Testing

- **Run:** ⌘U in Xcode, or `xcodebuild test -scheme GigLog -destination 'platform=iOS Simulator,name=iPhone 16'`.
- **Framework:** Swift Testing (`import Testing`, `@Test`, `#expect`).
- **Isolation:** tests use in-memory stores (`makeTestContext()`), never the app's real data.

| Suite | Covers |
|---|---|
| `CalculationTests` | IRS rate by date (incl. 2026 mid-year), missing rates, deduction rounding, totals, rounding helpers |
| `ParseNumberTests` | US and German number formats, currency symbols, invalid input |
| `DistanceFilterTests` | First fix, accuracy filter, real movement, parked drift, jumps and re-anchoring, out-of-order fixes |
| `RouteTests` | Binary round-trip, batching, truncated data, last point, segments, simplification |
| `CSVExportTests` | Quoting, formula injection, rows/totals/expenses |
| `BackupCryptoTests` | Encrypt/decrypt, wrong password, tampering, random salt/nonce, damaged files, round limits |
| `BackupRestoreTests` | Full backup → encrypt → decrypt → restore, legacy JSON, newer/invalid files |
| `ReportAndInsightsTests` | PDF validity, time-of-day blocks |

GPS, the camera, Face ID and Live Activities need a real device for manual testing. In the simulator, use **Features → Location → Freeway Drive** to simulate driving; the camera falls back to the photo library.

## Linting

`.swiftlint.yml` configures SwiftLint. Run `scripts/lint.sh` after `brew install swiftlint`. `.editorconfig` sets indentation and line endings for editors.
