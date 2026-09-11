import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/day_boundary.dart';
import 'exercise_details_provider.dart';

/// "Exercise Details" card — today's steps/distance/active calories plus
/// an hourly step bar (from the reset time), styled after Samsung
/// Health's own daily activity screen. Steps only for now; more metrics
/// (active time, per-hour distance/calories) can slot into the same
/// layout later.
class ExerciseDetailsCard extends ConsumerWidget {
  const ExerciseDetailsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final detailsAsync = ref.watch(exerciseDetailsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ScampiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exercise Details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              "Today's activity from Health Connect",
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: ScampiSpacing.md),
            detailsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SizedBox(
                height: 80,
                child: Center(
                    child: Text('$err', style: theme.textTheme.bodySmall)),
              ),
              data: (details) {
                if (details == null) {
                  return _DisabledPrompt(theme: theme);
                }
                return _ExerciseDetailsBody(details: details);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DisabledPrompt extends StatelessWidget {
  const _DisabledPrompt({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ScampiSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.watch_later_outlined, color: theme.colorScheme.outline),
          const SizedBox(width: ScampiSpacing.sm),
          Expanded(
            child: Text(
              'Turn on the Health App Connector in Profile to see steps, '
              'distance, and active calories here.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseDetailsBody extends StatelessWidget {
  const _ExerciseDetailsBody({required this.details});

  final ExerciseDetailsSummary details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBlock(
                label: 'Steps',
                value: NumberFormat.decimalPattern().format(details.steps),
                color: ScampiColors.macroCarbs,
              ),
            ),
            Expanded(
              child: _StatBlock(
                label: 'Distance',
                value: '${details.distanceKm.toStringAsFixed(2)} km',
                color: ScampiColors.blue,
              ),
            ),
            Expanded(
              child: _StatBlock(
                label: 'Active kcal',
                value: details.activeCalories.round().toString(),
                color: ScampiColors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: ScampiSpacing.md),
        Text(
          details.mostActivePeriodLabel != null
              ? 'Most active period: ${details.mostActivePeriodLabel}'
              : 'No steps recorded yet today',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: ScampiSpacing.sm),
        SizedBox(
          height: 130,
          child: _HourlyStepsChart(details: details),
        ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _HourlyStepsChart extends StatelessWidget {
  const _HourlyStepsChart({required this.details});

  final ExerciseDetailsSummary details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = details.hourlySteps;
    final maxSteps = buckets.fold<int>(0, (a, b) => a > b ? a : b);
    final chartMax = maxSteps <= 0 ? 10.0 : maxSteps * 1.2;
    final windowStart =
        dayWindowFor(DateTime.now(), details.resetMinuteOfDay).start;

    return BarChart(
      BarChartData(
        maxY: chartMax,
        alignment: BarChartAlignment.spaceBetween,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final hourLabel = DateFormat('h a')
                  .format(windowStart.add(Duration(hours: group.x)));
              return BarTooltipItem(
                '$hourLabel\n${rod.toY.round()} steps',
                TextStyle(
                    color: rod.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              // fl_chart's bar-chart title builder calls this once per
              // bar (i.e. all 24 hours) regardless of `interval` —
              // `interval` is only honored for line/scatter charts, not
              // bar charts (see AxisSideTitleWidgetsBuilder.makeWidgets).
              // Filtering by index here is the only way to avoid every
              // single hour label rendering shoulder-to-shoulder.
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= buckets.length || index % 6 != 0) {
                  return const SizedBox.shrink();
                }
                final label =
                    DateFormat('h a').format(windowStart.add(Duration(hours: index)));
                // fitInside clamps the label to stay within the chart's
                // own bounding box — without it, a label near the right
                // edge (e.g. "6 PM") is centered on its axis position but
                // not constrained, so its own text width pushes it past
                // the card's edge instead of being nudged back inside.
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(label, style: theme.textTheme.labelSmall),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buckets[i].toDouble(),
                  width: 5,
                  borderRadius: BorderRadius.circular(2),
                  color: ScampiColors.macroCarbs,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
