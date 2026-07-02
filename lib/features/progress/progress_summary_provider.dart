import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../data/models/water_weight_log.dart';
import '../../data/models/sleep_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// One day's calorie total vs goal, for the weekly bar chart.
class DailyCalorieProgress {
  const DailyCalorieProgress({
    required this.day,
    required this.consumed,
    required this.goal,
  });

  final DateTime day;
  final double consumed;
  final int goal;
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
  final weightLogRepo = ref.read(weightLogRepositoryProvider);
  final sleepLogRepo = ref.read(sleepLogRepositoryProvider);

  final profile = await profileRepo.getProfile();
  final latestWeight = await weightLogRepo.mostRecent();
  final calculation = profile != null
      ? CalorieCalculator.calculate(
          latestWeight != null ? profile.copyWith(weightKg: latestWeight.weightKg) : profile,
        )
      : null;
  final calorieGoal = (calculation?.dailyCalorieGoal ?? 2000).round();

  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final weekStart = todayStart.subtract(const Duration(days: 6));

  final weeklyCalories = <DailyCalorieProgress>[];
  for (var i = 0; i < 7; i++) {
    final day = weekStart.add(Duration(days: i));
    final totals = await foodLogRepo.totalsForDay(day);
    weeklyCalories.add(DailyCalorieProgress(day: day, consumed: totals.calories, goal: calorieGoal));
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
    calorieGoal: calorieGoal,
  );
});
