/// A half-open [start, end) window representing "today" for tracking
/// purposes, given a custom reset hour.
class DayWindow {
  const DayWindow(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

/// Computes the "logical day" window containing [now], given
/// [resetMinuteOfDay] (0–1439, minutes past midnight at which the day
/// rolls over — 0 is plain midnight). Full minute precision, not just
/// whole hours — someone who wakes at 7:45am wants the reset exactly
/// there, not rounded down to 7am.
///
/// For most users this is just calendar-midnight to calendar-midnight.
/// For someone who stays up past midnight (or sleeps before it), a
/// resetMinuteOfDay of e.g. 3:30am means "today" doesn't roll over
/// until then, so logging a late-night snack at 1am still counts
/// toward the previous day rather than starting a fresh one.
DayWindow dayWindowFor(DateTime now, int resetMinuteOfDay) {
  final todayReset = DateTime(now.year, now.month, now.day)
      .add(Duration(minutes: resetMinuteOfDay));
  final start = now.isBefore(todayReset)
      ? todayReset.subtract(const Duration(days: 1))
      : todayReset;
  return DayWindow(start, start.add(const Duration(days: 1)));
}

/// The Saturday (date-only) that starts the Cheat Day "week" containing
/// [day] — Cheat Day is fixed to a Saturday-through-Friday week
/// regardless of the user's chosen cheat weekday, so "move to the next
/// day, but never past the end of the week" has a fixed, unambiguous
/// boundary (Friday) to stop at. This is independent of Progress's
/// weekly chart, which is a rolling 7-days-ending-today window, not a
/// fixed calendar week — the two don't need to agree, since this only
/// exists to key [CheatDayOverride] rows by "which week is this".
DateTime cheatWeekStartFor(DateTime day, int resetMinuteOfDay) {
  final logicalDay = dayWindowFor(day, resetMinuteOfDay).start;
  // DateTime.weekday: Mon=1 .. Sun=7. Saturday=6 is day 0 of this week.
  final daysSinceSaturday = (logicalDay.weekday - DateTime.saturday + 7) % 7;
  return logicalDay.subtract(Duration(days: daysSinceSaturday));
}
