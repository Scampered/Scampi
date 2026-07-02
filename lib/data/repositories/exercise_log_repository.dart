import 'package:sqflite/sqflite.dart';
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

  Future<List<ExerciseLogEntry>> entriesForDay(DateTime day) async {
    final db = await _db;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final rows = await db.query(
      'exercise_log',
      where: 'logged_at >= ? AND logged_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'logged_at ASC',
    );
    return rows.map(ExerciseLogEntry.fromMap).toList();
  }

  Future<double> totalCaloriesBurnedForDay(DateTime day) async {
    final entries = await entriesForDay(day);
    return entries.fold<double>(0, (sum, e) => sum + e.caloriesBurned);
  }
}
