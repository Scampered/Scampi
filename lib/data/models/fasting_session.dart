enum FastingType {
  ramadan,
  intermittent,
  custom;

  String get label {
    switch (this) {
      case FastingType.ramadan:
        return 'Ramadan';
      case FastingType.intermittent:
        return 'Intermittent Fasting';
      case FastingType.custom:
        return 'Custom Fast';
    }
  }
}

/// A single fasting session (e.g. one day's Ramadan fast, or one 16:8
/// intermittent fasting window). `endAt` is null while the fast is
/// still in progress.
class FastingSession {
  const FastingSession({
    this.id,
    required this.type,
    required this.startAt,
    this.endAt,
    this.suhoorAt,
    this.iftarAt,
    this.targetDurationMinutes,
    this.note,
  });

  final int? id;
  final FastingType type;
  final DateTime startAt;
  final DateTime? endAt;

  /// Only meaningful for [FastingType.ramadan].
  final DateTime? suhoorAt;
  final DateTime? iftarAt;

  /// Target fast length in minutes, used to compute progress fraction
  /// for the Home screen fasting tile (e.g. 16:8 IF → 960 minutes).
  final int? targetDurationMinutes;
  final String? note;

  bool get isActive => endAt == null;

  Duration get elapsed =>
      (endAt ?? DateTime.now()).difference(startAt);

  double? get progressFraction {
    if (targetDurationMinutes == null || targetDurationMinutes == 0) {
      return null;
    }
    return (elapsed.inMinutes / targetDurationMinutes!).clamp(0.0, 1.0);
  }

  /// Whether the target spans more than a single day — a plain "Xh Ym
  /// elapsed" readout stops being useful once a fast is meant to run for
  /// several days (e.g. an extended fast), since the hour count just
  /// keeps climbing into the hundreds.
  bool get isMultiDay => targetDurationMinutes != null && targetDurationMinutes! > 24 * 60;

  /// Total whole days the target spans (at least 1).
  int get totalTargetDays {
    if (targetDurationMinutes == null) return 1;
    return (targetDurationMinutes! / (24 * 60)).ceil().clamp(1, 999);
  }

  /// Which day of the fast "today" is, 1-indexed and clamped to
  /// [totalTargetDays] (so it reads "Day 7/7" rather than "Day 8/7" once
  /// the target's been reached but the fast hasn't been ended yet).
  int get currentDayNumber => (elapsed.inHours ~/ 24 + 1).clamp(1, totalTargetDays);

  /// Time left until the target duration is reached — zero (not
  /// negative) once past it.
  Duration get remaining {
    if (targetDurationMinutes == null) return Duration.zero;
    final target = Duration(minutes: targetDurationMinutes!);
    final left = target - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type.name,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt?.toIso8601String(),
      'suhoor_at': suhoorAt?.toIso8601String(),
      'iftar_at': iftarAt?.toIso8601String(),
      'target_duration_minutes': targetDurationMinutes,
      'note': note,
    };
  }

  factory FastingSession.fromMap(Map<String, Object?> map) {
    return FastingSession(
      id: map['id'] as int?,
      type: FastingType.values.byName(map['type'] as String),
      startAt: DateTime.parse(map['start_at'] as String),
      endAt: map['end_at'] != null
          ? DateTime.parse(map['end_at'] as String)
          : null,
      suhoorAt: map['suhoor_at'] != null
          ? DateTime.parse(map['suhoor_at'] as String)
          : null,
      iftarAt: map['iftar_at'] != null
          ? DateTime.parse(map['iftar_at'] as String)
          : null,
      targetDurationMinutes: map['target_duration_minutes'] as int?,
      note: map['note'] as String?,
    );
  }
}
