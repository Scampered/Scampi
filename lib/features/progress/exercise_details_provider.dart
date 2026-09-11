import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/health/health_service.dart';
import '../../core/health/health_sync_controller.dart';
import '../../core/utils/day_boundary.dart';
import '../../data/repositories/data_refresh_signal.dart';
import '../../data/repositories/repository_providers.dart';

/// Today's steps/distance/active-calories plus an hourly step breakdown
/// (from the user's daily reset time), for the Progress "Exercise
/// Details" card — the same shape as Samsung Health's own daily activity
/// screen. Always "today" regardless of what else is being viewed
/// elsewhere in the app — there's no day-navigator on Progress.
class ExerciseDetailsSummary {
  const ExerciseDetailsSummary({
    required this.steps,
    required this.distanceKm,
    required this.activeCalories,
    required this.hourlySteps,
    required this.resetMinuteOfDay,
  });

  final int steps;
  final double distanceKm;
  final double activeCalories;

  /// 24 buckets, index 0 starting at the reset time — see
  /// [HealthService.stepsByHour].
  final List<int> hourlySteps;
  final int resetMinuteOfDay;

  /// The single busiest hour bucket, formatted like Samsung Health's
  /// "Most active period: 7:00 PM - 8:00 PM" — null if there's no step
  /// data at all yet today.
  String? get mostActivePeriodLabel {
    if (hourlySteps.every((s) => s == 0)) return null;
    var bestIndex = 0;
    for (var i = 1; i < hourlySteps.length; i++) {
      if (hourlySteps[i] > hourlySteps[bestIndex]) bestIndex = i;
    }
    final windowStart = dayWindowFor(DateTime.now(), resetMinuteOfDay).start;
    final bucketStart = windowStart.add(Duration(hours: bestIndex));
    final bucketEnd = bucketStart.add(const Duration(hours: 1));
    final fmt = DateFormat('h:mm a');
    return '${fmt.format(bucketStart)} - ${fmt.format(bucketEnd)}';
  }
}

/// Null when the user hasn't turned on the Health Connect sync in
/// Profile — the card itself decides what to show in that case (a
/// prompt to enable it) rather than this provider guessing.
final exerciseDetailsProvider = FutureProvider<ExerciseDetailsSummary?>((ref) async {
  ref.watch(dataRefreshSignalProvider);
  final enabled = ref.watch(healthSyncEnabledProvider);
  if (!enabled) return null;

  final profile = await ref.read(userProfileRepositoryProvider).getProfile();
  final resetMinuteOfDay = profile?.calorieResetMinuteOfDay ?? 0;

  final steps = await HealthService.instance.todaySteps();
  final distanceKm = await HealthService.instance.todayDistanceKm() ?? (steps * 0.0008);
  final activeCalories = await HealthService.instance.todayActiveEnergyKcal() ?? 0;
  final hourlySteps = await HealthService.instance.stepsByHour(DateTime.now(), resetMinuteOfDay);

  return ExerciseDetailsSummary(
    steps: steps,
    distanceKm: distanceKm,
    activeCalories: activeCalories,
    hourlySteps: hourlySteps,
    resetMinuteOfDay: resetMinuteOfDay,
  );
});
