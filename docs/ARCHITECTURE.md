# Architecture

Developer notes for Gig Log: a SwiftUI + SwiftData iPhone app (iOS 17+) with a WidgetKit extension for Live Activities.

## Targets

| Target | Folder(s) | Purpose |
|---|---|---|
| **GigLog** (app) | `GigLog/`, `Shared/` | The app |
| **GigLogWidgets** (app extension) | `GigLogWidgets/`, `Shared/` | Lock Screen / Dynamic Island Live Activity |

Folders are Xcode 16 *synchronized groups*: any file added to a folder is automatically part of that folder's target(s). `Shared/` belongs to both targets.

The bundle ID is set once in the project-level build setting `APP_BUNDLE_IDENTIFIER`. The app uses it as is; the widget uses `$(APP_BUNDLE_IDENTIFIER).widgets`.

Info.plist: most keys are generated from build settings (`INFOPLIST_KEY_*`). The `Info.plist` file at the root adds `UIBackgroundModes = location` and `NSSupportsLiveActivities`. `GigLogWidgets-Info.plist` declares the WidgetKit extension point.

## Source files

| File | Responsibility |
|---|---|
| `GigLogApp.swift` | App entry, `AppData` (shared `ModelContainer`, local only, `cloudKitDatabase: .none`) |
| `Models.swift` | SwiftData models, default platforms and IRS rates, mileage-rate lookup, formatting helpers |
| `ContentView.swift` | Tab bar; seeds defaults on first launch; resumes GPS and the Live Activity after relaunch |
| `ShiftControl.swift` | `ShiftControl` (start / errand toggle / finish), `LiveActivityController`, Shortcuts intents |
| `LocationTracker.swift` | CoreLocation wrapper: mileage counting, background updates, route recording |
| `RouteMapView.swift` | `RoutePoint` binary format, route segments, MapKit views |
| `ShiftListView.swift` | Shifts tab: period stats, weekly goal, start card, active shift, history |
| `ShiftEditorView.swift` | Add / edit / end-shift form |
| `ExpensesView.swift` | Expenses tab and editor |
| `SummaryView.swift` | Taxes tab, payouts editor, `Totals` |
| `InsightsView.swift` | Swift Charts "best times to drive" |
| `SettingsView.swift` | Settings, backup / restore UI |
| `PhotoField.swift` | Camera capture, thumbnail, JPEG compression |
| `CSVExport.swift` | CSV text and share-sheet file |
| `ReportPDF.swift` | Year-end PDF built with `UIGraphicsPDFRenderer` |
| `Backup.swift` | JSON backup / restore of all models |
| `LockGate.swift` | Face ID lock overlay |
| `Shared/ShiftActivity.swift` | `ShiftActivityAttributes`, `ToggleErrandIntent` (LiveActivityIntent) |
| `GigLogWidgets/GigLogWidgets.swift` | Widget bundle and Live Activity UI |
| `GigLogWidgets/ShiftControlStub.swift` | No-op `ShiftControl` so the shared intent compiles in the extension |

## Data model (SwiftData)

Every property has a default value or is optional, so new fields can be added without a migration.

```
Shift           platform, start, end?, odometerStart?, odometerEnd?,
                miles (business, deducted), commuteMiles (personal/commute, not deducted),
                earnings, tips, notes,
                gpsMiles? (business GPS; nil = GPS not used), personalGPSMiles, isPersonal,
                odometerStartPhoto?, odometerEndPhoto?, routeData?   ← external storage
Expense         date, category, amount, note, receiptPhoto?          ← external storage
PlatformPayout  year, platform, amount        (1099 / annual total reported by a platform)
Platform        name, sortOrder
MileageRate     effectiveFrom, rate           (rate in effect from that date)
```

- A shift with `end == nil` is the **active shift**. At most one exists.
- `miles` is the source of truth for deductions; GPS and odometer readings only pre-fill it in the editor.
- Mileage deduction = Σ `shift.miles × rate(on: shift.start)`. The rate is the `MileageRate` with the latest `effectiveFrom ≤ date`, which handles mid-year changes such as 2026.

Settings live in `UserDefaults` (`@AppStorage`): `useGPS`, `recordRoute`, `setAsidePercent`, `weeklyGoal`, `requireFaceID`, `didSeed`.

## GPS tracking (`LocationTracker`)

- `CLLocationManager` with `.automotiveNavigation`, best accuracy, 10 m distance filter, background updates, and a `CLBackgroundActivitySession`. Only *When In Use* authorization is needed.
- Filters:
  - Skips fixes with accuracy worse than 50 m.
  - Ignores movement smaller than max(10 m, accuracy), which is parked drift. The previous point is kept, so slow movement still adds up.
  - Rejects jumps faster than 60 m/s.
- Miles go to `gpsMiles`, or to `personalGPSMiles` while `isPersonal` is on.
- If the app is relaunched during a shift, `ContentView` restarts tracking.

### Route format

`routeData` is a flat binary array of 32-byte points: `latitude, longitude, unixTime, personalFlag`, each a little-endian `Double`. Points are buffered and appended every 20 points, and flushed on stop, to avoid rewriting the blob on every fix. `RouteSegment.split` turns points into business/personal runs for drawing.

## Live Activity

- `LiveActivityController` starts the activity when a shift starts (it must be in the foreground). It updates at most every 15 s from location updates, or immediately on mode changes, and ends it when the shift finishes.
- The Lock Screen button uses `ToggleErrandIntent: LiveActivityIntent`. The system runs it **in the app process**, where `ShiftControl.toggleErrand()` flips `isPersonal` on the active shift. The extension compiles a stub `ShiftControl` because it can't access the app's data.

## Shortcuts

- `StartShiftIntent` has `openAppWhenRun = true`, because location updates and Live Activities can only start while the app is in the foreground. Its parameter is `platform` (String, default "DoorDash").
- `GigLogShortcuts` (AppShortcutsProvider) exposes **Start Shift** and **Personal Errand** to Siri and Shortcuts.

## Exports

- **CSV**: one row per shift (business / personal miles, rate, deduction, pay), then expenses.
- **PDF**: summary, platform payouts, expenses and the mileage log; it paginates automatically.
- **Backup**: `Backup` (Codable) holds every model, with photo and route `Data` base64-encoded in JSON. Restore deletes all models, then inserts the backup's contents.

## Building and testing

- There are no automated tests yet. Build and run on a device, because GPS, the camera and Live Activities need real hardware.
- In the simulator, use **Features → Location → Freeway Drive** to simulate driving. The camera falls back to the photo library there.
