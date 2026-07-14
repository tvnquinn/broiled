# BROiled

**BROke streak? You're cooked.**

BROiled is an iOS workout accountability app with tough-love energy. Set a per-day workout deadline, and if Apple Health doesn't show a qualifying workout in time, you get roasted — escalating snoozes, morning reckonings, and eventually silence if you keep skipping.

> *Marketing:* Broke your workout streak? You're cooked.

## Status

**Native iOS build — active dogfooding.** The SwiftUI/SwiftData app, HealthKit verification, notifications, pause/rest-day flows, Burn Book, Live Activity, and widgets are implemented. Current work is focused on real-device reliability and daily-use fixes before external TestFlight distribution.

## How it works

1. **Onboarding** — pick workout days and configure one or more planned workouts per day, each with its own type, time, and duration.
2. **Countdown** — home screen shows time left until today's deadline (HealthKit-verified).
3. **Miss the window** — notifications escalate (MILD → SPICY → NUCLEAR). Snooze pushes the deadline back.
4. **Morning reckoning** — day after a miss: in-app banner on first open **and** a 12:00 PM push with the same copy.
5. **Success** — HealthKit or typed manual logging settles the day; extra workouts can still be logged without advancing the streak twice.
6. **Silence** — after 7 consecutive misses, the app stops nagging until you log a workout again.

The wireframes document the original product flow and the native app is now the behavior source of truth. [`wireframe_phase1.html`](wireframe_phase1.html) remains a reference for the planned tough-love persona system; `prototype.html` has not yet caught up with the latest native screens.

## Screenshots

![Phase 0 wireframes — gen-z voice](docs/screenshots/wireframe_phase0-rail.png)

## Design

**Char & Ember** palette — semantic tints, not filled alert boxes:

| Token | Hex | Use |
|-------|-----|-----|
| Ember | `#FF6B2B` | Countdown, primary CTAs |
| Flame | `#FF3B30` | Miss reckoning, destructive actions |
| Bronze | `#C9A227` | Backhanded success (never wellness green) |
| Ash | `#48484A` | Silence / give-up state |
| Background | `#0C0C0E` | App shell |

## Repo contents

| File | Description |
|------|-------------|
| [`wireframe_phase0.html`](wireframe_phase0.html) | Interactive Phase 0 wireframes — gen-z/meme voice |
| [`wireframe_phase1.html`](wireframe_phase1.html) | Same 12 screens, original tough-love voice (Phase 1 persona reference) |
| [`plan.md`](plan.md) | Full product & engineering plan |
| [`phase-1-persona-tough-love.md`](phase-1-persona-tough-love.md) | Tough-love motivation & insult pool, reserved for Phase 1 |
| [`logo.png`](logo.png) | App icon — flexing figure over the pot |
| [`scripts/capture-screenshots.mjs`](scripts/capture-screenshots.mjs) | Regenerate README screenshots from a wireframe file |

Regenerate screenshots after wireframe changes:

```bash
npm install playwright
npx playwright install chromium
node scripts/capture-screenshots.mjs wireframe_phase0.html
node scripts/capture-screenshots.mjs wireframe_phase1.html
```

## Stack

- SwiftUI + SwiftData (iOS 17+)
- HealthKit for workout verification
- Local notifications + background checks
- ActivityKit + WidgetKit for Live Activity and home-screen widgets
- Phase 1 next: persona voices and weekly roast report/share card

## License

TBD
