/// A one-week exception to [UserProfile.cheatDayOfWeek] — created when
/// the user "skips" a cheat day they barely used, moving that week's
/// bonus to the next day instead. Keyed by [weekStartDate] (the Saturday
/// starting the Cheat Day week — see `cheatWeekStartFor` in
/// day_boundary.dart), so it only ever affects the one week it was
/// created for; the following week reverts to the profile's normal day
/// automatically since no override row exists for it.
class CheatDayOverride {
  const CheatDayOverride({
    this.id,
    required this.weekStartDate,
    required this.effectiveWeekday,
  });

  final int? id;

  /// Date-only (time-of-day ignored) Saturday that starts this Cheat Day
  /// week.
  final DateTime weekStartDate;

  /// Which day ([DateTime.weekday], Mon=1..Sun=7) the bonus actually
  /// falls on this week, in place of [UserProfile.cheatDayOfWeek].
  final int effectiveWeekday;

  /// `YYYY-MM-DD`, date-only — the lookup key used for
  /// [CheatDayOverrideRepository] queries too, so a week is always
  /// matched by calendar date regardless of time-of-day.
  static String dateKey(DateTime d) {
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${pad2(d.month)}-${pad2(d.day)}';
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'week_start_date': dateKey(weekStartDate),
      'effective_weekday': effectiveWeekday,
    };
  }

  factory CheatDayOverride.fromMap(Map<String, Object?> map) {
    return CheatDayOverride(
      id: map['id'] as int?,
      weekStartDate: DateTime.parse(map['week_start_date'] as String),
      effectiveWeekday: map['effective_weekday'] as int,
    );
  }
}
