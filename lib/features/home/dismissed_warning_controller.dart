import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dismissedWarningGoalPrefsKey = 'scampi_dismissed_warning_goal';

/// Persists which daily calorie goal the health warning card was last
/// dismissed for, so closing/reopening the app doesn't bring it back —
/// it only reappears if the goal itself changes (a genuinely new
/// situation worth re-flagging), not just because the app restarted.
class DismissedWarningController extends StateNotifier<int?> {
  DismissedWarningController() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_dismissedWarningGoalPrefsKey);
  }

  Future<void> dismissForGoal(int calorieGoal) async {
    state = calorieGoal;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dismissedWarningGoalPrefsKey, calorieGoal);
  }
}

final dismissedWarningGoalProvider =
    StateNotifierProvider<DismissedWarningController, int?>(
  (ref) => DismissedWarningController(),
);

const _dismissedCheatDaySkipDatePrefsKey = 'scampi_dismissed_cheat_day_skip_date';

/// Same idea as [DismissedWarningController], for the Home "skip Cheat
/// Day" offer — persists the date (`YYYY-MM-DD`) it was last dismissed
/// for, so closing the offer doesn't just reappear on the next rebuild,
/// but does come back the next time it's actually a different day's
/// offer.
class DismissedCheatDaySkipController extends StateNotifier<String?> {
  DismissedCheatDaySkipController() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_dismissedCheatDaySkipDatePrefsKey);
  }

  Future<void> dismissForDate(String dateKey) async {
    state = dateKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedCheatDaySkipDatePrefsKey, dateKey);
  }
}

final dismissedCheatDaySkipDateProvider =
    StateNotifierProvider<DismissedCheatDaySkipController, String?>(
  (ref) => DismissedCheatDaySkipController(),
);

const _dismissedSetCheatDayKeyPrefsKey = 'scampi_dismissed_set_cheat_day_key';

/// Same idea again, for the "Set as Cheat Day" offer — keyed by
/// `"<today>_<candidate day>"` rather than just today's date, since a
/// *better* candidate appearing later the same day (a bigger over-eat)
/// should still surface even if an earlier, smaller candidate was
/// already dismissed today.
class DismissedSetCheatDayController extends StateNotifier<String?> {
  DismissedSetCheatDayController() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_dismissedSetCheatDayKeyPrefsKey);
  }

  Future<void> dismissForKey(String key) async {
    state = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedSetCheatDayKeyPrefsKey, key);
  }
}

final dismissedSetCheatDayKeyProvider =
    StateNotifierProvider<DismissedSetCheatDayController, String?>(
  (ref) => DismissedSetCheatDayController(),
);
