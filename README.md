# Stride

An iPhone app that rewards you for walking. It reads your daily step count from Apple Health and turns it into stamps, coins, badges and rewards you choose yourself.

Status: planning. Nothing is built yet.

## Proposed v1

- **Today**: live step count, progress toward your daily goal, coins earned today.
- **History**: the last 7 days against your goal.
- **Rewards**
  - A stamp for every day you hit your goal.
  - Coins: 1 per 100 steps, plus a bonus for hitting your goal.
  - Badges for milestones (first 10K day, 7-day streak, 1 million lifetime steps).
  - A reward shop of real treats you set yourself (a fancy coffee, new shoes) that you buy with coins.
  - Streak freezes so one rest day doesn't wipe out a streak.
- **Settings**: daily goal.

## Tech

- SwiftUI, iOS 17+
- HealthKit for step history (merges iPhone and Apple Watch counts), CoreMotion for live updates while the app is open
- SwiftData for local storage; no account or server
- Reward rules in a separate Swift package so they can be unit tested on their own

## Later

- Home and Lock Screen widgets
- A notification when you hit your goal
- A virtual journey: walk a real route (the Camino de Santiago, the Appalachian Trail) and unlock stops along the way
- Apple Watch app
