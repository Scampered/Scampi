import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/exercise_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';
import 'exercise_icons.dart';
import 'exercise_log_sheet.dart';
import 'fitness_log_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.entries.where((e) => !_removedIds.contains(e.id)).toList();

    if (entries.isEmpty) {
      return Center(
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
      );
    }

    final totalCalories = entries.fold<double>(0, (sum, e) => sum + e.caloriesBurned);
    final totalMinutes = entries.fold<int>(0, (sum, e) => sum + e.durationMinutes);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ScampiSpacing.md,
        ScampiSpacing.sm,
        ScampiSpacing.md,
        ScampiSpacing.xxl,
      ),
      children: [
        Text(
          '${totalCalories.round()} kcal burned today',
          style: theme.textTheme.titleMedium,
        ),
        Text(
          '$totalMinutes min across ${entries.length} session${entries.length == 1 ? '' : 's'}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: ScampiSpacing.md),
        for (final entry in entries)
          _ExerciseLogTile(entry: entry, onDelete: () => _delete(entry)),
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
