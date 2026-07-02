/// A single food item in the offline database. Nutrition values are
/// stored per 100g so any quantity/serving can be derived consistently,
/// per the spec.
class Food {
  const Food({
    this.id,
    required this.name,
    required this.category,
    this.region,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.defaultServingGrams,
    this.defaultServingLabel,
    this.isCustom = false,
    this.isFavorite = false,
    this.barcode,
  });

  final int? id;
  final String name;
  final String category;

  /// Region/country tag for filtering (Pakistan, Bahrain, Germany,
  /// Algeria, Middle East, South Asia, Europe, Global, etc). Nullable
  /// since not every food needs a region (e.g. "Generic Ingredients").
  final String? region;

  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  /// E.g. 150 grams for "1 medium banana" — used to pre-fill a sensible
  /// default quantity when a user selects this food.
  final double? defaultServingGrams;
  final String? defaultServingLabel;

  /// True for foods the user created via the Custom Food Creator, as
  /// opposed to foods seeded from the built-in database or an imported
  /// food pack.
  final bool isCustom;
  final bool isFavorite;

  /// Optional barcode for future barcode-scan lookup; not populated by
  /// the seed database but the column exists so it doesn't require a
  /// migration later.
  final String? barcode;

  /// Computes nutrition for an arbitrary gram quantity of this food.
  FoodNutrition nutritionForGrams(double grams) {
    final factor = grams / 100.0;
    return FoodNutrition(
      calories: caloriesPer100g * factor,
      proteinG: proteinPer100g * factor,
      carbsG: carbsPer100g * factor,
      fatG: fatPer100g * factor,
    );
  }

  Food copyWith({
    int? id,
    String? name,
    String? category,
    String? region,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    double? defaultServingGrams,
    String? defaultServingLabel,
    bool? isCustom,
    bool? isFavorite,
    String? barcode,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      region: region ?? this.region,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      defaultServingGrams: defaultServingGrams ?? this.defaultServingGrams,
      defaultServingLabel: defaultServingLabel ?? this.defaultServingLabel,
      isCustom: isCustom ?? this.isCustom,
      isFavorite: isFavorite ?? this.isFavorite,
      barcode: barcode ?? this.barcode,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'region': region,
      'calories_per_100g': caloriesPer100g,
      'protein_per_100g': proteinPer100g,
      'carbs_per_100g': carbsPer100g,
      'fat_per_100g': fatPer100g,
      'default_serving_grams': defaultServingGrams,
      'default_serving_label': defaultServingLabel,
      'is_custom': isCustom ? 1 : 0,
      'is_favorite': isFavorite ? 1 : 0,
      'barcode': barcode,
    };
  }

  factory Food.fromMap(Map<String, Object?> map) {
    return Food(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String,
      region: map['region'] as String?,
      caloriesPer100g: (map['calories_per_100g'] as num).toDouble(),
      proteinPer100g: (map['protein_per_100g'] as num).toDouble(),
      carbsPer100g: (map['carbs_per_100g'] as num).toDouble(),
      fatPer100g: (map['fat_per_100g'] as num).toDouble(),
      defaultServingGrams: (map['default_serving_grams'] as num?)?.toDouble(),
      defaultServingLabel: map['default_serving_label'] as String?,
      isCustom: (map['is_custom'] as int? ?? 0) == 1,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      barcode: map['barcode'] as String?,
    );
  }
}

/// Calculated nutrition for a specific logged quantity of a food.
class FoodNutrition {
  const FoodNutrition({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  FoodNutrition operator +(FoodNutrition other) {
    return FoodNutrition(
      calories: calories + other.calories,
      proteinG: proteinG + other.proteinG,
      carbsG: carbsG + other.carbsG,
      fatG: fatG + other.fatG,
    );
  }

  FoodNutrition operator *(double factor) {
    return FoodNutrition(
      calories: calories * factor,
      proteinG: proteinG * factor,
      carbsG: carbsG * factor,
      fatG: fatG * factor,
    );
  }

  static const zero = FoodNutrition(calories: 0, proteinG: 0, carbsG: 0, fatG: 0);
}
