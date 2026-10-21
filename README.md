# Stride

An iPhone app that levels you up for walking. Every step earns XP, and every five levels moves you up a tier, from Chalk through Copper, Steel and Gold to Aurora. Your app icon changes material to match.

Stride reads your steps from Apple Health and counts new ones live while the app is open.

## How it works

| | |
| --- | --- |
| **XP** | 1 XP per step, +1,500 for hitting your daily goal, and a bonus for each badge (200 to 10,000). |
| **Levels** | 50 levels. Level 2 comes on your first walk; level 50 takes roughly a year and a half of 8,000-step days. |
| **Tiers** | A new tier every 5 levels, each a different material: Chalk, Graphite, Copper, Bronze, Steel, Silver, Gold, Platinum, Obsidian and Aurora. |
| **App icon** | Switches to your newest tier's material when you reach it. You can also pick any unlocked icon in the Level tab. |
| **Stamps** | One for every day you hit your goal. |
| **Streak** | Consecutive goal days. Every 7 days in a row earns a streak freeze (up to 2 saved), used automatically if you miss a day. |
| **Badges** | 12 milestones, from your first day to 1,000,000 steps. |
| **Quests** | Three small challenges a day, like "2,000 steps before 9 AM" or "out-walk yesterday", each worth 500 to 1,000 XP. |
| **Journeys** | Pick where your steps take you: a real walking route from where you are to a park, landmark, museum, lake or beach nearby (planned with Apple Maps, from an afternoon's walk to a few weeks of steps), or a famous trail: the Inca Trail (≈43 km), Hadrian's Wall Path (≈135 km), the Camino de Santiago (≈780 km), the Appalachian Trail (≈3,500 km) or Route 66 (≈3,900 km). All your walking from the day you pick it moves you along the map. Every stop unlocks a postcard with a real view of the place (Look Around where Apple has it, otherwise 3D satellite), and finishing pays 100 XP per kilometer. Positions on the famous trails are approximate. |
| **Records** | Your best day, week and month, longest streak, longest and fastest walk, daily average and all-time totals, plus a calendar of the last year lit up by goal days. |

XP counts from the day you set the app up. Steps typed into the Health app by hand don't count.

**Steps in the Dynamic Island:** a Live Activity shows today's steps and your goal ring on the Lock Screen and in the Dynamic Island. It updates live while Stride is open or you're on a walk, and every so often in the background when iOS gives the app time (iOS decides how often). iOS ends Live Activities after 8 hours; opening Stride starts it again. You can turn it off in Settings.

**Walk mode:** tap Start a walk to track one walk's steps, distance, pace and GPS route. It keeps counting with the phone locked, adds the walk's timer and steps to the Live Activity (with pause and end buttons), and saves the walk with its route map and mile or kilometer splits when you finish.
- **Pause and auto-pause:** pause by hand, or let Stride pause when you stand still for about 25 seconds and carry on when you walk again. The clock shows moving time.
- **Spoken updates:** time and average pace every kilometer or half mile, and your goal at halfway and the finish. Music and podcasts dip while it talks. Mute it from the walk screen or Settings.
- **Apple Health workouts:** turn on **Save walks to Apple Health** in Settings to save each walk as a walking workout with its route.

**Hands-free:** say "Hey Siri, start a walk in Stride" (also pause, resume and end, or "check my steps in Stride"). The same actions are in the Shortcuts app, so a walk can go on the Action Button. On iOS 18 there's also a **Start a Walk** control for Control Center, the Lock Screen and the Action Button.

**Evening nudge:** optional. If you haven't hit your goal by a time you choose, a notification says how many steps are left and about how long a walk that is. Nothing is sent on days you've made it.

**Backup and status:** Settings can save everything Stride keeps (XP, journeys, quests, walks) to a file, for example in iCloud Drive, and restore it, also from the first screen after a reinstall. **Settings → Status** shows what Stride can read (Apple Health, Motion & Fitness, location, notifications, Live Activities, background updates) and how to fix anything that's off.

**Race your past self:** Today compares your steps so far with yesterday, and with your best day this week, at the same time of day.

**Recaps:** a card summing up your week or month (steps, goal days, best day, XP, level), shared as an image sized for Instagram Stories.

**Live steps:** the iPhone's pedometer only reports every few seconds, so while Stride is open it also counts steps from the accelerometer as they happen. When the pedometer reports, its number takes over; the count never goes backwards.

## Installing on your iPhone

There are two ways to install Stride on an iPhone running **iOS 17 or later**. Both work with a free Apple ID. With a free Apple ID the app stops opening after 7 days until you refresh or reinstall it, and your data stays as long as you don't delete the app.

### Option 1: Sideload a release (no Xcode)

Each release on the [Releases](../../releases) page has a `Stride_<version>.ipa` file. iPhones can't install an app file directly the way Android can, so you need a sideloading tool to sign it with your Apple ID:

- **SideStore** installs and refreshes apps from the iPhone itself. Setting it up needs a computer once; follow the guide at [sidestore.io](https://sidestore.io). After that:
  1. On the iPhone, download `Stride_<version>.ipa` from the Releases page in Safari.
  2. Open SideStore, go to **My Apps**, tap **+**, and pick the file.
  3. Open SideStore at least once a week and tap **Refresh All** so Stride doesn't expire.
- **Sideloadly** installs from a Mac or Windows PC over a cable:
  1. Install [Sideloadly](https://sideloadly.io) on the computer and plug in the iPhone.
  2. Drag `Stride_<version>.ipa` into Sideloadly, enter your Apple ID, and click **Start**.
  3. Do it again within 7 days, or turn on Sideloadly's automatic refresh while the computer is on.

Either way, the first time you also need to:
- Turn on **Settings → Privacy & Security → Developer Mode** on the iPhone and restart it.
- Trust your Apple ID under **Settings → General → VPN & Device Management**.

Deleting Stride deletes its data, so save a backup first (Settings → Backup) if you reinstall instead of refreshing.

A free Apple ID can have 3 sideloaded apps installed at once, and SideStore counts as one of them. Stride's Live Activity and Control Center button live in an app extension, which counts as an app too, so Stride uses 2 of the 3. Sideloadly and SideStore can strip the extension if you need the room; walks still work, just without the Lock Screen view.

Sideloading tools don't always keep the Apple Health permission. If Health access isn't offered, Stride uses the iPhone's motion sensor instead, which keeps about 7 days of history. Stride saves each day it sees, so your history still builds up as long as you open it at least once a week.

### Option 2: Build it in Xcode

You need a Mac with **Xcode 16 or later**.

1. Clone the repo and open `Stride.xcodeproj`.
2. In Xcode, open **Settings → Accounts** and add your Apple ID if it isn't there.
3. Select the **Stride** project, then the **Stride** target, then **Signing & Capabilities**. Set **Team** to your Apple ID ("Personal Team").
   - If Xcode says the bundle identifier isn't available, change `com.fry19.stride` to something unique, like `com.yourname.stride`. Then do the same for the **StrideWidgets** target, keeping `.widgets` on the end (`com.yourname.stride.widgets`), and set its Team too.
4. Connect your iPhone, unlock it, and pick it as the run destination at the top of the Xcode window.
   - The first time, turn on **Settings → Privacy & Security → Developer Mode** on the iPhone and restart it.
5. Press **Run** (⌘R).
   - If the iPhone says the developer isn't trusted, go to **Settings → General → VPN & Device Management**, tap your Apple ID, and tap **Trust**.
6. In the app, set a goal and tap **Connect Apple Health**. Allow Steps and Walking + Running Distance, and allow Motion & Fitness. The first walk asks for location.

With a free Apple ID, plug the phone back in and press Run again within 7 days to renew the app.

On a work Mac, your company's device management may stop you from adding a personal Apple ID to Xcode. If step 2 or 3 fails for that reason, you'll need a different Mac or your IT team's help.

#### If signing fails because of HealthKit

If Xcode refuses to sign the app because of the HealthKit capability, remove it: in **Signing & Capabilities**, delete the HealthKit capability (or clear the **Code Signing Entitlements** build setting). Stride then falls back to the iPhone's motion sensor, which keeps about 7 days of history. Stride saves each day it sees, so your history still builds up as long as you open the app at least once a week.

## Trying it in the simulator

The simulator has no step data. Open **Today → gear icon → Show sample data** to fill the app with 60 days of made-up walking. Turn it off to go back to your real data.

Debug builds can also open straight to a screen with sample data by launching with `-StrideScreen today` (or `walk`, `journey`, `picker`, `level`, `trophies`, `records`, `recap`, `celebration`, `onboarding`). The screenshot workflow uses this.

## Project layout

```
Stride.xcodeproj
Stride/                 The app (SwiftUI)
  Model/                App state, saving and backups, Apple Health, live steps, walks, nearby journeys, quests, nudges
  Views/                Today, Journey (with maps), Level, Trophies, walk screens, records, settings and status
  Intents/              Siri and Shortcuts
StrideWidgets/          Widget extension with the Live Activity and the Control Center button
Shared/                 Code used by both the app and the extension: Live Activity data and walk actions
StrideCore/             Swift package with the rules: XP, levels and tiers, streaks, badges, quests, journey routes
Design/                 Generator for the tier emblems, which are also the app icons
Config/                 Info.plist additions and entitlements (HealthKit)
```

The ten emblems (also the app icons) are drawn by `Design/emblems.py` as SVG and rendered with headless Chromium. To change them, edit the script and run `Design/build.sh`, which updates `Stride/Assets.xcassets`.

## Builds

GitHub Actions runs three workflows on macOS runners:

- **Build** (every push to `main` and every pull request): runs the `StrideCore` tests and builds the app.
- **Screenshots** (every push to `main`): runs the app in the iOS Simulator with sample data and pushes screenshots of each screen to the [`screenshots`](../../tree/screenshots) branch.
- **Release** (when a `v*` tag is pushed, like `v1.0.1`, or started by hand with a tag name): builds `Stride_<version>.ipa` and publishes it on the Releases page.

All the reward rules live in `StrideCore`, which has no iOS dependencies. To run its tests:

```
cd StrideCore
swift test
```

## Not built yet

- Home Screen widgets (they need App Groups, which free Apple IDs may not allow)
- A year-end "Wrapped"
- Apple Watch app
