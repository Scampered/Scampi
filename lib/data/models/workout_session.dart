import '../../data/models/exercise_log_entry.dart';

/// SharedPreferences key the active session is persisted under — shared
/// between the main isolate ([WorkoutSessionController]) and the
/// background foreground-service isolate (`WorkoutTaskHandler`), which is
/// how the two stay in sync without a direct object reference between
/// isolates.
const String activeWorkoutSessionPrefsKey = 'scampi_active_workout_session';

/// One stretch of a [WorkoutSession] at a single intensity. `end == null`
/// means this segment is the currently-running one (or the session is
/// paused with this as its last-closed segment) — there's no separate
/// pause flag on the session itself, "no open segment" doubles as paused.
class WorkoutIntensitySegment {
  const WorkoutIntensitySegment({
    required this.intensity,
    required this.start,
    this.end,
  });

  final ExerciseIntensity intensity;
  final DateTime start;
  final DateTime? end;

  bool get isOpen => end == null;

  Duration durationAsOf(DateTime now) => (end ?? now).difference(start);

  Map<String, Object?> toJson() => {
        'intensity': intensity.name,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
      };

  factory WorkoutIntensitySegment.fromJson(Map<String, Object?> json) {
    return WorkoutIntensitySegment(
      intensity: ExerciseIntensity.values.byName(json['intensity'] as String),
      start: DateTime.parse(json['start'] as String),
      end: json['end'] != null ? DateTime.parse(json['end'] as String) : null,
    );
  }
}

/// A live, in-progress workout: one fixed exercise category for the whole
/// session, with a timeline of intensity segments so calories can be
/// computed from the actual time-weighted intensity breakdown rather than
/// a single label picked at the end. Immutable — every state change (new
/// intensity, pause, resume) produces a new instance.
class WorkoutSession {
  const WorkoutSession({
    required this.category,
    required this.startedAt,
    required this.segments,
  });

  final ExerciseCategory category;
  final DateTime startedAt;
  final List<WorkoutIntensitySegment> segments;

  factory WorkoutSession.start(ExerciseCategory category, ExerciseIntensity intensity, DateTime now) {
    return WorkoutSession(
      category: category,
      startedAt: now,
      segments: [WorkoutIntensitySegment(intensity: intensity, start: now)],
    );
  }

  bool get isRunning => segments.isNotEmpty && segments.last.isOpen;

  ExerciseIntensity get currentIntensity => segments.last.intensity;

  /// Closes the current segment (if open) and opens a new one at
  /// [intensity] — a no-op returning the same session if already at that
  /// intensity and running.
  WorkoutSession withIntensity(ExerciseIntensity intensity, DateTime now) {
    if (isRunning && currentIntensity == intensity) return this;
    final closed = _closeOpenSegment(now);
    return WorkoutSession(
      category: category,
      startedAt: startedAt,
      segments: [...closed, WorkoutIntensitySegment(intensity: intensity, start: now)],
    );
  }

  /// Closes the current segment without opening a new one — this is what
  /// "paused" means.
  WorkoutSession paused(DateTime now) {
    if (!isRunning) return this;
    return WorkoutSession(category: category, startedAt: startedAt, segments: _closeOpenSegment(now));
  }

  /// Opens a new segment at the last-used intensity — this is what
  /// "resumed" means.
  WorkoutSession resumed(DateTime now) {
    if (isRunning || segments.isEmpty) return this;
    return WorkoutSession(
      category: category,
      startedAt: startedAt,
      segments: [...segments, WorkoutIntensitySegment(intensity: segments.last.intensity, start: now)],
    );
  }

  List<WorkoutIntensitySegment> _closeOpenSegment(DateTime now) {
    if (!isRunning) return segments;
    final open = segments.last;
    return [
      ...segments.sublist(0, segments.length - 1),
      WorkoutIntensitySegment(intensity: open.intensity, start: open.start, end: now),
    ];
  }

  Duration elapsedAsOf(DateTime now) =>
      segments.fold(Duration.zero, (sum, s) => sum + s.durationAsOf(now));

  /// Calories burned so far, summed per segment at that segment's
  /// intensity — mirrors the MET × weight(kg) × hours formula in
  /// [ExerciseLogEntry.estimateCalories] (flat MET, no pace-adjustment,
  /// since a live session doesn't track distance).
  double caloriesSoFarAsOf(DateTime now, {required double bodyWeightKg}) {
    var total = 0.0;
    for (final segment in segments) {
      final hours = segment.durationAsOf(now).inMilliseconds / (1000 * 60 * 60);
      if (hours <= 0) continue;
      final met = category.metValue * segment.intensity.metMultiplier;
      total += met * bodyWeightKg * hours;
    }
    return total;
  }

  /// The intensity with the most total time as of [now] — used as the
  /// single representative `intensity` label on the saved
  /// [ExerciseLogEntry] (whose `caloriesBurned` already reflects the full
  /// time-weighted blend regardless of this one label).
  ExerciseIntensity dominantIntensityAsOf(DateTime now) {
    final totals = <ExerciseIntensity, Duration>{};
    for (final segment in segments) {
      totals[segment.intensity] =
          (totals[segment.intensity] ?? Duration.zero) + segment.durationAsOf(now);
    }
    return totals.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  Map<String, Object?> toJson() => {
        'category': category.name,
        'startedAt': startedAt.toIso8601String(),
        'segments': segments.map((s) => s.toJson()).toList(),
      };

  factory WorkoutSession.fromJson(Map<String, Object?> json) {
    return WorkoutSession(
      category: ExerciseCategory.values.byName(json['category'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      segments: (json['segments'] as List)
          .map((s) => WorkoutIntensitySegment.fromJson(s as Map<String, Object?>))
          .toList(),
    );
  }
}

/// "H:MM:SS" once an hour in, otherwise "M:SS" — used by both the
/// notification text and the in-app live status card so they always
/// match.
String formatWorkoutDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$minutes:$ss';
}
