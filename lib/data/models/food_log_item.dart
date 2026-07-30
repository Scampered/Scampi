import 'food.dart';

/// One ingredient line within a [FoodLogEntry] that was logged from a
/// multi-ingredient meal/AI import — mirrors [MealIngredient] but stores
/// nutrition as per-100g rates (rather than joining live against a
/// [Food] row) so scaling `grams` later (an ingredient edit, or a
/// servings multiplier) recomputes correctly even if the ingredient
/// wasn't saved to the food database, or the underlying [Food] row
/// changes afterward.
class FoodLogItem {
  const FoodLogItem({
    this.id,
    this.foodId,
    required this.foodName,
    required this.grams,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });

  final int? id;

  /// Nullable when the ingredient was never saved to the food database
  /// (e.g. AI import with "Add to Your Ingredients" left unticked).
  final int? foodId;
  final String foodName;
  final double grams;

  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  FoodNutrition get nutrition {
    final factor = grams / 100.0;
    return FoodNutrition(
      calories: caloriesPer100g * factor,
      proteinG: proteinPer100g * factor,
      carbsG: carbsPer100g * factor,
      fatG: fatPer100g * factor,
    );
  }

  FoodLogItem copyWith({double? grams}) {
    return FoodLogItem(
      id: id,
      foodId: foodId,
      foodName: foodName,
      grams: grams ?? this.grams,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
    );
  }

  /// A synthetic [Food] carrying this item's snapshotted rates — lets the
  /// existing [IngredientAmountSheet] (built for real, DB-backed foods)
  /// be reused to edit this item's grams without needing to re-fetch (or
  /// having) a live food row.
  Food toSyntheticFood() {
    return Food(
      id: foodId,
      name: foodName,
      category: 'Ingredient',
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
    );
  }

  factory FoodLogItem.fromFood(Food food, double grams) {
    return FoodLogItem(
      foodId: food.id,
      foodName: food.name,
      grams: grams,
      caloriesPer100g: food.caloriesPer100g,
      proteinPer100g: food.proteinPer100g,
      carbsPer100g: food.carbsPer100g,
      fatPer100g: food.fatPer100g,
    );
  }

  /// [foodLogId] is passed separately rather than stored as a field since
  /// it's only known once the parent `food_log` row exists.
  Map<String, Object?> toMap(int foodLogId) {
    return {
      'food_log_id': foodLogId,
      'food_id': foodId,
      'food_name': foodName,
      'grams': grams,
      'calories_per_100g': caloriesPer100g,
      'protein_per_100g': proteinPer100g,
      'carbs_per_100g': carbsPer100g,
      'fat_per_100g': fatPer100g,
    };
  }

  factory FoodLogItem.fromMap(Map<String, Object?> map) {
    return FoodLogItem(
      id: map['id'] as int?,
      foodId: map['food_id'] as int?,
      foodName: map['food_name'] as String,
      grams: (map['grams'] as num).toDouble(),
      caloriesPer100g: (map['calories_per_100g'] as num).toDouble(),
      proteinPer100g: (map['protein_per_100g'] as num).toDouble(),
      carbsPer100g: (map['carbs_per_100g'] as num).toDouble(),
      fatPer100g: (map['fat_per_100g'] as num).toDouble(),
    );
  }
}
