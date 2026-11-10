import '../../core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pressable.dart';
import 'domain/progress.dart';
import 'progress_providers.dart';
import 'widgets.dart';

/// Home card: level and XP, with links to achievements and the weekly report.
class ProgressCard extends ConsumerWidget {
  const ProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(levelProvider);
    final all = ref.watch(achievementsProvider).keys;
    final done = ref.watch(completedSetsProvider);
    final set = (done + 1).clamp(1, badgeSets);
    final inSet = all.where((k) => k.set == set).length;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        children: [
          Pressable(
            onTap: () => context.push(Routes.achievements),
            child: LevelBar(level: level, compact: true),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => context.push(Routes.achievements),
                  icon: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: Text('$inSet/${Achievement.values.length} ${badgeSetNames[set - 1]} badges'),
                ),
              ),
              Container(width: 1, height: 22, color: AppColors.stroke),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => context.push(Routes.report),
                  icon: const Icon(Icons.insights_rounded, size: 18),
                  label: Text(tr('Your week')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
