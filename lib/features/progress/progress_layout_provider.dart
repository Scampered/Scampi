import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which reorderable cards the Progress tab shows, top to bottom.
/// [exerciseDetails] is new in v1.5.0 — see [exercise_details_card.dart].
enum ProgressCardType { calories, exerciseDetails, weight, sleep }

const List<ProgressCardType> _defaultOrder = [
  ProgressCardType.calories,
  ProgressCardType.exerciseDetails,
  ProgressCardType.weight,
  ProgressCardType.sleep,
];

const _prefsKey = 'scampi_progress_card_order';

/// Persists the user's chosen card order (via the pencil icon at the top
/// of Progress) across app restarts. Falls back to [_defaultOrder] on
/// first run, or if the saved order doesn't cleanly cover every current
/// card type (e.g. an older save from before a new card type existed).
class ProgressLayoutController extends StateNotifier<List<ProgressCardType>> {
  ProgressLayoutController() : super(_defaultOrder) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey);
    if (saved == null) return;

    final restored = <ProgressCardType>[];
    for (final name in saved) {
      for (final type in ProgressCardType.values) {
        if (type.name == name && !restored.contains(type)) {
          restored.add(type);
          break;
        }
      }
    }
    // A card type introduced after this order was saved has nowhere to
    // come from in `saved` — append it at the end rather than dropping
    // it from the list entirely.
    for (final type in ProgressCardType.values) {
      if (!restored.contains(type)) restored.add(type);
    }
    state = restored;
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = List<ProgressCardType>.from(state);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, list.map((t) => t.name).toList());
  }
}

final progressLayoutProvider =
    StateNotifierProvider<ProgressLayoutController, List<ProgressCardType>>(
  (ref) => ProgressLayoutController(),
);
