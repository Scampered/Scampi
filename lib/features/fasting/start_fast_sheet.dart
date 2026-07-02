import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/prayer_time_calculator.dart';
import '../../data/models/fasting_session.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// A few common fasting-window lengths shown as quick chips — picking one
/// sets the target end time to start + that many hours, rather than
/// making every fast require manually typing an end time.
const _presetHours = [16, 18, 20, 24];

/// Bottom sheet for starting a new fast: pick a type, when it started
/// (defaults to now), and when it should end (defaults to start + 16h).
/// Schedules a local "fast complete" notification for the target end.
class StartFastSheet extends ConsumerStatefulWidget {
  const StartFastSheet({super.key});

  @override
  ConsumerState<StartFastSheet> createState() => _StartFastSheetState();
}

class _StartFastSheetState extends ConsumerState<StartFastSheet> {
  FastingType _type = FastingType.intermittent;
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;
  bool _lookingUpPrayerTimes = false;
  String? _prayerTimeError;

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();
    _end = _start.add(const Duration(hours: 16));
  }

  void _setStartNow() {
    setState(() {
      _start = DateTime.now();
      if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 16));
    });
  }

  void _setEndNow() {
    setState(() => _end = DateTime.now());
  }

  void _setOneDayFast() {
    setState(() {
      _start = DateTime.now();
      _end = _start.add(const Duration(hours: 24));
    });
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 2)),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _start = picked;
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 16));
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _usePrayerTimes() async {
    setState(() {
      _lookingUpPrayerTimes = true;
      _prayerTimeError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are off');
      }

      // Falls back to the last known fix if a fresh one times out (e.g.
      // an emulator or a device indoors with a weak signal) — a slightly
      // stale location is still far more useful than failing outright
      // for something as coarse-grained as a prayer-time estimate.
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) {
        throw Exception('No location available');
      }

      final utcOffsetHours = DateTime.now().timeZoneOffset.inMinutes / 60.0;
      final times = PrayerTimeCalculator.calculate(
        date: _start,
        latitude: position.latitude,
        longitude: position.longitude,
        utcOffsetHours: utcOffsetHours,
      );

      if (!mounted) return;
      setState(() {
        _start = times.fajr;
        _end = times.maghrib.isAfter(times.fajr)
            ? times.maghrib
            : times.maghrib.add(const Duration(days: 1));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _prayerTimeError = "Couldn't get your location — enter times manually.");
    } finally {
      if (mounted) setState(() => _lookingUpPrayerTimes = false);
    }
  }

  Future<void> _confirmStart() async {
    if (_saving || !_end.isAfter(_start)) return;
    setState(() => _saving = true);

    final targetMinutes = _end.difference(_start).inMinutes;
    await ref.read(fastingRepositoryProvider).startSession(
          FastingSession(
            type: _type,
            startAt: _start,
            targetDurationMinutes: targetMinutes,
          ),
        );
    ref.read(dataRefreshSignalProvider.notifier).bump();

    final granted = await NotificationService.instance.requestPermission();
    if (granted) {
      await NotificationService.instance.scheduleFastingComplete(_end);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _end.difference(_start);
    final validDuration = duration > Duration.zero;

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
          child: SingleChildScrollView(
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
                Text('Start Fast', style: theme.textTheme.titleLarge),
                const SizedBox(height: ScampiSpacing.md),
                Wrap(
                  spacing: ScampiSpacing.xs,
                  children: [
                    for (final t in FastingType.values)
                      ChoiceChip(
                        label: Text(t.label),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ),
                  ],
                ),
                if (_type == FastingType.ramadan) ...[
                  const SizedBox(height: ScampiSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _lookingUpPrayerTimes ? null : _usePrayerTimes,
                      icon: _lookingUpPrayerTimes
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.mosque_rounded, size: 18),
                      label: Text(
                        _lookingUpPrayerTimes
                            ? 'Finding Suhoor/Iftar times…'
                            : 'Use Suhoor/Iftar for my location',
                      ),
                    ),
                  ),
                  if (_prayerTimeError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _prayerTimeError!,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                ],
                const SizedBox(height: ScampiSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _DateTimeField(
                        label: 'Start',
                        value: _start,
                        onTap: () => _pickDateTime(isStart: true),
                        onTapNow: _setStartNow,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: ScampiSpacing.xs),
                      child: Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.outline),
                    ),
                    Expanded(
                      child: _DateTimeField(
                        label: 'End',
                        value: _end,
                        onTap: () => _pickDateTime(isStart: false),
                        onTapNow: _setEndNow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ScampiSpacing.sm),
                Wrap(
                  spacing: ScampiSpacing.xs,
                  runSpacing: ScampiSpacing.xs,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.today_rounded, size: 16),
                      label: const Text('1 Day Fast (now → 24h)'),
                      onPressed: _setOneDayFast,
                    ),
                    for (final h in _presetHours)
                      ActionChip(
                        label: Text('${h}h'),
                        onPressed: () => setState(() => _end = _start.add(Duration(hours: h))),
                      ),
                  ],
                ),
                const SizedBox(height: ScampiSpacing.sm),
                Text(
                  validDuration
                      ? 'Target: ${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
                      : 'End must be after start',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: validDuration ? null : theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: ScampiSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: validDuration && !_saving ? _confirmStart : null,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Start Fast'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable date/time display with an inline "Now" button that jumps
/// straight to the current time — reused anywhere the user needs to set
/// a time (fasting start/end, sleep bedtime/wake), since "just use right
/// now" is the overwhelmingly common case and shouldn't require opening
/// the full date+time picker.
class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onTapNow,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;
  final VoidCallback onTapNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeText = TimeOfDay.fromDateTime(value).format(context);
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
                  Text(label, style: theme.textTheme.labelSmall),
                  const SizedBox(height: 2),
                  Text(timeText, style: theme.textTheme.titleMedium),
                  Text(ordinalDate(value), style: theme.textTheme.bodySmall),
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

/// Formats a date as "2nd June" rather than "6/2" — much less ambiguous
/// than a slash-separated month/day, which is easy to misread (and easy
/// to mis-tap in a date picker without noticing).
String ordinalDate(DateTime d) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final day = d.day;
  final suffix = _ordinalSuffix(day);
  return '$day$suffix ${months[d.month - 1]}';
}

String _ordinalSuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}
