import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/food.dart';
import '../../../data/models/food_log_entry.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/data_refresh_signal.dart';

/// Bottom sheet for editing an already-logged food entry in place — only
/// ever touches this one `food_log` row, never the `meals` table it may
/// have originally come from (entries are independent snapshots, see
/// [FoodLogEntry]'s doc comment).
///
/// If the entry references a real [Food] row (`foodId != null`), shows
/// the same grams/servings quantity input as [QuantityEntrySheet],
/// recomputing macros live from that food's per-100g values. Otherwise
/// (a meal snapshot, or a one-off AI/manual entry with no backing food),
/// there's no per-100g rate to scale from, so calories/protein/carbs/fat
/// are directly editable instead — the same "manual override" escape
/// hatch [ExerciseLogSheet] uses for its calories field.
class EditFoodLogEntrySheet extends ConsumerStatefulWidget {
  const EditFoodLogEntrySheet({super.key, required this.entry});

  final FoodLogEntry entry;

  @override
  ConsumerState<EditFoodLogEntrySheet> createState() => _EditFoodLogEntrySheetState();
}

class _EditFoodLogEntrySheetState extends ConsumerState<EditFoodLogEntrySheet> {
  bool _loadingFood = true;
  Food? _food;

  late QuantityMode _mode;
  late final TextEditingController _amountController;
  late double _grams;
  late double _servings;
  late MealSlot _mealSlot;

  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;

  bool _saving = false;

  bool get _hasServing => _food?.defaultServingGrams != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _mealSlot = entry.mealSlot;
    _mode = entry.quantityMode;
    _grams = entry.grams;
    _servings = entry.servings ?? 1;
    _amountController = TextEditingController(
      text: _formatNumber(_mode == QuantityMode.servings ? _servings : _grams),
    );
    _caloriesController = TextEditingController(text: entry.calories.round().toString());
    _proteinController = TextEditingController(text: entry.proteinG.round().toString());
    _carbsController = TextEditingController(text: entry.carbsG.round().toString());
    _fatController = TextEditingController(text: entry.fatG.round().toString());
    _loadFood();
  }

  Future<void> _loadFood() async {
    final foodId = widget.entry.foodId;
    final food = foodId != null ? await ref.read(foodRepositoryProvider).getById(foodId) : null;
    if (!mounted) return;
    setState(() {
      _food = food;
      _loadingFood = false;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    final food = _food;
    if (food == null) return;
    final parsed = double.tryParse(value);
    if (parsed == null) return;
    setState(() {
      if (_mode == QuantityMode.servings) {
        _servings = parsed;
        _grams = parsed * food.defaultServingGrams!;
      } else {
        _grams = parsed;
      }
    });
  }

  void _switchMode(QuantityMode mode) {
    final food = _food;
    if (mode == _mode || food == null) return;
    setState(() {
      _mode = mode;
      if (mode == QuantityMode.servings) {
        _servings = food.defaultServingGrams! > 0 ? _grams / food.defaultServingGrams! : 1;
        _amountController.text = _formatNumber(_servings);
      } else {
        _amountController.text = _formatNumber(_grams);
      }
    });
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  Future<void> _save() async {
    if (_saving) return;
    final food = _food;
    if (food != null && _grams <= 0) return;
    setState(() => _saving = true);

    final nutrition = food != null
        ? food.nutritionForGrams(_grams)
        : FoodNutrition(
            calories: double.tryParse(_caloriesController.text) ?? widget.entry.calories,
            proteinG: double.tryParse(_proteinController.text) ?? widget.entry.proteinG,
            carbsG: double.tryParse(_carbsController.text) ?? widget.entry.carbsG,
            fatG: double.tryParse(_fatController.text) ?? widget.entry.fatG,
          );

    final updated = FoodLogEntry(
      id: widget.entry.id,
      foodId: widget.entry.foodId,
      foodName: widget.entry.foodName,
      loggedAt: widget.entry.loggedAt,
      mealSlot: _mealSlot,
      quantityMode: food != null ? _mode : widget.entry.quantityMode,
      grams: food != null ? _grams : widget.entry.grams,
      servings: food != null && _mode == QuantityMode.servings ? _servings : widget.entry.servings,
      calories: nutrition.calories,
      proteinG: nutrition.proteinG,
      carbsG: nutrition.carbsG,
      fatG: nutrition.fatG,
    );

    await ref.read(foodLogRepositoryProvider).updateEntry(updated);
    ref.read(dataRefreshSignalProvider.notifier).bump();

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectionColor = scampiSelectionColor(context);
    final food = _food;

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
          child: _loadingFood
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: ScampiSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Column(
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
                    Text(widget.entry.foodName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: ScampiSpacing.lg),
                    if (food != null) ...[
                      if (_hasServing) ...[
                        SegmentedButton<QuantityMode>(
                          segments: [
                            ButtonSegment(
                              value: QuantityMode.servings,
                              label: Text(food.defaultServingLabel ?? 'Servings'),
                            ),
                            const ButtonSegment(value: QuantityMode.grams, label: Text('Grams')),
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
                    ] else ...[
                      Text(
                        'No linked food to scale from — edit the values directly.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: ScampiSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _caloriesController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Calories',
                                border: OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: ScampiSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _proteinController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Protein (g)',
                                border: OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
                              ),
                            ),
                          ),
                          const SizedBox(width: ScampiSpacing.xs),
                          Expanded(
                            child: TextField(
                              controller: _carbsController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Carbs (g)',
                                border: OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
                              ),
                            ),
                          ),
                          const SizedBox(width: ScampiSpacing.xs),
                          Expanded(
                            child: TextField(
                              controller: _fatController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Fat (g)',
                                border: OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
