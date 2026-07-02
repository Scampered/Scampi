/// Builds the normalized dedupe key used to detect duplicate foods
/// across the seed database and any imported food packs. Two foods are
/// considered the same if their name, category, and region all match
/// case-insensitively after trimming.
///
/// Centralized here so the seeder and the importer can never drift out
/// of sync on how the key is computed — if they did, the seed foods and
/// a freshly-imported pack could silently fail to dedupe against each
/// other.
String buildFoodDedupeKey({
  required String name,
  required String category,
  String? region,
}) {
  final normalizedRegion = (region ?? '').trim().toLowerCase();
  return '${name.trim().toLowerCase()}|${category.trim().toLowerCase()}|$normalizedRegion';
}
