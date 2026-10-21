# FitAlarm (working name)

An alarm that only stops when you've done your workout. The phone camera counts your reps. The app also includes a full daily-routine planner, verified step counting, diet planning, food scanning and a LeetCode-style streak heatmap.

<p>
  <img src="docs/screenshots/splash.png" width="200">
  <img src="docs/screenshots/welcome.png" width="200">
  <img src="docs/screenshots/home.png" width="200">
  <img src="docs/screenshots/home_heatmap.png" width="200">
</p>

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| 1 | App shell, premium design system, onboarding, health targets, home dashboard, streak heatmap | ✅ Done |
| 2 | Workout alarm: full-screen alarm and camera pose detection (ML Kit) with rep counting | ⏳ Next |
| 3 | My Day routine maker and scheduled reminders | |
| 4 | Dual step counter (sensor + GPS, vehicle filtering) and water reminders | |
| 5 | Diet plans, custom goals with deadlines, meal logging | |
| 6 | Food camera scanner (AI nutrition estimate) | |
| 7 | Badges, XP, weekly reports, friends, Play Store release | |

## Tech

- **Flutter** (Android first), Riverpod for state, go_router for navigation
- flutter_animate for motion, with custom painters for the progress rings, aurora background and heatmap
- Fonts (Inter + Sora) are bundled in `assets/google_fonts` and work offline
- Health maths in `lib/features/profile/domain/health_targets.dart`: Mifflin-St Jeor BMR, TDEE, macros, fiber, water and stride length

## Project layout

```
lib/
  core/            theme, router, shared widgets (GlassCard, ProgressRing, Pressable…)
  features/
    splash/        animated launch screen
    onboarding/    11-step animated onboarding with ruler pickers
    home/          "Today" dashboard
    streaks/       daily log, scoring, streak maths, heatmap widget
    profile/       user profile model, targets, profile screen
    shell/         floating glass bottom navigation
test/              unit tests (targets, streaks) and full onboarding flow tests
```

## Run it

```bash
flutter pub get
flutter run            # on an Android device or emulator
flutter test           # unit + widget tests
```
