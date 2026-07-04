import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../core/update/update_provider.dart';
import '../../core/update/update_screen.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../core/health/health_service.dart';
import '../../core/health/health_sync_controller.dart';
import '../../data/db/app_database.dart';
import '../onboarding/onboarding_screen.dart';
import '../../data/repositories/data_refresh_signal.dart';
import '../../data/repositories/repository_providers.dart';
import 'current_profile_provider.dart';

/// Profile tab: appearance (theme) settings, and the user's saved
/// profile with calculated BMR/maintenance calories, plus an edit link
/// that reuses [OnboardingScreen] pre-filled with the existing profile.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Appearance',
            child: Column(
              children: [
                _ThemeOptionTile(
                  label: 'Follow System',
                  icon: Icons.brightness_auto_rounded,
                  selected: currentMode == ThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.system),
                ),
                _ThemeOptionTile(
                  label: 'Light Mode',
                  icon: Icons.light_mode_rounded,
                  selected: currentMode == ThemeMode.light,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.light),
                ),
                _ThemeOptionTile(
                  label: 'Dark Mode',
                  icon: Icons.dark_mode_rounded,
                  selected: currentMode == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          profileAsync.when(
            loading: () => const _SectionCard(
              title: 'Your Profile',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => _SectionCard(
              title: 'Your Profile',
              child: Text("Couldn't load your profile: $err"),
            ),
            data: (profile) {
              if (profile == null) {
                return const _SectionCard(
                  title: 'Your Profile',
                  child: Text('No profile saved yet.'),
                );
              }

              final calc = CalorieCalculator.calculate(profile);

              return _SectionCard(
                title: 'Your Profile',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profile.name.isNotEmpty)
                      _ProfileStatRow(label: 'Name', value: profile.name),
                    _ProfileStatRow(label: 'Age', value: '${profile.age}'),
                    _ProfileStatRow(
                      label: 'Height',
                      value: '${profile.heightCm.toStringAsFixed(0)} cm',
                    ),
                    _ProfileStatRow(
                      label: 'Weight',
                      value: '${profile.weightKg.toStringAsFixed(1)} kg',
                    ),
                    _ProfileStatRow(
                      label: 'Goal Weight',
                      value: profile.goalWeightKg != null
                          ? '${profile.goalWeightKg!.toStringAsFixed(1)} kg'
                          : 'Not set',
                    ),
                    _ProfileStatRow(
                      label: 'Activity Level',
                      value: profile.activityLevel.label,
                    ),
                    _ProfileStatRow(label: 'Goal', value: profile.goalMode.label),
                    const Divider(height: 24),
                    _ProfileStatRow(
                      label: 'BMR',
                      value: '${calc.bmr.round()} kcal',
                    ),
                    _ProfileStatRow(
                      label: 'Maintenance Calories',
                      value: '${calc.maintenanceCalories.round()} kcal',
                    ),
                    _ProfileStatRow(
                      label: 'Daily Calorie Goal',
                      value: '${calc.dailyCalorieGoal.round()} kcal',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit Profile'),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OnboardingScreen(
                                existingProfile: profile,
                                onComplete: () {
                                  ref
                                      .read(dataRefreshSignalProvider.notifier)
                                      .bump();
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const _HealthSyncSection(),
          const SizedBox(height: 16),
          const _DailyResetSection(),
          const SizedBox(height: 16),
          const _UpdatesSection(),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Advanced',
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Reset All Data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
                onPressed: () => _confirmReset(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'This permanently deletes your profile, food log, exercise log, '
          'water and weight history, and fasting sessions. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppDatabase.instance.resetAllData();
      // Bumping the signal is what makes OnboardingGate notice the
      // profile is gone and swap back to onboarding automatically.
      ref.read(dataRefreshSignalProvider.notifier).bump();
    }
  }
}

/// "Health App Connector" section: opt-in sync of steps and sleep from
/// Android Health Connect — the on-device hub that Google Fit, Samsung
/// Health, and most wearable apps already write into, so this covers
/// "any health app" without a per-vendor integration. Turning it on
/// requests Health Connect's own data permissions plus the Activity
/// Recognition runtime permission (needed for step counts), then syncs
/// immediately; after that it re-syncs once per app open.
class _HealthSyncSection extends ConsumerStatefulWidget {
  const _HealthSyncSection();

  @override
  ConsumerState<_HealthSyncSection> createState() => _HealthSyncSectionState();
}

class _HealthSyncSectionState extends ConsumerState<_HealthSyncSection> {
  bool _connecting = false;
  String? _error;

  Future<void> _toggle(bool value) async {
    if (!value) {
      await ref.read(healthSyncEnabledProvider.notifier).setEnabled(false);
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final granted = await HealthService.instance.requestPermissions();
      if (!granted) {
        setState(() => _error =
            "Permission wasn't granted. Make sure Health Connect is installed and try again.");
        return;
      }
      await ref.read(healthSyncEnabledProvider.notifier).setEnabled(true);
      await _syncNow();
    } catch (e) {
      setState(() => _error = "Couldn't connect to Health Connect. Is it installed?");
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final profile = await ref.read(userProfileRepositoryProvider).getProfile();
      if (profile == null) return;
      await performHealthSync(ref, bodyWeightKg: profile.weightKg);
      ref.read(dataRefreshSignalProvider.notifier).bump();
    } catch (e) {
      // performHealthSync already recorded this in healthSyncStatusProvider
      // (shown below), so no need to duplicate it into _error here.
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = ref.watch(healthSyncEnabledProvider);
    final status = ref.watch(healthSyncStatusProvider);
    return _SectionCard(
      title: 'Health App Connector',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sync steps and sleep from Google Fit, Samsung Health, or any '
            'other app that writes to Android Health Connect. Steps show up '
            'as an auto-logged Walking entry; sleep fills in automatically '
            "if you haven't already logged it that day. If another app shows "
            "a different sleep number, that's its own separate estimate — "
            "this reads exactly what's stored in Health Connect, nothing else.",
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Connect Health App', style: theme.textTheme.titleSmall),
              ),
              if (_connecting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(value: enabled, onChanged: _toggle),
            ],
          ),
          if (enabled && !_connecting) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    status.lastSyncedAt != null
                        ? 'Last synced ${_relativeTime(status.lastSyncedAt!)}'
                        : 'Not synced yet',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: _syncNow,
                  child: const Text('Sync Now'),
                ),
              ],
            ),
            if (status.lastError != null)
              Text(
                'Last sync failed: ${status.lastError}',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// "Daily Reset Time" section: lets the user pick which hour "today"
/// rolls over at for calorie/water/exercise/sleep tracking — defaults to
/// midnight, but a late sleeper (or early-morning person) can shift it
/// so a post-midnight snack doesn't get counted as tomorrow's food.
class _DailyResetSection extends ConsumerStatefulWidget {
  const _DailyResetSection();

  @override
  ConsumerState<_DailyResetSection> createState() => _DailyResetSectionState();
}

class _DailyResetSectionState extends ConsumerState<_DailyResetSection> {
  int? _resetMinuteOfDay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final minuteOfDay =
        await ref.read(userProfileRepositoryProvider).getCalorieResetMinuteOfDay();
    if (!mounted) return;
    setState(() => _resetMinuteOfDay = minuteOfDay);
  }

  Future<void> _pickTime() async {
    final current = _resetMinuteOfDay ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked == null || !mounted) return;
    final minuteOfDay = picked.hour * 60 + picked.minute;
    await ref.read(userProfileRepositoryProvider).setCalorieResetMinuteOfDay(minuteOfDay);
    ref.read(dataRefreshSignalProvider.notifier).bump();
    setState(() => _resetMinuteOfDay = minuteOfDay);
  }

  static String _formatMinuteOfDay(BuildContext context, int minuteOfDay) {
    if (minuteOfDay == 0) return 'Midnight (12:00 AM)';
    if (minuteOfDay == 12 * 60) return 'Noon (12:00 PM)';
    final time = TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60);
    return time.format(context);
  }

  @override
  Widget build(BuildContext context) {
    final minuteOfDay = _resetMinuteOfDay;
    return _SectionCard(
      title: 'Daily Reset Time',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "When your calorie, water, exercise, and sleep tracking rolls over to a new day. "
            "Useful if you're up past midnight or asleep before it.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _ProfileStatRow(
            label: 'Resets at',
            value: minuteOfDay != null ? _formatMinuteOfDay(context, minuteOfDay) : '—',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.schedule_rounded),
              label: const Text('Change Reset Time'),
              onPressed: minuteOfDay == null ? null : _pickTime,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Updates" section: current installed version, when it was last
/// checked, and a manual "Check for Updates" entry point into
/// [UpdateScreen] — Scampi is sideloaded, not distributed through the
/// Play Store, so this replaces the update flow the Store would
/// otherwise provide.
class _UpdatesSection extends ConsumerStatefulWidget {
  const _UpdatesSection();

  @override
  ConsumerState<_UpdatesSection> createState() => _UpdatesSectionState();
}

class _UpdatesSectionState extends ConsumerState<_UpdatesSection> {
  String? _currentVersion;
  DateTime? _lastChecked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(updateServiceProvider);
    final version = await service.currentVersionName();
    final checked = await service.lastChecked();
    if (!mounted) return;
    setState(() {
      _currentVersion = version;
      _lastChecked = checked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Updates',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileStatRow(label: 'Current Version', value: _currentVersion ?? '—'),
          _ProfileStatRow(
            label: 'Last Checked',
            value: _lastChecked != null
                ? DateFormat('MMM d, yyyy · h:mm a').format(_lastChecked!)
                : 'Never',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.system_update_rounded),
              label: const Text('Check for Updates'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UpdateScreen()),
                );
                _load();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatRow extends StatelessWidget {
  const _ProfileStatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: theme.textTheme.bodyLarge),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}
