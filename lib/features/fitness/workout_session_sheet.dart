import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/exercise_log_entry.dart';
import 'exercise_icons.dart';
import 'workout_session_controller.dart';

/// Bottom sheet to start a live Workout Session: pick one exercise and a
/// starting intensity, then hand off to [WorkoutSessionController.start].
/// Unlike [ExerciseLogSheet] there's no duration/distance/calories entry
/// here — those are all derived live from the session's actual intensity
/// timeline once it's running.
class WorkoutSessionStartSheet extends ConsumerStatefulWidget {
  const WorkoutSessionStartSheet({super.key});

  @override
  ConsumerState<WorkoutSessionStartSheet> createState() => _WorkoutSessionStartSheetState();
}

class _WorkoutSessionStartSheetState extends ConsumerState<WorkoutSessionStartSheet> {
  ExerciseCategory _category = ExerciseCategory.walking;
  ExerciseIntensity _intensity = ExerciseIntensity.moderate;
  bool _starting = false;

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    await ref.read(workoutSessionControllerProvider.notifier).start(_category, _intensity);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectionColor = scampiSelectionColor(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ScampiRadius.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(
          ScampiSpacing.lg,
          ScampiSpacing.sm,
          ScampiSpacing.lg,
          ScampiSpacing.lg,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: ScampiSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: ScampiRadius.pillBorder,
                    ),
                  ),
                ),
                Text('Start Live Workout', style: theme.textTheme.titleLarge),
                const SizedBox(height: ScampiSpacing.xxs),
                Text(
                  'One exercise per session. Calories are tracked live from '
                  'the time spent at each intensity — you can change '
                  'intensity mid-session.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: ScampiSpacing.md),
                Text('Exercise', style: theme.textTheme.labelLarge),
                const SizedBox(height: ScampiSpacing.xs),
                Wrap(
                  spacing: ScampiSpacing.xs,
                  runSpacing: ScampiSpacing.xs,
                  children: ExerciseCategory.values.map((category) {
                    final selected = category == _category;
                    return ChoiceChip(
                      avatar: Icon(
                        iconForExerciseCategory(category),
                        size: 18,
                        color: selected ? selectionColor : theme.colorScheme.onSurfaceVariant,
                      ),
                      label: Text(category.label),
                      selected: selected,
                      onSelected: (_) => setState(() => _category = category),
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
                const SizedBox(height: ScampiSpacing.md),
                Text('Starting Intensity', style: theme.textTheme.labelLarge),
                const SizedBox(height: ScampiSpacing.xs),
                Wrap(
                  spacing: ScampiSpacing.xs,
                  children: ExerciseIntensity.values.map((intensity) {
                    final selected = intensity == _intensity;
                    return ChoiceChip(
                      label: Text(intensity.label),
                      selected: selected,
                      onSelected: (_) => setState(() => _intensity = intensity),
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
                const SizedBox(height: ScampiSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _starting ? null : _start,
                    icon: _starting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Session'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
