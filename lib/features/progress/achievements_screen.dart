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

  void _levels(BuildContext context, Level now) {
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
            for (var i = 0; i < badgeSets; i++)
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
                      onPressed: () => _levels(context, level),
                      icon: const Icon(Icons.format_list_numbered_rounded, size: 18),
                      label: const Text('All levels and XP'),
                    ),
                  ),
                  Text(
                    'Earn XP for every goal you hit: 10 per goal, 20 extra for a perfect day, plus a bonus for '
                    'each day your streak stays alive. Finishing a whole badge set pays extra, and so does finishing a '
                    'challenge together with a friend (50 XP, up to 3 a week).',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            for (var set = 1; set <= badgeSets; set++) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: _SetHeader(
                    set: set,
                    earned: earned.keys.where((k) => k.set == set).length,
                    open: set <= done + 1,
                    finished: set <= done,
                    bonus: f.format(badgeSetBonusXp[set - 1]),
                  ),
                ),
              ),
              if (set <= done + 1)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid.builder(
                    itemCount: Achievement.values.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      mainAxisExtent: 142,
                    ),
                    itemBuilder: (_, i) {
                      // Earned first (most recent first), then the rest in order.
                      final order = [...Achievement.values]
                        ..sort((a, b) {
                          final ea = earned[(kind: a, set: set)], eb = earned[(kind: b, set: set)];
                          if (ea != null && eb != null) return eb.compareTo(ea);
                          if (ea != null) return -1;
                          if (eb != null) return 1;
                          return a.index.compareTo(b.index);
                        });
                      final key = (kind: order[i], set: set);
                      return AchievementTile(badge: key, earnedOn: earned[key])
                          .animate(delay: (i * 25).ms)
                          .fadeIn(duration: 250.ms)
                          .moveY(begin: 6, end: 0, curve: Curves.easeOutCubic);
                    },
                  ),
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
    required this.open,
    required this.finished,
    required this.bonus,
  });

  final int set;
  final int earned;
  final bool open;
  final bool finished;
  final String bonus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(
          finished
              ? Icons.verified_rounded
              : open
              ? Icons.emoji_events_outlined
              : Icons.lock_outline_rounded,
          color: open ? AppColors.primary : AppColors.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set $set · ${badgeSetNames[set - 1]}', style: text.titleMedium),
              Text(
                !open
                    ? 'Finish set ${set - 1} to unlock · +$bonus XP'
                    : finished
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
