import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/repository_providers.dart';
import '../../data/repositories/data_refresh_signal.dart';

/// The current saved profile, or null if none exists yet. Re-fetches
/// whenever [dataRefreshSignalProvider] is bumped (e.g. after editing).
final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  ref.watch(dataRefreshSignalProvider);
  final repo = ref.read(userProfileRepositoryProvider);
  return repo.getProfile();
});
