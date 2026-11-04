# Privacy

Gig Log keeps everything **on your iPhone**. It has no account, no server, no analytics and no iCloud sync, and it doesn't send your data anywhere.

## What is stored

| Data | Where |
|---|---|
| Shifts: times, platform, miles, earnings, tips, notes | App's private storage on the iPhone |
| GPS route of each tracked shift | App's private storage (about 100–300 KB per shift) |
| Odometer and receipt photos | App's private storage, **not** your Photos library (about 200–300 KB each) |
| Expenses, platform payouts, settings | App's private storage |

Your data is included in your normal **iPhone backup** (iCloud Backup or computer backup). Deleting the app deletes all its data, so **make a Backup first**.

## Permissions

| Permission | Used for | When |
|---|---|---|
| **Location** (While Using) | Counting miles and recording the route | Only while a GPS-tracked shift is running. A blue location icon shows while tracking |
| **Camera** | Odometer and receipt photos | Only when you tap the camera button |
| **Face ID** | Locking the app | Only if you turn on *Require Face ID* |
| **Live Activities** | Lock Screen / Dynamic Island display | Only while a shift is running |

Location tracking **stops when you end or discard a shift**. You can turn off route saving in **Settings → Save route map**; miles are still counted.

## When data leaves the phone

Only when **you** choose to share it, using the iPhone share sheet:

- **CSV export** and **PDF report**: contain shifts, miles, earnings and expenses. They do not include photos or routes. In the CSV, text a spreadsheet could run as a formula (starting with `=`, `+`, `-` or `@`) gets a leading `'` so it shows as plain text.
- **Backup file**: contains **everything**, including photos and GPS routes, which show where you drove. It is **encrypted** with the password you choose (AES-256-GCM; the key is derived from your password with PBKDF2-SHA256, 600,000 rounds). Without the password it can't be read or changed without detection, and nobody can recover a forgotten password.

Exported files are written to a private temporary folder with iOS file protection, and that folder is emptied every time the app starts.

## Face ID lock

When it's on, the app is covered whenever you leave it and asks for Face ID (or your passcode) when you come back. Face ID data stays in iOS; Gig Log only gets a yes/no answer.

- The cover sits in its own window above everything, so open forms and sheets are hidden too.
- While locked, the app's screens are hidden from VoiceOver, so they can't be read aloud behind the lock.
- If the iPhone has no passcode, the lock can't be turned on.

## App switcher

Whether or not Face ID lock is on, the app is covered whenever it isn't in the foreground: in the app switcher, under Control Center, or during a phone call. Earnings and maps don't appear in the app-switcher preview.

The Lock Screen display (Live Activity) shows the platform, timer and miles, but no earnings.

## App Store privacy

`GigLog/PrivacyInfo.xcprivacy` declares: no tracking, no data collected, and one "required reason" API, UserDefaults (reason CA92.1, for the app's own settings).
