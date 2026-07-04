import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/workout/workout_task_handler.dart';
import '../../data/models/exercise_log_entry.dart';
import '../../data/models/workout_session.dart';

const int _workoutServiceId = 4001;

/// Riverpod mirror of the live Workout Session. The real state lives in
/// the foreground service's background isolate ([WorkoutTaskHandler]) so
/// it survives the app being backgrounded or killed — this controller
/// just displays whatever that isolate last reported, rehydrates it on a
/// fresh app start, and forwards in-app button presses there rather than
/// mutating its own state directly (so there's one source of truth
/// regardless of whether an action came from the UI or the notification).
class WorkoutSessionController extends StateNotifier<WorkoutSession?> {
  WorkoutSessionController() : super(null) {
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _rehydrate();
  }

  Timer? _ticker;
  Completer<Map<String, Object?>?>? _pendingEndResult;

  @override
  void dispose() {
    _ticker?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  Future<void> _rehydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(activeWorkoutSessionPrefsKey);
    if (raw == null) return;
    try {
      final session = WorkoutSession.fromJson(jsonDecode(raw) as Map<String, Object?>);
      final serviceRunning = await FlutterForegroundTask.isRunningService;
      if (!serviceRunning) {
        // The service died independently of the session record (rare —
        // e.g. the OS killed it outright). Nothing to safely resume from
        // here; drop the stale record rather than show a "live" session
        // whose timer isn't actually running anywhere.
        await prefs.remove(activeWorkoutSessionPrefsKey);
        return;
      }
      state = session;
      _startTicker();
    } catch (_) {
      await prefs.remove(activeWorkoutSessionPrefsKey);
    }
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final sessionJson = data['session'];
    if (sessionJson is Map) {
      try {
        state = WorkoutSession.fromJson(Map<String, Object?>.from(sessionJson));
      } catch (_) {
        // Ignore a malformed echo — the optimistic local update (or the
        // next tick's echo) is still good enough.
      }
    }
    if (data['ended'] == true) {
      _ticker?.cancel();
      state = null;
      final entry = data['entry'];
      _pendingEndResult?.complete(entry is Map ? Map<String, Object?>.from(entry) : null);
      _pendingEndResult = null;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    // Nothing to compute here — this just forces the live status card
    // (which reads `elapsedAsOf(DateTime.now())` off `state`) to rebuild
    // once a second. The actual elapsed/calorie numbers are always
    // recomputed fresh from the segment timestamps, never accumulated.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = state;
      if (session != null) state = session;
    });
  }

  Future<void> _ensureServiceInitialized() async {
    final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    await _requestBatteryOptimizationExemptionOnce();

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'scampi_workout_session',
        channelName: 'Workout Session',
        channelDescription: 'Shows while a live Workout Session is running.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  /// Asks, once ever, to be exempted from battery optimization — without
  /// it, some OEMs (Samsung included) may still kill the foreground
  /// service in the background despite it being correctly configured.
  /// Only asked the first time a session is ever started, not on every
  /// single start, since it takes the user to a system settings screen.
  Future<void> _requestBatteryOptimizationExemptionOnce() async {
    const prefsKey = 'scampi_workout_battery_hint_shown';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(prefsKey) ?? false) return;
    await prefs.setBool(prefsKey, true);
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  Future<void> start(ExerciseCategory category, ExerciseIntensity intensity) async {
    if (state != null) return; // one session at a time
    await _ensureServiceInitialized();

    final now = DateTime.now();
    final session = WorkoutSession.start(category, intensity, now);
    state = session;
    await _persist(session);
    _startTicker();

    await FlutterForegroundTask.startService(
      serviceId: _workoutServiceId,
      notificationTitle: '${category.label} · ${intensity.label}',
      notificationText: formatWorkoutDuration(Duration.zero),
      notificationButtons: const [
        NotificationButton(id: workoutPauseToggleButtonId, text: 'Pause'),
        NotificationButton(id: workoutStopButtonId, text: 'Stop'),
      ],
      callback: workoutTaskStartCallback,
    );
  }

  Future<void> setIntensity(ExerciseIntensity intensity) async {
    final session = state;
    if (session == null) return;
    state = session.withIntensity(intensity, DateTime.now());
    FlutterForegroundTask.sendDataToTask({'cmd': 'setIntensity', 'intensity': intensity.name});
  }

  Future<void> togglePause() async {
    final session = state;
    if (session == null) return;
    final now = DateTime.now();
    state = session.isRunning ? session.paused(now) : session.resumed(now);
    FlutterForegroundTask.sendDataToTask({'cmd': 'togglePause'});
  }

  /// Ends the session and returns the saved entry's summary map (via
  /// [ExerciseLogEntry.toMap]) once the background isolate confirms it —
  /// or `null` if the session was too short to have been logged at all.
  /// The actual save happens in [WorkoutTaskHandler], not here, so a
  /// "Stop" pressed straight from the notification (app fully closed)
  /// saves correctly too. Callers should still bump
  /// `dataRefreshSignalProvider` themselves afterward, same as any other
  /// repository write in this app.
  Future<Map<String, Object?>?> end() async {
    final session = state;
    if (session == null) return null;
    _ticker?.cancel();

    final completer = Completer<Map<String, Object?>?>();
    _pendingEndResult = completer;
    FlutterForegroundTask.sendDataToTask({'cmd': 'stop'});
    state = null;

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
  }

  Future<void> _persist(WorkoutSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(activeWorkoutSessionPrefsKey, jsonEncode(session.toJson()));
  }
}

final workoutSessionControllerProvider =
    StateNotifierProvider<WorkoutSessionController, WorkoutSession?>(
  (ref) => WorkoutSessionController(),
);
