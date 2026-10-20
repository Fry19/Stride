# Stride

An iPhone app that rewards you for walking. It reads your daily steps from Apple Health and turns them into passport stamps, coins you spend on real treats, badges, and a virtual journey along three famous trails.

## What you earn

| Reward | How |
| --- | --- |
| **Stamp** | Hit your daily step goal. Stamps fill your passport. |
| **Coins** | 1 coin per 100 steps, +25 for hitting your goal, plus a bonus for each badge (10 to 500). |
| **Rewards** | Treats you add yourself with a coin price, like a fancy coffee for 300. Redeem them when you can afford them. |
| **Streak** | Consecutive goal days. Every 7 days in a row earns a streak freeze (up to 2 saved). A freeze is used automatically if you miss a day, so one rest day doesn't end your streak. |
| **Badges** | 12 milestones, from your first day to 1,000,000 steps. |
| **Journey** | Your walking distance moves you along the Inca Trail (≈43 km), Hadrian's Wall Path (≈135 km) and the Camino de Santiago (≈780 km), in that order. Every stop you reach unlocks a postcard. Distances are approximate. |

Rewards count from the day you set the app up. Steps typed into the Health app by hand don't count.

## Running it on your iPhone

You need a Mac with **Xcode 16 or later** and an iPhone on **iOS 17 or later**.

1. Clone the repo and open `Stride.xcodeproj`.
2. In Xcode, open **Settings → Accounts** and add your Apple ID if it isn't there.
3. Select the **Stride** project, then the **Stride** target, then **Signing & Capabilities**. Set **Team** to your Apple ID ("Personal Team").
   - If Xcode says the bundle identifier isn't available, change `com.fry19.stride` to something unique, like `com.yourname.stride`.
4. Connect your iPhone, unlock it, and pick it as the run destination at the top of the Xcode window.
   - The first time, turn on **Settings → Privacy & Security → Developer Mode** on the iPhone and restart it.
5. Press **Run** (⌘R).
   - If the iPhone says the developer isn't trusted, go to **Settings → General → VPN & Device Management**, tap your Apple ID, and tap **Trust**.
6. In the app, set a goal and tap **Connect Apple Health**. Allow Steps and Walking + Running Distance, and allow Motion & Fitness.

With a free Apple ID, the app stops opening after 7 days. Plug the phone back in and press Run again to renew it. Your data stays as long as you don't delete the app.

On a work Mac, your company's device management may stop you from adding a personal Apple ID to Xcode. If step 2 or 3 fails for that reason, you'll need a different Mac or your IT team's help.

### If signing fails because of HealthKit

If Xcode refuses to sign the app because of the HealthKit capability, remove it: in **Signing & Capabilities**, delete the HealthKit capability (or clear the **Code Signing Entitlements** build setting). Stride then falls back to the iPhone's motion sensor, which keeps about 7 days of history. Stride saves each day it sees, so your history still builds up as long as you open the app at least once a week.

### Trying it in the simulator

The simulator has no step data. Open **Today → gear icon → Show sample data** to fill the app with 60 days of made-up walking. Turn it off to go back to your real data.

## Project layout

```
Stride.xcodeproj
Stride/                 The app (SwiftUI)
  Model/                App state, saving, Apple Health and motion sensor access
  Views/                Today, Journey, Passport, Rewards, Settings, onboarding, celebrations
StrideCore/             Swift package with the reward rules: coins, streaks, badges, journey routes
Config/                 Entitlements (HealthKit)
```

All the reward rules live in `StrideCore`, which has no iOS dependencies. To run its tests:

```
cd StrideCore
swift test
```

## Not built yet

- Home and Lock Screen widgets
- A notification when you hit your goal (this needs background Health updates)
- Apple Watch app
