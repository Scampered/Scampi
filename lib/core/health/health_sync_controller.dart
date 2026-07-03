import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _healthSyncEnabledPrefsKey = 'scampi_health_sync_enabled';

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
