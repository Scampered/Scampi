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
