# Scampi 🦐

Offline-first calorie, nutrition, exercise, weight, sleep, and fasting
tracker. No accounts, no login, no cloud, no subscriptions — everything
lives on the device. Distributed as a sideloaded APK via GitHub Releases
(not the Play Store), with a built-in self-updater.

## Status: v1.1.0 — feature-complete for daily use

All five tabs (Home, Food, Fitness, Progress, Profile) are fully built
and wired to real SQLite data. See "What's built" below for the full list.

## Getting set up

```bash
flutter pub get
cp android/local.properties.example android/local.properties
# edit android/local.properties with your sdk.dir and flutter.sdk paths
flutter analyze
flutter run                    # needs a connected device or emulator
flutter build apk --debug      # or --release for a real build
```

On first launch you'll see onboarding (name, age, sex, height, weight,
goal weight, activity level, goal mode) before the main app — it's
stored in SQLite from then on. Uninstalling/clearing app data resets
this, as expected for a fully local, no-account app.

## What's built

**Food** — search/browse ~180 seed foods across Fruits, Vegetables,
Dairy, Meat, Fish, Rice, Pasta, Bread, Desserts, Fast Food, Sandwiches,
Drinks, Snacks, Traditional Meals, Generic Ingredients (Pakistan,
Bahrain, Germany, Algeria, Middle East, South Asia, Europe, Global —
no pork or alcohol); custom food creator + edit/delete for "Your
Ingredients"; meal builder; AI import (photo *or* typed description,
share-sheet workflow to ChatGPT/Claude/Gemini, paste the JSON reply
back — decomposes composite dishes into separate ingredients).

**Fitness** — exercise logging with MET-based calorie estimates,
pace-adjusted for distance-trackable categories (walking/running/
cycling/swimming/hiking) so a faster session burns more than a slower
one of the same duration.

**Home dashboard** — calorie ring with an inner water arc and an outer
semicircle sleep arc (only shown once sleep tracking is actually in
use — see below); water droplet tile with quick-add chips and a full
log/edit/delete sheet; weight check-in; fasting tile; daily tip.

**Sleep** — manual bedtime/wake-time entry (editable, not just
add-only); optional Health Connect auto-sync (see below). The sleep
arc/stat on the ring auto-hides if there's no entry for today or
yesterday, so it never gets stuck showing a stale "0h" for someone who
tried it once and stopped.

**Fasting** — start/end a fast (Ramadan / Intermittent / Custom types),
duration presets, a "Right Now" button on every time field, live
elapsed/remaining display that switches to "Day X/Y" for multi-day
fasts instead of a raw triple-digit hour count, and a local notification
when the target duration is reached. Ramadan fasts can auto-fill
Suhoor/Iftar times from an **on-device** astronomical calculation
(`lib/core/utils/prayer_time_calculator.dart` — Fajr/Maghrib from
lat/lng/date, no network call) using the device's location.

**Progress** — weekly calorie bar chart, weight trend line (1M/6M
toggle, real date/weight axes), sleep bar chart (recommended-8h
reference line, hour axis).

**Health Connect sync** (opt-in, Profile → Health App Connector) —
reads steps and sleep sessions from Android Health Connect, which
Google Fit, Samsung Health, and most wearable apps already write into.
Steps become an auto-logged "Walking" exercise entry (replaced on
re-sync, never duplicated); sleep only fills in if you haven't already
logged it that day — a sync never overwrites a manual entry.

**Custom daily reset time** (Profile → Daily Reset Time) — pick when
"today" rolls over for calorie/water/exercise/sleep tracking instead of
always assuming midnight, for anyone up late or asleep before it.

**Notifications** — local-only (`flutter_local_notifications`), used
for the fasting-complete reminder; the infrastructure
(`lib/core/notifications/notification_service.dart`) is reusable for
future notification types.

**Self-update system** — since Scampi isn't on the Play Store, it
checks `version.json` on GitHub (startup + manual "Check for Updates"
in Profile), shows current vs. latest version + release notes, and
downloads/installs the APK via the system installer. See "Shipping a
new release" below.

## Architecture

```
lib/
  main.dart                    — entry point, wires ProviderScope + theme
  onboarding_gate.dart         — shows onboarding or AppShell based on
                                  whether a profile exists
  app_shell.dart               — bottom nav + IndexedStack across 5 tabs;
                                  also fires the silent startup update
                                  check and Health Connect sync

  core/
    theme/                     — colors, typography (Dosis, bundled
                                  locally — see note below), ThemeData
    constants/                 — db name/version, AppTab enum
    utils/
      calorie_calculator.dart  — Mifflin-St Jeor + TDEE + goal/macro/warnings
      day_boundary.dart        — shared "logical today" window given a
                                  custom reset hour
      dedupe_key.dart          — shared food dedupe key (seed + importer)
      food_icons.dart          — category/food emoji lookup
      prayer_time_calculator.dart — offline Fajr/Maghrib calculation
    notifications/
      notification_service.dart — flutter_local_notifications wrapper
    health/
      health_service.dart       — Health Connect read wrapper
      health_sync_controller.dart — persisted opt-in toggle
      health_sync_service.dart    — steps→exercise, sleep→sleep_log sync
    update/
      update_service.dart       — version.json fetch, semver compare,
                                   APK download + install handoff
      update_screen.dart, version_info.dart, update_provider.dart

  data/
    models/                    — UserProfile, Food, FoodLogEntry,
                                  ExerciseLogEntry, WaterLogEntry,
                                  WeightLogEntry, SleepLogEntry,
                                  FastingSession
    db/
      scampi_schema.dart        — raw SQL schema, all tables + indexes
      app_database.dart          — singleton open/create/migrate (see
                                    _onUpgrade for the full version history)
      seed_foods.dart             — seed food batches (seed_v1, seed_v2)
      food_pack_importer.dart     — JSON/CSV import, dedupe, merge
    repositories/               — one repo per table/concern
      repository_providers.dart  — Riverpod Provider<T> wrappers
      data_refresh_signal.dart   — bump-to-invalidate pattern

  features/
    home/                       — dashboard, calorie ring + arcs, tiles
    food/                       — search, meal builder, AI import,
                                    custom ingredient edit/delete
    fitness/                    — exercise log + entry sheet
    fasting/                    — start/active fast sheets
    progress/                   — weekly/weight/sleep charts
    onboarding/                 — first-run AND edit-profile form
    profile/                    — profile, Health Connect toggle, daily
                                    reset time, updates section
```

## Key design decisions worth knowing about

**Search strategy:** `FoodRepository.search` uses an indexed `LIKE
'%query%'` query rather than SQLite FTS — stays fast well past 50,000
rows with a plain index on `name`, without the trigger complexity FTS
virtual tables need to stay in sync.

**Refresh pattern:** writes call
`ref.read(dataRefreshSignalProvider.notifier).bump()`, and read-side
providers `ref.watch` that signal and re-run. Simple and appropriate
for a single-user local app where writes are infrequent relative to
reads.

**Dosis font is bundled locally**, not fetched via `google_fonts` at
runtime — an offline-first app can't depend on a network fetch for its
own typeface. See `assets/fonts/Dosis-Variable.ttf` and the `fonts:`
block in `pubspec.yaml`.

**Day-boundary math is centralized** in `day_boundary.dart` rather than
duplicated per-repository, so the custom reset-hour setting only needed
one new helper threaded through `FoodLogRepository`,
`ExerciseLogRepository`, and `WaterLogRepository`'s day-range queries.

**Update system uses GitHub Releases, not an API.** `version.json` at
the repo root points at a tagged release's APK asset — see "Shipping a
new release" below.

## Shipping a new release

1. Bump `version:` in `pubspec.yaml` (format `X.Y.Z+buildNumber`).
2. `flutter build apk --release`
3. Rename the output APK to `scampi-vX.Y.Z.apk` for clarity.
4. Update `version.json` at the repo root:
   ```json
   {
     "latest_version": "X.Y.Z",
     "version_code": <buildNumber>,
     "apk_url": "https://github.com/Scampered/Scampi/releases/download/vX.Y.Z/scampi-vX.Y.Z.apk",
     "release_notes": ["..."]
   }
   ```
5. Commit + push `pubspec.yaml`/`pubspec.lock`/`version.json`.
6. `gh release create vX.Y.Z path/to/scampi-vX.Y.Z.apk --title "vX.Y.Z" --notes "..."`

Anyone with the app installed will see the update prompt automatically
on next launch (or via Profile → Check for Updates).

## Known gaps / provisional decisions

- Release builds reuse the debug signing config — fine for a small
  sideload distribution, not Play-Store-ready.
- The macro-split and health-warning thresholds in
  `calorie_calculator.dart` are reasonable general defaults, not
  medical advice.
- Prayer-time calculation is accurate to roughly a minute or two of
  published times (standard solar-position formulas) — always
  presented as an editable starting point, never locked in.
- Health Connect sync runs once per app open, not continuously in the
  background — no foreground service or WorkManager integration.
- Native home-screen widgets are not built (deferred; would need a
  `home_widget`-based native Android `RemoteViews` layer, since there's
  no way to share Dart logic directly with a widget).
- Adaptive activity-level suggestions (auto-adjusting based on logged
  exercise trends) are deferred per product direction — "update your
  activity level yourself" was judged clearer than an automatic guess.
