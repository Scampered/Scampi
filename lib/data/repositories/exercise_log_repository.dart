import 'package:sqflite/sqflite.dart';
import '../../core/utils/day_boundary.dart';
import '../db/app_database.dart';
import '../models/exercise_log_entry.dart';

class ExerciseLogRepository {
  ExerciseLogRepository({Database? database}) : _databaseOverride = database;

  final Database? _databaseOverride;

  Future<Database> get _db async =>
      _databaseOverride ?? await AppDatabase.instance.database;

  Future<int> logEntry(ExerciseLogEntry entry) async {
    final db = await _db;
    return db.insert('exercise_log', entry.toMap());
  }

  Future<void> deleteEntry(int id) async {
    final db = await _db;
    await db.delete('exercise_log', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ExerciseLogEntry>> entriesForDay(DateTime day, {int resetMinuteOfDay = 0}) async {
    final db = await _db;
    final window = dayWindowFor(day, resetMinuteOfDay);

    final rows = await db.query(
      'exercise_log',
      where: 'logged_at >= ? AND logged_at < ?',
      whereArgs: [window.start.toIso8601String(), window.end.toIso8601String()],
      orderBy: 'logged_at ASC',
    );
    return rows.map(ExerciseLogEntry.fromMap).toList();
  }

  Future<double> totalCaloriesBurnedForDay(DateTime day, {int resetMinuteOfDay = 0}) async {
    final entries = await entriesForDay(day, resetMinuteOfDay: resetMinuteOfDay);
    return entries.fold<double>(0, (sum, e) => sum + e.caloriesBurned);
  }
}
