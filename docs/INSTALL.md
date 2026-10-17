# Installation

How to put Gig Log on your iPhone using Xcode on a Mac.

## What you need

- A Mac with **Xcode 16** or later. Install it from the Mac App Store and open it once so it can finish setting up.
- An iPhone on **iOS 17** or later, and a cable to connect it to the Mac.
- An **Apple ID**.

## Steps

### 1. Get the code

In Terminal:

```sh
git clone https://github.com/JasperCalapini/WorkSchedule.git
cd WorkSchedule
open GigLog.xcodeproj
```

To get updates later, run `git pull` in the `WorkSchedule` folder.

### 2. Sign in to Xcode

Xcode → **Settings** → **Accounts** → **+** → **Apple ID**, and sign in.

### 3. Set up signing

The project has two targets: the app (**GigLog**) and the Lock Screen display (**GigLogWidgets**).

1. Click the blue **GigLog** project icon at the top of the left sidebar.
2. Select the **GigLog** target → **Signing & Capabilities** → choose your **Team**.
3. Select the **GigLogWidgets** target → **Signing & Capabilities** → choose the same **Team**.

**If Xcode says the bundle identifier is not available:**

1. Click the blue **GigLog** project (not a target) → **Build Settings**.
2. Search for `APP_BUNDLE_IDENTIFIER`.
3. Change `com.jaspercalapini.giglog` to something unique, such as `com.yourname.giglog`.

Both targets use this value. The widget automatically gets `.widgets` added to the end.

### 4. Prepare the iPhone

1. Connect the iPhone to the Mac and tap **Trust** on the phone.
2. Turn on **Developer Mode**: iPhone **Settings → Privacy & Security → Developer Mode**, switch it on, and restart the phone.

### 5. Run

1. At the top of the Xcode window, choose your iPhone as the run destination.
2. Press **Run** (▶).
3. The first time, the iPhone may refuse to open the app. Go to **Settings → General → VPN & Device Management**, tap your Apple ID, and tap **Trust**. Then open Gig Log.

### 6. Allow permissions

Gig Log asks for these the first time they're needed:

| Permission | Choose | Why |
|---|---|---|
| Location | **Allow While Using App** | Count miles and record the route during a shift |
| Camera | **Allow** | Odometer and receipt photos |
| Face ID | **Allow** | Only if you turn on Face ID lock |

Live Activities (the Lock Screen display) are on by default. If they don't appear, check **Settings → Gig Log → Live Activities**.

## Free vs paid Apple Developer account

| | Free Apple ID | Paid ($99/year) |
|---|---|---|
| Install on your own iPhone | Yes | Yes |
| How long the app keeps working | **7 days**, then reinstall from Xcode | 1 year |
| TestFlight / App Store | No | Yes |

With a free account, connect the phone and press **Run** again once a week. **Your data is kept** when you reinstall, as long as you don't delete the app.

## Start a shift automatically when you open DoorDash

1. Open the **Shortcuts** app → **Automation** tab → **+** → **App**.
2. Choose **DoorDash** (or Amazon Flex), tick **Is Opened**, choose **Run Immediately**, then tap **Next**.
3. Add the action **Start Shift** (from Gig Log) and set **Platform** to `DoorDash`.

When you open DoorDash, Gig Log opens for a moment to start the shift; the iPhone only lets GPS tracking start while the app is open. Tap **◀ DoorDash** at the top-left to go back. If a shift is already running, nothing changes.

You can also say **"Hey Siri, start a shift in Gig Log"**.

## Troubleshooting

| Problem | Fix |
|---|---|
| "Untrusted Developer" when opening the app | iPhone Settings → General → VPN & Device Management → trust your Apple ID |
| App stopped opening after a week | Free Apple ID limit. Reconnect the phone and press Run in Xcode |
| "No account for team" / signing errors | Choose your Team for **both** targets (step 3) |
| Bundle identifier not available | Change `APP_BUNDLE_IDENTIFIER` (step 3) |
| Miles stay at 0.0 | iPhone Settings → Gig Log → Location → **While Using the App**. Make sure "Track miles with GPS" was on when you started the shift |
| Nothing on the Lock Screen | iPhone Settings → Gig Log → **Live Activities** on. The display appears after starting a shift in the app |
| Build errors in Xcode | Copy the error text and open an issue, or send it to whoever maintains the code |
