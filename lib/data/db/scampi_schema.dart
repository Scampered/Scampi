/// Raw SQL schema for the Scampi database. Kept as plain SQL strings
/// (rather than an ORM) so the schema is easy to read end-to-end, easy
/// to diff in migrations, and has no extra dependency surface.
///
/// Design notes:
/// - `foods` is built for scale: indexed on `name` (search), `category`,
///   and `region` so filtering/search stays fast even at 50,000+ rows.
///   FTS (full-text search) is intentionally NOT used in v1 — sqflite's
///   FTS4/FTS5 virtual tables add real complexity (separate triggers to
///   keep them in sync, can't ALTER TABLE on them) for a search problem
///   that a `LIKE` query with a covering index on `name` already solves
///   well below the 50k-row mark. Revisit if search ever feels slow.
/// - `food_packs` tracks which imported packs have been applied, so the
///   importer can detect "already imported this pack" without re-merging.
/// - All `*_log` tables store the snapshot values needed to render
///   history without joining back to `foods`/`user_profile`, so later
///   edits to a food or profile don't rewrite past diary entries.
class ScampiSchema {
  ScampiSchema._();

  static const String createUserProfile = '''
    CREATE TABLE user_profile (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      name TEXT NOT NULL DEFAULT '',
      age INTEGER NOT NULL,
      sex TEXT NOT NULL,
      height_cm REAL NOT NULL,
      weight_kg REAL NOT NULL,
      goal_weight_kg REAL,
      target_date TEXT,
      activity_level TEXT NOT NULL,
      goal_mode TEXT NOT NULL,
      custom_daily_offset INTEGER NOT NULL DEFAULT 0,
      units_system TEXT NOT NULL DEFAULT 'metric',
      water_goal_ml INTEGER NOT NULL DEFAULT 2500
    );
  ''';

  static const String createFoods = '''
    CREATE TABLE foods (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      region TEXT,
      calories_per_100g REAL NOT NULL,
      protein_per_100g REAL NOT NULL,
      carbs_per_100g REAL NOT NULL,
      fat_per_100g REAL NOT NULL,
      default_serving_grams REAL,
      default_serving_label TEXT,
      is_custom INTEGER NOT NULL DEFAULT 0,
      is_favorite INTEGER NOT NULL DEFAULT 0,
      barcode TEXT,
      source_pack_id TEXT,
      dedupe_key TEXT
    );
  ''';

  static const String createFoodsNameIndex =
      'CREATE INDEX idx_foods_name ON foods(name);';
  static const String createFoodsCategoryIndex =
      'CREATE INDEX idx_foods_category ON foods(category);';
  static const String createFoodsRegionIndex =
      'CREATE INDEX idx_foods_region ON foods(region);';
  static const String createFoodsFavoriteIndex =
      'CREATE INDEX idx_foods_favorite ON foods(is_favorite);';

  /// Unique-ish dedupe key (normalized name + category + region) used by
  /// the food-pack importer to detect duplicates across packs and the
  /// seed database. Not a hard UNIQUE constraint at the DB level because
  /// region/category can legitimately be null/blank for some entries —
  /// the importer enforces dedup logic explicitly instead.
  static const String createFoodsDedupeIndex =
      'CREATE INDEX idx_foods_dedupe_key ON foods(dedupe_key);';

  static const String createFoodPacks = '''
    CREATE TABLE food_packs (
      pack_id TEXT PRIMARY KEY,
      pack_name TEXT NOT NULL,
      version TEXT,
      imported_at TEXT NOT NULL,
      food_count INTEGER NOT NULL DEFAULT 0
    );
  ''';

  static const String createMeals = '''
    CREATE TABLE meals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      is_favorite INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
  ''';

  /// Join table: a meal is made of N foods at given gram quantities.
  static const String createMealItems = '''
    CREATE TABLE meal_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      meal_id INTEGER NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
      food_id INTEGER NOT NULL REFERENCES foods(id),
      grams REAL NOT NULL
    );
  ''';

  static const String createMealItemsMealIndex =
      'CREATE INDEX idx_meal_items_meal_id ON meal_items(meal_id);';

  static const String createFoodLog = '''
    CREATE TABLE food_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      food_id INTEGER REFERENCES foods(id),
      food_name TEXT NOT NULL,
      logged_at TEXT NOT NULL,
      meal_slot TEXT NOT NULL,
      quantity_mode TEXT NOT NULL,
      grams REAL NOT NULL,
      servings REAL,
      calories REAL NOT NULL,
      protein_g REAL NOT NULL,
      carbs_g REAL NOT NULL,
      fat_g REAL NOT NULL
    );
  ''';

  static const String createFoodLogDateIndex =
      'CREATE INDEX idx_food_log_logged_at ON food_log(logged_at);';

  static const String createExerciseLog = '''
    CREATE TABLE exercise_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category TEXT NOT NULL,
      logged_at TEXT NOT NULL,
      duration_minutes INTEGER NOT NULL,
      distance_km REAL,
      intensity TEXT NOT NULL,
      calories_burned REAL NOT NULL,
      was_estimated INTEGER NOT NULL DEFAULT 0,
      note TEXT
    );
  ''';

  static const String createExerciseLogDateIndex =
      'CREATE INDEX idx_exercise_log_logged_at ON exercise_log(logged_at);';

  static const String createWaterLog = '''
    CREATE TABLE water_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      logged_at TEXT NOT NULL,
      amount_ml INTEGER NOT NULL
    );
  ''';

  static const String createWaterLogDateIndex =
      'CREATE INDEX idx_water_log_logged_at ON water_log(logged_at);';

  static const String createWeightLog = '''
    CREATE TABLE weight_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      logged_at TEXT NOT NULL,
      weight_kg REAL NOT NULL,
      note TEXT
    );
  ''';

  static const String createWeightLogDateIndex =
      'CREATE INDEX idx_weight_log_logged_at ON weight_log(logged_at);';

  /// One row per calendar date (the wake-up date, i.e. "last night's
  /// sleep"). `date` is a UNIQUE plain-date string (`YYYY-MM-DD`) rather
  /// than a full timestamp so logging sleep for a day the user already
  /// logged is a natural upsert (`INSERT OR REPLACE`) instead of
  /// accumulating duplicate rows for the same night.
  static const String createSleepLog = '''
    CREATE TABLE sleep_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL UNIQUE,
      hours REAL NOT NULL,
      bedtime TEXT,
      wake_time TEXT
    );
  ''';

  static const String createSleepLogDateIndex =
      'CREATE INDEX idx_sleep_log_date ON sleep_log(date);';

  static const String createFastingSessions = '''
    CREATE TABLE fasting_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      type TEXT NOT NULL,
      start_at TEXT NOT NULL,
      end_at TEXT,
      suhoor_at TEXT,
      iftar_at TEXT,
      target_duration_minutes INTEGER,
      note TEXT
    );
  ''';

  static const String createFastingSessionsStartIndex =
      'CREATE INDEX idx_fasting_sessions_start_at ON fasting_sessions(start_at);';

  /// Executed in order on fresh database creation.
  static const List<String> createStatements = [
    createUserProfile,
    createFoods,
    createFoodsNameIndex,
    createFoodsCategoryIndex,
    createFoodsRegionIndex,
    createFoodsFavoriteIndex,
    createFoodsDedupeIndex,
    createFoodPacks,
    createMeals,
    createMealItems,
    createMealItemsMealIndex,
    createFoodLog,
    createFoodLogDateIndex,
    createExerciseLog,
    createExerciseLogDateIndex,
    createWaterLog,
    createWaterLogDateIndex,
    createWeightLog,
    createWeightLogDateIndex,
    createSleepLog,
    createSleepLogDateIndex,
    createFastingSessions,
    createFastingSessionsStartIndex,
  ];
}
