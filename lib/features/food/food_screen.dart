import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/food_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';
import 'food_log_provider.dart';
import 'food_search_screen.dart';

/// Food tab — today's food diary, grouped by meal slot, with a swipe-to-
/// delete gesture on each entry and an entry point into food search.
class FoodScreen extends ConsumerWidget {
  const FoodScreen({super.key});

  static Future<void> openSearch(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FoodSearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(todayFoodLogProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Food')),
      body: entriesAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('$err')),
        data: (entries) => _FoodLogContent(entries: entries),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openSearch(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Food'),
      ),
    );
  }
}

class _FoodLogContent extends ConsumerStatefulWidget {
  const _FoodLogContent({required this.entries});

  final List<FoodLogEntry> entries;

  @override
  ConsumerState<_FoodLogContent> createState() => _FoodLogContentState();
}

class _FoodLogContentState extends ConsumerState<_FoodLogContent> {
  // Entries the user has just swiped away. Filtered out immediately so the
  // Dismissible never gets asked to rebuild after it has already dismissed
  // itself — the DB delete + provider refresh that removes them for real
  // happens asynchronously in the background.
  final Set<int> _removedIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.entries.where((e) => !_removedIds.contains(e.id)).toList();

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ScampiSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant_rounded,
                size: 48,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(height: ScampiSpacing.sm),
              Text(
                'Nothing logged yet today.',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: ScampiSpacing.xxs),
              Text(
                'Tap "Add Food" to search and log a meal.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final totalCalories = entries.fold<double>(0, (sum, e) => sum + e.calories);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ScampiSpacing.md,
        ScampiSpacing.sm,
        ScampiSpacing.md,
        ScampiSpacing.xxl,
      ),
      children: [
        Text(
          '${totalCalories.round()} kcal logged today',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: ScampiSpacing.md),
        for (final slot in MealSlot.values)
          _MealSection(
            slot: slot,
            entries: entries.where((e) => e.mealSlot == slot).toList(),
            onDelete: _delete,
          ),
      ],
    );
  }

  Future<void> _delete(FoodLogEntry entry) async {
    if (entry.id == null) return;
    setState(() => _removedIds.add(entry.id!));
    await ref.read(foodLogRepositoryProvider).deleteEntry(entry.id!);
    ref.read(dataRefreshSignalProvider.notifier).bump();
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({required this.slot, required this.entries, required this.onDelete});

  final MealSlot slot;
  final List<FoodLogEntry> entries;
  final ValueChanged<FoodLogEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final slotCalories = entries.fold<double>(0, (sum, e) => sum + e.calories);

    return Padding(
      padding: const EdgeInsets.only(bottom: ScampiSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(slot.label, style: theme.textTheme.labelLarge),
              Text(
                '${slotCalories.round()} kcal',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: ScampiSpacing.xs),
          for (final entry in entries)
            _FoodLogTile(entry: entry, onDelete: () => onDelete(entry)),
        ],
      ),
    );
  }
}

class _FoodLogTile extends StatelessWidget {
  const _FoodLogTile({required this.entry, required this.onDelete});

  final FoodLogEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantityLabel = entry.quantityMode == QuantityMode.servings
        ? '${_formatNumber(entry.servings ?? 1)} serving${(entry.servings ?? 1) == 1 ? '' : 's'}'
        : '${entry.grams.round()}g';

    return Dismissible(
      key: ValueKey(entry.id ?? entry.hashCode),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: ScampiSpacing.xs),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.85),
          borderRadius: ScampiRadius.mdBorder,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: ScampiSpacing.md),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: ScampiSpacing.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ScampiSpacing.md,
            vertical: ScampiSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.foodName, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(quantityLabel, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                '${entry.calories.round()} kcal',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: ScampiColors.macroProtein,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}
