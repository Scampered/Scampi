import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import 'scampi_schema.dart';
import 'seed_foods.dart';

/// Owns the single sqflite [Database] instance for the app. Access via
/// `AppDatabase.instance.database` — opens lazily on first use and
/// reuses the same connection thereafter.
///
/// Migrations: bump [AppConstants.databaseVersion] and add a case to
/// [_onUpgrade] whenever the schema changes. Never edit an already-
/// shipped `createStatements` entry in place — old installs need an
/// upgrade path, not a rewritten "version 1".
class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final opened = await _open();
    _database = opened;
    return opened;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);

    return openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onConfigure: (db) async {
        // Enforce FK constraints (e.g. meal_items -> meals/foods) since
        // sqflite/sqlite3 doesn't do this by default.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        for (final statement in ScampiSchema.createStatements) {
          await db.execute(statement);
        }
        await seedInitialFoods(db);
      },
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v2 adds: user_profile.name (new column), and makes
      // goal_weight_kg nullable (goal weight became optional). SQLite
      // can't relax a NOT NULL constraint with a plain ALTER TABLE, so
      // this rebuilds the table: create the new shape, copy existing
      // rows across, drop the old table, rename the new one into place.
      await db.execute('''
        CREATE TABLE user_profile_v2 (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          name TEXT NOT NULL DEFAULT '',
          age INTEGER NOT NULL,
          sex TEXT NOT NULL,
          height_cm REAL NOT NULL,
          weight_kg REAL NOT NULL,
          goal_weight_kg REAL,
          activity_level TEXT NOT NULL,
          goal_mode TEXT NOT NULL,
          custom_daily_offset INTEGER NOT NULL DEFAULT 0,
          units_system TEXT NOT NULL DEFAULT 'metric',
          water_goal_ml INTEGER NOT NULL DEFAULT 2500
        );
      ''');
      await db.execute('''
        INSERT INTO user_profile_v2
          (id, name, age, sex, height_cm, weight_kg, goal_weight_kg,
           activity_level, goal_mode, custom_daily_offset, units_system,
           water_goal_ml)
        SELECT
          id, '', age, sex, height_cm, weight_kg, goal_weight_kg,
          activity_level, goal_mode, custom_daily_offset, units_system,
          water_goal_ml
        FROM user_profile;
      ''');
      await db.execute('DROP TABLE user_profile;');
      await db.execute('ALTER TABLE user_profile_v2 RENAME TO user_profile;');
    }

    if (oldVersion < 3) {
      // v3 adds: user_profile.target_date (optional — the date the user
      // wants to hit their goal weight by). A plain nullable column, so
      // no table rebuild needed here, unlike the v2 migration above.
      await db.execute('ALTER TABLE user_profile ADD COLUMN target_date TEXT;');
    }

    if (oldVersion < 4) {
      // v4 adds: sleep_log, for manual sleep entry (bedtime/wake time or
      // plain hours), shown on the Progress sleep chart and the Home
      // calorie ring's sleep arc.
      await db.execute(ScampiSchema.createSleepLog);
      await db.execute(ScampiSchema.createSleepLogDateIndex);
    }
  }

  /// Closes the database connection. Mainly useful for tests; the app
  /// itself doesn't need to call this during normal operation.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Wipes the entire local database (profile, food log, everything) and
  /// lets it recreate fresh — including reseeding the built-in food
  /// database — on next access. Used by the "Reset All Data" option in
  /// Profile, mainly useful for testing the onboarding flow again or
  /// genuinely starting over. This is irreversible; the caller is
  /// responsible for confirming with the user before calling it.
  Future<void> resetAllData() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);
    await close();
    await deleteDatabase(path);
  }
}
