import 'food.dart';

/// One ingredient line within a [Meal] — a food at a given gram quantity.
class MealIngredient {
  const MealIngredient({this.id, required this.food, required this.grams});

  final int? id;
  final Food food;
  final double grams;

  FoodNutrition get nutrition => food.nutritionForGrams(grams);
}

/// A user-created custom meal: a named collection of foods at fixed
/// quantities (e.g. "My Chicken Biryani Bowl" = 250g rice + 150g chicken +
/// 30g yogurt). Backed by the `meals` + `meal_items` tables. Logging a
/// meal snapshots its combined nutrition into a single [FoodLogEntry]
/// rather than one entry per ingredient.
class Meal {
  const Meal({
    this.id,
    required this.name,
    this.isFavorite = false,
    required this.createdAt,
    this.ingredients = const [],
  });

  final int? id;
  final String name;
  final bool isFavorite;
  final DateTime createdAt;
  final List<MealIngredient> ingredients;

  FoodNutrition get totalNutrition => ingredients.fold(
        FoodNutrition.zero,
        (acc, ingredient) => acc + ingredient.nutrition,
      );

  double get totalGrams =>
      ingredients.fold(0.0, (acc, ingredient) => acc + ingredient.grams);

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'is_favorite': isFavorite ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Meal.fromMap(
    Map<String, Object?> map, {
    List<MealIngredient> ingredients = const [],
  }) {
    return Meal(
      id: map['id'] as int?,
      name: map['name'] as String,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      ingredients: ingredients,
    );
  }
}
