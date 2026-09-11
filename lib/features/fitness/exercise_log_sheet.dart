import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/selected_day_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/exercise_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';
import '../profile/current_profile_provider.dart';
import 'exercise_icons.dart';

/// Fallback bodyweight used for the MET calorie estimate on the rare
/// chance no profile has been saved yet — should never really happen
/// since onboarding requires a weight, but keeps the estimate from
/// crashing rather than silently being wrong.
const double _fallbackBodyWeightKg = 70;

/// Bottom sheet for logging an exercise session: category, intensity,
/// duration, optional distance, with a live MET-based calorie estimate
/// the user can override by editing the calories field directly.
///
/// Pass [existing] to edit an already-logged entry instead of creating a
/// new one — prefills every field from it, keeps its original
/// `loggedAt`/id, and swaps the button to "Update Exercise".
class ExerciseLogSheet extends ConsumerStatefulWidget {
  const ExerciseLogSheet({super.key, this.existing});

  final ExerciseLogEntry? existing;

  @override
  ConsumerState<ExerciseLogSheet> createState() => _ExerciseLogSheetState();
}

class _ExerciseLogSheetState extends ConsumerState<ExerciseLogSheet> {
  bool get _isEditing => widget.existing != null;

  late ExerciseCategory _category =
      widget.existing?.category ?? ExerciseCategory.walking;
  late ExerciseIntensity _intensity =
      widget.existing?.intensity ?? ExerciseIntensity.moderate;
  late final _durationController = TextEditingController(
      text: (widget.existing?.durationMinutes ?? 30).toString());
  late final _distanceController = TextEditingController(
    text: widget.existing?.distanceKm != null
        ? _trimZeros(widget.existing!.distanceKm!)
        : '',
  );
  late final _caloriesController = TextEditingController(
    text: widget.existing != null
        ? widget.existing!.caloriesBurned.round().toString()
        : '',
  );
  // Editing an entry that was already manually adjusted (or already had
  // a real logged value) should keep the calories field as "manual" from
  // the start — re-opening it shouldn't silently start overwriting a
  // deliberately-entered number the moment duration/intensity changes.
  late bool _caloriesEditedManually =
      widget.existing != null && !widget.existing!.wasEstimated;
  bool _saving = false;

  static String _trimZeros(double value) {
    var s = value.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  @override
  void initState() {
    super.initState();
    _durationController.addListener(_recomputeEstimate);
    _distanceController.addListener(_recomputeEstimate);
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeEstimate());
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _distanceController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  double get _bodyWeightKg {
    final profile = ref.read(currentProfileProvider).value;
    return profile?.weightKg ?? _fallbackBodyWeightKg;
  }

  int get _durationMinutes => int.tryParse(_durationController.text) ?? 0;

  void _recomputeEstimate() {
    if (_caloriesEditedManually) return;
    final estimate = ExerciseLogEntry.estimateCalories(
      category: _category,
      intensity: _intensity,
      durationMinutes: _durationMinutes,
      bodyWeightKg: _bodyWeightKg,
      distanceKm: double.tryParse(_distanceController.text),
    );
    _caloriesController.text = estimate.round().toString();
    setState(() {});
  }

  void _selectCategory(ExerciseCategory category) {
    setState(() => _category = category);
    _recomputeEstimate();
  }

  void _selectIntensity(ExerciseIntensity intensity) {
    setState(() => _intensity = intensity);
    _recomputeEstimate();
  }

  Future<void> _save() async {
    final calories = double.tryParse(_caloriesController.text) ?? 0;
    if (_durationMinutes <= 0 || calories <= 0 || _saving) return;
    setState(() => _saving = true);

    final existing = widget.existing;
    final entry = ExerciseLogEntry(
      id: existing?.id,
      category: _category,
      // Editing keeps the entry's original day/time — only a brand new
      // entry should adopt "now" on whichever day is currently selected.
      loggedAt: existing?.loggedAt ??
          combineDayWithNow(ref.read(selectedDayProvider)),
      durationMinutes: _durationMinutes,
      distanceKm: double.tryParse(_distanceController.text),
      intensity: _intensity,
      caloriesBurned: calories,
      wasEstimated: !_caloriesEditedManually,
      // Once a user has hand-edited it, it's a manual entry regardless of
      // where it came from — clearing the note (e.g.
      // healthSyncStepsNote) keeps the next Health Connect sync from
      // treating it as still "its" auto-synced row to silently replace.
      note: null,
    );

    final repo = ref.read(exerciseLogRepositoryProvider);
    if (existing?.id != null) {
      await repo.updateEntry(entry);
    } else {
      await repo.logEntry(entry);
    }
    ref.read(dataRefreshSignalProvider.notifier).bump();

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    // Recompute once the profile (and its weight) finishes loading.
    ref.listen(currentProfileProvider, (_, __) => _recomputeEstimate());

    final theme = Theme.of(context);
    final selectionColor = scampiSelectionColor(context);
    final showDistance = distanceTrackedCategories.contains(_category);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(ScampiRadius.lg)),
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
                Text(_isEditing ? 'Edit Exercise' : 'Log Exercise',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: ScampiSpacing.md),
                Text('Category', style: theme.textTheme.labelLarge),
                const SizedBox(height: ScampiSpacing.xs),
                Wrap(
                  spacing: ScampiSpacing.xs,
                  runSpacing: ScampiSpacing.xs,
                  children: selectableExerciseCategories.map((category) {
                    final selected = category == _category;
                    return ChoiceChip(
                      avatar: Icon(
                        iconForExerciseCategory(category),
                        size: 18,
                        color: selected
                            ? selectionColor
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      label: Text(category.label),
                      selected: selected,
                      onSelected: (_) => _selectCategory(category),
                      selectedColor: selectionColor.withValues(alpha: 0.16),
                      labelStyle: TextStyle(
                        color: selected ? selectionColor : null,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                      side: BorderSide(
                        color: selected
                            ? selectionColor
                            : theme.colorScheme.outlineVariant,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: ScampiSpacing.md),
                Text('Intensity', style: theme.textTheme.labelLarge),
                const SizedBox(height: ScampiSpacing.xs),
                Wrap(
                  spacing: ScampiSpacing.xs,
                  children: ExerciseIntensity.values.map((intensity) {
                    final selected = intensity == _intensity;
                    return ChoiceChip(
                      label: Text(intensity.label),
                      selected: selected,
                      onSelected: (_) => _selectIntensity(intensity),
                      selectedColor: selectionColor.withValues(alpha: 0.16),
                      labelStyle: TextStyle(
                        color: selected ? selectionColor : null,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                      side: BorderSide(
                        color: selected
                            ? selectionColor
                            : theme.colorScheme.outlineVariant,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: ScampiSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Duration (min)',
                          border: OutlineInputBorder(
                              borderRadius: ScampiRadius.smBorder),
                        ),
                      ),
                    ),
                    if (showDistance) ...[
                      const SizedBox(width: ScampiSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _distanceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Distance (km)',
                            border: OutlineInputBorder(
                                borderRadius: ScampiRadius.smBorder),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: ScampiSpacing.md),
                TextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) =>
                      setState(() => _caloriesEditedManually = true),
                  decoration: InputDecoration(
                    labelText: 'Calories burned',
                    helperText: _caloriesEditedManually
                        ? 'Entered manually'
                        : showDistance
                            ? 'Estimated from pace, intensity, duration & your weight'
                            : 'Estimated from category, intensity, duration & your weight',
                    border:
                        OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
                  ),
                ),
                const SizedBox(height: ScampiSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Update' : 'Log Exercise'),
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
