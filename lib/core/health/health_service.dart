import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around the `health` package (Android Health Connect) —
/// the on-device hub that Google Fit, Samsung Health, and most fitness
/// wearables already write their steps/sleep data into, so connecting to
/// it covers "any health app" without Scampi needing per-vendor
/// integrations. Purely local reads; nothing is sent anywhere.
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  final _health = Health();
  bool _configured = false;

  static const _types = [HealthDataType.STEPS, HealthDataType.SLEEP_ASLEEP];
  static const _permissions = [HealthDataAccess.READ, HealthDataAccess.READ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Requests the Activity Recognition runtime permission (needed for
  /// step data) and Health Connect's own data-type authorization.
  /// Returns whether both were granted.
  Future<bool> requestPermissions() async {
    await _configure();

    final activityStatus = await Permission.activityRecognition.request();
    if (!activityStatus.isGranted) return false;

    final hasPermissions = await _health.hasPermissions(_types, permissions: _permissions);
    if (hasPermissions == true) return true;

    return _health.requestAuthorization(_types, permissions: _permissions);
  }

  Future<bool> hasPermissions() async {
    await _configure();
    return await _health.hasPermissions(_types, permissions: _permissions) ?? false;
  }

  /// Total steps recorded today (since local midnight).
  Future<int> todaySteps() async {
    await _configure();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(midnight, now);
    return steps ?? 0;
  }

  /// Total sleep duration for "last night" — sleep sessions ending
  /// between yesterday noon and today noon, which comfortably captures
  /// a normal overnight sleep regardless of exact bed/wake times.
  Future<Duration?> lastNightSleep() async {
    await _configure();
    final now = DateTime.now();
    final todayNoon = DateTime(now.year, now.month, now.day, 12);
    final windowStart = todayNoon.subtract(const Duration(days: 1));
    final windowEnd = now.isAfter(todayNoon) ? todayNoon : now;

    final data = await _health.getHealthDataFromTypes(
      types: [HealthDataType.SLEEP_ASLEEP],
      startTime: windowStart,
      endTime: windowEnd,
    );
    if (data.isEmpty) return null;

    var total = Duration.zero;
    for (final point in data) {
      total += point.dateTo.difference(point.dateFrom);
    }
    return total > Duration.zero ? total : null;
  }
}
