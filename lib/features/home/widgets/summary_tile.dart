import 'package:flutter/material.dart';

/// Compact summary card used for Water, Weight Goal, Fasting Status, and
/// Burned tiles on the Home screen.
///
/// Layout is deliberately tight (small gaps, compact icon badge) because
/// these tiles sit in a 2-column grid with a fixed aspect ratio — a
/// looser layout here overflows once a subtitle + progress bar are both
/// present. If you add content to this tile, check it against the
/// tallest case (icon + label + value + subtitle + progress bar all
/// present at once) before shipping.
class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    this.progress,
    this.onTap,
    this.actionLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;

  /// Optional 0.0–1.0 progress fraction shown as a thin bar.
  final double? progress;
  final VoidCallback? onTap;

  /// Optional small call-to-action label shown at the bottom of the tile
  /// (e.g. "Update Weight") so a tappable tile doesn't rely on the user
  /// guessing that tapping it does something.
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
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
                      color: iconColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
              if (progress != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: progress!.clamp(0.0, 1.0),
                    ),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedValue, _) {
                      return LinearProgressIndicator(
                        value: animatedValue,
                        minHeight: 5,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      );
                    },
                  ),
                ),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  actionLabel!,
                  style: theme.textTheme.labelSmall?.copyWith(color: iconColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
