import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/sleep_log_entry.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/data_refresh_signal.dart';

/// Bottom sheet for manually logging last night's sleep — bedtime and
/// wake time (hours computed automatically, wrapping past midnight), or
/// entering hours directly. Logs against today's date, so it reads as
/// "how long you slept before today" the way the Progress chart and
/// Home ring both expect.
class SleepLogSheet extends ConsumerStatefulWidget {
  const SleepLogSheet({super.key, this.existing});

  final SleepLogEntry? existing;

  @override
  ConsumerState<SleepLogSheet> createState() => _SleepLogSheetState();
}

class _SleepLogSheetState extends ConsumerState<SleepLogSheet> {
  late TimeOfDay _bedtime;
  late TimeOfDay _wakeTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _bedtime = existing?.bedtime != null
        ? TimeOfDay.fromDateTime(existing!.bedtime!)
        : const TimeOfDay(hour: 23, minute: 0);
    _wakeTime = existing?.wakeTime != null
        ? TimeOfDay.fromDateTime(existing!.wakeTime!)
        : const TimeOfDay(hour: 7, minute: 0);
  }

  double get _hours {
    final bedMinutes = _bedtime.hour * 60 + _bedtime.minute;
    final wakeMinutes = _wakeTime.hour * 60 + _wakeTime.minute;
    // Wake time is on the "next day" relative to bedtime whenever it's
    // numerically earlier (the normal case — sleep at 11pm, wake at 7am).
    final diff = wakeMinutes <= bedMinutes ? (1440 - bedMinutes + wakeMinutes) : (wakeMinutes - bedMinutes);
    return diff / 60.0;
  }

  Future<void> _pickBedtime() async {
    final picked = await showTimePicker(context: context, initialTime: _bedtime);
    if (picked != null) setState(() => _bedtime = picked);
  }

  Future<void> _pickWakeTime() async {
    final picked = await showTimePicker(context: context, initialTime: _wakeTime);
    if (picked != null) setState(() => _wakeTime = picked);
  }

  void _setBedtimeNow() => setState(() => _bedtime = TimeOfDay.fromDateTime(DateTime.now()));

  void _setWakeTimeNow() => setState(() => _wakeTime = TimeOfDay.fromDateTime(DateTime.now()));

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final today = DateTime.now();
    DateTime timeOn(TimeOfDay t) => DateTime(today.year, today.month, today.day, t.hour, t.minute);

    await ref.read(sleepLogRepositoryProvider).logEntry(
          SleepLogEntry(
            date: today,
            hours: _hours,
            bedtime: timeOn(_bedtime),
            wakeTime: timeOn(_wakeTime),
          ),
        );
    ref.read(dataRefreshSignalProvider.notifier).bump();

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
              Text('Log Sleep', style: theme.textTheme.titleLarge),
              const SizedBox(height: ScampiSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Bedtime',
                      icon: Icons.bedtime_rounded,
                      time: _bedtime,
                      onTap: _pickBedtime,
                      onTapNow: _setBedtimeNow,
                    ),
                  ),
                  const SizedBox(width: ScampiSpacing.sm),
                  Expanded(
                    child: _TimeField(
                      label: 'Wake time',
                      icon: Icons.wb_sunny_rounded,
                      time: _wakeTime,
                      onTap: _pickWakeTime,
                      onTapNow: _setWakeTimeNow,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ScampiSpacing.md),
              Center(
                child: Text(
                  '${_hours.toStringAsFixed(1)} hours of sleep',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: ScampiSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
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
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.icon,
    required this.time,
    required this.onTap,
    required this.onTapNow,
  });

  final String label;
  final IconData icon;
  final TimeOfDay time;
  final VoidCallback onTap;
  final VoidCallback onTapNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: ScampiRadius.smBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: ScampiSpacing.sm, vertical: ScampiSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: ScampiRadius.smBorder,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: ScampiColors.blue),
                      const SizedBox(width: 4),
                      Text(label, style: theme.textTheme.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(time.format(context), style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            InkWell(
              onTap: onTapNow,
              borderRadius: ScampiRadius.smBorder,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  'Now',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
