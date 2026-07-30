/// A single night's sleep, manually entered by the user or auto-synced
/// from Health Connect. `date` is the wake-up date (the day this sleep
/// "belongs to" on the Progress chart and Home ring), normalized to
/// midnight. `bedtime`/`wakeTime` are optional — kept only for display
/// when the entry was built from the bedtime/wake-time picker rather
/// than a plain hours value.
class SleepLogEntry {
  const SleepLogEntry({
    this.id,
    required this.date,
    required this.hours,
    this.bedtime,
    this.wakeTime,
    this.note,
  });

  final int? id;
  final DateTime date;
  final double hours;
  final DateTime? bedtime;
  final DateTime? wakeTime;

  /// Marks an entry as auto-synced from Health Connect (see
  /// `healthSyncSleepNote` in health_sync_service.dart) — lets a re-sync
  /// tell a stale auto-synced entry apart from a manual one, so it can
  /// safely refresh the former without ever touching the latter.
  final String? note;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'date': _dateKey(date),
      'hours': hours,
      'bedtime': bedtime?.toIso8601String(),
      'wake_time': wakeTime?.toIso8601String(),
      'note': note,
    };
  }

  factory SleepLogEntry.fromMap(Map<String, Object?> map) {
    return SleepLogEntry(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      hours: (map['hours'] as num).toDouble(),
      bedtime: map['bedtime'] != null ? DateTime.parse(map['bedtime'] as String) : null,
      wakeTime: map['wake_time'] != null ? DateTime.parse(map['wake_time'] as String) : null,
      note: map['note'] as String?,
    );
  }

  static String _dateKey(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String();
}
