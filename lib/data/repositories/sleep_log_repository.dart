import 'package:sqflite/sqflite.dart';
import '../../core/utils/day_boundary.dart';
import '../db/app_database.dart';
import '../models/sleep_log_entry.dart';

class SleepLogRepository {
  SleepLogRepository({Database? database}) : _databaseOverride = database;

  final Database? _databaseOverride;

  Future<Database> get _db async =>
      _databaseOverride ?? await AppDatabase.instance.database;

  /// Logging sleep for a date that already has an entry replaces it
  /// (there's only ever one sleep entry per night) rather than
  /// accumulating duplicates.
  Future<int> logEntry(SleepLogEntry entry) async {
    final db = await _db;
    return db.insert('sleep_log', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteEntry(int id) async {
    final db = await _db;
    await db.delete('sleep_log', where: 'id = ?', whereArgs: [id]);
  }

  /// [resetMinuteOfDay] resolves [day] to the correct logical-day date
  /// key (see `dayWindowFor`) before looking it up — matters for anyone
  /// with a non-midnight reset time, so viewing "yesterday" on Home's
  /// day-navigator around 1am still finds the right night's entry.
  Future<SleepLogEntry?> entryForDay(DateTime day, {int resetMinuteOfDay = 0}) async {
    final db = await _db;
    final window = dayWindowFor(day, resetMinuteOfDay);
    final key = DateTime(window.start.year, window.start.month, window.start.day).toIso8601String();
    final rows = await db.query('sleep_log', where: 'date = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return SleepLogEntry.fromMap(rows.first);
  }

  Future<List<SleepLogEntry>> history({DateTime? since}) async {
    final db = await _db;
    final rows = await db.query(
      'sleep_log',
      where: since != null ? 'date >= ?' : null,
      whereArgs: since != null ? [DateTime(since.year, since.month, since.day).toIso8601String()] : null,
      orderBy: 'date ASC',
    );
    return rows.map(SleepLogEntry.fromMap).toList();
  }
}
