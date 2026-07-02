import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/food.dart';

/// Result of picking a food + quantity for a meal ingredient.
class PickedIngredient {
  const PickedIngredient({required this.food, required this.grams});

  final Food food;
  final double grams;
}

/// Bottom sheet for entering a gram quantity of a food while building a
/// custom meal. Unlike [QuantityEntrySheet], this doesn't touch the
/// database or ask for a meal slot — it just pops with a [PickedIngredient]
/// for the meal builder to add to its in-progress ingredient list.
class IngredientAmountSheet extends StatefulWidget {
  const IngredientAmountSheet({super.key, required this.food, this.initialGrams});

  final Food food;

  /// Pre-fill with this amount instead of the food's default serving —
  /// used when editing an ingredient already in a meal.
  final double? initialGrams;

  @override
  State<IngredientAmountSheet> createState() => _IngredientAmountSheetState();
}

class _IngredientAmountSheetState extends State<IngredientAmountSheet> {
  late final TextEditingController _controller;
  late double _grams;

  @override
  void initState() {
    super.initState();
    _grams = widget.initialGrams ?? widget.food.defaultServingGrams ?? 100;
    _controller = TextEditingController(text: _formatNumber(_grams));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  void _onChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) return;
    setState(() => _grams = parsed);
  }

  void _confirm() {
    if (_grams <= 0) return;
    Navigator.of(context).pop(PickedIngredient(food: widget.food, grams: _grams));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nutrition = widget.food.nutritionForGrams(_grams);

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
              Text(widget.food.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                '${widget.food.category} · ${widget.food.caloriesPer100g.round()} kcal/100g',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: ScampiSpacing.lg),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onChanged,
                decoration: InputDecoration(
                  labelText: 'Grams',
                  suffixText: 'g',
                  border: OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
                ),
              ),
              const SizedBox(height: ScampiSpacing.md),
              Text(
                '${nutrition.calories.round()} kcal · '
                '${nutrition.proteinG.round()}g P · '
                '${nutrition.carbsG.round()}g C · '
                '${nutrition.fatG.round()}g F',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: ScampiSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _grams > 0 ? _confirm : null,
                  child: Text(widget.initialGrams != null ? 'Update' : 'Add to meal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
