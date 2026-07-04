import '../../data/models/exercise_log_entry.dart';
import '../../data/models/sleep_log_entry.dart';
import '../../data/repositories/exercise_log_repository.dart';
import '../../data/repositories/sleep_log_repository.dart';
import 'health_service.dart';

/// Marks an exercise_log row as auto-synced from Health Connect (in the
/// `note` field, since there's no dedicated "source" column) — lets a
/// re-sync find and replace today's synced entry instead of piling up a
/// new one every time the app opens.
const String healthSyncStepsNote = 'Auto-synced from Health Connect';

/// Average walking stride length, used to turn a step count into a
/// rough distance — a reasonable population average, not personalized.
const double _strideKm = 0.0008;
const double _assumedWalkingSpeedKmh = 5.0;

/// Pulls today's steps and last night's sleep from Health Connect (via
/// [HealthService]) and folds them into Scampi's own logs:
/// - Steps become a "Walking" exercise entry, replacing any previous
///   auto-synced entry for today (so re-syncing updates rather than
///   duplicates).
/// - Sleep only fills in if the user hasn't already logged sleep for
///   today — a sync never overwrites a manual entry.
class HealthSyncService {
  HealthSyncService._();
  static final HealthSyncService instance = HealthSyncService._();

  /// Does NOT gate on [HealthService.hasPermissions] — that call is
  /// documented as unreliable on Android Health Connect (it frequently
  /// returns null/false even when permission was actually granted), which
  /// previously made this method silently no-op every single sync. The
  /// real gate is the user's opt-in toggle (checked by callers before
  /// invoking this); here we just attempt the reads and let Health
  /// Connect itself return nothing if access truly isn't there.
  Future<void> syncToday({
    required double bodyWeightKg,
  }) async {
    await _syncSteps(bodyWeightKg: bodyWeightKg);
    await _syncSleep();
  }

  Future<void> _syncSteps({required double bodyWeightKg}) async {
    final steps = await HealthService.instance.todaySteps();
    if (steps <= 0) return;

    final repo = ExerciseLogRepository();
    final today = DateTime.now();
    final existing = await repo.entriesForDay(today);
    for (final entry in existing) {
      if (entry.note == healthSyncStepsNote && entry.id != null) {
        await repo.deleteEntry(entry.id!);
      }
    }

    final distanceKm = steps * _strideKm;
    final durationMinutes = (distanceKm / _assumedWalkingSpeedKmh * 60).round().clamp(1, 24 * 60);
    final calories = ExerciseLogEntry.estimateCalories(
      category: ExerciseCategory.walking,
      intensity: ExerciseIntensity.moderate,
      durationMinutes: durationMinutes,
      bodyWeightKg: bodyWeightKg,
      distanceKm: distanceKm,
    );

    await repo.logEntry(
      ExerciseLogEntry(
        category: ExerciseCategory.walking,
        loggedAt: today,
        durationMinutes: durationMinutes,
        distanceKm: distanceKm,
        intensity: ExerciseIntensity.moderate,
        caloriesBurned: calories,
        wasEstimated: true,
        note: healthSyncStepsNote,
      ),
    );
  }

  Future<void> _syncSleep() async {
    final today = DateTime.now();
    final repo = SleepLogRepository();
    final existing = await repo.entryForDay(today);
    if (existing != null) return; // never overwrite an existing entry

    final sleep = await HealthService.instance.lastNightSleep();
    if (sleep == null) return;

    await repo.logEntry(
      SleepLogEntry(
        date: today,
        hours: sleep.inMinutes / 60.0,
      ),
    );
  }
}
