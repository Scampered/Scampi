import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/exercise_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// Today's logged exercise entries. Re-fetches whenever
/// [dataRefreshSignalProvider] is bumped (e.g. after logging or deleting
/// an entry) — same pattern as `todayFoodLogProvider`.
final todayExerciseLogProvider = FutureProvider<List<ExerciseLogEntry>>((ref) async {
  ref.watch(dataRefreshSignalProvider);
  final repo = ref.read(exerciseLogRepositoryProvider);
  return repo.entriesForDay(DateTime.now());
});
