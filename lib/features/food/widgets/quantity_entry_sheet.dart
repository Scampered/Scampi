import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/food.dart';
import '../../../data/models/food_log_entry.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/data_refresh_signal.dart';

/// Sensible default meal slot based on the current time of day, so the
/// user usually doesn't have to touch the meal selector at all.
MealSlot defaultMealSlotForNow() {
  final hour = DateTime.now().hour;
  if (hour < 11) return MealSlot.breakfast;
  if (hour < 15) return MealSlot.lunch;
  if (hour < 21) return MealSlot.dinner;
  return MealSlot.snack;
}

/// Bottom sheet for entering a quantity (grams or servings) of a food and
/// logging it to today's diary. Pops with `true` if an entry was saved.
class QuantityEntrySheet extends ConsumerStatefulWidget {
  const QuantityEntrySheet({super.key, required this.food});

  final Food food;

  @override
  ConsumerState<QuantityEntrySheet> createState() => _QuantityEntrySheetState();
}

class _QuantityEntrySheetState extends ConsumerState<QuantityEntrySheet> {
  late QuantityMode _mode;
  late final TextEditingController _amountController;
  late double _grams;
  late double _servings;
  late MealSlot _mealSlot;
  bool _saving = false;

  bool get _hasServing => widget.food.defaultServingGrams != null;

  @override
  void initState() {
    super.initState();
    _mealSlot = defaultMealSlotForNow();
    if (_hasServing) {
      _mode = QuantityMode.servings;
      _servings = 1;
      _grams = widget.food.defaultServingGrams!;
      _amountController = TextEditingController(text: '1');
    } else {
      _mode = QuantityMode.grams;
      _servings = 1;
      _grams = 100;
      _amountController = TextEditingController(text: '100');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) return;
    setState(() {
      if (_mode == QuantityMode.servings) {
        _servings = parsed;
        _grams = parsed * widget.food.defaultServingGrams!;
      } else {
        _grams = parsed;
      }
    });
  }

  void _switchMode(QuantityMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      if (mode == QuantityMode.servings) {
        _servings = widget.food.defaultServingGrams! > 0
            ? _grams / widget.food.defaultServingGrams!
            : 1;
        _amountController.text = _formatNumber(_servings);
      } else {
        _amountController.text = _formatNumber(_grams);
      }
    });
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  Future<void> _confirm() async {
    if (_grams <= 0 || _saving) return;
    setState(() => _saving = true);

    final nutrition = widget.food.nutritionForGrams(_grams);
    final entry = FoodLogEntry(
      foodId: widget.food.id,
      foodName: widget.food.name,
      loggedAt: DateTime.now(),
      mealSlot: _mealSlot,
      quantityMode: _mode,
      grams: _grams,
      servings: _mode == QuantityMode.servings ? _servings : null,
      calories: nutrition.calories,
      proteinG: nutrition.proteinG,
      carbsG: nutrition.carbsG,
      fatG: nutrition.fatG,
    );

    await ref.read(foodLogRepositoryProvider).logEntry(entry);
    ref.read(dataRefreshSignalProvider.notifier).bump();

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectionColor = scampiSelectionColor(context);
    final nutrition = widget.food.nutritionForGrams(_grams);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(ScampiRadius.lg),
          ),
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
              Text(widget.food.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                '${widget.food.category} · ${widget.food.caloriesPer100g.round()} kcal/100g',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: ScampiSpacing.lg),
              if (_hasServing) ...[
                SegmentedButton<QuantityMode>(
                  segments: [
                    ButtonSegment(
                      value: QuantityMode.servings,
                      label: Text(widget.food.defaultServingLabel ?? 'Servings'),
                    ),
                    const ButtonSegment(
                      value: QuantityMode.grams,
                      label: Text('Grams'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => _switchMode(s.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: selectionColor.withValues(alpha: 0.16),
                    selectedForegroundColor: selectionColor,
                    side: BorderSide(color: selectionColor.withValues(alpha: 0.4)),
                  ),
                ),
                const SizedBox(height: ScampiSpacing.md),
              ],
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onAmountChanged,
                decoration: InputDecoration(
                  labelText: _mode == QuantityMode.grams ? 'Grams' : 'Servings',
                  suffixText: _mode == QuantityMode.grams ? 'g' : null,
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
                      color: selected
                          ? selectionColor
                          : theme.colorScheme.outlineVariant,
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
                  onPressed: _grams > 0 && !_saving ? _confirm : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Log this food'),
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
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(color: color),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
