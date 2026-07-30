import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/water_weight_log.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/data_refresh_signal.dart';

/// Logged water entries for a given day — same refresh-signal pattern as
/// the food and exercise logs. Powers the water history/remove sheet on
/// Home, keyed by whichever day is currently selected there (see
/// [HomeScreen]'s day-navigator, up to the last 7 days).
final dayWaterLogProvider =
    FutureProvider.family<List<WaterLogEntry>, DateTime>((ref, day) async {
  ref.watch(dataRefreshSignalProvider);
  final repo = ref.read(waterLogRepositoryProvider);
  return repo.entriesForDay(day);
});
