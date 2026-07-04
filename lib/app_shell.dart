import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/health/health_sync_controller.dart';
import 'core/notifications/notification_service.dart';
import 'core/update/update_provider.dart';
import 'core/update/update_screen.dart';
import 'core/update/update_service.dart';
import 'data/repositories/data_refresh_signal.dart';
import 'data/repositories/repository_providers.dart';
import 'features/home/home_screen.dart';
import 'features/food/food_screen.dart';
import 'features/fitness/fitness_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/profile/profile_screen.dart';

/// Root shell hosting the persistent bottom navigation bar and the five
/// main tabs: Home, Food, Fitness, Progress, Profile.
///
/// Uses an IndexedStack so each tab keeps its own scroll position and
/// state when switching back and forth, rather than rebuilding from
/// scratch every time.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  AppTab _currentTab = AppTab.home;

  /// Skips a resume-triggered sync if the last attempt (of any kind) was
  /// more recent than this — Health Connect data doesn't change fast
  /// enough to need re-checking on every single tab-away-and-back.
  static const _resumeSyncMinGap = Duration(minutes: 10);
  DateTime? _lastHealthSyncAttempt;

  static const _screens = [
    HomeScreen(),
    FoodScreen(),
    FitnessScreen(),
    ProgressScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Sets up the notification channel(s) so they exist before anything
    // tries to schedule through them (e.g. starting a fast). Doesn't
    // request the runtime permission here — that's asked for lazily, at
    // the point a notification is actually about to be scheduled.
    NotificationService.instance.init();
    // Best-effort, silent startup check — no dialog/error surfaced if
    // this fails (no internet, GitHub down, etc.) since a background
    // update check should never be the thing that interrupts opening
    // the app. Only acts if an update is actually available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _silentCheckForUpdate());
    WidgetsBinding.instance.addPostFrameCallback((_) => _silentHealthSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final last = _lastHealthSyncAttempt;
      if (last == null || DateTime.now().difference(last) >= _resumeSyncMinGap) {
        _silentHealthSync();
      }
    }
  }

  /// Best-effort, silent Health Connect sync — runs on cold start and on
  /// every resume (debounced, see [_resumeSyncMinGap]) so data pulled in
  /// later in the day (or after granting permission in Health Connect
  /// itself) shows up without needing a full app relaunch. Only runs if
  /// the user opted in via Profile settings. Failures are recorded via
  /// [performHealthSync] (visible in Profile) but never surfaced here —
  /// a background sync should never interrupt using the app.
  Future<void> _silentHealthSync() async {
    _lastHealthSyncAttempt = DateTime.now();
    try {
      final enabled = ref.read(healthSyncEnabledProvider);
      if (!enabled) return;
      final profile = await ref.read(userProfileRepositoryProvider).getProfile();
      if (profile == null) return;
      await performHealthSync(ref, bodyWeightKg: profile.weightKg);
      if (mounted) ref.read(dataRefreshSignalProvider.notifier).bump();
    } catch (_) {
      // Already recorded by performHealthSync — just don't let it
      // propagate into an interrupting error here.
    }
  }

  Future<void> _silentCheckForUpdate() async {
    try {
      final result = await ref.read(updateServiceProvider).checkForUpdate();
      if (!mounted || !result.updateAvailable) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Update Available'),
          content: Text(
            'Scampi ${result.remote.latestVersion} is available '
            '(you have ${result.currentVersion}).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UpdateScreen()),
                );
              },
              child: const Text('View'),
            ),
          ],
        ),
      );
    } on UpdateCheckException {
      // Silent — a failed background check just means try again later
      // (manually, via Profile → Updates, or on the next app launch).
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab.index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab.index,
        onDestinationSelected: (index) {
          setState(() => _currentTab = AppTab.values[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant_rounded),
            label: 'Food',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center_rounded),
            label: 'Fitness',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart_rounded),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
