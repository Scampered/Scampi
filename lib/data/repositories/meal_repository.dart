import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/food.dart';
import '../models/meal.dart';

/// Data access for custom meals (`meals` + `meal_items` tables).
class MealRepository {
  MealRepository({Database? database}) : _databaseOverride = database;

  final Database? _databaseOverride;

  Future<Database> get _db async =>
      _databaseOverride ?? await AppDatabase.instance.database;

  Future<int> createMeal(String name, List<MealIngredient> ingredients) async {
    final db = await _db;
    return db.transaction((txn) async {
      final mealId = await txn.insert('meals', {
        'name': name,
        'is_favorite': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final ingredient in ingredients) {
        await txn.insert('meal_items', {
          'meal_id': mealId,
          'food_id': ingredient.food.id,
          'grams': ingredient.grams,
        });
      }
      return mealId;
    });
  }

  /// Meals whose own name matches [query], OR that contain at least one
  /// ingredient whose food name matches — e.g. searching "biryani rice"
  /// finds both a meal literally named that and any other meal (like
  /// "Sunday Lunch") that happens to include Biryani Rice as one of its
  /// ingredients. `DISTINCT` because a meal with more than one matching
  /// ingredient would otherwise come back once per match.
  Future<List<Meal>> searchMeals(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final db = await _db;
    final likeQuery = '%$trimmed%';
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT meals.* FROM meals
      LEFT JOIN meal_items ON meal_items.meal_id = meals.id
      LEFT JOIN foods ON foods.id = meal_items.food_id
      WHERE meals.name LIKE ? OR foods.name LIKE ?
      ORDER BY meals.created_at DESC
      ''',
      [likeQuery, likeQuery],
    );
    final meals = <Meal>[];
    for (final row in rows) {
      final ingredients = await _ingredientsForMeal(db, row['id'] as int);
      meals.add(Meal.fromMap(row, ingredients: ingredients));
    }
    return meals;
  }

  Future<List<Meal>> getAllMeals() async {
    final db = await _db;
    final mealRows = await db.query('meals', orderBy: 'created_at DESC');
    final meals = <Meal>[];
    for (final row in mealRows) {
      final ingredients = await _ingredientsForMeal(db, row['id'] as int);
      meals.add(Meal.fromMap(row, ingredients: ingredients));
    }
    return meals;
  }

  Future<Meal?> getMeal(int id) async {
    final db = await _db;
    final rows = await db.query('meals', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final ingredients = await _ingredientsForMeal(db, id);
    return Meal.fromMap(rows.first, ingredients: ingredients);
  }

  /// Replaces a meal's name and full ingredient list. Ingredients are
  /// replaced wholesale (delete then re-insert) rather than diffed, since
  /// the meal builder always hands back the complete desired list.
  Future<void> updateMeal(int id, String name, List<MealIngredient> ingredients) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update('meals', {'name': name}, where: 'id = ?', whereArgs: [id]);
      await txn.delete('meal_items', where: 'meal_id = ?', whereArgs: [id]);
      for (final ingredient in ingredients) {
        await txn.insert('meal_items', {
          'meal_id': id,
          'food_id': ingredient.food.id,
          'grams': ingredient.grams,
        });
      }
    });
  }

  Future<void> deleteMeal(int id) async {
    final db = await _db;
    await db.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setFavorite(int id, bool isFavorite) async {
    final db = await _db;
    await db.update(
      'meals',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<MealIngredient>> _ingredientsForMeal(Database db, int mealId) async {
    final rows = await db.rawQuery('''
      SELECT mi.id as item_id, mi.grams as item_grams, f.*
      FROM meal_items mi
      JOIN foods f ON f.id = mi.food_id
      WHERE mi.meal_id = ?
    ''', [mealId]);
    return rows
        .map((row) => MealIngredient(
              id: row['item_id'] as int?,
              food: Food.fromMap(row),
              grams: (row['item_grams'] as num).toDouble(),
            ))
        .toList();
  }
}
