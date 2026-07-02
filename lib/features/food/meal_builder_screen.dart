import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/food.dart';
import '../../data/models/meal.dart';
import '../../data/repositories/repository_providers.dart';
import 'ai_import/ai_import_screen.dart';
import 'food_search_screen.dart';
import 'widgets/ingredient_amount_sheet.dart';

/// Custom meal builder — pick ingredients from the food database at fixed
/// gram quantities, see a live combined-nutrition total, and save as a
/// reusable [Meal]. Pops with `true` once a meal has been saved.
///
/// When [existingMeal] is provided, opens in edit mode: pre-filled with
/// its name and ingredients, and saving updates that meal in place
/// instead of creating a new one.
class MealBuilderScreen extends ConsumerStatefulWidget {
  const MealBuilderScreen({super.key, this.existingMeal});

  final Meal? existingMeal;

  @override
  ConsumerState<MealBuilderScreen> createState() => _MealBuilderScreenState();
}

class _MealBuilderScreenState extends ConsumerState<MealBuilderScreen> {
  final _nameController = TextEditingController();
  final List<MealIngredient> _ingredients = [];
  bool _saving = false;

  bool get _isEditing => widget.existingMeal != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingMeal;
    if (existing != null) {
      _nameController.text = existing.name;
      _ingredients.addAll(existing.ingredients);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addIngredient() async {
    final picked = await Navigator.of(context).push<PickedIngredient>(
      MaterialPageRoute(builder: (_) => const FoodSearchScreen(pickerMode: true)),
    );
    if (picked != null) {
      setState(() {
        _ingredients.add(MealIngredient(food: picked.food, grams: picked.grams));
      });
    }
  }

  Future<void> _addIngredientViaAi() async {
    // AiImportScreen decomposes a photo into one or more ingredients (e.g.
    // a burrito photo comes back as chicken + rice + sauce) — add all of
    // them rather than assuming exactly one.
    final picked = await Navigator.of(context).push<List<PickedIngredient>>(
      MaterialPageRoute(builder: (_) => const AiImportScreen(forMealIngredient: true)),
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() {
        for (final p in picked) {
          _ingredients.add(MealIngredient(food: p.food, grams: p.grams));
        }
      });
    }
  }

  void _removeIngredient(int index) {
    setState(() => _ingredients.removeAt(index));
  }

  Future<void> _editIngredient(int index) async {
    final current = _ingredients[index];
    final picked = await showModalBottomSheet<PickedIngredient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IngredientAmountSheet(food: current.food, initialGrams: current.grams),
    );
    if (picked != null) {
      setState(() {
        _ingredients[index] = MealIngredient(food: picked.food, grams: picked.grams);
      });
    }
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _ingredients.isNotEmpty && !_saving;

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _ingredients.isEmpty || _saving) return;
    setState(() => _saving = true);
    final existing = widget.existingMeal;
    if (existing != null) {
      await ref.read(mealRepositoryProvider).updateMeal(existing.id!, name, _ingredients);
    } else {
      await ref.read(mealRepositoryProvider).createMeal(name, _ingredients);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = _ingredients.fold<FoodNutrition>(
      FoodNutrition.zero,
      (acc, ingredient) => acc + ingredient.nutrition,
    );

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Meal' : 'Create Meal')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(ScampiSpacing.md),
                children: [
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Meal name',
                      hintText: 'e.g. My Chicken Biryani Bowl',
                      border: OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
                    ),
                  ),
                  const SizedBox(height: ScampiSpacing.lg),
                  Text('Ingredients', style: theme.textTheme.labelLarge),
                  const SizedBox(height: ScampiSpacing.xs),
                  if (_ingredients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: ScampiSpacing.md),
                      child: Text(
                        'No ingredients yet. Add foods from the database below.',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  else
                    for (var i = 0; i < _ingredients.length; i++)
                      _IngredientRow(
                        ingredient: _ingredients[i],
                        onTap: () => _editIngredient(i),
                        onRemove: () => _removeIngredient(i),
                      ),
                  const SizedBox(height: ScampiSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _addIngredient,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Ingredient'),
                  ),
                  const SizedBox(height: ScampiSpacing.xs),
                  OutlinedButton.icon(
                    onPressed: _addIngredientViaAi,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text("Can't find it? Ask AI"),
                  ),
                  if (_ingredients.isNotEmpty) ...[
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
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(ScampiSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Save Changes' : 'Save Meal'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient, required this.onTap, required this.onRemove});

  final MealIngredient ingredient;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nutrition = ingredient.nutrition;
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
                    Text(ingredient.food.name, style: theme.textTheme.titleSmall),
                    Text(
                      '${ingredient.grams.round()}g · ${nutrition.calories.round()} kcal · tap to edit',
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
