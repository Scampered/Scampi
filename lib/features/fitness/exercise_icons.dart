import 'package:flutter/material.dart';
import '../../data/models/exercise_log_entry.dart';

/// Icon shown for each exercise category, used on the category picker
/// and on logged entry tiles.
IconData iconForExerciseCategory(ExerciseCategory category) {
  switch (category) {
    case ExerciseCategory.walking:
      return Icons.directions_walk_rounded;
    case ExerciseCategory.running:
      return Icons.directions_run_rounded;
    case ExerciseCategory.cycling:
      return Icons.directions_bike_rounded;
    case ExerciseCategory.swimming:
      return Icons.pool_rounded;
    case ExerciseCategory.football:
      return Icons.sports_soccer_rounded;
    case ExerciseCategory.basketball:
      return Icons.sports_basketball_rounded;
    case ExerciseCategory.tennis:
      return Icons.sports_tennis_rounded;
    case ExerciseCategory.gym:
      return Icons.fitness_center_rounded;
    case ExerciseCategory.weightTraining:
      return Icons.sports_gymnastics_rounded;
    case ExerciseCategory.martialArts:
      return Icons.sports_martial_arts_rounded;
    case ExerciseCategory.hiking:
      return Icons.terrain_rounded;
    case ExerciseCategory.other:
      return Icons.sports_rounded;
  }
}

/// Categories where logging a distance makes sense.
const Set<ExerciseCategory> distanceTrackedCategories = {
  ExerciseCategory.walking,
  ExerciseCategory.running,
  ExerciseCategory.cycling,
  ExerciseCategory.swimming,
  ExerciseCategory.hiking,
};
