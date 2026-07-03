import 'package:sqflite/sqflite.dart';
import '../../core/utils/dedupe_key.dart';

/// Initial built-in food database, seeded on first app launch.
///
/// Values are per 100g and sourced from standard, widely-published
/// nutrition references (USDA FoodData Central figures and typical
/// manufacturer/recipe averages for prepared regional dishes). Prepared
/// dishes (e.g. biryani, currywurst) vary by recipe — these are
/// reasonable representative averages, not a substitute for a verified
/// branded database. This seed set is intentionally curated (~150 items)
/// to ship something usable immediately; the food-pack importer is the
/// path to scaling toward 2,000–50,000+ items from a real dataset.
///
/// `dedupe_key` is `name|category|region` lowercased, used by the
/// food-pack importer to detect duplicates against this seed set.
Future<void> seedInitialFoods(Database db) async {
  final batch = db.batch();

  for (final food in _seedFoods) {
    final dedupeKey = buildFoodDedupeKey(
      name: food['name'] as String,
      category: food['category'] as String,
      region: food['region'] as String?,
    );
    batch.insert('foods', {
      ...food,
      'is_custom': 0,
      'is_favorite': 0,
      'source_pack_id': 'seed_v1',
      'dedupe_key': dedupeKey,
    });
  }

  await batch.commit(noResult: true);
}

/// Second batch of seed foods, added after the initial ~150-item set
/// shipped — kept as its own list/source_pack_id ('seed_v2') so it can
/// also be inserted into already-seeded databases via a migration
/// ([AppDatabase]'s v6 upgrade step), not just fresh installs.
Future<void> seedMoreFoodsV2(Database db) async {
  final batch = db.batch();

  for (final food in _moreFoodsV2) {
    final dedupeKey = buildFoodDedupeKey(
      name: food['name'] as String,
      category: food['category'] as String,
      region: food['region'] as String?,
    );
    batch.insert('foods', {
      ...food,
      'is_custom': 0,
      'is_favorite': 0,
      'source_pack_id': 'seed_v2',
      'dedupe_key': dedupeKey,
    });
  }

  await batch.commit(noResult: true);
}

/// name, category, region, calories/protein/carbs/fat per 100g,
/// default serving grams + label.
final List<Map<String, Object?>> _seedFoods = [
  // ---------------- FRUITS ----------------
  _f('Apple', 'Fruits', 'Global', 52, 0.3, 14, 0.2, 182, '1 medium'),
  _f('Banana', 'Fruits', 'Global', 89, 1.1, 23, 0.3, 118, '1 medium'),
  _f('Orange', 'Fruits', 'Global', 47, 0.9, 12, 0.1, 131, '1 medium'),
  _f('Grapes', 'Fruits', 'Global', 69, 0.7, 18, 0.2, 92, '1 cup'),
  _f('Mango', 'Fruits', 'South Asia', 60, 0.8, 15, 0.4, 165, '1 cup sliced'),
  _f('Watermelon', 'Fruits', 'Global', 30, 0.6, 8, 0.2, 152, '1 cup'),
  _f('Strawberries', 'Fruits', 'Global', 32, 0.7, 8, 0.3, 144, '1 cup'),
  _f('Dates', 'Fruits', 'Middle East', 277, 1.8, 75, 0.2, 24, '3 dates'),
  _f('Pomegranate', 'Fruits', 'Middle East', 83, 1.7, 19, 1.2, 174, '1 cup arils'),
  _f('Figs', 'Fruits', 'Middle East', 74, 0.8, 19, 0.3, 50, '1 medium'),
  _f('Pineapple', 'Fruits', 'Global', 50, 0.5, 13, 0.1, 165, '1 cup'),
  _f('Peach', 'Fruits', 'Global', 39, 0.9, 10, 0.3, 150, '1 medium'),
  _f('Guava', 'Fruits', 'South Asia', 68, 2.6, 14, 1.0, 165, '1 cup'),
  _f('Apricot', 'Fruits', 'Middle East', 48, 1.4, 11, 0.4, 35, '1 medium'),

  // ---------------- VEGETABLES ----------------
  _f('Tomato', 'Vegetables', 'Global', 18, 0.9, 3.9, 0.2, 123, '1 medium'),
  _f('Cucumber', 'Vegetables', 'Global', 15, 0.7, 3.6, 0.1, 119, '1 medium'),
  _f('Carrot', 'Vegetables', 'Global', 41, 0.9, 10, 0.2, 61, '1 medium'),
  _f('Spinach', 'Vegetables', 'Global', 23, 2.9, 3.6, 0.4, 30, '1 cup'),
  _f('Broccoli', 'Vegetables', 'Global', 34, 2.8, 7, 0.4, 91, '1 cup chopped'),
  _f('Potato', 'Vegetables', 'Global', 77, 2.0, 17, 0.1, 173, '1 medium'),
  _f('Onion', 'Vegetables', 'Global', 40, 1.1, 9, 0.1, 110, '1 medium'),
  _f('Eggplant', 'Vegetables', 'Middle East', 25, 1.0, 6, 0.2, 82, '1 cup cubed'),
  _f('Bell Pepper', 'Vegetables', 'Global', 31, 1.0, 6, 0.3, 119, '1 medium'),
  _f('Okra', 'Vegetables', 'South Asia', 33, 1.9, 7, 0.2, 100, '1 cup'),
  _f('Zucchini', 'Vegetables', 'Europe', 17, 1.2, 3.1, 0.3, 124, '1 medium'),
  _f('Cauliflower', 'Vegetables', 'Global', 25, 1.9, 5, 0.3, 107, '1 cup'),
  _f('Garlic', 'Vegetables', 'Global', 149, 6.4, 33, 0.5, 3, '1 clove'),
  _f('Lettuce', 'Vegetables', 'Global', 15, 1.4, 2.9, 0.2, 36, '1 cup shredded'),

  // ---------------- DAIRY ----------------
  _f('Whole Milk', 'Dairy', 'Global', 61, 3.2, 4.8, 3.3, 244, '1 cup'),
  _f('Greek Yogurt (plain)', 'Dairy', 'Global', 59, 10, 3.6, 0.4, 170, '1 cup'),
  _f('Labneh', 'Dairy', 'Middle East', 145, 5.5, 4.0, 12, 30, '2 tbsp'),
  _f('Cheddar Cheese', 'Dairy', 'Europe', 403, 25, 1.3, 33, 28, '1 oz / 28g'),
  _f('Mozzarella', 'Dairy', 'Europe', 280, 28, 3.1, 17, 28, '1 oz / 28g'),
  _f('Feta Cheese', 'Dairy', 'Middle East', 264, 14, 4.1, 21, 28, '1 oz / 28g'),
  _f('Butter', 'Dairy', 'Global', 717, 0.9, 0.1, 81, 14, '1 tbsp'),
  _f('Paneer', 'Dairy', 'South Asia', 265, 18, 1.2, 21, 28, '1 oz / 28g'),
  _f('Eggs', 'Dairy', 'Global', 155, 13, 1.1, 11, 50, '1 large egg'),

  // ---------------- MEAT & POULTRY ----------------
  _f('Chicken Breast (cooked)', 'Meat', 'Global', 165, 31, 0, 3.6, 172, '1 breast'),
  _f('Chicken Thigh (cooked)', 'Meat', 'Global', 209, 26, 0, 11, 116, '1 thigh'),
  _f('Beef (lean, cooked)', 'Meat', 'Global', 217, 26, 0, 12, 85, '3 oz'),
  _f('Lamb (cooked)', 'Meat', 'Middle East', 294, 25, 0, 21, 85, '3 oz'),
  _f('Ground Beef (80/20, cooked)', 'Meat', 'Global', 254, 26, 0, 17, 85, '3 oz'),
  _f('Beef Liver (cooked)', 'Meat', 'Global', 175, 27, 3.9, 4.9, 85, '3 oz'),
  _f('Turkey Breast (cooked)', 'Meat', 'Global', 135, 30, 0, 1.0, 85, '3 oz'),
  _f('Lamb Kebab (grilled)', 'Meat', 'Middle East', 250, 24, 2, 16, 100, '1 skewer'),

  // ---------------- FISH ----------------
  _f('Salmon (cooked)', 'Fish', 'Global', 208, 20, 0, 13, 100, '1 fillet'),
  _f('Tuna (canned in water)', 'Fish', 'Global', 116, 26, 0, 1.0, 85, '3 oz'),
  _f('Tilapia (cooked)', 'Fish', 'Global', 128, 26, 0, 2.7, 100, '1 fillet'),
  _f('Shrimp (cooked)', 'Fish', 'Global', 99, 24, 0.2, 0.3, 85, '3 oz'),
  _f('Hammour (grilled)', 'Fish', 'Bahrain', 110, 22, 0, 2.0, 150, '1 fillet'),
  _f('Sardines (canned in oil)', 'Fish', 'Global', 208, 25, 0, 11, 100, '1 can'),

  // ---------------- RICE ----------------
  _f('White Rice (cooked)', 'Rice', 'Global', 130, 2.7, 28, 0.3, 158, '1 cup'),
  _f('Basmati Rice (cooked)', 'Rice', 'South Asia', 121, 2.5, 25, 0.4, 158, '1 cup'),
  _f('Brown Rice (cooked)', 'Rice', 'Global', 112, 2.3, 24, 0.8, 195, '1 cup'),
  _f('Machboos Rice', 'Rice', 'Bahrain', 175, 4.5, 28, 5.0, 250, '1 plate'),
  _f('Biryani Rice', 'Rice', 'South Asia', 200, 7, 26, 7, 300, '1 plate'),

  // ---------------- PASTA ----------------
  _f('Spaghetti (cooked)', 'Pasta', 'Europe', 158, 5.8, 31, 0.9, 140, '1 cup'),
  _f('Penne (cooked)', 'Pasta', 'Europe', 157, 5.7, 30, 0.9, 140, '1 cup'),
  _f('Macaroni and Cheese', 'Pasta', 'Global', 164, 6.4, 20, 6.5, 200, '1 cup'),
  _f('Lasagna', 'Pasta', 'Europe', 135, 8, 12, 6, 250, '1 piece'),

  // ---------------- BREAD ----------------
  _f('White Bread', 'Bread', 'Global', 265, 9, 49, 3.2, 28, '1 slice'),
  _f('Whole Wheat Bread', 'Bread', 'Global', 247, 13, 41, 3.4, 28, '1 slice'),
  _f('Khubz (Arabic flatbread)', 'Bread', 'Middle East', 275, 9, 53, 1.5, 60, '1 piece'),
  _f('Naan', 'Bread', 'South Asia', 310, 9, 50, 8, 90, '1 piece'),
  _f('Roti / Chapati', 'Bread', 'South Asia', 297, 11, 49, 7, 40, '1 piece'),
  _f('Brötchen (German roll)', 'Bread', 'Germany', 270, 9, 53, 1.8, 50, '1 roll'),
  _f('Pretzel (Brezel)', 'Bread', 'Germany', 338, 10, 70, 2.0, 80, '1 pretzel'),
  _f('Pita Bread', 'Bread', 'Middle East', 275, 9, 56, 1.2, 60, '1 piece'),

  // ---------------- DESSERTS ----------------
  _f('Baklava', 'Desserts', 'Middle East', 430, 6, 47, 26, 40, '1 piece'),
  _f('Kunafa', 'Desserts', 'Middle East', 330, 6, 40, 16, 100, '1 slice'),
  _f('Gulab Jamun', 'Desserts', 'South Asia', 320, 4, 50, 12, 40, '1 piece'),
  _f('Kheer (rice pudding)', 'Desserts', 'South Asia', 130, 3.2, 20, 4.0, 150, '1 cup'),
  _f('Black Forest Cake', 'Desserts', 'Germany', 330, 4, 38, 18, 100, '1 slice'),
  _f('Apfelstrudel', 'Desserts', 'Germany', 230, 3, 35, 9, 100, '1 slice'),
  _f('Ice Cream (vanilla)', 'Desserts', 'Global', 207, 3.5, 24, 11, 65, '1 scoop'),
  _f('Chocolate Chip Cookie', 'Desserts', 'Global', 488, 5.5, 64, 23, 16, '1 cookie'),
  _f('Cheesecake', 'Desserts', 'Global', 321, 5.5, 26, 22, 100, '1 slice'),
  _f('Makroudh', 'Desserts', 'Algeria', 410, 5, 60, 17, 50, '1 piece'),

  // ---------------- FAST FOOD ----------------
  _f('Cheeseburger', 'Fast Food', 'Global', 295, 16, 24, 15, 150, '1 burger'),
  _f('French Fries', 'Fast Food', 'Global', 312, 3.4, 41, 15, 117, '1 medium'),
  _f('Fried Chicken (breaded)', 'Fast Food', 'Global', 270, 19, 11, 17, 140, '1 piece'),
  _f('Shawarma (chicken wrap)', 'Fast Food', 'Middle East', 220, 14, 22, 9, 250, '1 wrap'),
  _f('Pizza (cheese, regular crust)', 'Fast Food', 'Global', 266, 11, 33, 10, 107, '1 slice'),
  _f('Currywurst', 'Fast Food', 'Germany', 280, 11, 14, 20, 200, '1 serving'),
  _f('Döner Kebab', 'Fast Food', 'Germany', 250, 15, 20, 12, 300, '1 sandwich'),
  _f('Samosa', 'Fast Food', 'South Asia', 308, 5, 30, 19, 50, '1 piece'),

  // ---------------- DRINKS ----------------
  _f('Black Tea', 'Drinks', 'Global', 1, 0, 0.3, 0, 240, '1 cup'),
  _f('Karak Chai', 'Drinks', 'Bahrain', 60, 1.5, 9, 2.0, 200, '1 cup'),
  _f('Arabic Coffee (Qahwa)', 'Drinks', 'Middle East', 2, 0.1, 0.2, 0, 60, '1 small cup'),
  _f('Orange Juice', 'Drinks', 'Global', 45, 0.7, 10, 0.2, 248, '1 cup'),
  _f('Cola (regular)', 'Drinks', 'Global', 42, 0, 10.6, 0, 355, '1 can'),
  _f('Laban (buttermilk)', 'Drinks', 'Middle East', 40, 3.0, 4.8, 1.0, 240, '1 cup'),
  _f('Mango Lassi', 'Drinks', 'South Asia', 95, 2.7, 17, 1.8, 240, '1 cup'),
  _f('Apfelschorle', 'Drinks', 'Germany', 22, 0, 5.4, 0, 250, '1 glass'),
  _f('Water', 'Drinks', 'Global', 0, 0, 0, 0, 250, '1 cup'),

  // ---------------- SNACKS ----------------
  _f('Almonds', 'Snacks', 'Global', 579, 21, 22, 50, 28, '1 oz / 28g'),
  _f('Pistachios', 'Snacks', 'Middle East', 560, 20, 28, 45, 28, '1 oz / 28g'),
  _f('Potato Chips', 'Snacks', 'Global', 536, 7, 53, 35, 28, '1 oz / 28g'),
  _f('Hummus', 'Snacks', 'Middle East', 166, 8, 14, 10, 60, '1/4 cup'),
  _f('Mixed Nuts', 'Snacks', 'Global', 607, 20, 21, 54, 28, '1 oz / 28g'),
  _f('Popcorn (air-popped)', 'Snacks', 'Global', 387, 13, 78, 4.5, 8, '1 cup'),
  _f('Dark Chocolate (70%)', 'Snacks', 'Global', 598, 7.8, 46, 43, 28, '1 oz / 28g'),
  _f('Pakora', 'Snacks', 'South Asia', 315, 8, 28, 19, 50, '4 pieces'),
  _f('Dried Apricots', 'Snacks', 'Middle East', 241, 3.4, 63, 0.5, 30, '1/4 cup'),

  // ---------------- TRADITIONAL MEALS ----------------
  _f('Chicken Biryani', 'Traditional Meals', 'South Asia', 165, 8, 20, 6, 350, '1 plate'),
  _f('Daal (lentil curry)', 'Traditional Meals', 'South Asia', 116, 7, 18, 1.5, 250, '1 bowl'),
  _f('Chicken Karahi', 'Traditional Meals', 'South Asia', 180, 14, 6, 11, 300, '1 serving'),
  _f('Nihari', 'Traditional Meals', 'South Asia', 210, 16, 5, 14, 300, '1 bowl'),
  _f('Machboos (chicken)', 'Traditional Meals', 'Bahrain', 175, 10, 20, 6, 350, '1 plate'),
  _f('Muhammar (sweet rice)', 'Traditional Meals', 'Bahrain', 190, 2.5, 35, 4.5, 250, '1 plate'),
  _f('Couscous with Vegetables', 'Traditional Meals', 'Algeria', 130, 4, 23, 2.0, 250, '1 bowl'),
  _f('Chorba (soup)', 'Traditional Meals', 'Algeria', 70, 3, 10, 2.0, 250, '1 bowl'),
  _f('Mansaf', 'Traditional Meals', 'Middle East', 220, 15, 12, 12, 350, '1 plate'),
  _f('Falafel', 'Traditional Meals', 'Middle East', 333, 13, 32, 18, 60, '4 pieces'),
  _f('Kabsa (chicken)', 'Traditional Meals', 'Middle East', 180, 10, 21, 6, 350, '1 plate'),
  _f('Chicken Schnitzel (breaded)', 'Traditional Meals', 'Germany', 250, 24, 12, 12, 150, '1 piece'),
  _f('Sauerbraten', 'Traditional Meals', 'Germany', 220, 24, 8, 10, 200, '1 serving'),
  _f('Bratwurst', 'Traditional Meals', 'Germany', 296, 12, 2, 27, 100, '1 sausage'),
  _f('Sauerkraut', 'Traditional Meals', 'Germany', 19, 0.9, 4.3, 0.1, 100, '1/2 cup'),
  _f('Kofta Curry', 'Traditional Meals', 'South Asia', 200, 13, 6, 14, 300, '1 serving'),
  _f('Saag (spinach curry)', 'Traditional Meals', 'South Asia', 95, 4, 8, 6, 250, '1 bowl'),

  // ---------------- GENERIC INGREDIENTS ----------------
  _f('Olive Oil', 'Generic Ingredients', 'Global', 884, 0, 0, 100, 14, '1 tbsp'),
  _f('Vegetable Oil', 'Generic Ingredients', 'Global', 884, 0, 0, 100, 14, '1 tbsp'),
  _f('Sugar (white)', 'Generic Ingredients', 'Global', 387, 0, 100, 0, 4, '1 tsp'),
  _f('Salt', 'Generic Ingredients', 'Global', 0, 0, 0, 0, 6, '1 tsp'),
  _f('Honey', 'Generic Ingredients', 'Global', 304, 0.3, 82, 0, 21, '1 tbsp'),
  _f('All-Purpose Flour', 'Generic Ingredients', 'Global', 364, 10, 76, 1.0, 125, '1 cup'),
  _f('Chickpeas (cooked)', 'Generic Ingredients', 'Middle East', 164, 9, 27, 2.6, 164, '1 cup'),
  _f('Lentils (cooked)', 'Generic Ingredients', 'South Asia', 116, 9, 20, 0.4, 198, '1 cup'),
  _f('Black Beans (cooked)', 'Generic Ingredients', 'Global', 132, 8.9, 24, 0.5, 172, '1 cup'),
  _f('Tahini', 'Generic Ingredients', 'Middle East', 595, 17, 21, 54, 15, '1 tbsp'),
  _f('Peanut Butter', 'Generic Ingredients', 'Global', 588, 25, 20, 50, 32, '2 tbsp'),

  // ---------------- MORE REGIONAL DISHES ----------------
  // Pakistan
  _f('Haleem', 'Traditional Meals', 'Pakistan', 150, 10, 15, 6, 250, '1 bowl'),
  _f('Seekh Kebab', 'Traditional Meals', 'Pakistan', 250, 20, 2, 18, 100, '2 skewers'),
  _f('Chapli Kebab', 'Traditional Meals', 'Pakistan', 280, 18, 8, 20, 100, '1 patty'),
  _f('Sindhi Biryani', 'Rice', 'Pakistan', 190, 9, 22, 7, 350, '1 plate'),
  _f('Paya', 'Traditional Meals', 'Pakistan', 150, 14, 3, 9, 300, '1 bowl'),
  _f('Roghni Naan', 'Bread', 'Pakistan', 330, 9, 52, 9, 100, '1 piece'),
  _f('Doodh Patti Chai', 'Drinks', 'Pakistan', 80, 2.5, 8, 4, 200, '1 cup'),
  _f('Sweet Lassi', 'Drinks', 'South Asia', 110, 3, 18, 3, 240, '1 glass'),
  _f('Sohan Halwa', 'Desserts', 'Pakistan', 480, 3, 60, 25, 30, '1 piece'),
  _f('Jalebi', 'Desserts', 'South Asia', 350, 2, 60, 12, 40, '2 pieces'),

  // Bahrain / Gulf
  _f('Balaleet', 'Desserts', 'Bahrain', 200, 6, 30, 6, 200, '1 plate'),
  _f('Harees', 'Traditional Meals', 'Bahrain', 160, 10, 20, 4, 250, '1 bowl'),
  _f('Khubz Regag', 'Bread', 'Bahrain', 280, 8, 55, 2, 50, '1 piece'),
  _f('Chebab (Khameer)', 'Bread', 'Bahrain', 250, 6, 45, 5, 80, '1 piece'),
  _f('Lugaimat', 'Desserts', 'Bahrain', 370, 4, 50, 17, 60, '4 pieces'),
  _f('Sambosa (Bahraini)', 'Snacks', 'Bahrain', 300, 6, 28, 18, 50, '1 piece'),

  // Middle East
  _f('Tabbouleh', 'Traditional Meals', 'Middle East', 36, 1, 7, 1, 150, '1 cup'),
  _f('Fattoush', 'Traditional Meals', 'Middle East', 55, 1.5, 8, 2, 200, '1 bowl'),
  _f('Shakshuka', 'Traditional Meals', 'Middle East', 120, 7, 8, 7, 250, '1 serving'),
  _f('Mujaddara', 'Traditional Meals', 'Middle East', 150, 6, 25, 3, 250, '1 bowl'),
  _f('Baba Ganoush', 'Snacks', 'Middle East', 130, 2.5, 9, 10, 100, '1/4 cup'),
  _f('Manakish (za\'atar)', 'Bread', 'Middle East', 300, 8, 40, 12, 100, '1 piece'),
  _f('Umm Ali', 'Desserts', 'Middle East', 280, 5, 30, 16, 150, '1 serving'),
  _f('Msakhan', 'Traditional Meals', 'Middle East', 230, 14, 20, 11, 250, '1 serving'),

  // Germany
  _f('Rouladen', 'Traditional Meals', 'Germany', 220, 20, 5, 13, 200, '1 roll'),
  _f('Kartoffelsalat', 'Traditional Meals', 'Germany', 140, 2, 18, 6, 150, '1 cup'),
  _f('Frikadellen', 'Traditional Meals', 'Germany', 230, 16, 6, 16, 100, '1 patty'),
  _f('Spätzle', 'Pasta', 'Germany', 200, 7, 35, 4, 150, '1 cup'),
  _f('Stollen', 'Desserts', 'Germany', 370, 6, 50, 16, 60, '1 slice'),

  // Algeria
  _f('Bourek', 'Fast Food', 'Algeria', 290, 10, 25, 17, 80, '2 pieces'),
  _f('Rechta', 'Pasta', 'Algeria', 180, 9, 25, 5, 300, '1 bowl'),
  _f('Mhadjeb', 'Bread', 'Algeria', 250, 6, 35, 9, 120, '1 piece'),
  _f('Chakhchoukha', 'Traditional Meals', 'Algeria', 170, 8, 20, 6, 300, '1 bowl'),
  _f('Zlabia', 'Desserts', 'Algeria', 360, 2, 58, 13, 40, '3 pieces'),
];

/// Second seed batch — see [seedMoreFoodsV2].
final List<Map<String, Object?>> _moreFoodsV2 = [
  // ---------------- MORE FRUITS & VEGETABLES ----------------
  _f('Coconut (fresh)', 'Fruits', 'South Asia', 354, 3.3, 15, 33, 80, '1/2 cup shredded'),
  _f('Dragon Fruit', 'Fruits', 'Global', 60, 1.2, 13, 0.4, 100, '1/2 fruit'),
  _f('Lychee', 'Fruits', 'South Asia', 66, 0.8, 17, 0.4, 100, '10 fruits'),
  _f('Kiwi', 'Fruits', 'Global', 61, 1.1, 15, 0.5, 76, '1 medium'),
  _f('Avocado', 'Fruits', 'Global', 160, 2, 9, 15, 150, '1 medium'),
  _f('Papaya', 'Fruits', 'South Asia', 43, 0.5, 11, 0.3, 145, '1 cup cubed'),
  _f('Sweet Potato (cooked)', 'Vegetables', 'Global', 90, 2, 21, 0.1, 130, '1 medium'),
  _f('Pumpkin (cooked)', 'Vegetables', 'Global', 20, 0.7, 5, 0.1, 245, '1 cup'),

  // ---------------- ENERGY DRINKS, JUICES, SHAKES ----------------
  _f('Energy Drink', 'Drinks', 'Global', 45, 0, 11, 0, 250, '1 can'),
  _f('Apple Juice', 'Drinks', 'Global', 46, 0.1, 11, 0.1, 248, '1 cup'),
  _f('Watermelon Juice', 'Drinks', 'Global', 30, 0.6, 7.5, 0.2, 240, '1 cup'),
  _f('Pomegranate Juice', 'Drinks', 'Middle East', 54, 0.2, 13, 0.3, 240, '1 cup'),
  _f('Chocolate Milkshake', 'Drinks', 'Global', 130, 3, 20, 4, 350, '1 glass'),
  _f('Vanilla Milkshake', 'Drinks', 'Global', 128, 3, 19, 4.3, 350, '1 glass'),
  _f('Strawberry Milkshake', 'Drinks', 'Global', 110, 2.8, 18, 3, 350, '1 glass'),
  _f('Mango Smoothie', 'Drinks', 'South Asia', 90, 1.5, 20, 0.5, 300, '1 glass'),
  _f('Mixed Berry Smoothie', 'Drinks', 'Global', 70, 1.2, 15, 0.5, 300, '1 glass'),

  // ---------------- SNACKS / BAKED GOODS ----------------
  _f('Chocolate Wafer Bar', 'Snacks', 'Global', 510, 6, 60, 27, 45, '1 bar'),
  _f('Digestive Biscuits', 'Snacks', 'Global', 471, 7, 68, 20, 16, '1 biscuit'),
  _f('Tea Biscuits (Rusk)', 'Snacks', 'South Asia', 407, 9, 73, 8, 15, '1 piece'),
  _f('Granola Bar', 'Snacks', 'Global', 471, 10, 64, 20, 40, '1 bar'),

  // ---------------- GENERIC INGREDIENTS (MORE) ----------------
  _f('Oatmeal (cooked)', 'Generic Ingredients', 'Global', 71, 2.5, 12, 1.5, 234, '1 cup cooked'),
  _f('Beef Bacon', 'Generic Ingredients', 'Global', 150, 20, 1, 8, 15, '2 slices'),

  // ---------------- SANDWICHES ----------------
  _f('Chicken Sandwich', 'Sandwiches', 'Global', 190, 14, 20, 6, 200, '1 sandwich'),
  _f('Beef Sandwich', 'Sandwiches', 'Global', 220, 13, 20, 10, 200, '1 sandwich'),
  _f('Egg Sandwich', 'Sandwiches', 'Global', 210, 9, 22, 9, 150, '1 sandwich'),
  _f('Cheese Sandwich', 'Sandwiches', 'Global', 260, 10, 28, 11, 150, '1 sandwich'),
  _f('Club Sandwich (Chicken)', 'Sandwiches', 'Global', 200, 12, 18, 8, 250, '1 sandwich'),
];

Map<String, Object?> _f(
  String name,
  String category,
  String region,
  double calories,
  double protein,
  double carbs,
  double fat,
  double servingGrams,
  String servingLabel,
) {
  return {
    'name': name,
    'category': category,
    'region': region,
    'calories_per_100g': calories,
    'protein_per_100g': protein,
    'carbs_per_100g': carbs,
    'fat_per_100g': fat,
    'default_serving_grams': servingGrams,
    'default_serving_label': servingLabel,
  };
}
