import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/food_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// Food log entries for an arbitrary day, grouped by meal slot. Watches
/// the refresh signal so logging or deleting an entry anywhere updates
/// this list automatically. Shared by the Food tab and Home's
/// day-navigator via [selectedDayProvider] so both show/edit the same
/// day's data.
final dayFoodLogProvider =
    FutureProvider.family<List<FoodLogEntry>, DateTime>((ref, day) async {
  ref.watch(dataRefreshSignalProvider);
  final repo = ref.read(foodLogRepositoryProvider);
  return repo.entriesForDay(day);
});
