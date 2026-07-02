/// Units system the user has chosen for display/entry.
enum UnitsSystem { metric, imperial }

/// Biological sex used for the Mifflin-St Jeor BMR formula. Kept narrowly
/// scoped to what the formula actually needs (it only has male/female
/// coefficients); this is a calculation input, not a gender-identity field.
enum BiologicalSex { male, female }

enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extremelyActive;

  /// TDEE multiplier per the spec.
  double get multiplier {
    switch (this) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.lightlyActive:
        return 1.375;
      case ActivityLevel.moderatelyActive:
        return 1.55;
      case ActivityLevel.veryActive:
        return 1.725;
      case ActivityLevel.extremelyActive:
        return 1.9;
    }
  }

  String get label {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Sedentary';
      case ActivityLevel.lightlyActive:
        return 'Lightly Active';
      case ActivityLevel.moderatelyActive:
        return 'Moderately Active';
      case ActivityLevel.veryActive:
        return 'Very Active';
      case ActivityLevel.extremelyActive:
        return 'Extremely Active';
    }
  }

  String get description {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Little or no exercise, desk job';
      case ActivityLevel.lightlyActive:
        return 'Light exercise 1–3 days/week';
      case ActivityLevel.moderatelyActive:
        return 'Moderate exercise 3–5 days/week';
      case ActivityLevel.veryActive:
        return 'Hard exercise 6–7 days/week';
      case ActivityLevel.extremelyActive:
        return 'Very hard exercise, physical job, or training twice a day';
    }
  }
}

enum GoalMode {
  maintain,
  leanBulk,
  bulk,
  weightLoss,
  aggressiveWeightLoss,
  custom;

  String get label {
    switch (this) {
      case GoalMode.maintain:
        return 'Maintain Weight';
      case GoalMode.leanBulk:
        return 'Lean Bulk';
      case GoalMode.bulk:
        return 'Bulk';
      case GoalMode.weightLoss:
        return 'Weight Loss';
      case GoalMode.aggressiveWeightLoss:
        return 'Aggressive Weight Loss';
      case GoalMode.custom:
        return 'Custom Goal';
    }
  }

  /// Daily calorie offset from maintenance (TDEE). Positive = surplus,
  /// negative = deficit. `custom` returns 0 here — the actual custom
  /// offset is stored separately on the profile, since it's user-chosen.
  int get defaultDailyOffset {
    switch (this) {
      case GoalMode.maintain:
        return 0;
      case GoalMode.leanBulk:
        return 250;
      case GoalMode.bulk:
        return 500;
      case GoalMode.weightLoss:
        return -500;
      case GoalMode.aggressiveWeightLoss:
        return -1000;
      case GoalMode.custom:
        return 0;
    }
  }
}

/// Given a current and (optional) goal weight, returns which goal modes
/// are physically coherent — e.g. "Bulk" doesn't make sense if the goal
/// weight is lower than the current weight. Used to filter/disable
/// options in onboarding rather than letting someone pick a
/// self-contradicting goal.
///
/// If [goalWeightKg] is null (the user skipped setting one), all modes
/// are considered plausible since there's no direction to check against.
List<GoalMode> allowedGoalModes({
  required double weightKg,
  required double? goalWeightKg,
}) {
  const all = [
    GoalMode.maintain,
    GoalMode.leanBulk,
    GoalMode.bulk,
    GoalMode.weightLoss,
    GoalMode.aggressiveWeightLoss,
  ];

  if (goalWeightKg == null) return all;

  // Within half a kilo is "the same weight" for this purpose.
  const tolerance = 0.5;
  final delta = goalWeightKg - weightKg;

  if (delta.abs() <= tolerance) {
    return [GoalMode.maintain];
  } else if (delta > 0) {
    // Goal weight is higher — bulking goals only.
    return [GoalMode.leanBulk, GoalMode.bulk];
  } else {
    // Goal weight is lower — cutting goals only.
    return [GoalMode.weightLoss, GoalMode.aggressiveWeightLoss];
  }
}

/// The user's profile: the inputs needed for BMR/TDEE/goal calculations.
/// Exactly one row of this should ever exist locally (single-user,
/// no-accounts app) — enforced at the repository level, not here.
class UserProfile {
  const UserProfile({
    this.id = 1,
    this.name = '',
    required this.age,
    required this.sex,
    required this.heightCm,
    required this.weightKg,
    this.goalWeightKg,
    this.targetDate,
    required this.activityLevel,
    required this.goalMode,
    this.customDailyOffset = 0,
    this.unitsSystem = UnitsSystem.metric,
  });

  final int id;
  final String name;
  final int age;
  final BiologicalSex sex;
  final double heightCm;
  final double weightKg;

  /// Optional — a user may not have a specific target weight in mind.
  /// When null, weight-direction-dependent goal modes (bulk/loss) can't
  /// be sense-checked against it, so the UI falls back to showing all
  /// goal modes without a mismatch warning.
  final double? goalWeightKg;

  /// Optional target date to hit [goalWeightKg] by. When both are set,
  /// onboarding offers a custom pace (via [customDailyOffset]) computed
  /// to land on that date, instead of only the fixed-rate presets.
  final DateTime? targetDate;
  final ActivityLevel activityLevel;
  final GoalMode goalMode;

  /// Only used when [goalMode] is [GoalMode.custom]. Calorie offset from
  /// maintenance, can be positive or negative.
  final int customDailyOffset;
  final UnitsSystem unitsSystem;

  int get dailyCalorieOffset =>
      goalMode == GoalMode.custom ? customDailyOffset : goalMode.defaultDailyOffset;

  UserProfile copyWith({
    String? name,
    int? age,
    BiologicalSex? sex,
    double? heightCm,
    double? weightKg,
    double? goalWeightKg,
    bool clearGoalWeight = false,
    DateTime? targetDate,
    bool clearTargetDate = false,
    ActivityLevel? activityLevel,
    GoalMode? goalMode,
    int? customDailyOffset,
    UnitsSystem? unitsSystem,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goalWeightKg:
          clearGoalWeight ? null : (goalWeightKg ?? this.goalWeightKg),
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      activityLevel: activityLevel ?? this.activityLevel,
      goalMode: goalMode ?? this.goalMode,
      customDailyOffset: customDailyOffset ?? this.customDailyOffset,
      unitsSystem: unitsSystem ?? this.unitsSystem,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'sex': sex.name,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'goal_weight_kg': goalWeightKg,
      'target_date': targetDate?.toIso8601String(),
      'activity_level': activityLevel.name,
      'goal_mode': goalMode.name,
      'custom_daily_offset': customDailyOffset,
      'units_system': unitsSystem.name,
    };
  }

  factory UserProfile.fromMap(Map<String, Object?> map) {
    return UserProfile(
      id: map['id'] as int,
      // Older rows (before the name column existed) will have a null
      // here — fall back to empty string rather than crashing.
      name: map['name'] as String? ?? '',
      age: map['age'] as int,
      sex: BiologicalSex.values.byName(map['sex'] as String),
      heightCm: (map['height_cm'] as num).toDouble(),
      weightKg: (map['weight_kg'] as num).toDouble(),
      goalWeightKg: (map['goal_weight_kg'] as num?)?.toDouble(),
      targetDate: map['target_date'] != null
          ? DateTime.parse(map['target_date'] as String)
          : null,
      activityLevel:
          ActivityLevel.values.byName(map['activity_level'] as String),
      goalMode: GoalMode.values.byName(map['goal_mode'] as String),
      customDailyOffset: map['custom_daily_offset'] as int,
      unitsSystem: UnitsSystem.values.byName(map['units_system'] as String),
    );
  }
}
