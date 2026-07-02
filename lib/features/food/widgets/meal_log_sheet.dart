import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/food_log_entry.dart';
import '../../../data/models/meal.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/data_refresh_signal.dart';
import 'quantity_entry_sheet.dart' show defaultMealSlotForNow;

/// What the caller should do after [MealLogSheet] closes.
enum MealSheetResult { logged, edit, deleted }

/// Bottom sheet for logging a saved custom [Meal]. A meal is logged as a
/// single [FoodLogEntry] snapshot (foodId null, foodName = meal name)
/// scaled by how many servings of the whole recipe were eaten, rather
/// than exploding it into one entry per ingredient. Also offers Edit
/// (hands off to the caller to open the meal builder in edit mode) and
/// Delete (handled right here, with a confirmation dialog).
class MealLogSheet extends ConsumerStatefulWidget {
  const MealLogSheet({super.key, required this.meal});

  final Meal meal;

  @override
  ConsumerState<MealLogSheet> createState() => _MealLogSheetState();
}

class _MealLogSheetState extends ConsumerState<MealLogSheet> {
  late final TextEditingController _servingsController;
  double _servings = 1;
  MealSlot _mealSlot = defaultMealSlotForNow();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _servingsController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _servingsController.dispose();
    super.dispose();
  }

  void _onServingsChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) return;
    setState(() => _servings = parsed);
  }

  Future<void> _confirm() async {
    if (_servings <= 0 || _saving) return;
    setState(() => _saving = true);

    final nutrition = widget.meal.totalNutrition * _servings;
    final entry = FoodLogEntry(
      foodId: null,
      foodName: widget.meal.name,
      loggedAt: DateTime.now(),
      mealSlot: _mealSlot,
      quantityMode: QuantityMode.servings,
      grams: widget.meal.totalGrams * _servings,
      servings: _servings,
      calories: nutrition.calories,
      proteinG: nutrition.proteinG,
      carbsG: nutrition.carbsG,
      fatG: nutrition.fatG,
    );

    await ref.read(foodLogRepositoryProvider).logEntry(entry);
    ref.read(dataRefreshSignalProvider.notifier).bump();

    if (mounted) Navigator.of(context).pop(MealSheetResult.logged);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text('"${widget.meal.name}" will be removed. This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(mealRepositoryProvider).deleteMeal(widget.meal.id!);
    if (mounted) Navigator.of(context).pop(MealSheetResult.deleted);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectionColor = scampiSelectionColor(context);
    final base = widget.meal.totalNutrition;
    final nutrition = base * _servings;

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
              Row(
                children: [
                  Expanded(
                    child: Text(widget.meal.name, style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(MealSheetResult.edit),
                    child: const Text('Edit'),
                  ),
                  IconButton(
                    tooltip: 'Delete meal',
                    icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                    onPressed: _delete,
                  ),
                ],
              ),
              Text(
                '${widget.meal.ingredients.length} ingredients · '
                '${base.calories.round()} kcal per serving',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: ScampiSpacing.lg),
              TextField(
                controller: _servingsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onServingsChanged,
                decoration: InputDecoration(
                  labelText: 'Servings',
                  border: OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
                ),
              ),
              const SizedBox(height: ScampiSpacing.md),
              Text('Meal', style: theme.textTheme.labelLarge),
              const SizedBox(height: ScampiSpacing.xs),
              Wrap(
                spacing: ScampiSpacing.xs,
                children: MealSlot.values.map((slot) {
                  final selected = slot == _mealSlot;
                  return ChoiceChip(
                    label: Text(slot.label),
                    selected: selected,
                    onSelected: (_) => setState(() => _mealSlot = slot),
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
              Container(
                padding: const EdgeInsets.all(ScampiSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: ScampiRadius.mdBorder,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NutrientPreview(
                      label: 'Calories',
                      value: nutrition.calories.round().toString(),
                      color: theme.colorScheme.primary,
                    ),
                    _NutrientPreview(
                      label: 'Protein',
                      value: '${nutrition.proteinG.round()}g',
                      color: ScampiColors.macroProtein,
                    ),
                    _NutrientPreview(
                      label: 'Carbs',
                      value: '${nutrition.carbsG.round()}g',
                      color: ScampiColors.macroCarbs,
                    ),
                    _NutrientPreview(
                      label: 'Fat',
                      value: '${nutrition.fatG.round()}g',
                      color: ScampiColors.macroFat,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ScampiSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _servings > 0 && !_saving ? _confirm : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Log this meal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutrientPreview extends StatelessWidget {
  const _NutrientPreview({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleMedium?.copyWith(color: color)),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
