enum ExerciseCategory {
  walking,
  running,
  cycling,
  swimming,
  football,
  basketball,
  tennis,
  gym,
  weightTraining,
  martialArts,
  hiking,
  other;

  String get label {
    switch (this) {
      case ExerciseCategory.walking:
        return 'Walking';
      case ExerciseCategory.running:
        return 'Running';
      case ExerciseCategory.cycling:
        return 'Cycling';
      case ExerciseCategory.swimming:
        return 'Swimming';
      case ExerciseCategory.football:
        return 'Football';
      case ExerciseCategory.basketball:
        return 'Basketball';
      case ExerciseCategory.tennis:
        return 'Tennis';
      case ExerciseCategory.gym:
        return 'Gym';
      case ExerciseCategory.weightTraining:
        return 'Weight Training';
      case ExerciseCategory.martialArts:
        return 'Martial Arts';
      case ExerciseCategory.hiking:
        return 'Hiking';
      case ExerciseCategory.other:
        return 'Other';
    }
  }

  /// Rough MET (Metabolic Equivalent of Task) value used to estimate
  /// calories burned when the user doesn't enter a value directly.
  /// These are widely-used approximate averages for the category, not
  /// individualized — the UI should make clear this is an estimate.
  /// For distance-trackable categories, this is the MET at the
  /// reference pace in [referenceSpeedKmh] — see [metValueForPace].
  double get metValue {
    switch (this) {
      case ExerciseCategory.walking:
        return 3.5;
      case ExerciseCategory.running:
        return 9.8;
      case ExerciseCategory.cycling:
        return 7.5;
      case ExerciseCategory.swimming:
        return 8.0;
      case ExerciseCategory.football:
        return 8.0;
      case ExerciseCategory.basketball:
        return 6.5;
      case ExerciseCategory.tennis:
        return 7.3;
      case ExerciseCategory.gym:
        return 5.0;
      case ExerciseCategory.weightTraining:
        return 6.0;
      case ExerciseCategory.martialArts:
        return 10.0;
      case ExerciseCategory.hiking:
        return 6.0;
      case ExerciseCategory.other:
        return 5.0;
    }
  }

  /// The pace (km/h) at which [metValue] applies, for categories where
  /// speed meaningfully changes effort (walking/running/cycling/
  /// swimming/hiking). Null for categories where a "pace" doesn't really
  /// apply (gym, sports, etc.) — those just use the flat [metValue].
  double? get referenceSpeedKmh {
    switch (this) {
      case ExerciseCategory.walking:
        return 5.0;
      case ExerciseCategory.running:
        return 9.7;
      case ExerciseCategory.cycling:
        return 19.0;
      case ExerciseCategory.swimming:
        return 2.5;
      case ExerciseCategory.hiking:
        return 4.0;
      case ExerciseCategory.football:
      case ExerciseCategory.basketball:
      case ExerciseCategory.tennis:
      case ExerciseCategory.gym:
      case ExerciseCategory.weightTraining:
      case ExerciseCategory.martialArts:
      case ExerciseCategory.other:
        return null;
    }
  }

  /// MET adjusted for actual pace when a distance and duration are both
  /// known — going faster than the reference pace burns more per minute,
  /// slower burns less, same logic as real MET tables varying by speed.
  /// The multiplier is clamped so a mistyped distance can't produce a
  /// wildly unrealistic estimate.
  double metValueForPace({double? distanceKm, required int durationMinutes}) {
    final referenceSpeed = referenceSpeedKmh;
    if (referenceSpeed == null || distanceKm == null || distanceKm <= 0 || durationMinutes <= 0) {
      return metValue;
    }
    final actualSpeedKmh = distanceKm / (durationMinutes / 60.0);
    final paceMultiplier = (actualSpeedKmh / referenceSpeed).clamp(0.6, 1.8);
    return metValue * paceMultiplier;
  }
}

enum ExerciseIntensity {
  light,
  moderate,
  intense;

  String get label {
    switch (this) {
      case ExerciseIntensity.light:
        return 'Light';
      case ExerciseIntensity.moderate:
        return 'Moderate';
      case ExerciseIntensity.intense:
        return 'Intense';
    }
  }

  /// Multiplier applied on top of the category's base MET value.
  double get metMultiplier {
    switch (this) {
      case ExerciseIntensity.light:
        return 0.8;
      case ExerciseIntensity.moderate:
        return 1.0;
      case ExerciseIntensity.intense:
        return 1.3;
    }
  }
}

class ExerciseLogEntry {
  const ExerciseLogEntry({
    this.id,
    required this.category,
    required this.loggedAt,
    required this.durationMinutes,
    this.distanceKm,
    required this.intensity,
    required this.caloriesBurned,
    this.wasEstimated = false,
    this.note,
  });

  final int? id;
  final ExerciseCategory category;
  final DateTime loggedAt;
  final int durationMinutes;
  final double? distanceKm;
  final ExerciseIntensity intensity;
  final double caloriesBurned;

  /// True if [caloriesBurned] was computed via the MET estimate rather
  /// than entered directly by the user.
  final bool wasEstimated;
  final String? note;

  /// Estimates calories burned using the standard formula:
  /// calories = MET × weight(kg) × duration(hours)
  ///
  /// When [distanceKm] is given for a distance-trackable category (see
  /// [ExerciseCategory.referenceSpeedKmh]), the MET is first adjusted for
  /// actual pace — running 2km in 10 minutes burns more than running
  /// 1km in the same 10 minutes, even though duration is identical.
  static double estimateCalories({
    required ExerciseCategory category,
    required ExerciseIntensity intensity,
    required int durationMinutes,
    required double bodyWeightKg,
    double? distanceKm,
  }) {
    final baseMet = category.metValueForPace(
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
    );
    final met = baseMet * intensity.metMultiplier;
    final hours = durationMinutes / 60.0;
    return met * bodyWeightKg * hours;
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'category': category.name,
      'logged_at': loggedAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'distance_km': distanceKm,
      'intensity': intensity.name,
      'calories_burned': caloriesBurned,
      'was_estimated': wasEstimated ? 1 : 0,
      'note': note,
    };
  }

  factory ExerciseLogEntry.fromMap(Map<String, Object?> map) {
    return ExerciseLogEntry(
      id: map['id'] as int?,
      category: ExerciseCategory.values.byName(map['category'] as String),
      loggedAt: DateTime.parse(map['logged_at'] as String),
      durationMinutes: map['duration_minutes'] as int,
      distanceKm: (map['distance_km'] as num?)?.toDouble(),
      intensity: ExerciseIntensity.values.byName(map['intensity'] as String),
      caloriesBurned: (map['calories_burned'] as num).toDouble(),
      wasEstimated: (map['was_estimated'] as int? ?? 0) == 1,
      note: map['note'] as String?,
    );
  }
}
