import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/theme/app_colors.dart';

/// A "full" night's sleep for the purposes of the sleep arc filling all
/// the way — deliberately generous (most people sleep less) so the arc
/// reads as "how much of a good night's sleep did you get" rather than
/// implying anything past this is wasted.
const double _maxSleepHoursForArc = 10.0;

/// Light purple used for the sleep arc/label — distinct from the water
/// (cyan) and calorie (mint/error) colors so all three read at a glance.
const Color _sleepColor = Color(0xFFA98CE0);

/// Large circular progress ring showing calories consumed vs daily goal,
/// e.g. "1700 / 2200 kcal". Animates smoothly when the underlying value
/// changes.
///
/// Two optional arcs sit around it:
/// - [waterFraction] draws a slimmer arc just inside the main ring,
///   filling up to a full inner circle as water is logged.
/// - [sleepHours] draws a semicircle arc just outside the main ring, on
///   the left side (bottom to top), filling as a fraction of
///   [_maxSleepHoursForArc]. Nothing is drawn until sleep has actually
///   been logged; the water and sleep values are also echoed as small
///   flanking labels next to "kcal remaining".
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.consumed,
    required this.goal,
    required this.remaining,
    this.waterFraction,
    this.waterLiters,
    this.sleepHours,
    this.showSleepStat = false,
    this.onTapSleep,
    this.size = 260,
  });

  final int consumed;
  final int goal;
  final int remaining;
  final double? waterFraction;
  final double? waterLiters;
  final double? sleepHours;

  /// Whether to show the sleep arc/flanking stat at all — kept separate
  /// from [sleepHours] so a user who tried sleep tracking once and
  /// stopped doesn't keep seeing a permanent "0h" stat; see
  /// [HomeDailySummary.sleepTrackingActive].
  final bool showSleepStat;

  /// Opens the sleep log/edit sheet when the flanking sleep stat is
  /// tapped. Only wired up when [showSleepStat] is true.
  final VoidCallback? onTapSleep;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = goal == 0 ? 0.0 : (consumed / goal).clamp(0.0, 1.0);
    final isOver = consumed > goal;
    final water = waterFraction?.clamp(0.0, 1.0);
    final sleepFraction = ((sleepHours ?? 0) / _maxSleepHoursForArc).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showSleepStat)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: sleepFraction),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CustomPaint(
                  size: Size(size, size),
                  painter: _SleepArcPainter(
                    fraction: value,
                    hasValue: sleepHours != null,
                    progressColor: _sleepColor,
                    strokeWidth: size * 0.045,
                  ),
                );
              },
            ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: fraction),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CustomPaint(
                size: Size(size, size),
                painter: _RingPainter(
                  fraction: value,
                  trackColor: theme.colorScheme.surfaceContainerHighest,
                  progressColor: isOver
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  strokeWidth: size * 0.072,
                  radiusFactor: 0.86,
                ),
              );
            },
          ),
          if (water != null)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: water),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CustomPaint(
                  size: Size(size, size),
                  painter: _InnerArcPainter(
                    fraction: value,
                    trackColor: ScampiColors.macroWater.withValues(alpha: 0.15),
                    progressColor: ScampiColors.macroWater,
                    strokeWidth: size * 0.035,
                    inset: size * (1 - 0.86) / 2 + size * 0.072 * 0.86 + size * 0.03,
                  ),
                );
              },
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                remaining >= 0 ? '$remaining' : '${-remaining}',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: size * 0.13,
                ),
                textAlign: TextAlign.center,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showSleepStat) ...[
                    GestureDetector(
                      onTap: onTapSleep,
                      behavior: HitTestBehavior.opaque,
                      child: _FlankingStat(
                        icon: Icons.bedtime_rounded,
                        color: _sleepColor,
                        value: sleepHours != null ? '${sleepHours!.toStringAsFixed(1)}h' : '–',
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    remaining >= 0 ? 'kcal remaining' : 'kcal over',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(width: 5),
                  _FlankingStat(
                    icon: Icons.water_drop_rounded,
                    color: ScampiColors.macroWater,
                    value: waterLiters != null ? '${waterLiters!.toStringAsFixed(1)}L' : '–',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$consumed / $goal kcal',
                style: theme.textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small icon+value label flanking the center of the ring — sleep hours
/// on the left, water liters on the right.
class _FlankingStat extends StatelessWidget {
  const _FlankingStat({required this.icon, required this.color, required this.value});

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 2),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(color: color, fontSize: 10.5),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
    this.radiusFactor = 1.0,
  });

  final double fraction;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  /// Shrinks the ring's radius relative to the full available size, to
  /// leave room outside it for the sleep arc.
  final double radiusFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = ((math.min(size.width, size.height) - strokeWidth) / 2) * radiusFactor;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * fraction;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Slimmer arc drawn [inset] pixels inside the main ring's radius — used
/// for the water indicator. Unlike the calorie ring, this always starts
/// its full background track (so the "goal shape" is visible even at
/// 0%) and never exceeds a full circle, since going over your water goal
/// isn't a warning state the way going over your calorie goal is.
class _InnerArcPainter extends CustomPainter {
  _InnerArcPainter({
    required this.fraction,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
    required this.inset,
  });

  final double fraction;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - inset;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * fraction.clamp(0.0, 1.0);

    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InnerArcPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Semicircle drawn just outside the main ring, on the left side, from
/// the bottom (6 o'clock) sweeping counter-clockwise through 9 o'clock
/// up to the top (12 o'clock) — represents sleep hours as a fraction of
/// [_maxSleepHoursForArc]. Nothing is drawn until [hasValue] is true —
/// unlike the water arc, an unlogged night has no natural "goal shape"
/// to preview, so an empty gray track would just look like clutter.
class _SleepArcPainter extends CustomPainter {
  _SleepArcPainter({
    required this.fraction,
    required this.hasValue,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double fraction;
  final bool hasValue;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (!hasValue || fraction <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Bottom (6 o'clock) sweeping clockwise through the left side (9
    // o'clock) up to the top (12 o'clock) — a 180° arc down the left.
    const startAngle = math.pi / 2;
    const fullSweep = math.pi;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fullSweep * fraction,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SleepArcPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.hasValue != hasValue ||
        oldDelegate.progressColor != progressColor;
  }
}
