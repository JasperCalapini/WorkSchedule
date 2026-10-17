# Gig Log

An iPhone app for delivery drivers (DoorDash, Amazon Flex, Uber Eats, Grubhub, Instacart, Walmart Spark and others) to record **shifts, business miles, earnings and expenses** for taxes.

Start a shift, drive, end the shift. Gig Log tracks your miles with GPS, keeps a mileage log the IRS accepts, and shows how much to set aside for taxes.

> Gig Log helps you keep records. It is **not tax advice**. Check with a tax professional for your situation.

## Features

**Tracking**
- One-tap **start / end shift** with a live timer.
- **GPS mileage tracking** that keeps running while you use DoorDash or Flex. It counts all miles while working, not just the platform's "active" miles.
- **Personal errand mode**: during a shift, miles are recorded but counted as personal, not business.
- **Route map** of every shift. Business driving shows as a solid line, personal driving as a dashed orange line.
- **Odometer readings and photos** at the start and end of a shift, as backup proof.
- **Lock Screen and Dynamic Island**: timer, miles and the Errand / Back-to-work button without opening the app.
- **Shortcuts**: start a shift automatically when you open DoorDash or Flex.

**Money and taxes**
- **Earnings and tips** per shift.
- **Expenses**: parking, tolls, phone share, supplies, each with an optional receipt photo.
- **Taxes tab**: income, mileage deduction (IRS standard rate by date), expenses, profit, and a **set-aside-for-taxes** estimate.
- **Platform payouts**: compare each app's 1099 total with your own log.
- **Year-end PDF report** and **CSV export** for you or your tax preparer.

**Insights**
- **This week / this month**: earnings, hours, miles, $/hour, $/mile.
- **Weekly earnings goal** with a progress bar.
- **Best times to drive**: $/hour by day of week, time of day and platform.

**Privacy and safety**
- All data stays **on your iPhone**. No account, no server, no iCloud sync.
- **Backup and restore** to a single file.
- Optional **Face ID lock**.
- **Dark mode**.

## Requirements

- iPhone with **iOS 17** or later
- A Mac with **Xcode 16** or later (free on the Mac App Store)
- An Apple ID (free works; see [Installation](docs/INSTALL.md#free-vs-paid-apple-developer-account))

## Quick start

1. Clone the repo and open `GigLog.xcodeproj` in Xcode.
2. Choose your Team under **Signing & Capabilities** for both targets, **GigLog** and **GigLogWidgets**.
3. Plug in your iPhone, select it, and press **Run** (▶).

Full steps and troubleshooting: **[docs/INSTALL.md](docs/INSTALL.md)**

## Documentation

| Document | What's in it |
|---|---|
| [Installation](docs/INSTALL.md) | Putting the app on your iPhone, signing, Shortcuts automation, troubleshooting |
| [User guide](docs/USER_GUIDE.md) | How to use every screen and feature |
| [Tax guide](docs/TAX_GUIDE.md) | How delivery gig taxes work and how Gig Log's numbers map to your tax return |
| [Privacy](docs/PRIVACY.md) | What data is stored, where, and which permissions are used |
| [Architecture](docs/ARCHITECTURE.md) | Code structure and design notes for developers |
| [Changelog](CHANGELOG.md) | What changed in each version |

## Project layout

```
GigLog/              App source (SwiftUI + SwiftData)
GigLogWidgets/       Lock Screen / Dynamic Island widget extension
Shared/              Code compiled into both the app and the widget
GigLog.xcodeproj     Xcode project
Info.plist           App Info.plist additions (background location, Live Activities)
docs/                Documentation
```

## License

Personal project. No license has been chosen yet; all rights reserved by the author.
