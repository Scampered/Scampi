import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'onboarding_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Must be called before runApp — sets up the port the live Workout
  // Session's background isolate uses to talk back to the main isolate.
  // The rest of flutter_foreground_task's setup (notification channel,
  // permissions) happens lazily when a session is actually started, in
  // WorkoutSessionController, consistent with how NotificationService
  // asks for its permission lazily too.
  FlutterForegroundTask.initCommunicationPort();
  runApp(const ProviderScope(child: ScampiApp()));
}

class ScampiApp extends ConsumerWidget {
  const ScampiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ScampiTheme.light,
      darkTheme: ScampiTheme.dark,
      themeMode: themeMode,
      home: const OnboardingGate(),
    );
  }
}
