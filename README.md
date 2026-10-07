# Gig Mileage Log

A simple, offline-friendly web app to record delivery gig shifts (DoorDash, Amazon Flex, Uber Eats, etc.) and business miles for taxes.

## Features
- **Quick start/end shift** – tap to start, enter odometer, tap to end.
- **Manual entry** – add or edit past shifts (date, times, odometer, miles, earnings, tips, notes).
- **Multiple platforms** – DoorDash, Amazon Flex and more; add your own.
- **Tax summary** – yearly miles, estimated mileage deduction (IRS standard rate), income, hours, by platform and month.
- **CSV export** – mileage log for your tax preparer / Schedule C.
- **Backup/restore** – JSON file. Data is stored only on your device (localStorage).

## Run
No build needed. Open `index.html`, or serve the folder:

```
python3 -m http.server 8000
```

Then visit http://localhost:8000. On a phone, use "Add to Home Screen" to install it like an app.
To host for free, enable **GitHub Pages** on this repo (Settings → Pages → deploy from branch).

## Notes
- IRS rates are prefilled (2023–2026) — verify each year at irs.gov and edit in Settings.
- Not tax advice. Keep the exported log with your records.
