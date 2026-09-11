import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/day_boundary.dart';

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

  // SLEEP_SESSION is the whole-night record most sources write (in
  // particular, a manually-entered sleep in Samsung Health) — it has a
  // start/end but no stage breakdown. SLEEP_ASLEEP is a finer-grained
  // stage record some sources (e.g. a tracked, not manually-entered,
  // night) also write alongside it. Requesting both and preferring
  // whichever is actually present avoids silently getting zero results
  // just because a source didn't happen to write stage-level data.
  //
  // ACTIVE_ENERGY_BURNED and DISTANCE_DELTA are what a wearable's own
  // health app (Samsung Health, etc.) actually writes for "calories
  // burned" and "distance walked" — derived from heart rate/GPS/
  // elevation, not just a step count. Reading these directly (with a
  // step-count estimate only as a fallback when they're absent) is what
  // lets Scampi's numbers line up with what the source app itself shows,
  // instead of recomputing a rougher estimate from steps alone.
  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_ASLEEP,
  ];
  static const _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

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

  /// Steps for [day] (respecting [resetMinuteOfDay]), bucketed into 24
  /// hourly totals starting at the reset time — e.g. bucket 0 is
  /// [resetHour, resetHour+1). Powers the "what time of day" step chart
  /// on the Exercise Details card, the same shape as Samsung Health's own
  /// hourly activity bars.
  ///
  /// Calls Health Connect's own interval-aggregate once per hour rather
  /// than summing raw STEPS records locally — Health Connect can hold
  /// overlapping records from more than one source (phone + watch both
  /// counting the same walk), and only its own aggregate query de-dupes
  /// that correctly. 24 short calls is not free, but this only runs when
  /// the user opens the details card, not on every sync.
  Future<List<int>> stepsByHour(DateTime day, int resetMinuteOfDay) async {
    await _configure();
    final window = dayWindowFor(day, resetMinuteOfDay);
    final now = DateTime.now();
    final buckets = <int>[];
    for (var i = 0; i < 24; i++) {
      final bucketStart = window.start.add(Duration(hours: i));
      if (bucketStart.isAfter(now)) {
        buckets.add(0);
        continue;
      }
      final bucketEnd = bucketStart.add(const Duration(hours: 1));
      final effectiveEnd = bucketEnd.isAfter(now) ? now : bucketEnd;
      final steps = await _health.getTotalStepsInInterval(bucketStart, effectiveEnd);
      buckets.add(steps ?? 0);
    }
    return buckets;
  }

  /// Total active-energy (i.e. NOT resting/BMR) calories Health Connect
  /// has for today, or null if the source app hasn't written any — the
  /// caller decides what "no data" should fall back to. Deliberately
  /// separate from [HealthDataType.TOTAL_CALORIES_BURNED], which bakes
  /// in BMR and would double-count against Scampi's own TDEE-based goal
  /// if added to it.
  Future<double?> todayActiveEnergyKcal() async {
    await _configure();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      startTime: midnight,
      endTime: now,
    );
    if (points.isEmpty) return null;
    final total = points.fold<double>(0, (sum, p) {
      final value = p.value;
      return sum + (value is NumericHealthValue ? value.numericValue.toDouble() : 0);
    });
    return total > 0 ? total : null;
  }

  /// Total distance Health Connect has for today, in km, or null if
  /// nothing's been written — same "let the caller pick the fallback"
  /// shape as [todayActiveEnergyKcal].
  Future<double?> todayDistanceKm() async {
    await _configure();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.DISTANCE_DELTA],
      startTime: midnight,
      endTime: now,
    );
    if (points.isEmpty) return null;
    final totalMeters = points.fold<double>(0, (sum, p) {
      final value = p.value;
      return sum + (value is NumericHealthValue ? value.numericValue.toDouble() : 0);
    });
    return totalMeters > 0 ? totalMeters / 1000 : null;
  }

  /// Total sleep duration for "last night" — sleep sessions ending
  /// between yesterday noon and today noon, which comfortably captures
  /// a normal overnight sleep regardless of exact bed/wake times.
  ///
  /// Prefers whole-night SLEEP_SESSION records (what a manually-entered
  /// Samsung Health sleep, or most simple trackers, actually write) over
  /// summing SLEEP_ASLEEP stage records — a session has no stages to sum
  /// in the first place, so requiring stage data would silently return
  /// nothing for the most common case.
  Future<Duration?> lastNightSleep() async {
    await _configure();
    final now = DateTime.now();
    final todayNoon = DateTime(now.year, now.month, now.day, 12);
    final windowStart = todayNoon.subtract(const Duration(days: 1));
    final windowEnd = now.isAfter(todayNoon) ? todayNoon : now;

    final sessions = await _health.getHealthDataFromTypes(
      types: [HealthDataType.SLEEP_SESSION],
      startTime: windowStart,
      endTime: windowEnd,
    );
    if (sessions.isNotEmpty) {
      return _sumDurations(sessions);
    }

    final stages = await _health.getHealthDataFromTypes(
      types: [HealthDataType.SLEEP_ASLEEP],
      startTime: windowStart,
      endTime: windowEnd,
    );
    if (stages.isEmpty) return null;
    return _sumDurations(stages);
  }

  /// Whether the Health Connect app itself is installed on this device —
  /// distinct from whether Scampi has been granted permission to read
  /// from it. Used by the setup/diagnostics screen to tell "not
  /// installed" apart from "installed but nothing's syncing".
  Future<bool> isHealthConnectInstalled() async {
    final status = await _health.getHealthConnectSdkStatus();
    return status == HealthConnectSdkStatus.sdkAvailable;
  }

  /// Per-type permission status, for the setup/diagnostics screen — the
  /// bulk [hasPermissions] check only says whether *all* types are
  /// granted, which isn't enough to tell someone specifically "steps is
  /// granted but distance isn't".
  Future<Map<HealthDataType, bool>> permissionStatusByType() async {
    await _configure();
    final result = <HealthDataType, bool>{};
    for (final type in _types) {
      result[type] = await _health.hasPermissions([type], permissions: [HealthDataAccess.READ]) ??
          false;
    }
    return result;
  }

  /// Whether Health Connect has ANY record of [type] in the last 30
  /// days — lets the setup screen distinguish "permission granted but no
  /// source app is actually writing this data" from a genuine sync
  /// problem on Scampi's side.
  Future<bool> hasRecentData(HealthDataType type) async {
    await _configure();
    final now = DateTime.now();
    final points = await _health.getHealthDataFromTypes(
      types: [type],
      startTime: now.subtract(const Duration(days: 30)),
      endTime: now,
    );
    return points.isNotEmpty;
  }

  Duration? _sumDurations(List<HealthDataPoint> points) {
    var total = Duration.zero;
    for (final point in points) {
      total += point.dateTo.difference(point.dateFrom);
    }
    return total > Duration.zero ? total : null;
  }
}
