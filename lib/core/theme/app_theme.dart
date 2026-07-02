import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Builds Scampi's Material 3 ThemeData for light and dark modes.
class ScampiTheme {
  ScampiTheme._();

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: ScampiColors.mint,
      onPrimary: Color(0xFF06291C),
      secondary: ScampiColors.blue,
      onSecondary: Color(0xFF06223E),
      tertiary: ScampiColors.orange,
      onTertiary: Color(0xFF3A2400),
      error: ScampiColors.danger,
      onError: Colors.white,
      surface: ScampiColors.lightSurface,
      onSurface: ScampiColors.lightOnBackground,
      surfaceContainerHighest: ScampiColors.lightSurfaceVariant,
      outline: ScampiColors.lightBorder,
    );

    final textTheme = ScampiTypography.textTheme(
      ScampiColors.lightOnBackground,
      ScampiColors.lightOnSurfaceMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ScampiColors.lightBackground,
      textTheme: textTheme,
      fontFamily: textTheme.bodyMedium?.fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: ScampiColors.lightBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ScampiColors.lightOnBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: ScampiColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: ScampiRadius.lgBorder,
          side: const BorderSide(color: ScampiColors.lightBorder, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ScampiColors.lightBackground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ScampiColors.mint.withValues(alpha: 0.18),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected
                ? ScampiColors.lightOnBackground
                : ScampiColors.lightOnSurfaceMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ScampiColors.mint,
          foregroundColor: const Color(0xFF06291C),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: ScampiSpacing.lg,
            vertical: ScampiSpacing.md,
          ),
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(borderRadius: ScampiRadius.pillBorder),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ScampiColors.lightOnBackground,
          side: const BorderSide(color: ScampiColors.lightBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: ScampiSpacing.lg,
            vertical: ScampiSpacing.md,
          ),
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(borderRadius: ScampiRadius.pillBorder),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ScampiColors.mint,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ScampiColors.lightSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ScampiSpacing.md,
          vertical: ScampiSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: ScampiRadius.mdBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ScampiRadius.mdBorder,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ScampiRadius.mdBorder,
          borderSide: const BorderSide(color: ScampiColors.mint, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: ScampiColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ScampiColors.mint,
        linearTrackColor: ScampiColors.lightSurfaceVariant,
      ),
    );
  }

  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: ScampiColors.mintSoft,
      onPrimary: Color(0xFF06291C),
      secondary: ScampiColors.blueMuted,
      onSecondary: Color(0xFFE9F1FB),
      tertiary: ScampiColors.orangeSoft,
      onTertiary: Color(0xFF3A2400),
      error: ScampiColors.danger,
      onError: Colors.white,
      surface: ScampiColors.darkSurface,
      onSurface: ScampiColors.darkOnBackground,
      surfaceContainerHighest: ScampiColors.darkSurfaceVariant,
      outline: ScampiColors.darkBorder,
    );

    final textTheme = ScampiTypography.textTheme(
      ScampiColors.darkOnBackground,
      ScampiColors.darkOnSurfaceMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ScampiColors.darkBackground,
      textTheme: textTheme,
      fontFamily: textTheme.bodyMedium?.fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: ScampiColors.darkBackground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ScampiColors.darkOnBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: ScampiColors.darkSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: ScampiRadius.lgBorder,
          side: const BorderSide(color: ScampiColors.darkBorder, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ScampiColors.darkBackground,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ScampiColors.mintSoft.withValues(alpha: 0.18),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected
                ? ScampiColors.darkOnBackground
                : ScampiColors.darkOnSurfaceMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ScampiColors.mintSoft,
          foregroundColor: const Color(0xFF06291C),
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: ScampiSpacing.lg,
            vertical: ScampiSpacing.md,
          ),
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(borderRadius: ScampiRadius.pillBorder),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ScampiColors.darkOnBackground,
          side: const BorderSide(color: ScampiColors.darkBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: ScampiSpacing.lg,
            vertical: ScampiSpacing.md,
          ),
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(borderRadius: ScampiRadius.pillBorder),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ScampiColors.mintSoft,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ScampiColors.darkSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ScampiSpacing.md,
          vertical: ScampiSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: ScampiRadius.mdBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ScampiRadius.mdBorder,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ScampiRadius.mdBorder,
          borderSide: const BorderSide(color: ScampiColors.mintSoft, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: ScampiColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ScampiColors.mintSoft,
        linearTrackColor: ScampiColors.darkSurfaceVariant,
      ),
    );
  }
}
