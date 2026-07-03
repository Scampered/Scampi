import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/user_profile.dart';

/// Manages the single user profile row. The app is single-user/no
/// accounts, so this repository deliberately only ever reads/writes the
/// row with `id = 1` (enforced by the `CHECK (id = 1)` constraint in the
/// schema as a second line of defense).
class UserProfileRepository {
  UserProfileRepository({Database? database}) : _databaseOverride = database;

  final Database? _databaseOverride;

  Future<Database> get _db async =>
      _databaseOverride ?? await AppDatabase.instance.database;

  Future<UserProfile?> getProfile() async {
    final db = await _db;
    final rows = await db.query('user_profile', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  Future<bool> hasProfile() async {
    final profile = await getProfile();
    return profile != null;
  }

  /// Inserts or replaces the profile row. Used both for initial
  /// onboarding and subsequent edits.
  ///
  /// IMPORTANT: [UserProfile.toMap] doesn't carry `water_goal_ml` (that's
  /// tracked separately via [setWaterGoalMl], not as a UserProfile field).
  /// Since this uses `ConflictAlgorithm.replace` — which deletes and
  /// re-inserts the row — naively writing only `toMap()` would silently
  /// reset any previously-set water goal back to the column default on
  /// every profile edit. So we read the existing goal first and carry it
  /// forward explicitly.
  Future<void> saveProfile(UserProfile profile) async {
    final db = await _db;
    final existingGoal = await getWaterGoalMl();
    await db.insert(
      'user_profile',
      {
        ...profile.toMap(),
        'water_goal_ml': existingGoal,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getWaterGoalMl() async {
    final db = await _db;
    final rows = await db.query(
      'user_profile',
      columns: ['water_goal_ml'],
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return 2500;
    return rows.first['water_goal_ml'] as int? ?? 2500;
  }

  Future<void> setWaterGoalMl(int goalMl) async {
    final db = await _db;
    await db.update(
      'user_profile',
      {'water_goal_ml': goalMl},
      where: 'id = 1',
    );
  }

  /// Minutes past midnight (0–1439) that "today" rolls over at for
  /// calorie/water/exercise/sleep tracking, defaulting to midnight.
  /// Full minute precision (e.g. 465 = 7:45am). Kept as its own setter
  /// (like [setWaterGoalMl]) so Settings can change it without going
  /// through the full onboarding/edit-profile form.
  Future<int> getCalorieResetMinuteOfDay() async {
    final db = await _db;
    final rows = await db.query(
      'user_profile',
      columns: ['calorie_reset_minute_of_day'],
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return rows.first['calorie_reset_minute_of_day'] as int? ?? 0;
  }

  Future<void> setCalorieResetMinuteOfDay(int minuteOfDay) async {
    final db = await _db;
    await db.update(
      'user_profile',
      {'calorie_reset_minute_of_day': minuteOfDay},
      where: 'id = 1',
    );
  }
}
