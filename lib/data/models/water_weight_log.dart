/// A single water intake log (e.g. "added 250ml at 10:32am"). The day's
/// total is the sum of entries for that calendar day, which keeps the
/// log naturally undoable/editable one entry at a time.
class WaterLogEntry {
  const WaterLogEntry({
    this.id,
    required this.loggedAt,
    required this.amountMl,
  });

  final int? id;
  final DateTime loggedAt;
  final int amountMl;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'logged_at': loggedAt.toIso8601String(),
      'amount_ml': amountMl,
    };
  }

  factory WaterLogEntry.fromMap(Map<String, Object?> map) {
    return WaterLogEntry(
      id: map['id'] as int?,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      amountMl: map['amount_ml'] as int,
    );
  }
}

/// A single weight check-in, used to drive the Progress weight chart and
/// weight-goal projections.
class WeightLogEntry {
  const WeightLogEntry({
    this.id,
    required this.loggedAt,
    required this.weightKg,
    this.note,
  });

  final int? id;
  final DateTime loggedAt;
  final double weightKg;
  final String? note;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'logged_at': loggedAt.toIso8601String(),
      'weight_kg': weightKg,
      'note': note,
    };
  }

  factory WeightLogEntry.fromMap(Map<String, Object?> map) {
    return WeightLogEntry(
      id: map['id'] as int?,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      weightKg: (map['weight_kg'] as num).toDouble(),
      note: map['note'] as String?,
    );
  }
}
