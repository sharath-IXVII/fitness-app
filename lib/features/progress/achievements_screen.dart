import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import 'domain/progress.dart';
import 'progress_providers.dart';
import 'widgets.dart';

/// Level, XP and the badge sets. Set 1 (Starter) is open from day one;
/// finishing all 12 of a set pays a XP bonus and opens the next, harder set.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  void _levels(BuildContext context, Level now, int openSets) {
    final text = Theme.of(context).textTheme;
    final f = NumberFormat.decimalPattern();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text('All levels', style: text.titleLarge),
            const SizedBox(height: 4),
            Text('XP you need to reach each level.', style: text.bodySmall),
            const SizedBox(height: 12),
            for (final l in Level.table())
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: l.number <= now.number ? AppColors.primary : AppColors.surfaceHigh,
                  child: Text(
                    '${l.number}',
                    style: text.labelMedium?.copyWith(
                      color: l.number <= now.number ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
                title: Text(l.title, style: text.titleSmall),
                trailing: Text(l.xp == 0 ? 'Start' : '${f.format(l.xp)} XP', style: text.labelLarge),
                selected: l.number == now.number,
              ),
            const Divider(height: 28),
            Text('Badge set bonuses', style: text.titleMedium),
            const SizedBox(height: 4),
            Text('Finish all 12 badges of a set for bonus XP and to open the next set.', style: text.bodySmall),
            const SizedBox(height: 8),
            for (var i = 0; i < openSets && i < badgeSets; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.emoji_events_rounded, color: AppColors.primary),
                title: Text('Set ${i + 1} · ${badgeSetNames[i]}', style: text.titleSmall),
                trailing: Text('+${f.format(badgeSetBonusXp[i])} XP', style: text.labelLarge),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final level = ref.watch(levelProvider);
    final earned = ref.watch(achievementsProvider);
    final done = ref.watch(completedSetsProvider);
    final f = NumberFormat.decimalPattern();

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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _levels(context, level, done + 1),
                      icon: const Icon(Icons.format_list_numbered_rounded, size: 18),
                      label: const Text('All levels and XP'),
                    ),
                  ),
                  Text(
                    'Earn XP for every goal you hit: 10 per goal, 20 extra for a perfect day, plus a bonus for '
                    'each day your streak stays alive. Finishing a whole badge set pays extra.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // Later sets and badges you haven't earned yet stay hidden, so
            // each new one is a surprise when it appears.
            for (var set = 1; set <= badgeSets && set <= done + 1; set++) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: _SetHeader(
                    set: set,
                    earned: earned.keys.where((k) => k.set == set).length,
                    finished: set <= done,
                    bonus: f.format(badgeSetBonusXp[set - 1]),
                  ),
                ),
              ),
              Builder(
                builder: (_) {
                  // Most recent first.
                  final mine = [
                    for (final k in earned.keys)
                      if (k.set == set) k,
                  ]..sort((a, b) => earned[b]!.compareTo(earned[a]!));
                  if (mine.isEmpty) {
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Your next badge is a surprise. Keep hitting your goals and it will appear here.',
                          style: text.bodySmall,
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid.builder(
                      itemCount: mine.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: 142,
                      ),
                      itemBuilder: (_, i) =>
                          AchievementTile(badge: mine[i], earnedOn: earned[mine[i]])
                              .animate(delay: (i * 25).ms)
                              .fadeIn(duration: 250.ms)
                              .moveY(begin: 6, end: 0, curve: Curves.easeOutCubic),
                    ),
                  );
                },
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _SetHeader extends StatelessWidget {
  const _SetHeader({
    required this.set,
    required this.earned,
    required this.finished,
    required this.bonus,
  });

  final int set;
  final int earned;
  final bool finished;
  final String bonus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(finished ? Icons.verified_rounded : Icons.emoji_events_outlined, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set $set · ${badgeSetNames[set - 1]}', style: text.titleMedium),
              Text(
                finished
                    ? 'Complete · +$bonus XP earned'
                    : '$earned of ${Achievement.values.length} earned · +$bonus XP when all 12 are done',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
