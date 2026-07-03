import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/food_icons.dart';
import '../../data/models/food.dart';
import '../../data/models/meal.dart';
import '../../data/repositories/repository_providers.dart';
import 'ai_import/ai_import_screen.dart';
import 'ai_import/ai_meal_import_screen.dart';
import 'meal_builder_screen.dart';
import 'widgets/edit_custom_food_sheet.dart';
import 'widgets/ingredient_amount_sheet.dart';
import 'widgets/ingredient_options_sheet.dart';
import 'widgets/meal_log_sheet.dart';
import 'widgets/quantity_entry_sheet.dart';

/// Food search screen — category browsing plus debounced text search over
/// the offline food database.
///
/// In its default mode, tapping a result opens [QuantityEntrySheet] to log
/// it, and pops back to the caller with `true` once something has actually
/// been logged. In [pickerMode] (used by the meal builder to pick
/// ingredients), tapping a result instead opens [IngredientAmountSheet]
/// and pops the whole screen with a [PickedIngredient].
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key, this.pickerMode = false});

  final bool pickerMode;

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  /// Display label of the selected category tile — either a main-group
  /// label (e.g. "Carbs") or a raw db category (e.g. "Drinks").
  String? _selectedCategoryLabel;
  List<String>? _selectedCategoryGroup;

  /// True while viewing the "Your Ingredients" pseudo-category (all custom
  /// foods — anything added manually or via AI import). Handled separately
  /// from [_selectedCategoryGroup] since it doesn't query by db category.
  bool _showingCustomIngredients = false;

  bool _loading = false;
  bool _showAllMeals = false;
  List<Food> _results = [];
  List<Food> _favorites = [];
  List<Food> _recent = [];
  List<Meal> _meals = [];
  List<String> _categories = [];

  bool get _hasFilter =>
      _controller.text.trim().isNotEmpty ||
      _selectedCategoryGroup != null ||
      _showingCustomIngredients;

  List<String> get _otherCategories {
    final mainCategories = kMainFoodCategoryGroups.values.expand((c) => c).toSet();
    return _categories.where((c) => !mainCategories.contains(c)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final repo = ref.read(foodRepositoryProvider);
    final logRepo = ref.read(foodLogRepositoryProvider);
    final favorites = await repo.getFavorites();
    final recent = await logRepo.recentLoggedFoods();
    final categories = await repo.getCategories();
    // Meals can't be picked as meal ingredients (meal_items only
    // references foods), so skip loading them in picker mode.
    final meals = widget.pickerMode
        ? <Meal>[]
        : await ref.read(mealRepositoryProvider).getAllMeals();
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _recent = recent;
      _categories = categories;
      _meals = meals;
    });
  }

  void _onChanged(String value) {
    if (_showingCustomIngredients) {
      setState(() => _showingCustomIngredients = false);
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runQuery);
  }

  void _onCategoryTap(String label, List<String> group) {
    setState(() {
      _showingCustomIngredients = false;
      if (_selectedCategoryLabel == label) {
        _selectedCategoryLabel = null;
        _selectedCategoryGroup = null;
      } else {
        _selectedCategoryLabel = label;
        _selectedCategoryGroup = group;
      }
    });
    _runQuery();
  }

  void _onTapYourIngredients() {
    setState(() {
      _selectedCategoryLabel = null;
      _selectedCategoryGroup = null;
      _showingCustomIngredients = !_showingCustomIngredients;
    });
    _runQuery();
  }

  Future<void> _runQuery() async {
    if (_showingCustomIngredients) {
      setState(() => _loading = true);
      final results = await ref.read(foodRepositoryProvider).getCustomFoods();
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
      return;
    }
    if (!_hasFilter) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final results = await ref.read(foodRepositoryProvider).search(
          _controller.text,
          categories: _selectedCategoryGroup,
        );
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectFood(Food food) async {
    if (widget.pickerMode) {
      final picked = await showModalBottomSheet<PickedIngredient>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => IngredientAmountSheet(food: food),
      );
      if (picked != null && mounted) {
        Navigator.of(context).pop(picked);
      }
      return;
    }

    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuantityEntrySheet(food: food),
    );
    if (logged == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _selectCustomIngredient(Food food) async {
    final option = await showModalBottomSheet<IngredientOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IngredientOptionsSheet(food: food),
    );
    if (!mounted || option == null) return;

    switch (option) {
      case IngredientOption.log:
        await _selectFood(food);
      case IngredientOption.edit:
        final saved = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EditCustomFoodSheet(food: food),
        );
        if (saved == true) _runQuery();
      case IngredientOption.delete:
        final confirmed = await _confirmDeleteIngredient(food);
        if (confirmed == true && food.id != null) {
          await ref.read(foodRepositoryProvider).deleteCustomFood(food.id!);
          _runQuery();
        }
    }
  }

  Future<bool?> _confirmDeleteIngredient(Food food) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ingredient?'),
        content: Text('This removes "${food.name}" from Your Ingredients. Any food log entries that already used it are unaffected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectMeal(Meal meal) async {
    final result = await showModalBottomSheet<MealSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MealLogSheet(meal: meal),
    );
    if (!mounted) return;

    switch (result) {
      case MealSheetResult.logged:
        Navigator.of(context).pop(true);
      case MealSheetResult.edit:
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => MealBuilderScreen(existingMeal: meal)),
        );
        if (saved == true) _loadDefaults();
      case MealSheetResult.deleted:
        _loadDefaults();
      case null:
        break;
    }
  }

  Future<void> _createMeal() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MealBuilderScreen()),
    );
    if (saved == true) _loadDefaults();
  }

  Future<void> _generateMealWithAi() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AiMealImportScreen()),
    );
    if (saved == true) _loadDefaults();
  }

  Future<void> _openAiImport() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AiImportScreen()),
    );
    if (saved == true) _loadDefaults();
  }

  /// Back should step out of a category/search filter one level at a time
  /// rather than immediately exiting the whole screen — pressing back
  /// while viewing a category's results returns to the category grid
  /// first, and only exits on the next press.
  void _handlePopAttempt(bool didPop, Object? result) {
    if (didPop) return;
    if (_hasFilter) {
      _controller.clear();
      setState(() {
        _selectedCategoryLabel = null;
        _selectedCategoryGroup = null;
        _showingCustomIngredients = false;
        _results = [];
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasFilter,
      onPopInvokedWithResult: _handlePopAttempt,
      child: Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search foods…',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (!widget.pickerMode)
            Padding(
              padding: const EdgeInsets.only(right: ScampiSpacing.sm),
              child: Tooltip(
                message: 'Ask AI to add a food',
                child: Material(
                  color: ScampiColors.orange.withValues(alpha: 0.16),
                  borderRadius: ScampiRadius.smBorder,
                  child: InkWell(
                    onTap: _openAiImport,
                    borderRadius: ScampiRadius.smBorder,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.auto_awesome_rounded, color: ScampiColors.orange, size: 22),
                    ),
                  ),
                ),
              ),
            ),
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _hasFilter
                ? _ResultsList(
                    results: _results,
                    onTap: _showingCustomIngredients ? _selectCustomIngredient : _selectFood,
                  )
                : _DefaultList(
                    recent: _recent,
                    favorites: _favorites,
                    meals: _meals,
                    showAllMeals: _showAllMeals,
                    onToggleShowAllMeals: () => setState(() => _showAllMeals = !_showAllMeals),
                    categories: _otherCategories,
                    selectedCategoryLabel: _selectedCategoryLabel,
                    showingCustomIngredients: _showingCustomIngredients,
                    showCreateMeal: !widget.pickerMode,
                    onTapFood: _selectFood,
                    onTapMeal: _selectMeal,
                    onCreateMeal: _createMeal,
                    onGenerateMealWithAi: _generateMealWithAi,
                    onTapCategory: _onCategoryTap,
                    onTapYourIngredients: _onTapYourIngredients,
                  ),
      ),
      ),
    );
  }
}

class _DefaultList extends StatelessWidget {
  const _DefaultList({
    required this.recent,
    required this.favorites,
    required this.meals,
    required this.showAllMeals,
    required this.onToggleShowAllMeals,
    required this.categories,
    required this.selectedCategoryLabel,
    required this.showingCustomIngredients,
    required this.showCreateMeal,
    required this.onTapFood,
    required this.onTapMeal,
    required this.onCreateMeal,
    required this.onGenerateMealWithAi,
    required this.onTapCategory,
    required this.onTapYourIngredients,
  });

  final List<Food> recent;
  final List<Food> favorites;
  final List<Meal> meals;
  final bool showAllMeals;
  final VoidCallback onToggleShowAllMeals;
  final List<String> categories;
  final String? selectedCategoryLabel;
  final bool showingCustomIngredients;
  final bool showCreateMeal;
  final ValueChanged<Food> onTapFood;
  final ValueChanged<Meal> onTapMeal;
  final VoidCallback onCreateMeal;
  final VoidCallback onGenerateMealWithAi;
  final void Function(String label, List<String> group) onTapCategory;
  final VoidCallback onTapYourIngredients;

  static const int _mealsPreviewCount = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentIds = recent.map((f) => f.id).toSet();
    final favoritesOnly = favorites.where((f) => !recentIds.contains(f.id)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ScampiSpacing.md,
        ScampiSpacing.sm,
        ScampiSpacing.md,
        ScampiSpacing.md,
      ),
      children: [
        if (showCreateMeal) ...[
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onCreateMeal,
                  borderRadius: ScampiRadius.smBorder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: ScampiSpacing.xxs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_rounded, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: ScampiSpacing.xxs),
                        Flexible(
                          child: Text(
                            'Create custom meal',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: theme.colorScheme.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: onGenerateMealWithAi,
                  borderRadius: ScampiRadius.smBorder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: ScampiSpacing.xxs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: ScampiSpacing.xxs),
                        Flexible(
                          child: Text(
                            'Generate with AI',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: theme.colorScheme.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ScampiSpacing.sm),
        ],
        if (meals.isNotEmpty) ...[
          const _SectionHeader('Your Meals'),
          for (final meal in (showAllMeals ? meals : meals.take(_mealsPreviewCount)))
            Padding(
              padding: const EdgeInsets.only(bottom: ScampiSpacing.xs),
              child: _MealResultTile(meal: meal, onTap: () => onTapMeal(meal)),
            ),
          if (meals.length > _mealsPreviewCount)
            InkWell(
              onTap: onToggleShowAllMeals,
              borderRadius: ScampiRadius.smBorder,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: ScampiSpacing.xxs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      showAllMeals ? 'Show fewer' : 'More (${meals.length - _mealsPreviewCount})',
                      style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                    Icon(
                      showAllMeals ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: ScampiSpacing.xs),
        ],
        if (showCreateMeal) ...[
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: ScampiSpacing.xs),
        ],
        const _SectionHeader('Categories'),
        const SizedBox(height: ScampiSpacing.xxs),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: ScampiSpacing.xs,
          crossAxisSpacing: ScampiSpacing.xs,
          childAspectRatio: 1.05,
          children: [
            for (final entry in kMainFoodCategoryGroups.entries)
              _CategoryTile(
                label: entry.key,
                emoji: kMainFoodCategoryEmoji[entry.key]!,
                selected: entry.key == selectedCategoryLabel,
                onTap: () => onTapCategory(entry.key, entry.value),
              ),
          ],
        ),
        const SizedBox(height: ScampiSpacing.md),
        const _SectionHeader('More'),
        const SizedBox(height: ScampiSpacing.xxs),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: ScampiSpacing.xs,
          crossAxisSpacing: ScampiSpacing.xs,
          childAspectRatio: 1.05,
          children: [
            _CategoryTile(
              label: 'Your Ingredients',
              emoji: '🧪',
              selected: showingCustomIngredients,
              onTap: onTapYourIngredients,
            ),
            for (final category in categories)
              _CategoryTile(
                // "Generic Ingredients" overflows the tile at this width
                // — shortened just for display; the underlying category
                // value used for filtering is untouched.
                label: category == 'Generic Ingredients' ? 'Generic' : category,
                emoji: emojiForCategory(category),
                selected: category == selectedCategoryLabel,
                onTap: () => onTapCategory(category, [category]),
              ),
          ],
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: ScampiSpacing.md),
          const _SectionHeader('Recent'),
          for (final food in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: ScampiSpacing.xs),
              child: _FoodResultTile(food: food, onTap: () => onTapFood(food)),
            ),
        ],
        if (favoritesOnly.isNotEmpty) ...[
          const SizedBox(height: ScampiSpacing.xs),
          const _SectionHeader('Favorites'),
          for (final food in favoritesOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: ScampiSpacing.xs),
              child: _FoodResultTile(food: food, onTap: () => onTapFood(food)),
            ),
        ],
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectionColor = scampiSelectionColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: ScampiRadius.mdBorder,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? selectionColor.withValues(alpha: 0.16)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: ScampiRadius.mdBorder,
          border: Border.all(
            color: selected ? selectionColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? selectionColor : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results, required this.onTap});

  final List<Food> results;
  final ValueChanged<Food> onTap;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const _EmptyState(showingResults: true);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: ScampiSpacing.md,
        vertical: ScampiSpacing.sm,
      ),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: ScampiSpacing.xs),
      itemBuilder: (context, index) {
        final food = results[index];
        return _FoodResultTile(food: food, onTap: () => onTap(food));
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ScampiSpacing.xxs),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.showingResults});

  final bool showingResults;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ScampiSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 48,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: ScampiSpacing.sm),
            Text(
              showingResults
                  ? 'No foods found.'
                  : 'Search or pick a category to get started.\nYour recent and favorite foods will appear here.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodResultTile extends StatelessWidget {
  const _FoodResultTile({required this.food, required this.onTap});

  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: ScampiRadius.mdBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ScampiSpacing.md,
            vertical: ScampiSpacing.sm,
          ),
          child: Row(
            children: [
              Text(emojiForFood(food), style: const TextStyle(fontSize: 22)),
              const SizedBox(width: ScampiSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(food.category, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                '${food.caloriesPer100g.round()} kcal',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealResultTile extends StatelessWidget {
  const _MealResultTile({required this.meal, required this.onTap});

  final Meal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nutrition = meal.totalNutrition;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: ScampiRadius.mdBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ScampiSpacing.md,
            vertical: ScampiSpacing.sm,
          ),
          child: Row(
            children: [
              const Text('🍱', style: TextStyle(fontSize: 22)),
              const SizedBox(width: ScampiSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meal.name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${meal.ingredients.length} ingredients',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '${nutrition.calories.round()} kcal',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
