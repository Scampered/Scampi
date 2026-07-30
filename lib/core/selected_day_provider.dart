import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Truncates to midnight — the canonical "just the date" form used
/// wherever a day (not a moment) is being compared or stored.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// How far back the day-navigator lets you go — a week of history to
/// view/edit, not an open-ended calendar.
const int selectedDayHistoryLimit = 6;

/// Which day Home, Food, and Fitness are currently showing — defaults to
/// today. Shared across tabs (rather than each screen assuming "today"
/// independently, or Home owning it as private widget state) so
/// navigating back a day on Home and then switching to Food or Fitness
/// shows that same day there too, with normal add/edit/delete against
/// it, instead of Home needing its own read-only view of what those tabs
/// hold.
final selectedDayProvider = StateProvider<DateTime>((ref) => dateOnly(DateTime.now()));

/// Combines [day]'s date with the current time-of-day — used when a log
/// entry is saved while a non-today day is selected, so it keeps a
/// realistic "logged at" time instead of defaulting to midnight. Same
/// "move the date, keep the time" pattern already used for water/weight.
DateTime combineDayWithNow(DateTime day) {
  final now = DateTime.now();
  return DateTime(day.year, day.month, day.day, now.hour, now.minute, now.second);
}

/// "Today" / "Yesterday" / formatted date label for [day], relative to
/// now — shared by Home's day-navigator and the Food/Fitness app bars so
/// they describe the selected day identically.
String selectedDayLabel(DateTime day) {
  final today = dateOnly(DateTime.now());
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEE, MMM d').format(day);
}
