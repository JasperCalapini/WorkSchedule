# Changelog

All notable changes to Gig Log. Versions follow [semantic versioning](https://semver.org).

## 1.0.0 — unreleased

### Reliability and quality (from the code review)
- GPS uses iOS 17 live location updates with a background session, so iOS can resume a shift after closing the app; tracking also resumes as soon as the app launches.
- The Lock Screen shows "Not updating — open Gig Log" if tracking stops (for example, the app was swiped away). Shifts with a GPS gap are flagged, and the end-shift form asks for odometer readings.
- GPS progress is saved every 20 points, so a crash loses at most a few points.
- "Discard shift" now asks for confirmation.
- Numbers follow the phone's region format, so pasting "1,206.25" works.
- PDF text is readable when the phone is in dark mode, and a warning appears for shifts without an IRS rate.
- Restore keeps your current data if it fails, and resumes a shift that was running.
- The weekly goal field saves as you type.
- The app shows an error screen instead of crashing if its data can't be opened. The data model is versioned for safe future updates.

### Security and privacy
- Backups are encrypted with a password (AES-256-GCM, PBKDF2-SHA256 with 600,000 rounds).
- The app is covered in the app switcher.
- The Face ID lock covers open sheets too and hides the app from VoiceOver while locked. It can't be turned on without a passcode.
- CSV export guards against spreadsheet formula injection.
- Exported files are cleaned up on every launch.
- A privacy manifest is included.

### Performance and memory
- Photo thumbnails are decoded at small size.
- Route maps are simplified.
- Lists no longer load route data.
- The CSV is built only when requested.
- Backups no longer use base64.

### Project
- Unit tests (Swift Testing), app icon, SwiftLint config, version 1.0.0 with a bump script, LICENSE (all rights reserved).

### Features in this version

**Tracking**
- Start / end shifts with a live timer; add or edit past shifts manually.
- GPS mileage tracking in the background, with odometer readings as a backup.
- Route map per shift, with a full-screen route view.
- Personal errand mode: miles still recorded, counted as personal, shown dashed orange on the map.
- Odometer photos at start and end of a shift.
- Commute / personal miles kept separate from business miles.
- Lock Screen and Dynamic Island Live Activity with an Errand / Back-to-work button.
- Shortcuts actions **Start Shift** and **Personal Errand**, so a shift can start automatically when DoorDash opens.

**Money and taxes**
- Earnings and tips per shift; expenses with receipt photos.
- Taxes tab: profit, mileage deduction using IRS rates by effective date (handles the 2026 mid-year change), set-aside estimate.
- Platform payouts (1099) compared with the log.
- Year-end PDF report and CSV export.

**Insights**
- This week / this month stats with $/hour and $/mile.
- Weekly earnings goal.
- Best times to drive by day, time of day and platform.

**Privacy and data**
- All data stored on the device only (no iCloud sync).
- Backup to a file and restore.
- Optional Face ID lock.
- Dark mode.
