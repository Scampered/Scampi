# Scampi 🦐

Offline-first calorie, nutrition, exercise, weight, and fasting tracker.
No accounts, no login, no cloud, no subscriptions — everything lives on
the device.

This README documents what's built, how to run it, and what's planned
next. It's written assuming you (or a future session of Claude) need to
pick this project back up without extra context.

## Status: Phase 2 of N

**Phase 1 (done):** project skeleton, Material 3 theme (light/dark +
system toggle), 5-tab bottom nav shell, Home screen UI.

**Phase 2 (done, this update):**
- Full SQLite schema (`lib/data/db/scampi_schema.dart`) — user profile,
  foods (indexed for 50,000+ rows), food packs tracking, meals/meal
  items, food/exercise/water/weight logs, fasting sessions
- `AppDatabase` singleton managing open/create/migrate lifecycle, with a
  documented migration pattern for future schema changes
- Calorie/macro calculation engine (`calorie_calculator.dart`):
  Mifflin-St Jeor BMR, TDEE via activity multipliers, goal-mode calorie
  offsets, a bodyweight-anchored macro split, and health warnings for
  unsafe targets (too-low calories, aggressive deficits/surpluses, low
  protein)
- Seed food database: ~133 real foods across all requested categories
  (Fruits, Vegetables, Dairy, Meat, Fish, Rice, Pasta, Bread, Desserts,
  Fast Food, Drinks, Snacks, Traditional Meals, Generic Ingredients) and
  regions (Pakistan, Bahrain, Germany, Algeria, Middle East, South Asia,
  Europe, Global) — see the note on scaling below
- Food-pack importer (`food_pack_importer.dart`): JSON and CSV import,
  validates rows, dedupes against existing data by normalized
  name+category+region, merges via a single batched insert (fast even
  at thousands of rows), tracks applied packs so re-importing is a safe
  no-op
- Full repository layer: `UserProfileRepository`, `FoodRepository`,
  `FoodLogRepository`, `ExerciseLogRepository`, `WaterLogRepository`,
  `WeightLogRepository`, `FastingRepository`
- Riverpod wiring: repository providers, a `dataRefreshSignalProvider`
  invalidation pattern (bump after any write, dependent providers
  refetch), `homeSummaryProvider` aggregating everything Home needs
- Onboarding flow: first-run profile setup form (age, sex, height,
  weight, goal weight, activity level, goal mode, units), gated in
  `OnboardingGate` so the app shows onboarding until a profile exists
- Profile tab now shows the real saved profile, calculated BMR/
  maintenance/goal calories, and an Edit Profile flow (reuses the
  onboarding form pre-filled)
- Home screen is now fully wired to real data — calorie ring, macro
  bars, water/weight/fasting tiles, and the Add Water quick action all
  read from and write to SQLite. `home_mock_data.dart` has been deleted.

**Not yet built:** food search/logging UI (the Food tab is still a
placeholder — `FoodRepository.search` exists and works, just has no
screen yet), custom food creator UI, favorites/recents UI, meal builder,
fitness logging UI, fasting start/stop UI, water/weight history entry
beyond the quick-add button, AI Meal Import parsing UI, Progress charts,
notifications, native widgets.

## Getting set up

```bash
flutter pub get
cp android/local.properties.example android/local.properties
# edit android/local.properties with your sdk.dir and flutter.sdk paths
flutter analyze
flutter run            # needs a connected device or emulator
flutter build apk --debug
```

On first launch with a fresh install, you'll see the onboarding form
before the main app — fill it in once and it persists in SQLite from
then on (uninstalling/clearing app data resets this, as expected for a
fully local, no-account app).

## Architecture

```
lib/
  main.dart                  — entry point, wires ProviderScope + theme
  onboarding_gate.dart        — shows onboarding or AppShell depending on
                                 whether a profile exists yet
  app_shell.dart              — bottom nav + IndexedStack across 5 tabs

  core/
    theme/                   — colors, typography, ThemeData, theme mode
    constants/                — app-wide constants (db name, AppTab enum)
    utils/
      calorie_calculator.dart — Mifflin-St Jeor + TDEE + goal/macro/warnings
      dedupe_key.dart          — shared food dedupe key builder (seed + importer)

  data/
    models/                  — UserProfile, Food, FoodLogEntry,
                                ExerciseLogEntry, WaterLogEntry,
                                WeightLogEntry, FastingSession
    db/
      scampi_schema.dart      — raw SQL schema, all tables + indexes
      app_database.dart        — singleton open/create/migrate
      seed_foods.dart           — ~133 built-in foods, seeded on first run
      food_pack_importer.dart   — JSON/CSV import, dedupe, merge
    repositories/             — one repo per table/concern, all reading
                                 through AppDatabase.instance.database
      repository_providers.dart — Riverpod Provider<T> wrappers
      data_refresh_signal.dart  — bump-to-invalidate pattern

  features/
    home/
      home_screen.dart         — dashboard UI, now data-driven
      home_summary_provider.dart — aggregates profile+logs into one
                                    FutureProvider<HomeDailySummary>
    onboarding/
      onboarding_screen.dart   — first-run AND edit-profile form (same
                                  widget, pass existingProfile to pre-fill)
    profile/
      profile_screen.dart       — real profile display + edit entry point
      current_profile_provider.dart
    food/, fitness/, progress/  — still placeholders (ComingSoonScaffold)

  shared/
    widgets/coming_soon_scaffold.dart
```

## Key design decisions worth knowing about

**Search strategy:** `FoodRepository.search` uses an indexed `LIKE '%query%'`
query rather than SQLite FTS. This is a deliberate simplification — FTS
virtual tables need triggers to stay in sync with the base table and
can't be `ALTER TABLE`'d, which adds real complexity for a search
problem that stays fast well past 50,000 rows with a plain index on
`name`. Revisit only if search actually feels slow in practice.

**Refresh pattern:** rather than wiring sqflite to a reactive stream
layer, writes call `ref.read(dataRefreshSignalProvider.notifier).bump()`,
and read-side providers (`homeSummaryProvider`, `currentProfileProvider`)
`ref.watch` that signal and re-run. Simple, predictable, and appropriate
for a single-user local app where writes are infrequent relative to
reads. If a future screen needs finer-grained invalidation (e.g. only
refetch the food log, not the whole Home summary), consider splitting
the signal per-concern rather than replacing the pattern entirely.

**Macro split:** protein is computed as grams-per-kilogram of body
weight (1.8 g/kg normally, 2.0 g/kg during a cut to help preserve
muscle) rather than as a flat percentage of calories — percentage-based
splits under-protein lighter individuals in a way that's not actually
healthy. Fat is ~28% of total calories; carbs take the remainder. This
is a reasonable general-purpose default, not personalized advice — the
in-app health warnings exist specifically to flag when a goal pushes
into genuinely unsafe territory.

**Profile editing preserves the water goal:** `UserProfileRepository.
saveProfile` uses `ConflictAlgorithm.replace`, which deletes and
re-inserts the row — if `UserProfile.toMap()` were written as the
literal map (which doesn't carry `water_goal_ml`, tracked separately),
every profile edit would silently reset the water goal to its column
default. The repository explicitly reads and re-applies the existing
water goal before saving to avoid this. Worth knowing if you ever touch
that file.

## Roadmap (remaining phases)

3. Food logging UI: search screen, quantity/grams/servings entry, meal
   builder, custom food creator UI, favorites/recents UI — the
   repository layer for all of this already exists
4. Fitness logging UI — `ExerciseLogRepository` and the MET-based
   calorie estimate in `ExerciseLogEntry.estimateCalories` already exist
5. Fasting start/stop UI, water/weight manual history entry — repository
   layer exists, just needs screens
6. Progress screen: charts (fl_chart) over the log repositories' history
   methods
7. AI Meal Import: prompt template, clipboard copy, paste-and-parse
8. Notifications — deferred per earlier direction
9. Native home-screen widgets — deferred, needs on-device testing

### About the food database

Per earlier direction, the seed set (~133 foods) is hand-curated from
standard nutrition references rather than invented, but it's
intentionally not 2,000–5,000 entries — that scale needs a real sourced
dataset (USDA FoodData Central or your own pack). The schema and
`FoodPackImporter` are built to scale to 50,000+ rows without code
changes: drop a JSON or CSV pack matching the documented shape (see
the doc comment at the top of `food_pack_importer.dart`) and it merges
in, deduped against everything already present.

## Known gaps / things to verify on next build

- **Fixed this session:** `app_shell.dart` had incorrect `../` relative
  imports (it's at `lib/app_shell.dart`, so `core/` and `features/` are
  siblings, not parents) — this would have failed `flutter analyze`.
  Caught and fixed; every relative import in the project has now been
  programmatically verified to resolve to a real file.
- No app icon / launcher icon asset exists yet. `AndroidManifest.xml`
  references `@mipmap/ic_launcher`, and the mipmap density folders exist
  but are empty — no PNGs in them. This will fail the build until you
  either add `flutter_launcher_icons` + a source icon and run
  `dart run flutter_launcher_icons`, or run `flutter create .` once over
  the project root to scaffold defaults (don't let it overwrite
  `AndroidManifest.xml` or `MainActivity.kt` if prompted).
- This project still hasn't been run through `flutter build apk` (only
  `flutter analyze`, per your last report). The SQLite layer in
  particular has only been reviewed, not executed — please run it and
  paste back the onboarding flow + Home screen behavior, since DB code
  is the highest-risk-of-runtime-bug part of this phase.
- `meals` / `meal_items` tables exist in the schema but have no
  repository or UI yet — intentional groundwork for the Phase 3 meal
  builder, not a bug.
- The macro-split and health-warning thresholds in
  `calorie_calculator.dart` are reasonable general defaults, not
  medical advice — worth a comment in-app eventually, not just in this
  README.
- Release builds reuse the debug signing config — fine for development,
  not for distribution.
- The theme uses `ColorScheme.surfaceContainerHighest`, a newer Material
  3 surface role. This needs a reasonably recent Flutter SDK (3.22+ ish)
  to resolve — if `flutter analyze` flags it as undefined, that's a
  signal to run `flutter upgrade` rather than a sign something else is
  wrong.
