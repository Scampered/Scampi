/// How a logged quantity was specified by the user — grams entered
/// directly, or a number of servings of the food's default serving size.
enum QuantityMode { grams, servings }

/// A single logged food entry in the user's diary for a given day.
/// Snapshots the food's nutrition values at the time of logging (rather
/// than joining live against the foods table) so edits to a food later,
/// or food-pack updates, don't retroactively rewrite history.
class FoodLogEntry {
  const FoodLogEntry({
    this.id,
    required this.foodId,
    required this.foodName,
    required this.loggedAt,
    required this.mealSlot,
    required this.quantityMode,
    required this.grams,
    this.servings,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int? id;

  /// Nullable because a custom one-off entry (e.g. from AI Meal Import,
  /// not saved to the food database) may not reference a stored food row.
  final int? foodId;
  final String foodName;

  final DateTime loggedAt;
  final MealSlot mealSlot;

  final QuantityMode quantityMode;
  final double grams;
  final double? servings;

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'food_id': foodId,
      'food_name': foodName,
      'logged_at': loggedAt.toIso8601String(),
      'meal_slot': mealSlot.name,
      'quantity_mode': quantityMode.name,
      'grams': grams,
      'servings': servings,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
    };
  }

  factory FoodLogEntry.fromMap(Map<String, Object?> map) {
    return FoodLogEntry(
      id: map['id'] as int?,
      foodId: map['food_id'] as int?,
      foodName: map['food_name'] as String,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      mealSlot: MealSlot.values.byName(map['meal_slot'] as String),
      quantityMode: QuantityMode.values.byName(map['quantity_mode'] as String),
      grams: (map['grams'] as num).toDouble(),
      servings: (map['servings'] as num?)?.toDouble(),
      calories: (map['calories'] as num).toDouble(),
      proteinG: (map['protein_g'] as num).toDouble(),
      carbsG: (map['carbs_g'] as num).toDouble(),
      fatG: (map['fat_g'] as num).toDouble(),
    );
  }
}

enum MealSlot {
  breakfast,
  lunch,
  dinner,
  snack;

  String get label {
    switch (this) {
      case MealSlot.breakfast:
        return 'Breakfast';
      case MealSlot.lunch:
        return 'Lunch';
      case MealSlot.dinner:
        return 'Dinner';
      case MealSlot.snack:
        return 'Snack';
    }
  }
}
