import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/water_weight_log.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/data_refresh_signal.dart';

/// Today's logged water entries — same refresh-signal pattern as the food
/// and exercise logs. Powers the water history/remove sheet on Home.
final todayWaterLogProvider = FutureProvider<List<WaterLogEntry>>((ref) async {
  ref.watch(dataRefreshSignalProvider);
  final repo = ref.read(waterLogRepositoryProvider);
  return repo.entriesForDay(DateTime.now());
});
