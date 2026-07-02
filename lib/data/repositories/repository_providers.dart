import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/user_profile_repository.dart';
import '../repositories/food_repository.dart';
import '../repositories/food_log_repository.dart';
import '../repositories/meal_repository.dart';
import '../repositories/exercise_log_repository.dart';
import '../repositories/water_weight_repository.dart';
import '../repositories/sleep_log_repository.dart';
import '../repositories/fasting_repository.dart';
import 'data_refresh_signal.dart';

/// Plain repository instance providers. These don't hold UI state
/// themselves — they're the data-access boundary that the state/summary
/// providers in each feature build on top of.
final userProfileRepositoryProvider =
    Provider<UserProfileRepository>((ref) => UserProfileRepository());

final foodRepositoryProvider =
    Provider<FoodRepository>((ref) => FoodRepository());

final foodLogRepositoryProvider =
    Provider<FoodLogRepository>((ref) => FoodLogRepository());

final mealRepositoryProvider =
    Provider<MealRepository>((ref) => MealRepository());

final exerciseLogRepositoryProvider =
    Provider<ExerciseLogRepository>((ref) => ExerciseLogRepository());

final waterLogRepositoryProvider =
    Provider<WaterLogRepository>((ref) => WaterLogRepository());

final weightLogRepositoryProvider =
    Provider<WeightLogRepository>((ref) => WeightLogRepository());

final sleepLogRepositoryProvider =
    Provider<SleepLogRepository>((ref) => SleepLogRepository());

final fastingRepositoryProvider =
    Provider<FastingRepository>((ref) => FastingRepository());

/// Whether a profile currently exists — drives [OnboardingGate]. Watches
/// the refresh signal so it reacts automatically both when onboarding
/// completes (signal bumped in OnboardingScreen._save) and when data is
/// wiped via "Reset All Data" in Profile (signal bumped there too),
/// routing back to onboarding without any manual navigation needed.
final hasProfileProvider = FutureProvider<bool>((ref) async {
  ref.watch(dataRefreshSignalProvider);
  final repo = ref.read(userProfileRepositoryProvider);
  return repo.hasProfile();
});
