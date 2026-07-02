import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/food.dart';

enum IngredientOption { log, edit, delete }

/// Bottom sheet shown when tapping a food in "Your Ingredients" — since
/// that list is for managing custom ingredients rather than just logging
/// them, tapping one offers Log/Edit/Delete instead of jumping straight
/// into [QuantityEntrySheet].
class IngredientOptionsSheet extends StatelessWidget {
  const IngredientOptionsSheet({super.key, required this.food});

  final Food food;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(ScampiRadius.lg)),
      ),
      child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ScampiSpacing.lg,
          ScampiSpacing.sm,
          ScampiSpacing.lg,
          ScampiSpacing.lg,
        ),
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
            Text(food.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              '${food.caloriesPer100g.round()} kcal per 100g',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: ScampiSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.restaurant_rounded, color: theme.colorScheme.primary),
              title: const Text('Log this food'),
              onTap: () => Navigator.of(context).pop(IngredientOption.log),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_rounded, color: theme.colorScheme.secondary),
              title: const Text('Edit ingredient'),
              onTap: () => Navigator.of(context).pop(IngredientOption.edit),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_rounded, color: theme.colorScheme.error),
              title: Text('Delete ingredient', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () => Navigator.of(context).pop(IngredientOption.delete),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
