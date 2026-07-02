import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/notifications/notification_service.dart';
import 'core/update/update_provider.dart';
import 'core/update/update_screen.dart';
import 'core/update/update_service.dart';
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

class _AppShellState extends ConsumerState<AppShell> {
  AppTab _currentTab = AppTab.home;

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
