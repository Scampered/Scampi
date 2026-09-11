import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'health_sync_service.dart';

const _healthSyncEnabledPrefsKey = 'scampi_health_sync_enabled';
const _healthSyncLastSyncedAtPrefsKey = 'scampi_health_last_synced_at';
const _healthSyncLastErrorPrefsKey = 'scampi_health_last_error';
const _healthSyncStepsSyncedPrefsKey = 'scampi_health_steps_synced';
const _healthSyncStepsSkipReasonPrefsKey = 'scampi_health_steps_skip_reason';
const _healthSyncSleepSyncedPrefsKey = 'scampi_health_sleep_synced';
const _healthSyncSleepSkipReasonPrefsKey = 'scampi_health_sleep_skip_reason';

/// Whether the user has opted in to syncing steps/sleep from Health
/// Connect. Off by default — this reads sensitive health data, so it
/// should never be silently on.
class HealthSyncController extends StateNotifier<bool> {
  HealthSyncController() : super(false) {
    _loaded = _load();
  }

  /// Resolves once the persisted enabled/disabled flag has actually been
  /// read from SharedPreferences. `state` starts as the constructor's
  /// `false` default and only becomes accurate after that async read
  /// completes — a caller that reads `state` before awaiting this (e.g.
  /// a cold-start sync firing in the very first frame) would see "off"
  /// even when the user has it turned on, and silently skip syncing. This
  /// was the actual cause of Health Connect only ever syncing via the
  /// manual "Sync Now" button or a resume, never a true cold start.
  late final Future<void> _loaded;
  Future<void> get ready => _loaded;

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
/// Profile so a failure (or a silent skip, e.g. "no sleep data found") is
/// visible instead of looking identical to success (which is what
/// [HealthSyncService.syncToday]'s callers do on the happy path, since a
/// background sync should never interrupt the user with an error dialog).
class HealthSyncStatus {
  const HealthSyncStatus({this.lastSyncedAt, this.lastError, this.lastOutcome});

  final DateTime? lastSyncedAt;
  final String? lastError;
  final HealthSyncOutcome? lastOutcome;
}

class HealthSyncStatusController extends StateNotifier<HealthSyncStatus> {
  HealthSyncStatusController() : super(const HealthSyncStatus()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_healthSyncLastSyncedAtPrefsKey);
    final stepsSynced = prefs.getBool(_healthSyncStepsSyncedPrefsKey);
    final sleepSynced = prefs.getBool(_healthSyncSleepSyncedPrefsKey);
    state = HealthSyncStatus(
      lastSyncedAt: iso != null ? DateTime.tryParse(iso) : null,
      lastError: prefs.getString(_healthSyncLastErrorPrefsKey),
      lastOutcome: stepsSynced != null && sleepSynced != null
          ? HealthSyncOutcome(
              stepsSynced: stepsSynced,
              stepsSkipReason: prefs.getString(_healthSyncStepsSkipReasonPrefsKey),
              sleepSynced: sleepSynced,
              sleepSkipReason: prefs.getString(_healthSyncSleepSkipReasonPrefsKey),
            )
          : null,
    );
  }

  Future<void> recordSuccess(HealthSyncOutcome outcome) async {
    final now = DateTime.now();
    state = HealthSyncStatus(lastSyncedAt: now, lastError: null, lastOutcome: outcome);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_healthSyncLastSyncedAtPrefsKey, now.toIso8601String());
    await prefs.remove(_healthSyncLastErrorPrefsKey);
    await prefs.setBool(_healthSyncStepsSyncedPrefsKey, outcome.stepsSynced);
    await prefs.setBool(_healthSyncSleepSyncedPrefsKey, outcome.sleepSynced);
    if (outcome.stepsSkipReason != null) {
      await prefs.setString(_healthSyncStepsSkipReasonPrefsKey, outcome.stepsSkipReason!);
    } else {
      await prefs.remove(_healthSyncStepsSkipReasonPrefsKey);
    }
    if (outcome.sleepSkipReason != null) {
      await prefs.setString(_healthSyncSleepSkipReasonPrefsKey, outcome.sleepSkipReason!);
    } else {
      await prefs.remove(_healthSyncSleepSkipReasonPrefsKey);
    }
  }

  Future<void> recordFailure(String message) async {
    state = HealthSyncStatus(
      lastSyncedAt: state.lastSyncedAt,
      lastError: message,
      lastOutcome: state.lastOutcome,
    );
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
    final outcome = await HealthSyncService.instance.syncToday(bodyWeightKg: bodyWeightKg);
    await ref.read(healthSyncStatusProvider.notifier).recordSuccess(outcome);
  } catch (e) {
    await ref.read(healthSyncStatusProvider.notifier).recordFailure(e.toString());
    rethrow;
  }
}
