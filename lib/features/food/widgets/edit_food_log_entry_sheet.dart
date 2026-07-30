import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/food.dart';
import '../../../data/models/food_log_entry.dart';
import '../../../data/models/food_log_item.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/data_refresh_signal.dart';
import '../food_search_screen.dart';
import 'ingredient_amount_sheet.dart';

/// Bottom sheet for editing an already-logged food entry in place — only
/// ever touches this one `food_log` row (and its `food_log_items`
/// snapshot, if any), never the `meals` table it may have originally
/// come from (entries are independent snapshots, see [FoodLogEntry]'s
/// doc comment).
///
/// If the entry has an ingredient snapshot (logged from a meal or a
/// multi-ingredient AI import), shows meal-builder-style editing: a
/// servings multiplier that scales every ingredient at once (e.g. 0.8 if
/// only 80% was eaten), plus tap-to-edit/remove per ingredient and an
/// "Add Ingredient" button.
///
/// Otherwise, if it references a real [Food] row (`foodId != null`),
/// shows the same grams/servings quantity input as [QuantityEntrySheet],
/// recomputing macros live from that food's per-100g values. Otherwise
/// (a one-off AI/manual entry with no backing food and no ingredient
/// snapshot), there's no per-100g rate to scale from, so
/// calories/protein/carbs/fat are directly editable instead — the same
/// "manual override" escape hatch [ExerciseLogSheet] uses for its
/// calories field.
class EditFoodLogEntrySheet extends ConsumerStatefulWidget {
  const EditFoodLogEntrySheet({super.key, required this.entry});

  final FoodLogEntry entry;

  @override
  ConsumerState<EditFoodLogEntrySheet> createState() => _EditFoodLogEntrySheetState();
}

class _EditFoodLogEntrySheetState extends ConsumerState<EditFoodLogEntrySheet> {
  bool _loading = true;
  Food? _food;

  List<FoodLogItem> _items = [];
  double _servingsMultiplier = 1;
  late final TextEditingController _itemsServingsController;

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
  bool get _hasItems => _items.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _mealSlot = entry.mealSlot;
    _mode = entry.quantityMode;
    _grams = entry.grams;
    _servings = entry.servings ?? 1;
    _servingsMultiplier = entry.servings ?? 1;
    _amountController = TextEditingController(
      text: _formatNumber(_mode == QuantityMode.servings ? _servings : _grams),
    );
    _itemsServingsController = TextEditingController(text: _formatNumber(_servingsMultiplier));
    _caloriesController = TextEditingController(text: entry.calories.round().toString());
    _proteinController = TextEditingController(text: entry.proteinG.round().toString());
    _carbsController = TextEditingController(text: entry.carbsG.round().toString());
    _fatController = TextEditingController(text: entry.fatG.round().toString());
    _load();
  }

  Future<void> _load() async {
    final entry = widget.entry;
    final items = entry.id != null
        ? await ref.read(foodLogRepositoryProvider).itemsForEntry(entry.id!)
        : <FoodLogItem>[];
    final food = items.isEmpty && entry.foodId != null
        ? await ref.read(foodRepositoryProvider).getById(entry.foodId!)
        : null;
    if (!mounted) return;
    setState(() {
      _items = items;
      _food = food;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _itemsServingsController.dispose();
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

  // Scales every current ingredient by the ratio between the newly typed
  // multiplier and the last-applied one, so a per-item edit (or an
  // ingredient added afterward) isn't clobbered by re-typing the same
  // value, and typing e.g. 0.8 then back to 1 roughly restores the
  // original amounts.
  void _onItemsServingsChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0 || _servingsMultiplier <= 0) return;
    final ratio = parsed / _servingsMultiplier;
    setState(() {
      _items = _items.map((item) => item.copyWith(grams: item.grams * ratio)).toList();
      _servingsMultiplier = parsed;
    });
  }

  Future<void> _addItem() async {
    final picked = await Navigator.of(context).push<PickedIngredient>(
      MaterialPageRoute(builder: (_) => const FoodSearchScreen(pickerMode: true)),
    );
    if (picked == null) return;
    setState(() {
      _items = [..._items, FoodLogItem.fromFood(picked.food, picked.grams)];
    });
  }

  Future<void> _editItem(int index) async {
    final current = _items[index];
    final picked = await showModalBottomSheet<PickedIngredient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IngredientAmountSheet(
        food: current.toSyntheticFood(),
        initialGrams: current.grams,
      ),
    );
    if (picked == null) return;
    setState(() {
      _items = [..._items]..[index] = current.copyWith(grams: picked.grams);
    });
  }

  void _removeItem(int index) {
    setState(() => _items = [..._items]..removeAt(index));
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  bool get _canSave {
    if (_saving) return false;
    if (_hasItems) return _items.isNotEmpty;
    if (_food != null) return _grams > 0;
    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    final food = _food;
    if (_hasItems) {
      if (_items.isEmpty) return;
    } else if (food != null && _grams <= 0) {
      return;
    }
    setState(() => _saving = true);

    if (_hasItems) {
      final nutrition = _items.fold<FoodNutrition>(
        FoodNutrition.zero,
        (acc, item) => acc + item.nutrition,
      );
      final totalGrams = _items.fold<double>(0, (sum, item) => sum + item.grams);
      final updated = FoodLogEntry(
        id: widget.entry.id,
        foodId: widget.entry.foodId,
        foodName: widget.entry.foodName,
        loggedAt: widget.entry.loggedAt,
        mealSlot: _mealSlot,
        quantityMode: QuantityMode.servings,
        grams: totalGrams,
        servings: _servingsMultiplier,
        calories: nutrition.calories,
        proteinG: nutrition.proteinG,
        carbsG: nutrition.carbsG,
        fatG: nutrition.fatG,
      );
      await ref.read(foodLogRepositoryProvider).updateEntryWithItems(updated, _items);
    } else {
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
    }

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
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: ScampiSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              : SingleChildScrollView(
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
                      Text(widget.entry.foodName, style: theme.textTheme.titleLarge),
                      const SizedBox(height: ScampiSpacing.lg),
                      if (_hasItems) ...[
                        TextField(
                          controller: _itemsServingsController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: _onItemsServingsChanged,
                          decoration: InputDecoration(
                            labelText: 'Servings eaten',
                            helperText: 'Scales every ingredient — e.g. 0.8 if you ate 80%',
                            border: OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
                          ),
                        ),
                        const SizedBox(height: ScampiSpacing.md),
                        Text('Ingredients', style: theme.textTheme.labelLarge),
                        const SizedBox(height: ScampiSpacing.xs),
                        for (var i = 0; i < _items.length; i++)
                          _FoodLogItemRow(
                            item: _items[i],
                            onTap: () => _editItem(i),
                            onRemove: () => _removeItem(i),
                          ),
                        const SizedBox(height: ScampiSpacing.xs),
                        OutlinedButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Ingredient'),
                        ),
                      ] else if (food != null) ...[
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
                      if (_hasItems) ...[
                        const SizedBox(height: ScampiSpacing.lg),
                        _ItemsTotalPreview(items: _items),
                      ],
                      const SizedBox(height: ScampiSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _canSave ? _save : null,
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
      ),
    );
  }
}

class _FoodLogItemRow extends StatelessWidget {
  const _FoodLogItemRow({required this.item, required this.onTap, required this.onRemove});

  final FoodLogItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nutrition = item.nutrition;
    return Card(
      margin: const EdgeInsets.only(bottom: ScampiSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: ScampiRadius.mdBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ScampiSpacing.md,
            vertical: ScampiSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.foodName, style: theme.textTheme.titleSmall),
                    Text(
                      '${item.grams.round()}g · ${nutrition.calories.round()} kcal · tap to edit',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemsTotalPreview extends StatelessWidget {
  const _ItemsTotalPreview({required this.items});

  final List<FoodLogItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = items.fold<FoodNutrition>(
      FoodNutrition.zero,
      (acc, item) => acc + item.nutrition,
    );
    return Container(
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
            value: totals.calories.round().toString(),
            color: theme.colorScheme.primary,
          ),
          _NutrientPreview(
            label: 'Protein',
            value: '${totals.proteinG.round()}g',
            color: ScampiColors.macroProtein,
          ),
          _NutrientPreview(
            label: 'Carbs',
            value: '${totals.carbsG.round()}g',
            color: ScampiColors.macroCarbs,
          ),
          _NutrientPreview(
            label: 'Fat',
            value: '${totals.fatG.round()}g',
            color: ScampiColors.macroFat,
          ),
        ],
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
