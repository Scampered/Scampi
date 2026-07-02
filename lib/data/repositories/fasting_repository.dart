import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/fasting_session.dart';

class FastingRepository {
  FastingRepository({Database? database}) : _databaseOverride = database;

  final Database? _databaseOverride;

  Future<Database> get _db async =>
      _databaseOverride ?? await AppDatabase.instance.database;

  Future<int> startSession(FastingSession session) async {
    final db = await _db;
    return db.insert('fasting_sessions', session.toMap());
  }

  Future<void> endSession(int id, DateTime endAt) async {
    final db = await _db;
    await db.update(
      'fasting_sessions',
      {'end_at': endAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// The currently in-progress fast, if any (there should only ever be
  /// zero or one — the UI is responsible for not starting a second fast
  /// while one is already active).
  Future<FastingSession?> getActiveSession() async {
    final db = await _db;
    final rows = await db.query(
      'fasting_sessions',
      where: 'end_at IS NULL',
      orderBy: 'start_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FastingSession.fromMap(rows.first);
  }

  Future<List<FastingSession>> history({DateTime? since}) async {
    final db = await _db;
    final rows = await db.query(
      'fasting_sessions',
      where: since != null ? 'start_at >= ?' : null,
      whereArgs: since != null ? [since.toIso8601String()] : null,
      orderBy: 'start_at DESC',
    );
    return rows.map(FastingSession.fromMap).toList();
  }

  /// Current consecutive-day fasting streak (completed sessions only,
  /// most recent day backwards, allowing at most one session per day).
  Future<int> currentStreakDays() async {
    final completed = (await history())
        .where((s) => !s.isActive)
        .toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));

    if (completed.isEmpty) return 0;

    var streak = 0;
    DateTime? expectedDay = DateTime(
      completed.first.startAt.year,
      completed.first.startAt.month,
      completed.first.startAt.day,
    );

    final loggedDays = completed
        .map((s) => DateTime(s.startAt.year, s.startAt.month, s.startAt.day))
        .toSet();

    while (loggedDays.contains(expectedDay)) {
      streak++;
      expectedDay = expectedDay!.subtract(const Duration(days: 1));
    }

    return streak;
  }
}
