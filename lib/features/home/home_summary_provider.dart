import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../core/utils/day_boundary.dart';
import '../../data/models/fasting_session.dart';
import '../../data/models/sleep_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// Everything the Home screen needs for a given day, aggregated from the
/// profile, food log, exercise log, water log, weight log, and any
/// active fast. Built fresh each time [homeSummaryProvider] re-runs (on
/// app start and whenever [dataRefreshSignalProvider] is bumped).
class HomeDailySummary {
  const HomeDailySummary({
    required this.hasProfile,
    this.userName = '',
    this.calculation,
    this.cheatDayBonusKcal = 0,
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

  /// Bonus calories added to [calorieGoal] when the viewed day is the
  /// user's configured cheat day — 0 otherwise. See Profile's "Cheat Day"
  /// settings.
  final int cheatDayBonusKcal;

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

  int get calorieGoal => (calculation?.dailyCalorieGoal ?? 2000).round() + cheatDayBonusKcal;
  int get netCalories =>
      (caloriesConsumed - caloriesBurned).round();
  int get caloriesRemaining => calorieGoal - netCalories;
}

/// Keyed by the calendar day being viewed (normalized to midnight) — see
/// [HomeScreen]'s day-navigator, which lets the last 7 days be viewed and
/// edited, not just today.
final homeSummaryProvider =
    FutureProvider.family<HomeDailySummary, DateTime>((ref, selectedDay) async {
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

  final now = DateTime.now();
  final isToday = selectedDay.year == now.year &&
      selectedDay.month == now.month &&
      selectedDay.day == now.day;

  final profile = await profileRepo.getProfile();
  final resetMinuteOfDay = profile?.calorieResetMinuteOfDay ?? 0;
  final foodTotals =
      await foodLogRepo.totalsForDay(selectedDay, resetMinuteOfDay: resetMinuteOfDay);
  final caloriesBurned = await exerciseLogRepo.totalCaloriesBurnedForDay(
    selectedDay,
    resetMinuteOfDay: resetMinuteOfDay,
  );
  final waterMl =
      await waterLogRepo.totalMlForDay(selectedDay, resetMinuteOfDay: resetMinuteOfDay);
  final waterGoalMl = await profileRepo.getWaterGoalMl();
  final latestWeight = isToday
      ? await weightLogRepo.mostRecent()
      : await weightLogRepo.mostRecentAsOf(selectedDay, resetMinuteOfDay: resetMinuteOfDay);
  // A fast is live session state, not per-day history — only meaningful
  // while looking at today.
  final activeFast = isToday ? await fastingRepo.getActiveSession() : null;
  final selectedDaySleep =
      await sleepLogRepo.entryForDay(selectedDay, resetMinuteOfDay: resetMinuteOfDay);
  final priorDaySleep = await sleepLogRepo.entryForDay(
    selectedDay.subtract(const Duration(days: 1)),
    resetMinuteOfDay: resetMinuteOfDay,
  );
  final sleepTrackingActive = selectedDaySleep != null || priorDaySleep != null;

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
  final cheatDayBonus = profile != null &&
          profile.cheatDayEnabled &&
          profile.cheatDayOfWeek == dayWindowFor(selectedDay, resetMinuteOfDay).start.weekday
      ? profile.cheatDayBonusKcal
      : 0;

  return HomeDailySummary(
    hasProfile: profile != null,
    userName: profile?.name ?? '',
    calculation: calculation,
    cheatDayBonusKcal: cheatDayBonus,
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
    sleepHours: selectedDaySleep?.hours,
    todaySleepEntry: selectedDaySleep,
    sleepTrackingActive: sleepTrackingActive,
  );
});
