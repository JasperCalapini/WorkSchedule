# User guide

Gig Log has four tabs: **Shifts**, **Expenses**, **Taxes** and **Settings**.

## Shifts

### Weekly and monthly stats

At the top: earnings, hours, business miles, **$ per hour**, **$ per mile** and number of shifts. Switch between **This week** and **This month**.

If you set a **weekly goal** in Settings, a progress bar shows how close you are.

### Starting a shift

1. Pick the **Platform** (DoorDash, Amazon Flex…).
2. Leave **Track miles with GPS** on (recommended).
3. Optional backup: type the **start odometer** and take an **odometer photo**.
4. Tap **Start shift now**.

You can also start a shift from Siri or a Shortcuts automation; see [Installation](INSTALL.md#start-a-shift-automatically-when-you-open-doordash).

### During a shift

- The shift card shows the **timer**, **business miles** and a small **route map**.
- GPS keeps counting while you use DoorDash or Flex. A blue location icon at the top of the screen means tracking is on.
- The **Lock Screen** and **Dynamic Island** show the timer, miles and an Errand button.

### Keep the app running

Don't swipe Gig Log away in the app switcher during a shift: iPhone stops GPS for apps that are swiped away. If that happens:

- The Lock Screen shows **"Not updating — open Gig Log"**.
- When you open the app again, tracking continues. The shift is marked **GPS interrupted**, and the End shift form asks you to enter both odometer readings.

### Personal errands

If you run a personal errand during a shift (groceries, picking someone up), tap **Personal errand**:

- GPS keeps recording, but those miles count as **personal**, not business.
- The route shows that part as a **dashed orange line**.
- Tap **Back to work** when you're done.

You can also do this from the Lock Screen button. Why it matters: [Tax guide](TAX_GUIDE.md#which-miles-count).

### Ending a shift

Tap **End shift** and check the form:

| Field | What to enter |
|---|---|
| Start / End | Filled in automatically. Adjust if needed |
| Start / End odometer | Optional backup. If both are filled in, miles are calculated from them |
| Business GPS miles | What GPS counted. Tap **use** to apply it |
| Commute / personal miles | Filled in from personal-errand miles. Add any commute you want kept separate |
| **Business miles** | Total driven minus commute/personal. **This is the number that's deducted** |
| Odometer photos | Start photo (if taken) and an end photo |
| Earnings, Tips | From the platform's summary for the shift |
| Notes | Optional, e.g. area or vehicle |

Tap **Save**.

**Discard shift** deletes the running shift, including its miles, route and photos. It asks you to confirm first.

### History

Past shifts are listed with date, hours, miles and pay. A map icon means a route was saved. Tap a shift to edit it or view the route; swipe left to delete it.

To add a shift you forgot to track, tap **+** in the top-right corner.

### Route view

Tap a route map to open it full screen:

- Solid line: business driving. Dashed orange: personal.
- Green flag: start. Red flag: end.
- Below the map: business and personal GPS miles, time, start and end.

## Expenses

Business costs **other than driving**: parking, tolls, the business share of your phone bill, delivery bags, chargers.

- Tap **+**, choose a category, enter the amount, and optionally add a note and a **receipt photo**.
- For your phone, enter only the business share (for example 40% of the bill).
- **Don't add gas, repairs, insurance or car payments.** The standard mileage rate already covers them.

## Taxes

Pick the **tax year** at the top.

- **Set aside for taxes**: profit × your set-aside % (Settings). See the [Tax guide](TAX_GUIDE.md#how-much-to-set-aside).
- **Totals**: gross income, mileage deduction, other expenses, **profit (Schedule C)**, business miles, personal/commute miles, hours.
- **Platform payouts vs your log**: at year end, tap a platform and enter what it reported (1099 or annual summary). Gig Log shows any difference.
- **Best times to drive**: $/hour by day and time of day, and a platform comparison.
- **By platform / By month**: breakdowns.
- **Create year-end PDF report**: summary, payouts, expenses and full mileage log. Tap **Share PDF report** to save or send it.
- **Create CSV for taxes**: the same data as a spreadsheet. Tap **Share CSV** to save or send it.

## Settings

| Setting | What it does |
|---|---|
| Set aside | % of profit to save for taxes (default 25%) |
| Weekly earnings goal | Shows a progress bar on the Shifts tab. Set to $0 to turn off |
| Require Face ID | Locks the app when you leave it. It asks for Face ID once to turn it on, and needs a passcode set on the iPhone |
| Save route map | Turn off to stop saving routes; miles are still counted |
| Backup | **Create backup** → choose a password → **Save backup file…** to keep a copy in Files or email it. The file is encrypted; **if you forget the password it can't be opened** |
| Restore from backup | Pick the backup file, enter its password, and confirm. Replaces everything in the app; if anything goes wrong, your current data is kept |
| About | App version and build number |
| Platforms | Add, remove or reorder (tap **Edit**) |
| IRS mileage rate | Rates by start date. Check irs.gov each year and add new rates here |

## Tips

- **Start the shift before you start driving** to work, and end it when you stop.
- Use a **car charger**; GPS plus delivery apps use battery.
- **Back up** once a month, and before changing phones.
- At year end: enter platform payouts, create the **PDF report**, and send it to your tax preparer.
