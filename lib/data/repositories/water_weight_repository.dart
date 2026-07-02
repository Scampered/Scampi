import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/water_weight_log.dart';

class WaterLogRepository {
  WaterLogRepository({Database? database}) : _databaseOverride = database;

  final Database? _databaseOverride;

  Future<Database> get _db async =>
      _databaseOverride ?? await AppDatabase.instance.database;

  Future<int> logEntry(WaterLogEntry entry) async {
    final db = await _db;
    return db.insert('water_log', entry.toMap());
  }

  Future<void> deleteEntry(int id) async {
    final db = await _db;
    await db.delete('water_log', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WaterLogEntry>> entriesForDay(DateTime day) async {
    final db = await _db;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final rows = await db.query(
      'water_log',
      where: 'logged_at >= ? AND logged_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'logged_at ASC',
    );
    return rows.map(WaterLogEntry.fromMap).toList();
  }

  Future<int> totalMlForDay(DateTime day) async {
    final entries = await entriesForDay(day);
    return entries.fold<int>(0, (sum, e) => sum + e.amountMl);
  }
}

class WeightLogRepository {
  WeightLogRepository({Database? database}) : _databaseOverride = database;

  final Database? _databaseOverride;

  Future<Database> get _db async =>
      _databaseOverride ?? await AppDatabase.instance.database;

  Future<int> logEntry(WeightLogEntry entry) async {
    final db = await _db;
    return db.insert('weight_log', entry.toMap());
  }

  Future<void> deleteEntry(int id) async {
    final db = await _db;
    await db.delete('weight_log', where: 'id = ?', whereArgs: [id]);
  }

  /// Most recent weight entry, used to drive "current weight" displays
  /// even on days with no new check-in.
  Future<WeightLogEntry?> mostRecent() async {
    final db = await _db;
    final rows = await db.query(
      'weight_log',
      orderBy: 'logged_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WeightLogEntry.fromMap(rows.first);
  }

  Future<List<WeightLogEntry>> history({DateTime? since}) async {
    final db = await _db;
    final rows = await db.query(
      'weight_log',
      where: since != null ? 'logged_at >= ?' : null,
      whereArgs: since != null ? [since.toIso8601String()] : null,
      orderBy: 'logged_at ASC',
    );
    return rows.map(WeightLogEntry.fromMap).toList();
  }
}
