import 'package:flutter/material.dart';
import '../../../shared/widgets/shimmer_box.dart';

/// Skeleton loading state for the Home screen, shown only on genuine
/// first load (not on background refreshes after logging food/water/
/// exercise — those keep the previous data visible, see home_screen.dart).
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const ShimmerBox(width: 160, height: 24),
        const SizedBox(height: 24),
        const Center(
          child: ShimmerBox(
            width: 220,
            height: 220,
            borderRadius: 110,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            4,
            (_) => const ShimmerBox(width: 48, height: 32),
          ),
        ),
        const SizedBox(height: 24),
        const ShimmerBox(height: 140, borderRadius: 24),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: List.generate(
            4,
            (_) => const ShimmerBox(borderRadius: 24),
          ),
        ),
      ],
    );
  }
}
