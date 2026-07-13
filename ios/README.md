# BROiled iOS - Phase 0 source

Real Swift/SwiftUI/SwiftData/HealthKit/UserNotifications code implementing the Phase 0
loop from `plan.md`.

**Xcode project:** open `broiled/broiled.xcodeproj` at the repo root. It references
`ios/BROiledApp/` directly (not a copied duplicate), so copy edits in
`ios/BROiledApp/Services/InsultPool.swift` are what the app builds. After pulling copy
changes, use **Product → Clean Build Folder** in Xcode, then rebuild.

**Copy source of truth:** `InsultPool.swift` mirrors `plan.md` and `wireframe_phase0.html`.
Views should read UI strings from `InsultPool` constants, not hardcode lines in SwiftUI.

There's also a manual setup path below if you prefer creating a fresh Xcode project.

## Setup

1. **Xcode → File → New → Project → iOS → App**
   - Product Name: `BROiledApp`
   - Interface: SwiftUI
   - Storage: SwiftData
   - Bundle ID: `com.quinnnguyen.broiled` (or your own team prefix - see plan.md)
   - Minimum deployment: iOS 17

2. **Delete** the default `ContentView.swift` and the default `Item.swift` (or whatever
   SwiftData model Xcode scaffolds) that come with the template.

3. **Drag the `BROiledApp/` folder from this repo into the Xcode project navigator**
   (check "Copy items if needed" and add to the app target). This brings in:
   - `BROiledApp.swift` - replaces the template's app entry point (delete the template's
     version first, or Xcode will complain about two `@main` types)
   - `Theme.swift`
   - `Models/` - `Habit.swift`, `DayLog.swift`, `UserSettings.swift`
   - `Services/` - `HealthKitService.swift`, `NotificationService.swift`,
     `InsultPool.swift`, `DayScheduler.swift`
   - `Views/` - `RootView.swift`, `OnboardingView.swift`, `HomeView.swift`,
     `GutCheckSheet.swift`, `SnoozeSheet.swift`, `SilenceView.swift`, `SettingsView.swift`

4. **Add the HealthKit capability**: select the project → target → **Signing &
   Capabilities** → **+ Capability** → **HealthKit**. Xcode generates the entitlement
   file automatically. **v0.2: also tick the "Background Delivery" checkbox** under the
   HealthKit capability - the success push / background workout detection
   (`enableBackgroundDelivery` in HealthKitService) silently no-ops without it.

5. **Add Info.plist keys** (target → Info tab → add rows, or edit raw Info.plist):
   - `NSHealthShareUsageDescription` → something like *"BROiled checks whether you've
     logged a workout today - it never writes to Health."*
   - `NSHealthUpdateUsageDescription` is **not** needed - BROiled only reads, never writes.

6. **Notifications** don't need an Info.plist entry or capability - `requestAuthorization`
   in `NotificationService` triggers the system permission prompt on first launch.

7. Build and run on a physical device (HealthKit workout data won't be meaningful in the
   Simulator - use a device with real Health app data, or manually add a workout via the
   Health app on the device for testing).

## What's implemented vs. what's still a stub

**Implemented**, matching `plan.md` exactly:
- Per-weekday schedule with individual deadline times (`Habit` + `OnboardingView`)
- Live countdown, morning reckoning banner tiered by miss streak (`HomeView`)
- HealthKit read-only query for a qualifying workout, checked when the countdown hits
  zero (`HealthKitService`, `HomeView.checkOutcome`)
- Manual "I've locked in today" fallback with the gut-check confirm (`GutCheckSheet`)
- Uncapped snooze with a real user-editable deadline picker (`SnoozeSheet`), MILD/SPICY/
  NUCLEAR escalation by snooze count (`InsultPool.snoozeLine`)
- 7-day silence mechanic + reactivation (`SilenceView`, `DayScheduler.recordMiss/reactivate`)
- Streak/rank milestone ladder (`UserSettings.rankTitle`)
- Local notification scheduling for the T-30min reminder, miss-check, and next-day
  morning reckoning (`NotificationService`)
- Day-settlement reconciliation on launch, so the streak stays correct even if a
  background notification never fired (`DayScheduler.reconcile`) - this was flagged as
  the trickiest correctness issue during planning; walking forward from
  `lastSettledDateKey` on every launch is what actually keeps `successStreak`/
  `missStreak` trustworthy, not the notification timing itself.

**Interactive miss-check (implemented):** the miss-check notification is an
"are you working out right now?" prompt with **yes / no** actions instead of a flat
accusation - firing "you didn't work out" is unfair when a workout started near the
deadline can still be running when the check fires. **Yes** gives grace (no penalty) and
re-arms the check for another workout's worth of time; **No** (or a plain tap) opens the
snooze sheet. Foreground and background both route through this one question surface
(`NotificationDelegate` + `NotificationDelegate.didDeclineWorkout`).

**Not implemented yet / genuine gaps to know about**:
- **No background HealthKit observer.** The app can't re-query HealthKit in the background
  and auto-resolve the day if you work out between backgrounding and the deadline - it
  relies on the foreground `checkOutcome()` (auto-success if a workout is found) plus the
  interactive miss-check notification above. This is why the notification asks rather than
  asserts: without a background observer it can't *know* whether you're mid-session, so it
  asks. `HKObserverQuery` + background delivery is the real fix, deferred for now.
- **No Live Activity / Dynamic Island countdown** - that's explicitly Phase 1 in the plan.
- **No unit tests.** `DayScheduler`'s reconciliation logic is the highest-risk piece
  (see the earlier "how is the streak stored" discussion) and deserves test coverage
  before you trust it across timezone changes / DST / app-killed scenarios.
- **I have not compiled this.** There's no Xcode available in the environment this was
  written in, so treat this as a strong first draft, not verified-working code. Expect to
  fix a handful of small type/API mismatches on first build - most likely spots are the
  `HKSampleQuery` closure signature and `UNCalendarNotificationTrigger` date component
  handling, both of which are easy to get subtly wrong without the compiler checking you.
