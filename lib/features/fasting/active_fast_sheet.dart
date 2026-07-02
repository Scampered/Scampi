import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/fasting_session.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// Bottom sheet shown when tapping the "Today's Fast" tile while a fast
/// is already active — shows live elapsed/target progress and an "End
/// Fast Now" action, rather than only being viewable/endable from
/// nowhere.
class ActiveFastSheet extends ConsumerStatefulWidget {
  const ActiveFastSheet({super.key, required this.session});

  final FastingSession session;

  @override
  ConsumerState<ActiveFastSheet> createState() => _ActiveFastSheetState();
}

class _ActiveFastSheetState extends ConsumerState<ActiveFastSheet> {
  Timer? _ticker;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _endFast() async {
    if (_ending || widget.session.id == null) return;
    setState(() => _ending = true);

    await ref.read(fastingRepositoryProvider).endSession(widget.session.id!, DateTime.now());
    await NotificationService.instance.cancelFastingComplete();
    ref.read(dataRefreshSignalProvider.notifier).bump();

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = widget.session;
    final elapsed = session.elapsed;
    final progress = session.progressFraction;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(ScampiRadius.lg)),
      ),
      padding: const EdgeInsets.fromLTRB(
        ScampiSpacing.lg,
        ScampiSpacing.sm,
        ScampiSpacing.lg,
        ScampiSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: ScampiSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: ScampiRadius.pillBorder,
                ),
              ),
            ),
            Text(session.type.label, style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Started ${_formatTime(context, session.startAt)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: ScampiSpacing.md),
            if (session.isMultiDay) ...[
              Center(
                child: Text(
                  'Day ${session.currentDayNumber}/${session.totalTargetDays}',
                  style: theme.textTheme.displayLarge,
                ),
              ),
              Center(
                child: Text(
                  session.remaining == Duration.zero
                      ? 'Target reached — great work!'
                      : '${_formatDuration(session.remaining)} remaining',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ] else ...[
              Center(
                child: Text(_formatDuration(elapsed), style: theme.textTheme.displayLarge),
              ),
              Center(
                child: Text('elapsed', style: theme.textTheme.bodySmall),
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: ScampiSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                progress >= 1.0
                    ? 'Target reached — great work!'
                    : '${(progress * 100).round()}% of target',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: ScampiSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: _ending ? null : _endFast,
                child: _ending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('End Fast Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h}h ${m}m ${s}s';
  }

  static String _formatTime(BuildContext context, DateTime dt) {
    return TimeOfDay.fromDateTime(dt).format(context);
  }
}
