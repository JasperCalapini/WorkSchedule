# Gig Log (iPhone app)

Native iOS app (SwiftUI + SwiftData) to record delivery gig shifts — DoorDash, Amazon Flex, Uber Eats, etc. — and business miles for taxes.

## Features
- **Start / end a shift** with one tap; live timer while you drive.
- **GPS mileage tracking** during a shift, even while you use DoorDash/Flex in the foreground. Counts all miles while working, not just the platform's "active" miles.
- **Odometer backup + photos** — start/end odometer readings and photos as proof.
- **Commute miles** logged separately from business miles (not deducted).
- **This week / this month** stats: earnings, hours, miles, $/hour, $/mile.
- **Expenses** — parking, tolls, phone share, supplies — with receipt photos.
- **Taxes tab** per year: income, mileage deduction, expenses, profit, and a **set-aside-for-taxes** estimate (% adjustable in Settings).
- **Platform payouts** — enter each app's 1099 / annual total and compare with your log.
- **CSV export** of shifts and expenses via the share sheet.
- **Dark mode** (follows the iPhone setting).

## Install on your iPhone
Requires a Mac with **Xcode 16 or newer** (free from the Mac App Store). iPhone must run iOS 17+.

1. Clone this repo on your Mac and open `GigLog.xcodeproj`.
2. Xcode → Settings → Accounts → sign in with your Apple ID.
3. Select the **GigLog** target → *Signing & Capabilities* → pick your Team. If the bundle ID is taken, change it (e.g. `com.yourname.giglog`).
4. Plug in your iPhone, select it as the run destination, press **Run** (▶).
5. On the iPhone: Settings → General → VPN & Device Management → trust your developer certificate. On iOS 16+, also enable Settings → Privacy & Security → **Developer Mode**.

With a free Apple ID the app must be re-installed from Xcode every 7 days. A paid Apple Developer account ($99/yr) removes that limit and lets you use TestFlight or the App Store.

## Notes
- IRS rates are stored by effective date (2026 changed mid-year: 72.5¢ Jan–Jun, 76¢ Jul–Dec). Verify at irs.gov and edit in Settings.
- GPS: allow location access when asked. A blue location pill shows while tracking; it stops when you end the shift.
- Photos are stored inside the app (not your Photos library), shrunk to ~200–300 KB each. Data stays on your iPhone and is included in your normal iPhone/iCloud backup.
- Not tax advice.
