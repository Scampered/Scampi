import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/exercise_log_entry.dart';
import '../../data/models/workout_session.dart';
import '../../data/repositories/exercise_log_repository.dart';
import '../../data/repositories/user_profile_repository.dart';

/// Notification button ids.
const String workoutPauseToggleButtonId = 'pause_toggle';
const String workoutStopButtonId = 'stop';

/// Marks a saved exercise_log row as coming from a live Workout Session
/// (as opposed to the manual [ExerciseLogEntry] logging sheet or the
/// Health Connect step sync) — same "stash it in `note`" approach those
/// already use, there's no dedicated source column.
const String workoutSessionNote = 'Live workout session';

/// Sessions shorter than this are treated as an accidental start/stop and
/// not saved — not a real workout worth logging.
const Duration _minSessionDurationToSave = Duration(seconds: 10);

/// Fallback bodyweight if, somehow, no profile exists yet when a session
/// ends — mirrors the same fallback used by the manual logging sheet.
const double _fallbackBodyWeightKg = 70;

/// Entry point the foreground service isolate calls to install the
/// handler. Must stay top-level/static per `flutter_foreground_task`'s
/// requirements — it's invoked in a fresh background isolate, so it can't
/// close over any state from the main isolate.
@pragma('vm:entry-point')
void workoutTaskStartCallback() {
  FlutterForegroundTask.setTaskHandler(WorkoutTaskHandler());
}

/// Runs in the foreground service's own background isolate — this is what
/// keeps the workout timer and its notification alive independent of the
/// main Flutter engine, so a session survives the app being backgrounded
/// or swiped from Recents entirely (the same mechanism apps like TikTok
/// use to keep background audio running).
///
/// This isolate is the single source of truth for the live session: it
/// owns the in-memory [WorkoutSession], persists it every tick so
/// [WorkoutSessionController] can rehydrate it on a fresh app start, and
/// — critically — saves the finished [ExerciseLogEntry] itself when
/// stopped, directly through [ExerciseLogRepository] (this isolate has its
/// own full plugin registration, sqflite included, so this works even if
/// the main app process has been killed entirely and "Stop" is pressed
/// straight from the notification). [WorkoutSessionController] just
/// mirrors this isolate's state for display and forwards in-app UI
/// actions here rather than mutating its own state directly, so there's
/// never two different opinions about what the session's state is.
class WorkoutTaskHandler extends TaskHandler {
  WorkoutSession? _session;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(activeWorkoutSessionPrefsKey);
    if (raw == null) return;
    try {
      _session = WorkoutSession.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      _session = null;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_session == null) return;
    _refreshNotification();
    _persist();
    _reportSessionToMain();
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    switch (data['cmd']) {
      case 'setIntensity':
        final name = data['intensity'] as String?;
        if (name == null) return;
        _mutate((s) => s.withIntensity(ExerciseIntensity.values.byName(name), DateTime.now()));
        break;
      case 'togglePause':
        _mutate((s) => s.isRunning ? s.paused(DateTime.now()) : s.resumed(DateTime.now()));
        break;
      case 'stop':
        _stop();
        break;
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == workoutPauseToggleButtonId) {
      _mutate((s) => s.isRunning ? s.paused(DateTime.now()) : s.resumed(DateTime.now()));
    } else if (id == workoutStopButtonId) {
      _stop();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _persist();
  }

  void _mutate(WorkoutSession Function(WorkoutSession) update) {
    final session = _session;
    if (session == null) return;
    _session = update(session);
    _refreshNotification();
    _persist();
    _reportSessionToMain();
  }

  Future<void> _stop() async {
    final session = _session;
    if (session != null) {
      final now = DateTime.now();
      Map<String, Object?>? savedEntry;
      final elapsed = session.elapsedAsOf(now);
      if (elapsed >= _minSessionDurationToSave) {
        final profile = await UserProfileRepository().getProfile();
        final bodyWeightKg = profile?.weightKg ?? _fallbackBodyWeightKg;
        final entry = ExerciseLogEntry(
          category: session.category,
          loggedAt: session.startedAt,
          durationMinutes: elapsed.inMinutes.clamp(1, 24 * 60),
          intensity: session.dominantIntensityAsOf(now),
          caloriesBurned: session.caloriesSoFarAsOf(now, bodyWeightKg: bodyWeightKg),
          wasEstimated: true,
          note: workoutSessionNote,
        );
        await ExerciseLogRepository().logEntry(entry);
        savedEntry = entry.toMap();
      }
      _session = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(activeWorkoutSessionPrefsKey);
      FlutterForegroundTask.sendDataToMain({'ended': true, 'entry': savedEntry});
    }
    await FlutterForegroundTask.stopService();
  }

  void _refreshNotification() {
    final session = _session;
    if (session == null) return;
    final now = DateTime.now();
    final paused = !session.isRunning;
    FlutterForegroundTask.updateService(
      notificationTitle:
          '${session.category.label} · ${session.currentIntensity.label}${paused ? ' (Paused)' : ''}',
      notificationText: formatWorkoutDuration(session.elapsedAsOf(now)),
      notificationButtons: [
        NotificationButton(id: workoutPauseToggleButtonId, text: paused ? 'Resume' : 'Pause'),
        const NotificationButton(id: workoutStopButtonId, text: 'Stop'),
      ],
    );
  }

  Future<void> _persist() async {
    final session = _session;
    if (session == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(activeWorkoutSessionPrefsKey, jsonEncode(session.toJson()));
  }

  void _reportSessionToMain() {
    final session = _session;
    if (session == null) return;
    FlutterForegroundTask.sendDataToMain({'session': session.toJson()});
  }
}
