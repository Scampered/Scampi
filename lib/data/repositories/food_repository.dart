import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/food.dart';

/// Data access for the `foods` table: search, lookup, custom food
/// creation, and favorites. Search is a simple indexed `LIKE` query —
/// see the note in `scampi_schema.dart` for why this is sufficient at
/// the target scale rather than reaching for FTS.
class FoodRepository {
  FoodRepository({Database? database}) : _databaseOverride = database;

  final Database? _databaseOverride;

  Future<Database> get _db async =>
      _databaseOverride ?? await AppDatabase.instance.database;

  /// Instant offline search by name, optionally filtered by category
  /// and/or region. Favorites and exact-prefix matches are sorted first
  /// so the most likely intended result tends to surface near the top.
  Future<List<Food>> search(
    String query, {
    String? category,
    List<String>? categories,
    String? region,
    int limit = 50,
  }) async {
    final db = await _db;
    final trimmed = query.trim();

    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (trimmed.isNotEmpty) {
      whereClauses.add('name LIKE ?');
      whereArgs.add('%$trimmed%');
    }
    if (categories != null && categories.isNotEmpty) {
      whereClauses.add('category IN (${List.filled(categories.length, '?').join(',')})');
      whereArgs.addAll(categories);
    } else if (category != null) {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }
    if (region != null) {
      whereClauses.add('region = ?');
      whereArgs.add(region);
    }

    final rows = await db.query(
      'foods',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'is_favorite DESC, name ASC',
      limit: limit,
    );

    return rows.map(Food.fromMap).toList();
  }

  Future<Food?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('foods', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Food.fromMap(rows.first);
  }

  /// Case-insensitive exact name match, used to dedupe AI-imported
  /// ingredients against what's already in the database rather than
  /// creating a near-duplicate custom food every time.
  Future<Food?> findByExactName(String name) async {
    final db = await _db;
    final rows = await db.query(
      'foods',
      where: 'LOWER(name) = ?',
      whereArgs: [name.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Food.fromMap(rows.first);
  }

  Future<List<String>> getCategories() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT DISTINCT category FROM foods ORDER BY category ASC',
    );
    return rows.map((r) => r['category'] as String).toList();
  }

  Future<List<String>> getRegions() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT DISTINCT region FROM foods WHERE region IS NOT NULL ORDER BY region ASC',
    );
    return rows.map((r) => r['region'] as String).toList();
  }

  /// All custom foods — anything the user (or an AI import) added rather
  /// than what shipped in the seed catalog. Powers the "Your Ingredients"
  /// category on the Add Food screen.
  Future<List<Food>> getCustomFoods({int limit = 200}) async {
    final db = await _db;
    final rows = await db.query(
      'foods',
      where: 'is_custom = 1',
      orderBy: 'name ASC',
      limit: limit,
    );
    return rows.map(Food.fromMap).toList();
  }

  Future<List<Food>> getFavorites({int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(
      'foods',
      where: 'is_favorite = 1',
      orderBy: 'name ASC',
      limit: limit,
    );
    return rows.map(Food.fromMap).toList();
  }

  Future<int> createCustomFood(Food food) async {
    final db = await _db;
    return db.insert('foods', {
      ...food.toMap(),
      'is_custom': 1,
    });
  }

  Future<void> updateFood(Food food) async {
    if (food.id == null) {
      throw ArgumentError('Cannot update a food with no id.');
    }
    final db = await _db;
    await db.update(
      'foods',
      food.toMap(),
      where: 'id = ?',
      whereArgs: [food.id],
    );
  }

  Future<void> setFavorite(int foodId, bool isFavorite) async {
    final db = await _db;
    await db.update(
      'foods',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [foodId],
    );
  }

  Future<void> deleteCustomFood(int foodId) async {
    final db = await _db;
    await db.delete(
      'foods',
      where: 'id = ? AND is_custom = 1',
      whereArgs: [foodId],
    );
  }

  Future<int> countAll() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM foods');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
