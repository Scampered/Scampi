import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/meal.dart';
import '../../../data/repositories/repository_providers.dart';
import '../meal_builder_screen.dart';
import '../widgets/ingredient_amount_sheet.dart';
import '../widgets/meal_log_sheet.dart';
import '../widgets/quantity_entry_sheet.dart';
import 'ai_food_prompt.dart';
import 'ai_photo_picker.dart';

/// Ask-AI food import: take or choose a photo, share it (with a generated
/// prompt) to ChatGPT/Claude/Gemini/whatever's installed, paste the reply
/// back, review/adjust the parsed ingredients, and save.
///
/// Uses the same decomposition prompt as [AiMealImportScreen] — a photo of
/// a single banana comes back as one ingredient, a photo of a burrito with
/// fries and sauce comes back as three, each with its own gram estimate.
/// That's deliberate: a composite dish shouldn't get flattened into one
/// blob of nutrition just because it was added through "Add Food" instead
/// of "Generate a Meal".
///
/// This is a fully offline, manual share-sheet + clipboard workflow —
/// Scampi never calls any AI API directly.
///
/// - When [forMealIngredient] is true (opened from the meal builder's "add
///   ingredient via AI" button), saving pops with a `List<PickedIngredient>`
///   — one entry per decomposed ingredient — for the caller to add to its
///   in-progress ingredient list.
/// - Otherwise: a single parsed ingredient logs immediately via
///   [QuantityEntrySheet] (unchanged single-food convenience); two or more
///   get saved as an ad-hoc [Meal] and logged via [MealLogSheet], same as
///   [AiMealImportScreen].
class AiImportScreen extends ConsumerStatefulWidget {
  const AiImportScreen({super.key, this.forMealIngredient = false});

  final bool forMealIngredient;

  @override
  ConsumerState<AiImportScreen> createState() => _AiImportScreenState();
}

class _AiImportScreenState extends ConsumerState<AiImportScreen> with WidgetsBindingObserver {
  File? _image;
  final _notesController = TextEditingController();
  final _pasteController = TextEditingController();
  final _mealNameController = TextEditingController();
  final List<TextEditingController> _gramsControllers = [];

  bool _saving = false;
  String? _parseError;
  ParsedMealDraft? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notesController.dispose();
    _pasteController.dispose();
    _mealNameController.dispose();
    for (final c in _gramsControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboardForReply();
  }

  Future<void> _checkClipboardForReply() async {
    if (_pasteController.text.trim().isNotEmpty) return;
    final text = await pasteFromClipboard();
    if (text != null && looksLikeMealReply(text) && mounted) {
      setState(() => _pasteController.text = text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pasted the AI reply from your clipboard')),
      );
    }
  }

  Future<String?> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  Future<void> _pasteButtonTapped() async {
    final text = await pasteFromClipboard();
    if (text != null) setState(() => _pasteController.text = text);
  }

  Future<void> _shareToAi() async {
    final image = _image;
    if (image == null) return;
    final prompt = buildMealImportPrompt(notes: _notesController.text);
    await Clipboard.setData(ClipboardData(text: prompt));
    await shareAiPhoto(image, prompt);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Prompt copied too, in case your AI app doesn't pick up the shared text"),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _parseReply() {
    setState(() => _parseError = null);
    try {
      final draft = parseMealResponse(_pasteController.text);
      for (final c in _gramsControllers) {
        c.dispose();
      }
      _gramsControllers
        ..clear()
        ..addAll(draft.ingredients.map((i) => TextEditingController(text: _fmt(i.grams))));
      setState(() {
        _draft = draft;
        _mealNameController.text = draft.mealName;
      });
    } on AiImportParseException catch (e) {
      setState(() => _parseError = e.message);
    }
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  void _onGramsChanged(int index, String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) return;
    setState(() => _draft!.ingredients[index].grams = parsed);
  }

  _Totals get _totals {
    final draft = _draft;
    if (draft == null) return const _Totals(calories: 0, proteinG: 0, carbsG: 0, fatG: 0);
    double calories = 0, protein = 0, carbs = 0, fat = 0;
    for (final ingredient in draft.ingredients) {
      final factor = ingredient.grams / 100.0;
      calories += ingredient.food.caloriesPer100g * factor;
      protein += ingredient.food.proteinPer100g * factor;
      carbs += ingredient.food.carbsPer100g * factor;
      fat += ingredient.food.fatPer100g * factor;
    }
    return _Totals(calories: calories, proteinG: protein, carbsG: carbs, fatG: fat);
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    setState(() => _saving = true);

    final foodRepo = ref.read(foodRepositoryProvider);
    final resolved = <MealIngredient>[];
    for (final ingredient in draft.ingredients) {
      // Reuse an existing database food by name instead of creating a
      // near-duplicate every time the same ingredient shows up.
      final food = await resolveOrCreateFood(foodRepo, ingredient.food);
      resolved.add(MealIngredient(food: food, grams: ingredient.grams));
    }

    if (!mounted) return;

    if (widget.forMealIngredient) {
      final picked = resolved
          .map((r) => PickedIngredient(food: r.food, grams: r.grams))
          .toList();
      Navigator.of(context).pop(picked);
      return;
    }

    if (resolved.length == 1) {
      // Single ingredient — go straight into logging it, same as before.
      final logged = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => QuantityEntrySheet(food: resolved.first.food),
      );
      if (mounted) Navigator.of(context).pop(logged ?? true);
      return;
    }

    // Multiple ingredients — save as an ad-hoc meal and log it, same flow
    // as "Generate a Meal with AI".
    final mealName = _mealNameController.text.trim().isEmpty
        ? draft.mealName
        : _mealNameController.text.trim();
    final mealId = await ref.read(mealRepositoryProvider).createMeal(mealName, resolved);

    if (!mounted) return;
    final meal = Meal(id: mealId, name: mealName, createdAt: DateTime.now(), ingredients: resolved);
    final result = await showModalBottomSheet<MealSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MealLogSheet(meal: meal),
    );
    if (!mounted) return;

    if (result == MealSheetResult.edit) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => MealBuilderScreen(existingMeal: meal)),
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _draft;
    final totals = _totals;
    final isMultiIngredient = (draft?.ingredients.length ?? 0) > 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Food with AI')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(ScampiSpacing.md),
          children: [
            Text(
              'Snap or choose a photo of the food, share it to ChatGPT, Claude, or '
              'Gemini, then paste the reply back here. If the photo shows more than '
              "one item, they'll come back as separate ingredients. Nothing leaves "
              'this app automatically — you control the share and the paste.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: ScampiSpacing.md),
            AiPhotoPicker(image: _image, onChanged: (f) => setState(() => _image = f)),
            const SizedBox(height: ScampiSpacing.sm),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Extra details (optional)',
                hintText: 'e.g. no sauce, large portion',
                border: OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
              ),
            ),
            const SizedBox(height: ScampiSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _image == null ? null : _shareToAi,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share Photo to AI App'),
              ),
            ),
            const SizedBox(height: ScampiSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Paste the AI's reply", style: theme.textTheme.labelLarge),
                TextButton.icon(
                  onPressed: _pasteButtonTapped,
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text('Paste'),
                ),
              ],
            ),
            TextField(
              controller: _pasteController,
              onChanged: (_) => setState(() {}),
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Paste the JSON reply here…',
                border: OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
              ),
            ),
            if (_parseError != null) ...[
              const SizedBox(height: ScampiSpacing.xs),
              Text(_parseError!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: ScampiSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _pasteController.text.trim().isEmpty ? null : _parseReply,
                child: const Text('Parse reply'),
              ),
            ),
            if (draft != null) ...[
              const SizedBox(height: ScampiSpacing.lg),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: ScampiSpacing.sm),
              Text('Review before saving', style: theme.textTheme.labelLarge),
              const SizedBox(height: ScampiSpacing.sm),
              if (isMultiIngredient) ...[
                TextField(
                  controller: _mealNameController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(borderRadius: ScampiRadius.smBorder),
                  ),
                ),
                const SizedBox(height: ScampiSpacing.md),
              ],
              for (var i = 0; i < draft.ingredients.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: ScampiSpacing.xs),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ScampiSpacing.md,
                        vertical: ScampiSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(draft.ingredients[i].food.name, style: theme.textTheme.titleSmall),
                                Text(
                                  '${draft.ingredients[i].food.caloriesPer100g.round()} kcal/100g',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: ScampiSpacing.xs),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _gramsControllers[i],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) => _onGramsChanged(i, v),
                              decoration: const InputDecoration(suffixText: 'g', isDense: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: ScampiSpacing.sm),
              Container(
                padding: const EdgeInsets.all(ScampiSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: ScampiRadius.mdBorder,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(label: 'Calories', value: totals.calories.round().toString()),
                    _Stat(label: 'Protein', value: '${totals.proteinG.round()}g'),
                    _Stat(label: 'Carbs', value: '${totals.carbsG.round()}g'),
                    _Stat(label: 'Fat', value: '${totals.fatG.round()}g'),
                  ],
                ),
              ),
              const SizedBox(height: ScampiSpacing.md),
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
                      : Text(widget.forMealIngredient ? 'Save & add to meal' : 'Save'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Totals {
  const _Totals({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
