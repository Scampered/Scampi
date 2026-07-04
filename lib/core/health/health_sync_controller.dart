import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'health_sync_service.dart';

const _healthSyncEnabledPrefsKey = 'scampi_health_sync_enabled';
const _healthSyncLastSyncedAtPrefsKey = 'scampi_health_last_synced_at';
const _healthSyncLastErrorPrefsKey = 'scampi_health_last_error';

/// Whether the user has opted in to syncing steps/sleep from Health
/// Connect. Off by default — this reads sensitive health data, so it
/// should never be silently on.
class HealthSyncController extends StateNotifier<bool> {
  HealthSyncController() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_healthSyncEnabledPrefsKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_healthSyncEnabledPrefsKey, enabled);
  }
}

final healthSyncEnabledProvider = StateNotifierProvider<HealthSyncController, bool>(
  (ref) => HealthSyncController(),
);

/// Last known outcome of a Health Connect sync attempt — surfaced in
/// Profile so a failure is visible instead of silently swallowed (which is
/// what [HealthSyncService.syncToday]'s callers do, since a background
/// sync should never interrupt the user with an error dialog).
class HealthSyncStatus {
  const HealthSyncStatus({this.lastSyncedAt, this.lastError});

  final DateTime? lastSyncedAt;
  final String? lastError;
}

class HealthSyncStatusController extends StateNotifier<HealthSyncStatus> {
  HealthSyncStatusController() : super(const HealthSyncStatus()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_healthSyncLastSyncedAtPrefsKey);
    state = HealthSyncStatus(
      lastSyncedAt: iso != null ? DateTime.tryParse(iso) : null,
      lastError: prefs.getString(_healthSyncLastErrorPrefsKey),
    );
  }

  Future<void> recordSuccess() async {
    final now = DateTime.now();
    state = HealthSyncStatus(lastSyncedAt: now, lastError: null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_healthSyncLastSyncedAtPrefsKey, now.toIso8601String());
    await prefs.remove(_healthSyncLastErrorPrefsKey);
  }

  Future<void> recordFailure(String message) async {
    state = HealthSyncStatus(lastSyncedAt: state.lastSyncedAt, lastError: message);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_healthSyncLastErrorPrefsKey, message);
  }
}

final healthSyncStatusProvider =
    StateNotifierProvider<HealthSyncStatusController, HealthSyncStatus>(
  (ref) => HealthSyncStatusController(),
);

/// Runs [HealthSyncService.syncToday] and records the outcome into
/// [healthSyncStatusProvider] either way, so every call site (silent
/// startup sync, resume sync, manual "Sync Now") gets the same visible
/// status instead of each having to remember to record it themselves.
/// Rethrows on failure — callers that want to stay silent should catch it.
Future<void> performHealthSync(WidgetRef ref, {required double bodyWeightKg}) async {
  try {
    await HealthSyncService.instance.syncToday(bodyWeightKg: bodyWeightKg);
    await ref.read(healthSyncStatusProvider.notifier).recordSuccess();
  } catch (e) {
    await ref.read(healthSyncStatusProvider.notifier).recordFailure(e.toString());
    rethrow;
  }
}
