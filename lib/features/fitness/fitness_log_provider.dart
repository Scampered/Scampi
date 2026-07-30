import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/exercise_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// Logged exercise entries for an arbitrary day. Re-fetches whenever
/// [dataRefreshSignalProvider] is bumped (e.g. after logging or deleting
/// an entry). Respects the user's custom Daily Reset Time (same
/// `calorieResetMinuteOfDay` used by Home/Progress/food/water), so a
/// post-midnight session still counts as "yesterday" for a late-sleeper
/// the same way food/water do. Shared by the Fitness tab via
/// `selectedDayProvider`.
final dayExerciseLogProvider =
    FutureProvider.family<List<ExerciseLogEntry>, DateTime>((ref, day) async {
  ref.watch(dataRefreshSignalProvider);
  final repo = ref.read(exerciseLogRepositoryProvider);
  final profile = await ref.read(userProfileRepositoryProvider).getProfile();
  final resetMinuteOfDay = profile?.calorieResetMinuteOfDay ?? 0;
  return repo.entriesForDay(day, resetMinuteOfDay: resetMinuteOfDay);
});
