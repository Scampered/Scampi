import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../core/utils/day_boundary.dart';
import '../../data/models/fasting_session.dart';
import '../../data/models/sleep_log_entry.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// Threshold for the Home "skip Cheat Day" offer — if what's been eaten
/// so far on the cheat day is still within this many kcal of the
/// *normal* (non-bonus) goal, the bonus is essentially unused, so it's
/// worth offering to move it to the next day instead of losing it.
const int cheatDaySkipThresholdKcal = 50;

/// The last weekday ([DateTime.friday]) a Cheat Day week's bonus can
/// land on — Progress's chart resets its 7-day window right after this,
/// so a bonus already sitting here has nowhere left to move to.
const int cheatWeekLastWeekday = DateTime.friday;

/// Everything the Home screen needs for a given day, aggregated from the
/// profile, food log, exercise log, water log, weight log, and any
/// active fast. Built fresh each time [homeSummaryProvider] re-runs (on
/// app start and whenever [dataRefreshSignalProvider] is bumped).
class HomeDailySummary {
  const HomeDailySummary({
    required this.hasProfile,
    this.userName = '',
    this.calculation,
    this.cheatDayBonusKcal = 0,
    required this.caloriesConsumed,
    required this.caloriesBurned,
    required this.proteinConsumedG,
    required this.carbsConsumedG,
    required this.fatConsumedG,
    required this.waterMl,
    required this.waterGoalMl,
    this.currentWeightKg,
    this.goalWeightKg,
    this.activeFast,
    this.sleepHours,
    this.todaySleepEntry,
    this.sleepTrackingActive = false,
    this.cheatDaySkipEligible = false,
    this.cheatDaySkipTargetDay,
    this.setCheatDayCandidateDay,
    this.setCheatDayCandidateCalories,
  });

  final bool hasProfile;
  final String userName;
  final CalorieCalculation? calculation;

  /// Bonus calories added to [calorieGoal] when the viewed day is the
  /// user's configured cheat day — 0 otherwise. See Profile's "Cheat Day"
  /// settings.
  final int cheatDayBonusKcal;

  final double caloriesConsumed;
  final double caloriesBurned;
  final double proteinConsumedG;
  final double carbsConsumedG;
  final double fatConsumedG;

  final int waterMl;
  final int waterGoalMl;

  final double? currentWeightKg;
  final double? goalWeightKg;

  final FastingSession? activeFast;

  /// Hours slept last night, if the user manually logged it — null shows
  /// as an empty sleep arc rather than a zero-length one.
  final double? sleepHours;

  /// Today's raw sleep entry (bedtime/wake time), if logged — used to
  /// prefill [SleepLogSheet] for editing rather than starting fresh.
  final SleepLogEntry? todaySleepEntry;

  /// Whether sleep has been logged today or yesterday — the sleep arc
  /// and flanking stat on the ring are only shown while this is true, so
  /// the feature disappears cleanly for anyone who tried it once and
  /// stopped, rather than permanently showing an empty "0h" stat.
  final bool sleepTrackingActive;

  /// Whether today qualifies for the "barely touched your Cheat Day —
  /// move it?" offer: today IS the (possibly already-moved) cheat day,
  /// it's not the last day of the Cheat Day week (nowhere left to move
  /// to), and what's been eaten so far is still within
  /// [cheatDaySkipThresholdKcal] of the normal goal. Only ever true for
  /// [isToday] — a past day's cheat day is done and can't be moved.
  final bool cheatDaySkipEligible;

  /// The day the bonus would move to if the user accepts the offer above
  /// — always tomorrow. Null unless [cheatDaySkipEligible] is true.
  final DateTime? cheatDaySkipTargetDay;

  /// The best "you basically already had a Cheat Day, just not on the
  /// configured day" candidate found this Cheat Day week (Saturday
  /// through today) — the day, other than the currently-effective cheat
  /// day, with the highest calories eaten among any day whose calories
  /// reached (goal + bonus − [cheatDaySkipThresholdKcal]). Whichever day
  /// crossed that line hardest wins, so a later, bigger over-eat than an
  /// earlier candidate naturally replaces it if the offer is re-checked.
  /// Null when nothing this week qualifies. Only ever computed for
  /// [isToday] — this is a "here's what your week looked like" check
  /// meant to run once per day, not a per-past-day computation.
  final DateTime? setCheatDayCandidateDay;

  /// [setCheatDayCandidateDay]'s calories eaten that day, for display —
  /// null exactly when [setCheatDayCandidateDay] is null.
  final double? setCheatDayCandidateCalories;

  int get calorieGoal => (calculation?.dailyCalorieGoal ?? 2000).round() + cheatDayBonusKcal;
  int get netCalories =>
      (caloriesConsumed - caloriesBurned).round();
  int get caloriesRemaining => calorieGoal - netCalories;
}

/// Keyed by the calendar day being viewed (normalized to midnight) — see
/// [HomeScreen]'s day-navigator, which lets the last 7 days be viewed and
/// edited, not just today.
final homeSummaryProvider =
    FutureProvider.family<HomeDailySummary, DateTime>((ref, selectedDay) async {
  // Watching the refresh signal means any logged food/water/exercise/
  // weight entry (which bumps it) causes this provider to re-run and
  // the Home screen to update automatically.
  ref.watch(dataRefreshSignalProvider);

  final profileRepo = ref.read(userProfileRepositoryProvider);
  final foodLogRepo = ref.read(foodLogRepositoryProvider);
  final exerciseLogRepo = ref.read(exerciseLogRepositoryProvider);
  final waterLogRepo = ref.read(waterLogRepositoryProvider);
  final weightLogRepo = ref.read(weightLogRepositoryProvider);
  final sleepLogRepo = ref.read(sleepLogRepositoryProvider);
  final fastingRepo = ref.read(fastingRepositoryProvider);

  final now = DateTime.now();
  final isToday = selectedDay.year == now.year &&
      selectedDay.month == now.month &&
      selectedDay.day == now.day;

  final profile = await profileRepo.getProfile();
  final resetMinuteOfDay = profile?.calorieResetMinuteOfDay ?? 0;
  final foodTotals =
      await foodLogRepo.totalsForDay(selectedDay, resetMinuteOfDay: resetMinuteOfDay);
  final caloriesBurned = await exerciseLogRepo.totalCaloriesBurnedForDay(
    selectedDay,
    resetMinuteOfDay: resetMinuteOfDay,
  );
  final waterMl =
      await waterLogRepo.totalMlForDay(selectedDay, resetMinuteOfDay: resetMinuteOfDay);
  final waterGoalMl = await profileRepo.getWaterGoalMl();
  final latestWeight = isToday
      ? await weightLogRepo.mostRecent()
      : await weightLogRepo.mostRecentAsOf(selectedDay, resetMinuteOfDay: resetMinuteOfDay);
  // A fast is live session state, not per-day history — only meaningful
  // while looking at today.
  final activeFast = isToday ? await fastingRepo.getActiveSession() : null;
  final selectedDaySleep =
      await sleepLogRepo.entryForDay(selectedDay, resetMinuteOfDay: resetMinuteOfDay);
  final priorDaySleep = await sleepLogRepo.entryForDay(
    selectedDay.subtract(const Duration(days: 1)),
    resetMinuteOfDay: resetMinuteOfDay,
  );
  final sleepTrackingActive = selectedDaySleep != null || priorDaySleep != null;

  final calculation = profile != null
      ? CalorieCalculator.calculate(
          // Use the most recent logged weight if available, since body
          // weight changes over time and the profile's stored weight may
          // be stale; fall back to the profile's weight otherwise.
          latestWeight != null
              ? profile.copyWith(weightKg: latestWeight.weightKg)
              : profile,
        )
      : null;

  // A saved CheatDayOverride for this week takes over which weekday the
  // bonus falls on, in place of the profile's normal recurring day — see
  // skipCheatDayToNextDay below.
  final selectedDayWeekday = dayWindowFor(selectedDay, resetMinuteOfDay).start.weekday;
  int? effectiveCheatWeekday;
  if (profile != null && profile.cheatDayEnabled) {
    final override =
        await ref.read(cheatDayOverrideRepositoryProvider).forWeek(
              cheatWeekStartFor(selectedDay, resetMinuteOfDay),
            );
    effectiveCheatWeekday = override?.effectiveWeekday ?? profile.cheatDayOfWeek;
  }
  final isCheatDay = effectiveCheatWeekday != null && effectiveCheatWeekday == selectedDayWeekday;
  final cheatDayBonus = isCheatDay ? profile!.cheatDayBonusKcal : 0;

  final baseCalorieGoal = (calculation?.dailyCalorieGoal ?? 2000).round();
  final skipEligible = isToday &&
      isCheatDay &&
      selectedDayWeekday != cheatWeekLastWeekday &&
      foodTotals.calories <= baseCalorieGoal + cheatDaySkipThresholdKcal;

  // "Set as Cheat Day" — the mirror image of Skip, for when the
  // *configured* cheat day goes (or will go) unused but some other day
  // this week clearly didn't. Scans every day from this Cheat Day
  // week's Saturday through today (inclusive), skipping whichever day
  // is currently the effective cheat day, and keeps the one with the
  // highest calories among any that reached cheat-day-ish levels.
  // Deliberately not gated on the effective day having actually gone
  // unused yet — a bigger, more recent over-eat should always be able
  // to replace an earlier pick if the user changes their mind, and if
  // the configured day later turns out to genuinely need the bonus,
  // that's fine too since nothing here prevents picking it normally.
  DateTime? setCheatDayCandidateDay;
  double? setCheatDayCandidateCalories;
  if (isToday && profile != null && profile.cheatDayEnabled && effectiveCheatWeekday != null) {
    final cheatDayFullGoal = baseCalorieGoal + profile.cheatDayBonusKcal;
    final weekStartRaw = cheatWeekStartFor(selectedDay, resetMinuteOfDay);
    final weekStartDate = DateTime(weekStartRaw.year, weekStartRaw.month, weekStartRaw.day);
    for (var d = weekStartDate; !d.isAfter(selectedDay); d = d.add(const Duration(days: 1))) {
      final dWeekday = dayWindowFor(d, resetMinuteOfDay).start.weekday;
      if (dWeekday == effectiveCheatWeekday) continue;
      final dCalories = d.isAtSameMomentAs(selectedDay)
          ? foodTotals.calories
          : (await foodLogRepo.totalsForDay(d, resetMinuteOfDay: resetMinuteOfDay)).calories;
      if (dCalories < cheatDayFullGoal - cheatDaySkipThresholdKcal) continue;
      if (setCheatDayCandidateCalories == null || dCalories > setCheatDayCandidateCalories) {
        setCheatDayCandidateDay = d;
        setCheatDayCandidateCalories = dCalories;
      }
    }
  }

  return HomeDailySummary(
    hasProfile: profile != null,
    userName: profile?.name ?? '',
    calculation: calculation,
    cheatDayBonusKcal: cheatDayBonus,
    caloriesConsumed: foodTotals.calories,
    caloriesBurned: caloriesBurned,
    proteinConsumedG: foodTotals.proteinG,
    carbsConsumedG: foodTotals.carbsG,
    fatConsumedG: foodTotals.fatG,
    waterMl: waterMl,
    waterGoalMl: waterGoalMl,
    currentWeightKg: latestWeight?.weightKg ?? profile?.weightKg,
    goalWeightKg: profile?.goalWeightKg,
    activeFast: activeFast,
    sleepHours: selectedDaySleep?.hours,
    todaySleepEntry: selectedDaySleep,
    sleepTrackingActive: sleepTrackingActive,
    cheatDaySkipEligible: skipEligible,
    cheatDaySkipTargetDay: skipEligible ? selectedDay.add(const Duration(days: 1)) : null,
    setCheatDayCandidateDay: setCheatDayCandidateDay,
    setCheatDayCandidateCalories: setCheatDayCandidateCalories,
  );
});

/// Moves this Cheat Day week's bonus from [today] to the next calendar
/// day, by writing a [CheatDayOverride] for the week [today] falls in.
/// Only ever called from the Home "skip" offer, which already gates on
/// [HomeDailySummary.cheatDaySkipEligible] — in particular, that the
/// current cheat day isn't already the last day of the week
/// ([cheatWeekLastWeekday]), so there's always a valid next day to move
/// to within the same week.
Future<void> skipCheatDayToNextDay(WidgetRef ref, {required DateTime today}) async {
  final profile = await ref.read(userProfileRepositoryProvider).getProfile();
  if (profile == null) return;
  final resetMinuteOfDay = profile.calorieResetMinuteOfDay;
  final weekStart = cheatWeekStartFor(today, resetMinuteOfDay);
  final nextDay = dayWindowFor(today, resetMinuteOfDay).start.add(const Duration(days: 1));
  await ref.read(cheatDayOverrideRepositoryProvider).setForWeek(weekStart, nextDay.weekday);
  ref.read(dataRefreshSignalProvider.notifier).bump();
}

/// Makes [day] this Cheat Day week's effective cheat day, by writing a
/// [CheatDayOverride] for the week [day] falls in — the "Set as Cheat
/// Day" counterpart to [skipCheatDayToNextDay] above, driven by
/// [HomeDailySummary.setCheatDayCandidateDay] instead of the Skip
/// offer. Re-callable within the same week to change the pick (e.g. a
/// bigger over-eat on a later day) since `setForWeek` upserts.
Future<void> setDayAsCheatDay(WidgetRef ref, {required DateTime day}) async {
  final profile = await ref.read(userProfileRepositoryProvider).getProfile();
  if (profile == null) return;
  final resetMinuteOfDay = profile.calorieResetMinuteOfDay;
  final weekStart = cheatWeekStartFor(day, resetMinuteOfDay);
  final dayWeekday = dayWindowFor(day, resetMinuteOfDay).start.weekday;
  await ref.read(cheatDayOverrideRepositoryProvider).setForWeek(weekStart, dayWeekday);
  ref.read(dataRefreshSignalProvider.notifier).bump();
}
