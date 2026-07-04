import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/exercise_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// Today's logged exercise entries. Re-fetches whenever
/// [dataRefreshSignalProvider] is bumped (e.g. after logging or deleting
/// an entry) — same pattern as `todayFoodLogProvider`. Respects the
/// user's custom Daily Reset Time (same `calorieResetMinuteOfDay` used by
/// Home/Progress/food/water), so a post-midnight session still counts as
/// "yesterday" for a late-sleeper the same way food/water do.
final todayExerciseLogProvider = FutureProvider<List<ExerciseLogEntry>>((ref) async {
  ref.watch(dataRefreshSignalProvider);
  final repo = ref.read(exerciseLogRepositoryProvider);
  final profile = await ref.read(userProfileRepositoryProvider).getProfile();
  final resetMinuteOfDay = profile?.calorieResetMinuteOfDay ?? 0;
  return repo.entriesForDay(DateTime.now(), resetMinuteOfDay: resetMinuteOfDay);
});
