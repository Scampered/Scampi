import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/repositories/repository_providers.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'app_shell.dart';

/// Decides whether to show onboarding (no profile saved yet) or the
/// main app shell. Reactively watches [hasProfileProvider], which in
/// turn watches the data-refresh signal — so both finishing onboarding
/// and wiping all data (Profile → Reset All Data) automatically flip
/// this gate without any manual navigation.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProfileAsync = ref.watch(hasProfileProvider);

    return hasProfileAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text("Couldn't load: $err")),
      ),
      data: (hasProfile) {
        if (hasProfile) return const AppShell();
        // onComplete is a no-op here — hasProfileProvider re-fetching
        // (triggered by the signal bump inside OnboardingScreen._save)
        // is what actually swaps this gate over to AppShell.
        return OnboardingScreen(onComplete: () {});
      },
    );
  }
}
