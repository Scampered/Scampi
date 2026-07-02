import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/food.dart';
import '../../../data/repositories/repository_providers.dart';

/// Bottom sheet for editing a custom ingredient's name and per-100g
/// nutrition. Opened from "Your Ingredients" via [IngredientOptionsSheet].
/// Pops with `true` if the food was saved.
class EditCustomFoodSheet extends ConsumerStatefulWidget {
  const EditCustomFoodSheet({super.key, required this.food});

  final Food food;

  @override
  ConsumerState<EditCustomFoodSheet> createState() => _EditCustomFoodSheetState();
}

class _EditCustomFoodSheetState extends ConsumerState<EditCustomFoodSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.food;
    _nameController = TextEditingController(text: f.name);
    _caloriesController = TextEditingController(text: f.caloriesPer100g.toStringAsFixed(0));
    _proteinController = TextEditingController(text: f.proteinPer100g.toStringAsFixed(1));
    _carbsController = TextEditingController(text: f.carbsPer100g.toStringAsFixed(1));
    _fatController = TextEditingController(text: f.fatPer100g.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().isNotEmpty &&
      double.tryParse(_caloriesController.text) != null &&
      double.tryParse(_proteinController.text) != null &&
      double.tryParse(_carbsController.text) != null &&
      double.tryParse(_fatController.text) != null;

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);

    final updated = widget.food.copyWith(
      name: _nameController.text.trim(),
      caloriesPer100g: double.parse(_caloriesController.text),
      proteinPer100g: double.parse(_proteinController.text),
      carbsPer100g: double.parse(_carbsController.text),
      fatPer100g: double.parse(_fatController.text),
    );
    await ref.read(foodRepositoryProvider).updateFood(updated);

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              Text('Edit Ingredient', style: theme.textTheme.titleLarge),
              const SizedBox(height: ScampiSpacing.md),
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: ScampiSpacing.sm),
              Text('Per 100g', style: theme.textTheme.labelLarge),
              const SizedBox(height: ScampiSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caloriesController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Calories', suffixText: 'kcal'),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Protein', suffixText: 'g'),
                    ),
                  ),
                  const SizedBox(width: ScampiSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _carbsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Carbs', suffixText: 'g'),
                    ),
                  ),
                  const SizedBox(width: ScampiSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _fatController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Fat', suffixText: 'g'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ScampiSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isValid && !_saving ? _save : null,
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
