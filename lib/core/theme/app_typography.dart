import 'package:flutter/material.dart';

/// Typography tokens. Uses Dosis (bundled locally in assets/fonts, see
/// pubspec.yaml) for a rounded, friendly, modern feel consistent with
/// Duolingo/Yazio-style apps.
///
/// Previously loaded via the `google_fonts` package, which fetches the
/// font over the network on first use and caches it — a problem for an
/// offline-first app, since a device with no connectivity on first run
/// (or ever) silently fell back to the system font. Bundling the actual
/// Dosis[wght].ttf as an asset and referencing `fontFamily: 'Dosis'`
/// directly guarantees the real font (and its real bold weight) always
/// renders, online or not.
class ScampiTypography {
  ScampiTypography._();

  static const String fontFamily = 'Dosis';

  // Every size is nudged up from Material's defaults and every weight is
  // pushed toward Dosis's bolder end — small print (labelSmall/bodySmall)
  // was reading as thin, near-illegible gray text at default sizes, and
  // headings (app name, tab titles, "Food"/"Fitness" etc.) looked
  // underweight for a heading. Headline* sizes are also bumped explicitly
  // now (not just weight) so a screen's AppBar title reads unmistakably
  // bigger than the body content below it.
  static TextTheme textTheme(Color onBackground, Color onSurfaceMuted) {
    TextStyle style(double size, FontWeight weight, Color color, {double? letterSpacing}) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );
    }

    return TextTheme(
      displayLarge: style(59, FontWeight.w800, onBackground, letterSpacing: -0.5),
      displayMedium: style(47, FontWeight.w800, onBackground),
      displaySmall: style(38, FontWeight.w800, onBackground),
      headlineLarge: style(34, FontWeight.w800, onBackground),
      headlineMedium: style(30, FontWeight.w800, onBackground),
      headlineSmall: style(28, FontWeight.w800, onBackground),
      titleLarge: style(24, FontWeight.w800, onBackground),
      titleMedium: style(18, FontWeight.w700, onBackground),
      titleSmall: style(15, FontWeight.w700, onBackground),
      bodyLarge: style(17, FontWeight.w500, onBackground),
      bodyMedium: style(15, FontWeight.w600, onBackground),
      bodySmall: style(13.5, FontWeight.w600, onSurfaceMuted),
      labelLarge: style(15, FontWeight.w700, onBackground),
      labelMedium: style(13.5, FontWeight.w700, onSurfaceMuted),
      labelSmall: style(12.5, FontWeight.w700, onSurfaceMuted),
    );
  }
}

/// Spacing scale used throughout the app for consistent, clean spacing.
class ScampiSpacing {
  ScampiSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radius scale — soft, rounded corners throughout.
class ScampiRadius {
  ScampiRadius._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;

  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
  static BorderRadius get xlBorder => BorderRadius.circular(xl);
  static BorderRadius get pillBorder => BorderRadius.circular(pill);
}

/// Standard animation durations/curves for smooth, consistent motion.
class ScampiMotion {
  ScampiMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve bouncy = Curves.easeOutBack;
}
