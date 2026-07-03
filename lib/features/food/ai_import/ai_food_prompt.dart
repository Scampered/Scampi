import 'dart:convert';

import '../../../data/models/food.dart';
import '../../../data/repositories/food_repository.dart';

/// Builds the copy/paste prompt sent alongside a shared photo to an
/// external AI chat app (ChatGPT, Claude, Gemini) asking it to identify a
/// food and estimate its nutrition from the photo. This is intentionally a
/// manual share-sheet + clipboard workflow, not a live API call — Scampi
/// has no network dependency and no API keys. [notes] is optional extra
/// context the user typed (e.g. "no sauce", "large portion").
String buildFoodImportPrompt({String? notes}) {
  final noteLine = (notes != null && notes.trim().isNotEmpty)
      ? '\n\nExtra context from me: "${notes.trim()}"'
      : '';

  return '''
I'm using an offline nutrition tracking app. Please look at the attached photo, identify the food, and estimate its nutrition.$noteLine

Respond with ONLY a single JSON object, no markdown formatting, no code fences, no explanation — just the raw JSON, in exactly this shape:

{"name": "string", "category": "string", "calories_per_100g": number, "protein_per_100g": number, "carbs_per_100g": number, "fat_per_100g": number, "default_serving_grams": number, "default_serving_label": "string"}

Rules:
- All nutrition values are per 100 grams, using your best estimate from standard nutrition data and what's visible in the photo.
- "category" should be a short common category like Fruits, Vegetables, Dairy, Meat, Fish, Bread, Rice, Pasta, Desserts, Drinks, Snacks, Fast Food, or Traditional Meals.
- "default_serving_grams" and "default_serving_label" should estimate the portion shown in the photo, e.g. 150 and "1 medium".
''';
}

/// Builds the prompt sent alongside a shared meal photo — the AI returns a
/// meal name plus a list of ingredients it can identify in the photo, each
/// shaped like a single food import with an estimated gram quantity.
String buildMealImportPrompt({String? notes}) {
  final noteLine = (notes != null && notes.trim().isNotEmpty)
      ? '\n\nExtra context from me: "${notes.trim()}"'
      : '';

  return '''
I'm using an offline nutrition tracking app. Please look at the attached photo of my meal, break it down into its distinct ingredients/components, and estimate the nutrition for each.$noteLine

Respond with ONLY a single JSON object, no markdown formatting, no code fences, no explanation — just the raw JSON, in exactly this shape:

{"meal_name": "string", "ingredients": [{"name": "string", "category": "string", "grams": number, "calories_per_100g": number, "protein_per_100g": number, "carbs_per_100g": number, "fat_per_100g": number}]}

Rules:
- Break the meal down into its visible ingredients/components with a realistic gram quantity for each, based on the portion shown in the photo.
- All calories_per_100g/protein_per_100g/carbs_per_100g/fat_per_100g values are per 100 grams of that ingredient, using your best estimate from standard nutrition data.
- "category" should be a short common category like Fruits, Vegetables, Dairy, Meat, Fish, Bread, Rice, Pasta, Desserts, Drinks, Snacks, Fast Food, or Traditional Meals.
''';
}

/// Builds the prompt for a text-only description (no photo) — e.g. "100g
/// grilled prawns, 200g rice, 20ml garlic sauce" for something not on the
/// menu and not worth photographing. Same JSON reply shape as
/// [buildMealImportPrompt] so it reuses the same parser/review UI.
String buildTextMealImportPrompt(String description) {
  return '''
I'm using an offline nutrition tracking app. Based on this description of my meal, break it down into its distinct ingredients/components and estimate the nutrition for each:

"${description.trim()}"

Respond with ONLY a single JSON object, no markdown formatting, no code fences, no explanation — just the raw JSON, in exactly this shape:

{"meal_name": "string", "ingredients": [{"name": "string", "category": "string", "grams": number, "calories_per_100g": number, "protein_per_100g": number, "carbs_per_100g": number, "fat_per_100g": number}]}

Rules:
- Use the quantities I gave (grams, ml, "small"/"large" etc.) to estimate a realistic gram amount for each ingredient — convert ml/portions to grams as needed.
- All calories_per_100g/protein_per_100g/carbs_per_100g/fat_per_100g values are per 100 grams of that ingredient, using your best estimate from standard nutrition data.
- "category" should be a short common category like Fruits, Vegetables, Dairy, Meat, Fish, Bread, Rice, Pasta, Desserts, Drinks, Snacks, Fast Food, or Traditional Meals.
''';
}

/// A parsed single-food AI response, editable before saving.
class ParsedFoodDraft {
  ParsedFoodDraft({
    required this.name,
    required this.category,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.defaultServingGrams,
    this.defaultServingLabel,
  });

  String name;
  String category;
  double caloriesPer100g;
  double proteinPer100g;
  double carbsPer100g;
  double fatPer100g;
  double? defaultServingGrams;
  String? defaultServingLabel;
}

/// A parsed meal AI response: a name plus draft ingredients, each with a
/// gram quantity for this serving of the meal.
class ParsedMealDraft {
  ParsedMealDraft({required this.mealName, required this.ingredients});

  String mealName;
  List<ParsedMealIngredientDraft> ingredients;
}

class ParsedMealIngredientDraft {
  ParsedMealIngredientDraft({
    required this.food,
    required this.grams,
  });

  final ParsedFoodDraft food;
  double grams;
}

/// Quick heuristic for "does this clipboard text look like a food-import
/// AI reply" — used to auto-offer a paste when the app resumes (e.g. the
/// user just switched back after copying the AI's answer) without having
/// to fully parse it first.
bool looksLikeFoodReply(String text) {
  final t = text.trim();
  return t.contains('{') &&
      t.contains('}') &&
      t.contains('calories_per_100g') &&
      !t.contains('"ingredients"');
}

/// Same idea as [looksLikeFoodReply] but for the whole-meal shape.
bool looksLikeMealReply(String text) {
  final t = text.trim();
  return t.contains('{') && t.contains('}') && t.contains('"ingredients"') && t.contains('meal_name');
}

/// Resolves an AI-parsed ingredient against the existing food database by
/// exact (case-insensitive) name match — if it's already there, reuse that
/// row's id and nutrition rather than creating a near-duplicate; otherwise
/// save it as a new custom food so it shows up under "Your ingredients"
/// (any custom food) on future searches too.
Future<Food> resolveOrCreateFood(FoodRepository repo, ParsedFoodDraft draft) async {
  final existing = await repo.findByExactName(draft.name);
  if (existing != null) return existing;

  final food = Food(
    name: draft.name,
    category: draft.category.trim().isEmpty ? 'Generic Ingredients' : draft.category.trim(),
    caloriesPer100g: draft.caloriesPer100g,
    proteinPer100g: draft.proteinPer100g,
    carbsPer100g: draft.carbsPer100g,
    fatPer100g: draft.fatPer100g,
    defaultServingGrams: draft.defaultServingGrams,
    defaultServingLabel: draft.defaultServingLabel,
    isCustom: true,
  );
  final id = await repo.createCustomFood(food);
  return food.copyWith(id: id);
}

class AiImportParseException implements Exception {
  AiImportParseException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Extracts the first `{...}` JSON object from arbitrary pasted text (AI
/// replies sometimes wrap JSON in markdown fences or add a sentence before
/// or after it) and decodes it.
Map<String, Object?> _extractJsonObject(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start == -1 || end == -1 || end < start) {
    throw AiImportParseException(
      "Couldn't find a JSON object in that text. Make sure you pasted the AI's full reply.",
    );
  }
  final jsonText = raw.substring(start, end + 1);
  try {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, Object?>) {
      throw AiImportParseException('Expected a JSON object but got something else.');
    }
    return decoded;
  } on FormatException {
    throw AiImportParseException(
      "That doesn't look like valid JSON. Make sure you pasted the AI's full, unedited reply.",
    );
  }
}

double _num(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _str(Map<String, Object?> map, String key, {String fallback = ''}) {
  final value = map[key];
  if (value is String) return value;
  return fallback;
}

ParsedFoodDraft parseFoodResponse(String raw) {
  final map = _extractJsonObject(raw);
  final name = _str(map, 'name');
  if (name.isEmpty) {
    throw AiImportParseException('The reply is missing a food "name" field.');
  }
  return ParsedFoodDraft(
    name: name,
    category: _str(map, 'category', fallback: 'Generic Ingredients'),
    caloriesPer100g: _num(map, 'calories_per_100g'),
    proteinPer100g: _num(map, 'protein_per_100g'),
    carbsPer100g: _num(map, 'carbs_per_100g'),
    fatPer100g: _num(map, 'fat_per_100g'),
    defaultServingGrams: map['default_serving_grams'] != null ? _num(map, 'default_serving_grams') : null,
    defaultServingLabel: map['default_serving_label'] as String?,
  );
}

ParsedMealDraft parseMealResponse(String raw) {
  final map = _extractJsonObject(raw);
  final mealName = _str(map, 'meal_name');
  if (mealName.isEmpty) {
    throw AiImportParseException('The reply is missing a "meal_name" field.');
  }
  final rawIngredients = map['ingredients'];
  if (rawIngredients is! List || rawIngredients.isEmpty) {
    throw AiImportParseException('The reply is missing an "ingredients" list.');
  }
  final ingredients = <ParsedMealIngredientDraft>[];
  for (final entry in rawIngredients) {
    if (entry is! Map<String, Object?>) continue;
    final name = _str(entry, 'name');
    if (name.isEmpty) continue;
    ingredients.add(
      ParsedMealIngredientDraft(
        food: ParsedFoodDraft(
          name: name,
          category: _str(entry, 'category', fallback: 'Generic Ingredients'),
          caloriesPer100g: _num(entry, 'calories_per_100g'),
          proteinPer100g: _num(entry, 'protein_per_100g'),
          carbsPer100g: _num(entry, 'carbs_per_100g'),
          fatPer100g: _num(entry, 'fat_per_100g'),
        ),
        grams: _num(entry, 'grams'),
      ),
    );
  }
  if (ingredients.isEmpty) {
    throw AiImportParseException("Couldn't parse any ingredients from that reply.");
  }
  return ParsedMealDraft(mealName: mealName, ingredients: ingredients);
}
