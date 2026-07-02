import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/water_weight_log.dart';
import '../../data/models/sleep_log_entry.dart';
import 'progress_summary_provider.dart';

/// Progress tab — weekly calorie chart up top (the main one), weight trend
/// below, and a placeholder for sleep tracking (not built yet).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(progressSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: SafeArea(
        child: summaryAsync.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('$err')),
          data: (summary) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _WeeklyCalorieCard(summary: summary),
              const SizedBox(height: ScampiSpacing.md),
              _WeightTrendCard(history: summary.weightHistory),
              const SizedBox(height: ScampiSpacing.md),
              _SleepTrendCard(history: summary.sleepHistory),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyCalorieCard extends StatelessWidget {
  const _WeeklyCalorieCard({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = summary.weeklyCalories;
    final maxConsumed = days.map((d) => d.consumed).fold<double>(0, (a, b) => a > b ? a : b);
    final chartMax = [maxConsumed, summary.calorieGoal.toDouble()].reduce((a, b) => a > b ? a : b) * 1.15;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ScampiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Week', style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              'Calories eaten each day vs your ${summary.calorieGoal} kcal goal',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: ScampiSpacing.md),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: chartMax <= 0 ? 2000 : chartMax,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= days.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _weekdayLabel(days[index].day),
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: summary.calorieGoal.toDouble(),
                        color: theme.colorScheme.outline,
                        strokeWidth: 1,
                        dashArray: [6, 4],
                      ),
                    ],
                  ),
                  barGroups: [
                    for (var i = 0; i < days.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: days[i].consumed,
                            width: 20,
                            borderRadius: BorderRadius.circular(6),
                            color: days[i].consumed > days[i].goal
                                ? ScampiColors.orange
                                : theme.colorScheme.primary,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekdayLabel(DateTime day) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[day.weekday - 1];
  }
}

enum _WeightTimeframe {
  oneMonth(30, '1M'),
  sixMonths(183, '6M');

  const _WeightTimeframe(this.days, this.label);
  final int days;
  final String label;
}

class _WeightTrendCard extends StatefulWidget {
  const _WeightTrendCard({required this.history});

  final List<WeightLogEntry> history;

  @override
  State<_WeightTrendCard> createState() => _WeightTrendCardState();
}

class _WeightTrendCardState extends State<_WeightTrendCard> {
  _WeightTimeframe _timeframe = _WeightTimeframe.oneMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final windowStart = DateTime.now().subtract(Duration(days: _timeframe.days));
    final filtered = widget.history.where((e) => e.loggedAt.isAfter(windowStart)).toList()
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ScampiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Weight', style: theme.textTheme.titleMedium),
                _TimeframeToggle(
                  selected: _timeframe,
                  onChanged: (t) => setState(() => _timeframe = t),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              filtered.length < 2
                  ? 'Log at least two weigh-ins to see a trend line here.'
                  : '${filtered.length} check-ins in the last ${_timeframe.label == '1M' ? 'month' : '6 months'}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: ScampiSpacing.md),
            if (filtered.length < 2)
              const SizedBox(height: 140)
            else
              SizedBox(
                height: 200,
                child: _WeightLineChart(entries: filtered, windowDays: _timeframe.days),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimeframeToggle extends StatelessWidget {
  const _TimeframeToggle({required this.selected, required this.onChanged});

  final _WeightTimeframe selected;
  final ValueChanged<_WeightTimeframe> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: ScampiRadius.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in _WeightTimeframe.values)
            _TimeframeChip(
              label: t.label,
              selected: t == selected,
              onTap: () => onChanged(t),
            ),
        ],
      ),
    );
  }
}

class _TimeframeChip extends StatelessWidget {
  const _TimeframeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primary : Colors.transparent,
      borderRadius: ScampiRadius.pillBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: ScampiRadius.pillBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeightLineChart extends StatelessWidget {
  const _WeightLineChart({required this.entries, required this.windowDays});

  final List<WeightLogEntry> entries;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final windowStart = DateTime.now().subtract(Duration(days: windowDays));

    double xFor(DateTime d) => d.difference(windowStart).inHours / 24.0;

    final points = [
      for (final e in entries) FlSpot(xFor(e.loggedAt), e.weightKg),
    ];
    final rawMinY = points.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    final rawMaxY = points.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    // Rounds the axis out to whole kg and picks a whole-kg tick interval
    // (at least 1kg) — weights logged close together (e.g. three
    // check-ins within a kg of each other) would otherwise produce a
    // sub-1 interval, causing adjacent labels to round to the same
    // integer and visually overlap.
    final minY = (rawMinY - 1).floorToDouble();
    final maxY = (rawMaxY + 1).ceilToDouble();
    final interval = ((maxY - minY) / 3).clamp(1.0, double.infinity).roundToDouble();
    final maxX = windowDays.toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} kg',
                      theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onInverseSurface),
                    ))
                .toList(),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: maxX / 4,
              getTitlesWidget: (value, meta) {
                final date = windowStart.add(Duration(hours: (value * 24).round()));
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('MMM d').format(date),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3.5,
                color: theme.colorScheme.primary,
                strokeWidth: 2,
                strokeColor: theme.colorScheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Last 7 days of sleep as a bar chart — days with no manual entry show
/// as an empty (zero-height) bar rather than being skipped, so the week
/// stays visually complete and gaps are obvious.
/// Commonly recommended nightly sleep for adults — shown as a dashed
/// reference line on the chart, the same way the weekly calorie chart
/// shows a dashed line at the calorie goal.
const double _recommendedSleepHours = 8.0;

const Color _sleepChartColor = Color(0xFFA98CE0);

class _SleepTrendCard extends StatelessWidget {
  const _SleepTrendCard({required this.history});

  final List<SleepLogEntry> history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final weekStart = todayStart.subtract(const Duration(days: 6));

    final byDate = {
      for (final e in history) DateTime(e.date.year, e.date.month, e.date.day): e,
    };
    final days = [
      for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i)),
    ];
    final hasAnyEntry = byDate.isNotEmpty;
    final maxHours = days
        .map((d) => byDate[d]?.hours ?? 0)
        .fold<double>(_recommendedSleepHours, (a, b) => a > b ? a : b);
    // Rounded up to the next even hour (rather than a plain 1.15x
    // padding) so the chart's top edge lands exactly on an interval-2
    // gridline — otherwise fl_chart draws its own axis-max label there
    // too, which duplicated the topmost hour label (e.g. "10h" twice).
    const sleepAxisInterval = 2.0;
    final chartMax = (maxHours / sleepAxisInterval).ceil() * sleepAxisInterval + sleepAxisInterval;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ScampiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep', style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              hasAnyEntry
                  ? 'Hours slept each night vs a recommended ${_recommendedSleepHours.toStringAsFixed(0)}h'
                  : 'Log sleep from Home to see your week here.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: ScampiSpacing.md),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: chartMax,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 2,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}h',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= days.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _weekdayLabel(days[index]),
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: _recommendedSleepHours,
                        color: theme.colorScheme.outline,
                        strokeWidth: 1,
                        dashArray: [6, 4],
                      ),
                    ],
                  ),
                  barGroups: [
                    for (var i = 0; i < days.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: byDate[days[i]]?.hours ?? 0,
                            width: 20,
                            borderRadius: BorderRadius.circular(6),
                            color: _sleepChartColor,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekdayLabel(DateTime day) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[day.weekday - 1];
  }
}
