import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/food_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// Today's food log entries, grouped by meal slot. Watches the refresh
/// signal so logging or deleting an entry anywhere updates this list
/// automatically.
final todayFoodLogProvider = FutureProvider<List<FoodLogEntry>>((ref) async {
  ref.watch(dataRefreshSignalProvider);
  final repo = ref.read(foodLogRepositoryProvider);
  return repo.entriesForDay(DateTime.now());
});
