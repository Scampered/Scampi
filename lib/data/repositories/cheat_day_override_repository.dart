import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/cheat_day_override.dart';

class CheatDayOverrideRepository {
  CheatDayOverrideRepository({Database? database}) : _databaseOverride = database;

  final Database? _databaseOverride;

  Future<Database> get _db async => _databaseOverride ?? await AppDatabase.instance.database;

  Future<CheatDayOverride?> forWeek(DateTime weekStartDate) async {
    final db = await _db;
    final rows = await db.query(
      'cheat_day_overrides',
      where: 'week_start_date = ?',
      whereArgs: [CheatDayOverride.dateKey(weekStartDate)],
    );
    if (rows.isEmpty) return null;
    return CheatDayOverride.fromMap(rows.first);
  }

  /// Upserts the override for [weekStartDate] — `week_start_date` is
  /// UNIQUE, so `ConflictAlgorithm.replace` naturally overwrites any
  /// existing row for that week (e.g. a chained move within the same
  /// week) instead of accumulating duplicates.
  Future<void> setForWeek(DateTime weekStartDate, int effectiveWeekday) async {
    final db = await _db;
    await db.insert(
      'cheat_day_overrides',
      CheatDayOverride(weekStartDate: weekStartDate, effectiveWeekday: effectiveWeekday).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearForWeek(DateTime weekStartDate) async {
    final db = await _db;
    await db.delete(
      'cheat_day_overrides',
      where: 'week_start_date = ?',
      whereArgs: [CheatDayOverride.dateKey(weekStartDate)],
    );
  }
}
