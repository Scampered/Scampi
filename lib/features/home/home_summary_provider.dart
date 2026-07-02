import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../data/models/fasting_session.dart';
import '../../data/models/sleep_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// Everything the Home screen needs for "today", aggregated from the
/// profile, food log, exercise log, water log, weight log, and any
/// active fast. Built fresh each time [homeSummaryProvider] re-runs
/// (on app start and whenever [dataRefreshSignalProvider] is bumped).
class HomeDailySummary {
  const HomeDailySummary({
    required this.hasProfile,
    this.userName = '',
    this.calculation,
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.proteinConsumedG,
    required this.carbsConsumedG,
    required this.fatConsumedG,
    required this.waterMl,
    required this.waterGoalMl,
    this.currentWeightKg,
    this.goalWeightKg,
    this.activeFast,
    this.sleepHours,
    this.todaySleepEntry,
    this.sleepTrackingActive = false,
  });

  final bool hasProfile;
  final String userName;
  final CalorieCalculation? calculation;

  final double caloriesConsumed;
  final double caloriesBurned;
  final double proteinConsumedG;
  final double carbsConsumedG;
  final double fatConsumedG;

  final int waterMl;
  final int waterGoalMl;

  final double? currentWeightKg;
  final double? goalWeightKg;

  final FastingSession? activeFast;

  /// Hours slept last night, if the user manually logged it — null shows
  /// as an empty sleep arc rather than a zero-length one.
  final double? sleepHours;

  /// Today's raw sleep entry (bedtime/wake time), if logged — used to
  /// prefill [SleepLogSheet] for editing rather than starting fresh.
  final SleepLogEntry? todaySleepEntry;

  /// Whether sleep has been logged today or yesterday — the sleep arc
  /// and flanking stat on the ring are only shown while this is true, so
  /// the feature disappears cleanly for anyone who tried it once and
  /// stopped, rather than permanently showing an empty "0h" stat.
  final bool sleepTrackingActive;

  int get calorieGoal => (calculation?.dailyCalorieGoal ?? 2000).round();
  int get netCalories =>
      (caloriesConsumed - caloriesBurned).round();
  int get caloriesRemaining => calorieGoal - netCalories;
}

final homeSummaryProvider = FutureProvider<HomeDailySummary>((ref) async {
  // Watching the refresh signal means any logged food/water/exercise/
  // weight entry (which bumps it) causes this provider to re-run and
  // the Home screen to update automatically.
  ref.watch(dataRefreshSignalProvider);

  final profileRepo = ref.read(userProfileRepositoryProvider);
  final foodLogRepo = ref.read(foodLogRepositoryProvider);
  final exerciseLogRepo = ref.read(exerciseLogRepositoryProvider);
  final waterLogRepo = ref.read(waterLogRepositoryProvider);
  final weightLogRepo = ref.read(weightLogRepositoryProvider);
  final sleepLogRepo = ref.read(sleepLogRepositoryProvider);
  final fastingRepo = ref.read(fastingRepositoryProvider);

  final today = DateTime.now();

  final profile = await profileRepo.getProfile();
  final foodTotals = await foodLogRepo.totalsForDay(today);
  final caloriesBurned = await exerciseLogRepo.totalCaloriesBurnedForDay(today);
  final waterMl = await waterLogRepo.totalMlForDay(today);
  final waterGoalMl = await profileRepo.getWaterGoalMl();
  final latestWeight = await weightLogRepo.mostRecent();
  final activeFast = await fastingRepo.getActiveSession();
  final todaySleep = await sleepLogRepo.entryForDay(today);
  final yesterdaySleep =
      await sleepLogRepo.entryForDay(today.subtract(const Duration(days: 1)));
  final sleepTrackingActive = todaySleep != null || yesterdaySleep != null;

  final calculation = profile != null
      ? CalorieCalculator.calculate(
          // Use the most recent logged weight if available, since body
          // weight changes over time and the profile's stored weight may
          // be stale; fall back to the profile's weight otherwise.
          latestWeight != null
              ? profile.copyWith(weightKg: latestWeight.weightKg)
              : profile,
        )
      : null;

  return HomeDailySummary(
    hasProfile: profile != null,
    userName: profile?.name ?? '',
    calculation: calculation,
    caloriesConsumed: foodTotals.calories,
    caloriesBurned: caloriesBurned,
    proteinConsumedG: foodTotals.proteinG,
    carbsConsumedG: foodTotals.carbsG,
    fatConsumedG: foodTotals.fatG,
    waterMl: waterMl,
    waterGoalMl: waterGoalMl,
    currentWeightKg: latestWeight?.weightKg ?? profile?.weightKg,
    goalWeightKg: profile?.goalWeightKg,
    activeFast: activeFast,
    sleepHours: todaySleep?.hours,
    todaySleepEntry: todaySleep,
    sleepTrackingActive: sleepTrackingActive,
  );
});
