import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../core/utils/day_boundary.dart';
import '../../data/models/water_weight_log.dart';
import '../../data/models/sleep_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// One day's calorie total vs goal, for the weekly bar chart. [goal] is
/// that specific day's own goal — including a cheat-day bonus if that
/// day was the configured cheat day — not just today's current goal
/// applied uniformly across the week.
class DailyCalorieProgress {
  const DailyCalorieProgress({
    required this.day,
    required this.consumed,
    required this.burned,
    required this.goal,
    required this.isCheatDay,
  });

  final DateTime day;
  final double consumed;
  final double burned;
  final int goal;
  final bool isCheatDay;

  /// What the bar actually plots — eaten minus burned, matching the
  /// "kcal remaining" math used everywhere else (Home's ring, etc.),
  /// instead of raw calories eaten.
  double get net => consumed - burned;
}

class ProgressSummary {
  const ProgressSummary({
    required this.weeklyCalories,
    required this.weightHistory,
    required this.sleepHistory,
    required this.calorieGoal,
  });

  final List<DailyCalorieProgress> weeklyCalories;
  final List<WeightLogEntry> weightHistory;
  final List<SleepLogEntry> sleepHistory;
  final int calorieGoal;
}

/// Aggregates the last 7 days of calorie totals and the last 90 days of
/// weight check-ins for the Progress screen's charts. Watches the refresh
/// signal so a fresh food/weight log entry updates the charts immediately.
final progressSummaryProvider = FutureProvider<ProgressSummary>((ref) async {
  ref.watch(dataRefreshSignalProvider);

  final profileRepo = ref.read(userProfileRepositoryProvider);
  final foodLogRepo = ref.read(foodLogRepositoryProvider);
  final exerciseLogRepo = ref.read(exerciseLogRepositoryProvider);
  final weightLogRepo = ref.read(weightLogRepositoryProvider);
  final sleepLogRepo = ref.read(sleepLogRepositoryProvider);

  final profile = await profileRepo.getProfile();
  final latestWeight = await weightLogRepo.mostRecent();
  final calculation = profile != null
      ? CalorieCalculator.calculate(
          latestWeight != null ? profile.copyWith(weightKg: latestWeight.weightKg) : profile,
        )
      : null;
  final baseCalorieGoal = (calculation?.dailyCalorieGoal ?? 2000).round();
  final resetMinuteOfDay = profile?.calorieResetMinuteOfDay ?? 0;

  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final weekStart = todayStart.subtract(const Duration(days: 6));

  final cheatDayOverrideRepo = ref.read(cheatDayOverrideRepositoryProvider);
  // A rolling 7-day window can span two different Cheat Day weeks (see
  // cheatWeekStartFor's doc comment — that "week" is a fixed Sat-Fri
  // calendar block, unlike this chart's window), so the override lookup
  // is cached per week-start rather than assumed to be the same for
  // every day in the loop.
  final overrideCache = <DateTime, int>{};

  final weeklyCalories = <DailyCalorieProgress>[];
  for (var i = 0; i < 7; i++) {
    final day = weekStart.add(Duration(days: i));
    final totals = await foodLogRepo.totalsForDay(day, resetMinuteOfDay: resetMinuteOfDay);
    final burned = await exerciseLogRepo.totalCaloriesBurnedForDay(
      day,
      resetMinuteOfDay: resetMinuteOfDay,
    );
    // Same check home_summary_provider.dart uses — that day's own
    // effective cheat weekday (a CheatDayOverride for that week wins
    // over the profile's normal recurring day), not today's, so a past
    // or moved cheat day is reflected correctly here too.
    bool isCheatDay = false;
    if (profile != null && profile.cheatDayEnabled) {
      final dayWeekStart = cheatWeekStartFor(day, resetMinuteOfDay);
      if (!overrideCache.containsKey(dayWeekStart)) {
        final override = await cheatDayOverrideRepo.forWeek(dayWeekStart);
        overrideCache[dayWeekStart] = override?.effectiveWeekday ?? profile.cheatDayOfWeek ?? -1;
      }
      isCheatDay = overrideCache[dayWeekStart] == dayWindowFor(day, resetMinuteOfDay).start.weekday;
    }
    final dayGoal = baseCalorieGoal + (isCheatDay ? profile!.cheatDayBonusKcal : 0);
    weeklyCalories.add(DailyCalorieProgress(
      day: day,
      consumed: totals.calories,
      burned: burned,
      goal: dayGoal,
      isCheatDay: isCheatDay,
    ));
  }

  // Fetched wide enough to cover the chart's longest selectable timeframe
  // (6 months) — the Progress screen filters down to 1 month client-side
  // when that's the selected view, rather than re-querying.
  final weightHistory = await weightLogRepo.history(
    since: today.subtract(const Duration(days: 183)),
  );
  final sleepHistory = await sleepLogRepo.history(since: weekStart);

  return ProgressSummary(
    weeklyCalories: weeklyCalories,
    weightHistory: weightHistory,
    sleepHistory: sleepHistory,
    calorieGoal: baseCalorieGoal,
  );
});
