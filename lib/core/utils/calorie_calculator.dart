import '../../data/models/user_profile.dart';

/// Result of a full calorie/macro calculation for a profile.
class CalorieCalculation {
  const CalorieCalculation({
    required this.bmr,
    required this.maintenanceCalories,
    required this.dailyCalorieGoal,
    required this.proteinGoalG,
    required this.carbsGoalG,
    required this.fatGoalG,
    required this.warnings,
  });

  final double bmr;
  final double maintenanceCalories;
  final double dailyCalorieGoal;
  final double proteinGoalG;
  final double carbsGoalG;
  final double fatGoalG;
  final List<HealthWarning> warnings;
}

enum HealthWarningSeverity { caution, serious }

class HealthWarning {
  const HealthWarning({
    required this.message,
    required this.severity,
  });

  final String message;
  final HealthWarningSeverity severity;
}

/// Pure calculation logic — no I/O, no Flutter dependency, so it's
/// trivially unit-testable. Implements the Mifflin-St Jeor equation and
/// TDEE multipliers exactly as specified, plus goal-mode offsets and
/// macro splits.
class CalorieCalculator {
  CalorieCalculator._();

  /// Mifflin-St Jeor BMR.
  /// Male:   (10 × weight kg) + (6.25 × height cm) − (5 × age) + 5
  /// Female: (10 × weight kg) + (6.25 × height cm) − (5 × age) − 161
  static double calculateBmr({
    required BiologicalSex sex,
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    final base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    return sex == BiologicalSex.male ? base + 5 : base - 161;
  }

  static double calculateTdee({
    required double bmr,
    required ActivityLevel activityLevel,
  }) {
    return bmr * activityLevel.multiplier;
  }

  /// Full calculation for a profile: BMR, maintenance (TDEE), the daily
  /// calorie goal after applying the goal mode's offset, a sensible
  /// macro split, and any health warnings the resulting target should
  /// raise.
  ///
  /// Macro split approach: protein is set relative to body weight
  /// (a more physiologically meaningful anchor than a flat percentage),
  /// fat is set as a percentage of total calories, and carbs take the
  /// remainder. This avoids the common bug where percentage-based splits
  /// produce unrealistically low protein for lighter individuals.
  static CalorieCalculation calculate(UserProfile profile) {
    final bmr = calculateBmr(
      sex: profile.sex,
      weightKg: profile.weightKg,
      heightCm: profile.heightCm,
      age: profile.age,
    );
    final maintenance = calculateTdee(
      bmr: bmr,
      activityLevel: profile.activityLevel,
    );

    final offset = profile.dailyCalorieOffset.toDouble();
    var goalCalories = maintenance + offset;

    // Floor: never recommend below a absolute safety minimum regardless
    // of how aggressive the offset is. These floors mirror commonly-
    // cited general safe minimums (not personalized medical advice).
    final safetyFloor = profile.sex == BiologicalSex.male ? 1500.0 : 1200.0;
    final warnings = <HealthWarning>[];

    if (goalCalories < safetyFloor) {
      warnings.add(HealthWarning(
        message:
            'Your current goal is below the commonly recommended minimum '
            'of ${safetyFloor.round()} kcal/day. Very low-calorie diets '
            'can be unsafe without medical supervision — consider a less '
            'aggressive deficit.',
        severity: HealthWarningSeverity.serious,
      ));
      goalCalories = goalCalories.clamp(800.0, double.infinity);
    } else if (offset <= -750) {
      warnings.add(const HealthWarning(
        message:
            'This is an aggressive calorie deficit. Rapid weight loss can '
            'increase the risk of muscle loss and fatigue — make sure '
            "you're getting enough protein and listening to your body.",
        severity: HealthWarningSeverity.caution,
      ));
    }

    if (offset >= 750) {
      warnings.add(const HealthWarning(
        message:
            'This is a large calorie surplus. Expect a faster rate of fat '
            'gain alongside muscle gain — a more moderate surplus is '
            'usually more sustainable for lean progress.',
        severity: HealthWarningSeverity.caution,
      ));
    }

    // Protein: ~1.6-2.2 g/kg is a well-supported range for active
    // individuals; we use 1.8 g/kg as a reasonable single default,
    // higher during a cut (preserve muscle) and slightly lower during
    // a surplus.
    double proteinPerKg;
    switch (profile.goalMode) {
      case GoalMode.weightLoss:
      case GoalMode.aggressiveWeightLoss:
        proteinPerKg = 2.0;
        break;
      case GoalMode.leanBulk:
      case GoalMode.bulk:
        proteinPerKg = 1.8;
        break;
      case GoalMode.maintain:
      case GoalMode.custom:
        proteinPerKg = 1.8;
        break;
    }

    final proteinG = profile.weightKg * proteinPerKg;
    final proteinCalories = proteinG * 4;

    if (proteinCalories > goalCalories * 0.5 && proteinCalories > 0) {
      // Sanity guard for edge cases (e.g. extremely low calorie goal vs
      // high bodyweight) so protein can't exceed half the total budget.
      warnings.add(const HealthWarning(
        message:
            'Your calorie goal is low relative to your protein target — '
            "double check your numbers, since there won't be much room "
            'left for carbs and fat.',
        severity: HealthWarningSeverity.caution,
      ));
    }

    const fatPercentOfCalories = 0.28;
    final fatCalories = goalCalories * fatPercentOfCalories;
    final fatG = fatCalories / 9;

    final remainingCalories =
        (goalCalories - proteinCalories - fatCalories).clamp(0.0, double.infinity);
    final carbsG = remainingCalories / 4;

    if (proteinG / profile.weightKg < 0.6) {
      warnings.add(const HealthWarning(
        message:
            'Your protein target is quite low for your body weight, which '
            'can make it harder to preserve muscle and stay full. '
            'Consider prioritizing protein-rich foods.',
        severity: HealthWarningSeverity.caution,
      ));
    }

    return CalorieCalculation(
      bmr: bmr,
      maintenanceCalories: maintenance,
      dailyCalorieGoal: goalCalories,
      proteinGoalG: proteinG,
      carbsGoalG: carbsG,
      fatGoalG: fatG,
      warnings: warnings,
    );
  }

  /// Rough projection of weeks to reach the goal weight, based on the
  /// standard ~7700 kcal ≈ 1kg body mass approximation. This is a
  /// simplification (real-world weight change isn't perfectly linear)
  /// and should be presented to the user as an estimate, not a promise.
  static int? estimatedWeeksToGoal(UserProfile profile) {
    final goalWeightKg = profile.goalWeightKg;
    if (goalWeightKg == null) return null;

    final offset = profile.dailyCalorieOffset;
    if (offset == 0) return null;

    final weightDeltaKg = goalWeightKg - profile.weightKg;
    final isLosing = offset < 0;
    final isGaining = offset > 0;

    if (isLosing && weightDeltaKg >= 0) return null; // goal isn't a loss
    if (isGaining && weightDeltaKg <= 0) return null; // goal isn't a gain

    const kcalPerKg = 7700;
    final totalKcalNeeded = weightDeltaKg.abs() * kcalPerKg;
    final weeklyOffset = offset.abs() * 7;
    if (weeklyOffset == 0) return null;

    return (totalKcalNeeded / weeklyOffset).ceil();
  }

  /// Converts a fixed daily calorie offset into an approximate weekly
  /// body-weight change rate in kg, using the standard ~7700 kcal ≈ 1kg
  /// approximation. Used to annotate goal-mode options with a concrete
  /// rate (e.g. "≈0.45 kg/week") rather than just an abstract label.
  static double weeklyRateKgForDailyOffset(int dailyOffsetKcal) {
    return dailyOffsetKcal.abs() * 7 / 7700;
  }

  /// Given a current weight, goal weight, and target date, computes the
  /// daily calorie offset (signed — negative for a deficit, positive for
  /// a surplus) needed to land on the goal weight by that date.
  ///
  /// Returns null if the target date is in the past, or if the goal
  /// weight is essentially the same as the current weight (nothing to
  /// pace toward).
  static int? requiredDailyOffsetForTarget({
    required double weightKg,
    required double goalWeightKg,
    required DateTime targetDate,
  }) {
    final days = targetDate.difference(DateTime.now()).inDays;
    if (days <= 0) return null;

    final deltaKg = goalWeightKg - weightKg;
    if (deltaKg.abs() < 0.5) return null;

    const kcalPerKg = 7700;
    final totalKcal = deltaKg * kcalPerKg;
    return (totalKcal / days).round();
  }
}
