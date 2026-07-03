/// Static app-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Scampi';

  // SQLite
  static const String databaseName = 'scampi.db';
  static const int databaseVersion = 7;

  // Shared preferences keys (non-theme; theme key lives in
  // theme_mode_controller.dart to keep that concern self-contained)
  static const String prefsOnboardingComplete = 'scampi_onboarding_complete';
  static const String prefsUnitsSystem = 'scampi_units_system'; // metric/imperial
}

/// Bottom navigation tab indices, kept in one place so screens and the
/// shell stay in sync without magic numbers scattered around.
enum AppTab { home, food, fitness, progress, profile }
