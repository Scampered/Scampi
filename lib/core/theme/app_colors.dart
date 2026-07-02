import 'package:flutter/material.dart';

/// Scampi brand color palette.
///
/// Light theme: white backgrounds, mint green primary accent,
/// soft blue secondary accent, soft orange for warnings.
///
/// Dark theme: deep charcoal backgrounds, soft mint highlights,
/// muted blue accents, tuned for high readability.
class ScampiColors {
  ScampiColors._();

  // ---- Brand core ----
  static const Color mint = Color(0xFF4FD1A5); // primary accent (light)
  static const Color mintSoft = Color(0xFF7EE3C0); // dark-mode mint highlight
  static const Color blue = Color(0xFF6CA6E0); // secondary accent (light)
  static const Color blueMuted = Color(0xFF5B8FC7); // dark-mode blue accent
  static const Color orange = Color(0xFFF2A65A); // warnings (light)
  static const Color orangeSoft = Color(0xFFF4B97A); // warnings (dark)

  // ---- Status colors (shared) ----
  static const Color success = Color(0xFF4FD1A5);
  static const Color danger = Color(0xFFE0735C);
  static const Color warning = Color(0xFFF2A65A);
  static const Color info = Color(0xFF6CA6E0);

  // ---- Light theme surfaces ----
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF7F9F8);
  static const Color lightSurfaceVariant = Color(0xFFEFF3F1);
  static const Color lightOnBackground = Color(0xFF1C2422);
  static const Color lightOnSurfaceMuted = Color(0xFF6B756F);
  static const Color lightBorder = Color(0xFFE3E8E6);

  // ---- Dark theme surfaces ----
  static const Color darkBackground = Color(0xFF15191B);
  static const Color darkSurface = Color(0xFF1E2426);
  static const Color darkSurfaceVariant = Color(0xFF272F31);
  static const Color darkOnBackground = Color(0xFFEDF2F0);
  static const Color darkOnSurfaceMuted = Color(0xFFA3ACA8);
  static const Color darkBorder = Color(0xFF333C3E);

  // ---- Macro chart colors (consistent across themes) ----
  static const Color macroProtein = Color(0xFFE0735C); // warm red-orange
  static const Color macroCarbs = Color(0xFF6CA6E0); // blue
  static const Color macroFat = Color(0xFFF2C94C); // soft yellow
  static const Color macroWater = Color(0xFF5BC0DE); // cyan-blue

  // ---- Selection accent (mint × purple) ----
  // A dedicated color for "this option is selected" states — segmented
  // buttons, selectable cards in onboarding, etc. Deliberately separate
  // from `primary`/`secondary` so all selection UI reads consistently
  // regardless of what else those roles are used for elsewhere.
  static const Color selectionLight = Color(0xFF8B5CF6); // vivid violet
  static const Color selectionDark = Color(0xFFC4A6F5); // softer violet, dark bg
}

/// Returns the selection accent color appropriate for the current
/// theme brightness. See [ScampiColors.selectionLight]/[selectionDark].
Color scampiSelectionColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? ScampiColors.selectionDark
      : ScampiColors.selectionLight;
}
