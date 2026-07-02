import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/food.dart';
import '../models/food_log_entry.dart';

/// Data access for the food diary (`food_log` table).
class FoodLogRepository {
  FoodLogRepository({Database? database}) : _databaseOverride = database;

  final Database? _databaseOverride;

  Future<Database> get _db async =>
      _databaseOverride ?? await AppDatabase.instance.database;

  Future<int> logEntry(FoodLogEntry entry) async {
    final db = await _db;
    return db.insert('food_log', entry.toMap());
  }

  Future<void> deleteEntry(int id) async {
    final db = await _db;
    await db.delete('food_log', where: 'id = ?', whereArgs: [id]);
  }

  /// All entries logged on the given calendar day (local time), ordered
  /// by when they were logged.
  Future<List<FoodLogEntry>> entriesForDay(DateTime day) async {
    final db = await _db;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final rows = await db.query(
      'food_log',
      where: 'logged_at >= ? AND logged_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'logged_at ASC',
    );
    return rows.map(FoodLogEntry.fromMap).toList();
  }

  /// Summed nutrition totals for the given day — what the Home screen's
  /// calorie ring and macro bars are driven by.
  Future<FoodNutrition> totalsForDay(DateTime day) async {
    final entries = await entriesForDay(day);
    return entries.fold<FoodNutrition>(
      FoodNutrition.zero,
      (acc, e) => acc +
          FoodNutrition(
            calories: e.calories,
            proteinG: e.proteinG,
            carbsG: e.carbsG,
            fatG: e.fatG,
          ),
    );
  }

  /// Most recently logged distinct foods, for the "Recent Foods" list.
  Future<List<String>> recentFoodNames({int limit = 10}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT food_name, MAX(logged_at) as last_logged
      FROM food_log
      GROUP BY food_name
      ORDER BY last_logged DESC
      LIMIT ?
    ''', [limit]);
    return rows.map((r) => r['food_name'] as String).toList();
  }

  /// Distinct foods the user has actually logged before, resolved back to
  /// full [Food] rows for quick re-logging. Ranked by most recent first,
  /// then by how often they've been logged — a food logged many times but
  /// not recently still surfaces above a one-off from long ago once the
  /// most recent items are exhausted. Foods that were deleted since being
  /// logged (food_id no longer resolves) are silently skipped.
  Future<List<Food>> recentLoggedFoods({int limit = 10}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT f.*, MAX(fl.logged_at) as last_logged, COUNT(*) as log_count
      FROM food_log fl
      JOIN foods f ON f.id = fl.food_id
      WHERE fl.food_id IS NOT NULL
      GROUP BY fl.food_id
      ORDER BY last_logged DESC, log_count DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(Food.fromMap).toList();
  }
}
