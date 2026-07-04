import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/exercise_log_entry.dart';
import '../../data/models/workout_session.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';
import 'exercise_icons.dart';
import 'exercise_log_sheet.dart';
import 'fitness_log_provider.dart';
import 'workout_session_controller.dart';
import 'workout_session_sheet.dart';

/// Fitness tab — today's exercise log with a swipe-to-delete gesture on
/// each entry and a bottom sheet for logging a new session.
class FitnessScreen extends ConsumerWidget {
  const FitnessScreen({super.key});

  static Future<void> openLogSheet(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ExerciseLogSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(todayExerciseLogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fitness')),
      body: entriesAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('$err')),
        data: (entries) => _FitnessLogContent(entries: entries),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openLogSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Exercise'),
      ),
    );
  }
}

/// Live status card mirroring the workout notification: elapsed time, an
/// intensity switcher, Pause/Resume, and End.
class _ActiveWorkoutSessionCard extends ConsumerWidget {
  const _ActiveWorkoutSessionCard({
    required this.session,
    required this.ending,
    required this.onEnd,
  });

  final WorkoutSession session;
  final bool ending;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final selectionColor = scampiSelectionColor(context);

    return Card(
      color: ScampiColors.blue.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(ScampiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconForExerciseCategory(session.category), color: ScampiColors.blue),
                const SizedBox(width: ScampiSpacing.xs),
                Expanded(
                  child: Text(
                    '${session.category.label}${session.isRunning ? '' : ' (Paused)'}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  formatWorkoutDuration(session.elapsedAsOf(now)),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: ScampiSpacing.xs),
            Wrap(
              spacing: ScampiSpacing.xs,
              children: ExerciseIntensity.values.map((intensity) {
                final selected = intensity == session.currentIntensity;
                return ChoiceChip(
                  label: Text(intensity.label),
                  selected: selected,
                  onSelected: (_) =>
                      ref.read(workoutSessionControllerProvider.notifier).setIntensity(intensity),
                  selectedColor: selectionColor.withValues(alpha: 0.16),
                  labelStyle: TextStyle(
                    color: selected ? selectionColor : null,
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                  side: BorderSide(
                    color: selected ? selectionColor : theme.colorScheme.outlineVariant,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: ScampiSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(workoutSessionControllerProvider.notifier).togglePause(),
                    icon: Icon(session.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    label: Text(session.isRunning ? 'Pause' : 'Resume'),
                  ),
                ),
                const SizedBox(width: ScampiSpacing.xs),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: ending ? null : onEnd,
                    style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                    icon: ending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.stop_rounded),
                    label: const Text('End'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FitnessLogContent extends ConsumerStatefulWidget {
  const _FitnessLogContent({required this.entries});

  final List<ExerciseLogEntry> entries;

  @override
  ConsumerState<_FitnessLogContent> createState() => _FitnessLogContentState();
}

class _FitnessLogContentState extends ConsumerState<_FitnessLogContent> {
  // See food_screen.dart's _FoodLogContentState for why this exists:
  // filtering out just-dismissed entries locally avoids a Dismissible
  // being asked to rebuild after it already dismissed itself.
  final Set<int> _removedIds = {};
  bool _ending = false;

  Future<void> _endSession() async {
    if (_ending) return;
    setState(() => _ending = true);
    final saved = await ref.read(workoutSessionControllerProvider.notifier).end();
    ref.read(dataRefreshSignalProvider.notifier).bump();
    if (!mounted) return;
    setState(() => _ending = false);
    final calories = (saved?['calories_burned'] as num?)?.round();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(calories != null ? 'Workout saved: $calories kcal' : 'Workout ended'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.entries.where((e) => !_removedIds.contains(e.id)).toList();
    final session = ref.watch(workoutSessionControllerProvider);

    final totalCalories = entries.fold<double>(0, (sum, e) => sum + e.caloriesBurned);
    final totalMinutes = entries.fold<int>(0, (sum, e) => sum + e.durationMinutes);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ScampiSpacing.md,
            ScampiSpacing.sm,
            ScampiSpacing.md,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: entries.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${totalCalories.round()} kcal burned today',
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            '$totalMinutes min across ${entries.length} '
                            'session${entries.length == 1 ? '' : 's'}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
              ),
              if (session == null)
                OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const WorkoutSessionStartSheet(),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Live Session'),
                ),
            ],
          ),
        ),
        Expanded(
          child: (session == null && entries.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(ScampiSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_run_rounded,
                          size: 48,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: ScampiSpacing.sm),
                        Text(
                          'Nothing logged yet today.',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: ScampiSpacing.xxs),
                        Text(
                          'Tap "Add Exercise" to log a session.',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    ScampiSpacing.md,
                    ScampiSpacing.sm,
                    ScampiSpacing.md,
                    ScampiSpacing.xxl,
                  ),
                  children: [
                    if (session != null) ...[
                      _ActiveWorkoutSessionCard(
                        session: session,
                        ending: _ending,
                        onEnd: _endSession,
                      ),
                      const SizedBox(height: ScampiSpacing.md),
                    ],
                    for (final entry in entries)
                      _ExerciseLogTile(entry: entry, onDelete: () => _delete(entry)),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _delete(ExerciseLogEntry entry) async {
    if (entry.id == null) return;
    setState(() => _removedIds.add(entry.id!));
    await ref.read(exerciseLogRepositoryProvider).deleteEntry(entry.id!);
    ref.read(dataRefreshSignalProvider.notifier).bump();
  }
}

class _ExerciseLogTile extends StatelessWidget {
  const _ExerciseLogTile({required this.entry, required this.onDelete});

  final ExerciseLogEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      '${entry.durationMinutes} min',
      entry.intensity.label,
      if (entry.distanceKm != null) '${entry.distanceKm!.toStringAsFixed(1)} km',
    ].join(' · ');

    return Dismissible(
      key: ValueKey(entry.id ?? entry.hashCode),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: ScampiSpacing.xs),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.85),
          borderRadius: ScampiRadius.mdBorder,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: ScampiSpacing.md),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: ScampiSpacing.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ScampiSpacing.md,
            vertical: ScampiSpacing.sm,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: ScampiColors.blue.withValues(alpha: 0.15),
                child: Icon(iconForExerciseCategory(entry.category), color: ScampiColors.blue),
              ),
              const SizedBox(width: ScampiSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.category.label, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(details, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                '${entry.caloriesBurned.round()} kcal',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ScampiColors.macroProtein,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
