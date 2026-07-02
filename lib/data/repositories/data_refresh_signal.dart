import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A simple incrementing counter that other providers can `watch` to
/// know when to refetch. Call `ref.read(dataRefreshSignalProvider.notifier)
/// .bump()` after any write (logging food, water, exercise, weight,
/// starting/ending a fast) so dependent FutureProviders re-run.
///
/// This is a deliberately simple alternative to wiring up a full
/// stream-based reactive layer over sqflite — appropriate for a
/// single-user local app where writes are infrequent relative to reads.
class DataRefreshSignal extends StateNotifier<int> {
  DataRefreshSignal() : super(0);

  void bump() => state = state + 1;
}

final dataRefreshSignalProvider =
    StateNotifierProvider<DataRefreshSignal, int>((ref) => DataRefreshSignal());
