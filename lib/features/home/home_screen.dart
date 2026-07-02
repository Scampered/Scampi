import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../data/models/water_weight_log.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';
import '../fasting/active_fast_sheet.dart';
import '../fasting/start_fast_sheet.dart';
import '../fitness/fitness_screen.dart';
import '../food/ai_import/ai_meal_import_screen.dart';
import '../food/food_screen.dart';
import 'dismissed_warning_controller.dart';
import 'home_summary_provider.dart';
import 'widgets/calorie_ring.dart';
import 'widgets/macro_bar.dart';
import 'widgets/summary_tile.dart';
import 'widgets/quick_action_button.dart';
import 'widgets/home_skeleton.dart';
import 'widgets/sleep_log_sheet.dart';
import 'widgets/water_log_sheet.dart';

/// Home tab — the daily dashboard. Backed by [homeSummaryProvider],
/// which aggregates the profile, today's food log, exercise log, water
/// log, and any active fast from SQLite.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(homeSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/scampi_logo.png',
              width: 36,
              height: 36,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.set_meal_rounded, size: 28),
            ),
            const SizedBox(width: 8),
            const Text('Scampi'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        // skipLoadingOnReload keeps the previous data on screen while a
        // background refetch happens (e.g. after logging water) instead
        // of flashing back to a loading state — the AsyncValue still
        // updates once the new data arrives, it just doesn't blank the
        // screen in between. Only a genuine first load (no previous
        // data at all) falls through to the skeleton.
        child: summaryAsync.when(
          skipLoadingOnReload: true,
          loading: () => const HomeSkeleton(),
          error: (err, stack) => _ErrorState(message: '$err'),
          data: (summary) => _HomeContent(summary: summary),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 40),
            const SizedBox(height: 12),
            Text(
              "Couldn't load your daily summary.",
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(message, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.summary});

  final HomeDailySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final calc = summary.calculation;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _GreetingHeader(name: summary.userName),
        const SizedBox(height: 20),
        Center(
          child: CalorieRing(
            consumed: summary.netCalories,
            goal: summary.calorieGoal,
            remaining: summary.caloriesRemaining,
            waterFraction:
                summary.waterGoalMl == 0 ? 0 : summary.waterMl / summary.waterGoalMl,
            waterLiters: summary.waterMl / 1000,
            sleepHours: summary.sleepHours,
            showSleepStat: summary.sleepTrackingActive,
            onTapSleep: () => _openSleepSheet(context, summary),
          ),
        ),
        const SizedBox(height: 12),
        _CalorieBreakdownRow(summary: summary),
        if (calc != null && calc.warnings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Builder(builder: (context) {
            final dismissedGoal = ref.watch(dismissedWarningGoalProvider);
            if (dismissedGoal == summary.calorieGoal) return const SizedBox.shrink();
            return Column(
              children: [
                for (final w in calc.warnings)
                  _HealthWarningCard(
                    warning: w,
                    onDismiss: () => ref
                        .read(dismissedWarningGoalProvider.notifier)
                        .dismissForGoal(summary.calorieGoal),
                  ),
              ],
            );
          }),
        ],
        const SizedBox(height: 20),
        Divider(color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Macros', style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                MacroBar(
                  label: 'Protein',
                  current: summary.proteinConsumedG,
                  goal: calc?.proteinGoalG ?? 1,
                  color: ScampiColors.macroProtein,
                ),
                const SizedBox(height: 14),
                MacroBar(
                  label: 'Carbohydrates',
                  current: summary.carbsConsumedG,
                  goal: calc?.carbsGoalG ?? 1,
                  color: ScampiColors.macroCarbs,
                ),
                const SizedBox(height: 14),
                MacroBar(
                  label: 'Fat',
                  current: summary.fatConsumedG,
                  goal: calc?.fatGoalG ?? 1,
                  color: ScampiColors.macroFat,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Two IntrinsicHeight rows instead of a GridView — each row's
        // tiles size to their own content (via the Cards' mainAxisSize.min
        // Column) and just stretch to match whichever one in that row is
        // taller, rather than every tile being forced to the height of
        // the single tallest tile on Home (which left a lot of empty
        // space in the short Today's Fast/Burned tiles).
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _WaterTile(summary: summary)),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryTile(
                  icon: Icons.monitor_weight_rounded,
                  iconColor: theme.colorScheme.secondary,
                  label: 'Weight Goal',
                  value: summary.currentWeightKg != null
                      ? '${summary.currentWeightKg!.toStringAsFixed(1)} kg'
                      : '—',
                  subtitle: summary.goalWeightKg != null
                      ? 'goal ${summary.goalWeightKg!.toStringAsFixed(1)} kg'
                      : 'no goal set',
                  onTap: () => _updateWeight(context, ref, summary.currentWeightKg),
                  actionLabel: 'Update Weight',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SummaryTile(
                  icon: Icons.timer_outlined,
                  iconColor: theme.colorScheme.tertiary,
                  label: "Today's Fast",
                  value: summary.activeFast == null
                      ? 'Not fasting'
                      : summary.activeFast!.isMultiDay
                          ? 'Day ${summary.activeFast!.currentDayNumber}/${summary.activeFast!.totalTargetDays}'
                          : _formatDuration(summary.activeFast!.elapsed),
                  subtitle: summary.activeFast != null
                      ? summary.activeFast!.type.label
                      : null,
                  progress: summary.activeFast?.progressFraction,
                  onTap: () => _openFastSheet(context, summary),
                  actionLabel: summary.activeFast == null ? 'Start Fast' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryTile(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: ScampiColors.macroProtein,
                  label: 'Burned',
                  value: '${summary.caloriesBurned.round()} kcal',
                  subtitle: 'from exercise today',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Quick Actions', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            QuickActionButton(
              icon: Icons.restaurant_rounded,
              label: 'Add Food',
              color: ScampiColors.mint,
              onTap: () => FoodScreen.openSearch(context),
            ),
            const SizedBox(width: 10),
            QuickActionButton(
              icon: Icons.directions_run_rounded,
              label: 'Add Exercise',
              color: ScampiColors.blue,
              onTap: () => FitnessScreen.openLogSheet(context),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            QuickActionButton(
              icon: Icons.water_drop_rounded,
              label: 'Add Water',
              color: ScampiColors.macroWater,
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const WaterLogSheet(),
              ),
            ),
            const SizedBox(width: 10),
            QuickActionButton(
              icon: Icons.smart_toy_rounded,
              label: 'AI Meal Import',
              color: ScampiColors.orange,
              onTap: () => Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const AiMealImportScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            QuickActionButton(
              icon: Icons.bedtime_rounded,
              label: summary.todaySleepEntry != null ? 'Edit Sleep' : 'Log Sleep',
              color: ScampiColors.blue,
              onTap: () => _openSleepSheet(context, summary),
            ),
            const SizedBox(width: 10),
            QuickActionButton(
              icon: Icons.timer_outlined,
              label: summary.activeFast != null ? 'View Fast' : 'Start Fast',
              color: ScampiColors.orange,
              onTap: () => _openFastSheet(context, summary),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _DailyTipCard(
          tip: 'Protein at every meal helps keep you fuller for longer — '
              'try adding a source like eggs, yogurt, or lentils to your '
              'next meal.',
        ),
      ],
    );
  }

  Future<void> _updateWeight(BuildContext context, WidgetRef ref, double? currentWeightKg) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UpdateWeightSheet(currentWeightKg: currentWeightKg),
    );
  }

  Future<void> _openSleepSheet(BuildContext context, HomeDailySummary summary) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SleepLogSheet(existing: summary.todaySleepEntry),
    );
  }

  Future<void> _openFastSheet(BuildContext context, HomeDailySummary summary) async {
    final activeFast = summary.activeFast;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => activeFast != null
          ? ActiveFastSheet(session: activeFast)
          : const StartFastSheet(),
    );
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      greeting = 'Good evening';
    } else {
      greeting = 'Still up?';
    }

    final text = name.isNotEmpty ? '$greeting, $name 👋' : '$greeting 👋';

    return Text(text, style: theme.textTheme.headlineSmall);
  }
}

class _CalorieBreakdownRow extends StatelessWidget {
  const _CalorieBreakdownRow({required this.summary});

  final HomeDailySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget stat(String label, String value) {
      return Column(
        children: [
          Text(value, style: theme.textTheme.titleMedium),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        stat('Goal', '${summary.calorieGoal}'),
        stat('Eaten', '${summary.caloriesConsumed.round()}'),
        stat('Burned', '${summary.caloriesBurned.round()}'),
        stat('Net', '${summary.netCalories}'),
      ],
    );
  }
}

class _HealthWarningCard extends StatelessWidget {
  const _HealthWarningCard({required this.warning, required this.onDismiss});

  final HealthWarning warning;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSerious = warning.severity == HealthWarningSeverity.serious;
    final color = isSerious ? theme.colorScheme.error : ScampiColors.orange;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        color: color.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(warning.message, style: theme.textTheme.bodySmall),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, color: color, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyTipCard extends StatelessWidget {
  const _DailyTipCard({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Tip', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(tip, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every droplet in [_WaterDroplets] represents this fraction of the
/// daily goal — 5 droplets span the goal exactly (so a half-filled
/// droplet is one tenth of the goal, e.g. 250ml of a 2.5L goal).
const int _dropletsPerGoal = 5;

/// Drinking past the goal keeps filling more droplets, but the row never
/// grows past this many — represents double the goal.
const int _maxDroplets = 10;

/// Water tile — like [SummaryTile] but shows progress as a row of
/// droplets (each one representing a fifth of the goal, filling
/// smoothly as ml are logged) plus one quick-add chip, so a common
/// amount can be logged without leaving Home. Tapping the tile body
/// opens [WaterLogSheet] for a custom amount or to remove a mistaken
/// entry.
class _WaterTile extends ConsumerWidget {
  const _WaterTile({required this.summary});

  final HomeDailySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const WaterLogSheet(),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ScampiColors.macroWater.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: ScampiColors.macroWater,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Water',
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${(summary.waterMl / 1000).toStringAsFixed(1)} L',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              Text(
                'of ${(summary.waterGoalMl / 1000).toStringAsFixed(1)} L goal',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              _WaterDroplets(waterMl: summary.waterMl, goalMl: summary.waterGoalMl),
              const SizedBox(height: 8),
              _WaterChip(label: '+250ml', onTap: () => _quickAdd(ref, 250)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickAdd(WidgetRef ref, int amountMl) async {
    await ref.read(waterLogRepositoryProvider).logEntry(
          WaterLogEntry(loggedAt: DateTime.now(), amountMl: amountMl),
        );
    ref.read(dataRefreshSignalProvider.notifier).bump();
  }
}

/// Row of droplet icons, each smoothly filling in as water is logged.
/// [_dropletsPerGoal] droplets span the goal; drinking past the goal
/// fills more droplets up to [_maxDroplets], after which extra water
/// just doesn't add more (the row caps out full).
class _WaterDroplets extends StatelessWidget {
  const _WaterDroplets({required this.waterMl, required this.goalMl});

  final int waterMl;
  final int goalMl;

  @override
  Widget build(BuildContext context) {
    final perDroplet = goalMl > 0 ? goalMl / _dropletsPerGoal : 500.0;
    final dropletsToShow = waterMl <= 0
        ? _dropletsPerGoal
        : (waterMl / perDroplet).ceil().clamp(_dropletsPerGoal, _maxDroplets);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < dropletsToShow; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          _Droplet(fraction: ((waterMl - i * perDroplet) / perDroplet).clamp(0.0, 1.0)),
        ],
      ],
    );
  }
}

class _Droplet extends StatelessWidget {
  const _Droplet({required this.fraction});

  final double fraction;

  static const double _size = 15;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: fraction),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          children: [
            const Icon(
              Icons.water_drop_outlined,
              size: _size,
              color: ScampiColors.macroWater,
            ),
            ClipRect(
              clipper: _BottomFractionClipper(value),
              child: const Icon(
                Icons.water_drop_rounded,
                size: _size,
                color: ScampiColors.macroWater,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clips to the bottom [fraction] of the child — used to fill a droplet
/// icon from the bottom up as water is logged, like a liquid level.
class _BottomFractionClipper extends CustomClipper<Rect> {
  const _BottomFractionClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) {
    final top = size.height * (1 - fraction);
    return Rect.fromLTRB(0, top, size.width, size.height);
  }

  @override
  bool shouldReclip(covariant _BottomFractionClipper oldClipper) {
    return oldClipper.fraction != fraction;
  }
}

class _WaterChip extends StatelessWidget {
  const _WaterChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ScampiColors.macroWater.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: ScampiColors.macroWater),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for logging a new weigh-in from the Home "Weight Goal"
/// tile, rather than only being able to see weight via Progress.
class _UpdateWeightSheet extends ConsumerStatefulWidget {
  const _UpdateWeightSheet({required this.currentWeightKg});

  final double? currentWeightKg;

  @override
  ConsumerState<_UpdateWeightSheet> createState() => _UpdateWeightSheetState();
}

class _UpdateWeightSheetState extends ConsumerState<_UpdateWeightSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentWeightKg != null ? widget.currentWeightKg!.toStringAsFixed(1) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final weightKg = double.tryParse(_controller.text);
    if (weightKg == null || weightKg <= 0 || _saving) return;
    setState(() => _saving = true);

    await ref.read(weightLogRepositoryProvider).logEntry(
          WeightLogEntry(loggedAt: DateTime.now(), weightKg: weightKg),
        );
    ref.read(dataRefreshSignalProvider.notifier).bump();

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update Weight', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              "Day-to-day swings are usually water weight, not fat — food, "
              "sodium, hydration, and hormones can shift the scale a kg or "
              "more overnight. Don't worry about single-day changes; the "
              'trend over a couple of weeks is what matters.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (double.tryParse(_controller.text) ?? 0) > 0 && !_saving
                    ? _save
                    : null,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
