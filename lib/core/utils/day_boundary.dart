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
