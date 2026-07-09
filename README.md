# BROiled

**BROke streak? You're cooked.**

BROiled is an iOS workout accountability app with tough-love energy. Set a per-day workout deadline, and if Apple Health doesn't show a qualifying workout in time, you get roasted — escalating snoozes, morning reckonings, and eventually silence if you keep skipping.

> *Marketing:* Broke your workout streak? You're cooked.

## Status

**Phase 0 — design & planning.** Interactive wireframes and product spec live in this repo; the SwiftUI app is not built yet.

## How it works

1. **Onboarding** — pick workout days, set a **deadline per day**, and choose a minimum duration.
2. **Countdown** — home screen shows time left until today's deadline (HealthKit-verified).
3. **Miss the window** — notifications escalate (MILD → SPICY → NUCLEAR). Snooze pushes the deadline back.
4. **Morning reckoning** — day after a miss: in-app banner on first open **and** a 12:00 PM push with the same copy.
5. **Success** — backhanded celebration (bronze, not cheerleader green).
6. **Silence** — after 7 consecutive misses, the app stops nagging until you log a workout again.

Open [`wireframe_phase0.html`](wireframe_phase0.html) in a browser for all 12 Phase 0 screens (gen-z/meme voice) with design notes. [`wireframe_phase1.html`](wireframe_phase1.html) is the same 12 screens with the original tough-love voice, kept as reference for the Phase 1 persona system.

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

## Stack (planned)

- SwiftUI + SwiftData (iOS 17+)
- HealthKit for workout verification
- Local notifications + background checks
- Phase 1+: persona voices, Live Activity countdown, weekly roast report

## License

TBD
