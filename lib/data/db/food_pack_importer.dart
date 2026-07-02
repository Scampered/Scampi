import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/utils/dedupe_key.dart';
import 'app_database.dart';

/// Result of a food pack import, returned to the UI so it can show a
/// summary like "Imported 1,842 foods, skipped 58 duplicates."
class ImportResult {
  const ImportResult({
    required this.packId,
    required this.totalRows,
    required this.imported,
    required this.skippedDuplicates,
    required this.skippedInvalid,
    this.errorMessage,
  });

  final String packId;
  final int totalRows;
  final int imported;
  final int skippedDuplicates;
  final int skippedInvalid;
  final String? errorMessage;

  bool get succeeded => errorMessage == null;
}

/// Imports additional food packs (JSON or CSV) into the `foods` table.
///
/// Design goals per the architecture spec:
/// - Packs merge into the existing database rather than replacing it.
/// - Duplicates (same normalized name+category+region as an existing
///   row) are skipped, not re-inserted.
/// - Re-importing the same pack is safe — `food_packs` tracks pack IDs
///   so a second import of an already-applied pack is a no-op.
/// - Designed to scale: uses a single `Batch` for the insert pass rather
///   than one `await db.insert(...)` per row, which is what actually
///   keeps a 5,000–50,000 row import fast on-device.
///
/// Expected JSON shape (a list of food objects):
/// ```json
/// {
///   "pack_id": "usda_fruits_v1",
///   "pack_name": "USDA Fruits Pack",
///   "version": "1.0",
///   "foods": [
///     {
///       "name": "Apple, raw",
///       "category": "Fruits",
///       "region": "Global",
///       "calories_per_100g": 52,
///       "protein_per_100g": 0.3,
///       "carbs_per_100g": 14,
///       "fat_per_100g": 0.2,
///       "default_serving_grams": 182,
///       "default_serving_label": "1 medium"
///     }
///   ]
/// }
/// ```
///
/// Expected CSV shape: a header row with at minimum
/// `name,category,calories_per_100g,protein_per_100g,carbs_per_100g,fat_per_100g`
/// — `region`, `default_serving_grams`, and `default_serving_label` are
/// optional columns.
class FoodPackImporter {
  FoodPackImporter({Database? database}) : _databaseOverride = database;

  final Database? _databaseOverride;

  Future<Database> get _db async =>
      _databaseOverride ?? await AppDatabase.instance.database;

  Future<ImportResult> importJson(String jsonString) async {
    late final Map<String, Object?> parsed;
    try {
      parsed = jsonDecode(jsonString) as Map<String, Object?>;
    } catch (e) {
      return ImportResult(
        packId: 'unknown',
        totalRows: 0,
        imported: 0,
        skippedDuplicates: 0,
        skippedInvalid: 0,
        errorMessage: 'Could not parse JSON: $e',
      );
    }

    final packId = (parsed['pack_id'] as String?) ?? 'pack_${DateTime.now().millisecondsSinceEpoch}';
    final packName = (parsed['pack_name'] as String?) ?? packId;
    final version = parsed['version'] as String?;
    final foodsRaw = parsed['foods'];

    if (foodsRaw is! List) {
      return ImportResult(
        packId: packId,
        totalRows: 0,
        imported: 0,
        skippedDuplicates: 0,
        skippedInvalid: 0,
        errorMessage: 'JSON pack is missing a "foods" array.',
      );
    }

    final rows = <Map<String, Object?>>[];
    var invalid = 0;
    for (final item in foodsRaw) {
      if (item is! Map) {
        invalid++;
        continue;
      }
      final row = _normalizeRawRow(item.cast<String, Object?>());
      if (row == null) {
        invalid++;
        continue;
      }
      rows.add(row);
    }

    return _mergeRows(
      packId: packId,
      packName: packName,
      version: version,
      rows: rows,
      totalRows: foodsRaw.length,
      preInvalid: invalid,
    );
  }

  Future<ImportResult> importCsv(
    String csvString, {
    required String packId,
    String? packName,
    String? version,
  }) async {
    final rows = const CsvToListConverter(eol: '\n').convert(csvString);
    if (rows.isEmpty) {
      return ImportResult(
        packId: packId,
        totalRows: 0,
        imported: 0,
        skippedDuplicates: 0,
        skippedInvalid: 0,
        errorMessage: 'CSV file is empty.',
      );
    }

    final header = rows.first.map((e) => e.toString().trim()).toList();
    final dataRows = rows.skip(1).toList();

    final parsedRows = <Map<String, Object?>>[];
    var invalid = 0;
    for (final row in dataRows) {
      if (row.length != header.length) {
        invalid++;
        continue;
      }
      final map = <String, Object?>{
        for (var i = 0; i < header.length; i++) header[i]: row[i],
      };
      final normalized = _normalizeRawRow(map);
      if (normalized == null) {
        invalid++;
        continue;
      }
      parsedRows.add(normalized);
    }

    return _mergeRows(
      packId: packId,
      packName: packName ?? packId,
      version: version,
      rows: parsedRows,
      totalRows: dataRows.length,
      preInvalid: invalid,
    );
  }

  /// Validates and coerces a raw row (from JSON or CSV) into the shape
  /// `foods` table inserts expect. Returns null if required fields are
  /// missing or non-numeric, so the caller can count it as invalid
  /// rather than crash the whole import on one bad row.
  Map<String, Object?>? _normalizeRawRow(Map<String, Object?> raw) {
    final name = raw['name']?.toString().trim();
    final category = raw['category']?.toString().trim();
    if (name == null || name.isEmpty || category == null || category.isEmpty) {
      return null;
    }

    double? asDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final calories = asDouble(raw['calories_per_100g']);
    final protein = asDouble(raw['protein_per_100g']);
    final carbs = asDouble(raw['carbs_per_100g']);
    final fat = asDouble(raw['fat_per_100g']);

    if (calories == null || protein == null || carbs == null || fat == null) {
      return null;
    }

    final region = raw['region']?.toString().trim();
    final servingGrams = asDouble(raw['default_serving_grams']);
    final servingLabel = raw['default_serving_label']?.toString().trim();

    return {
      'name': name,
      'category': category,
      'region': (region == null || region.isEmpty) ? null : region,
      'calories_per_100g': calories,
      'protein_per_100g': protein,
      'carbs_per_100g': carbs,
      'fat_per_100g': fat,
      'default_serving_grams': servingGrams,
      'default_serving_label':
          (servingLabel == null || servingLabel.isEmpty) ? null : servingLabel,
    };
  }

  Future<ImportResult> _mergeRows({
    required String packId,
    required String packName,
    String? version,
    required List<Map<String, Object?>> rows,
    required int totalRows,
    required int preInvalid,
  }) async {
    final db = await _db;

    // Already-applied pack guard: re-importing the same pack_id is a
    // no-op rather than a duplicate-flood.
    final existingPack = await db.query(
      'food_packs',
      where: 'pack_id = ?',
      whereArgs: [packId],
      limit: 1,
    );
    if (existingPack.isNotEmpty) {
      return ImportResult(
        packId: packId,
        totalRows: totalRows,
        imported: 0,
        skippedDuplicates: totalRows,
        skippedInvalid: preInvalid,
        errorMessage: 'Pack "$packId" was already imported.',
      );
    }

    // Build the set of existing dedupe keys once, rather than querying
    // per-row, so a large pack import stays fast.
    final existingKeysResult = await db.query('foods', columns: ['dedupe_key']);
    final existingKeys = existingKeysResult
        .map((r) => r['dedupe_key'] as String?)
        .whereType<String>()
        .toSet();

    var imported = 0;
    var duplicates = 0;
    final batch = db.batch();
    final seenInThisPack = <String>{};

    for (final row in rows) {
      final key = buildFoodDedupeKey(
        name: row['name'] as String,
        category: row['category'] as String,
        region: row['region'] as String?,
      );

      if (existingKeys.contains(key) || seenInThisPack.contains(key)) {
        duplicates++;
        continue;
      }

      seenInThisPack.add(key);
      batch.insert('foods', {
        ...row,
        'is_custom': 0,
        'is_favorite': 0,
        'source_pack_id': packId,
        'dedupe_key': key,
      });
      imported++;
    }

    batch.insert('food_packs', {
      'pack_id': packId,
      'pack_name': packName,
      'version': version,
      'imported_at': DateTime.now().toIso8601String(),
      'food_count': imported,
    });

    await batch.commit(noResult: true);

    return ImportResult(
      packId: packId,
      totalRows: totalRows,
      imported: imported,
      skippedDuplicates: duplicates,
      skippedInvalid: preInvalid,
    );
  }
}
