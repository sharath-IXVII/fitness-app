import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import 'domain/progress.dart';
import 'progress_providers.dart';
import 'widgets.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final level = ref.watch(levelProvider);
    final earned = ref.watch(achievementsProvider);
    // Earned first (most recent first), then locked in definition order.
    final list = [...Achievement.values]
      ..sort((a, b) {
        final ea = earned[a], eb = earned[b];
        if (ea != null && eb != null) return eb.compareTo(ea);
        if (ea != null) return -1;
        if (eb != null) return 1;
        return a.index.compareTo(b.index);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: PageBackground(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverList.list(
                children: [
                  GlassCard(child: LevelBar(level: level)),
                  const SizedBox(height: 12),
                  Text(
                    'Earn XP for every goal you hit: 10 per goal, 20 extra for a perfect day, plus a bonus for '
                    'each day your streak stays alive.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 22),
                  Text('${earned.length} of ${Achievement.values.length} earned', style: text.titleMedium),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverGrid.builder(
                itemCount: list.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 142,
                ),
                itemBuilder: (_, i) => AchievementTile(achievement: list[i], earnedOn: earned[list[i]])
                    .animate(delay: (i * 25).ms)
                    .fadeIn(duration: 250.ms)
                    .moveY(begin: 6, end: 0, curve: Curves.easeOutCubic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
