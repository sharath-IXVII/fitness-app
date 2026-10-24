import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import 'domain/progress.dart';

/// Level number, title and XP bar.
class LevelBar extends StatelessWidget {
  const LevelBar({super.key, required this.level, this.compact = false});

  final Level level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final f = NumberFormat.decimalPattern();
    return Row(
      children: [
        Container(
          width: compact ? 44 : 56,
          height: compact ? 44 : 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(16)),
          child: Text(
            '${level.number}',
            style: (compact ? text.titleLarge : text.headlineSmall)?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Level ${level.number} · ${level.title}', style: text.titleSmall)),
                  Text('${f.format(level.xp)} XP', style: text.labelMedium),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: level.progress.clamp(0, 1)),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 7,
                    color: AppColors.primary,
                    backgroundColor: AppColors.surfaceHigh,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text('${f.format(level.toNext)} XP to level ${level.number + 1}', style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class AchievementTile extends StatelessWidget {
  const AchievementTile({super.key, required this.badge, this.earnedOn});

  final BadgeKey badge;
  final DateTime? earnedOn;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final earned = earnedOn != null;
    final info = badge.kind.info(badge.set);
    final achievement = badge.kind;
    return Semantics(
      label: '${info.title}, ${earned ? 'earned' : 'locked'}. ${info.description}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: earned ? AppColors.primary.withValues(alpha: 0.3) : AppColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: earned ? AppColors.brandGradient : null,
                color: earned ? null : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                earned ? achievement.icon : Icons.lock_outline_rounded,
                size: 20,
                color: earned ? Colors.white : AppColors.textMuted,
              ),
            ),
            const Spacer(),
            Text(
              info.title,
              style: text.titleSmall?.copyWith(color: earned ? AppColors.textPrimary : AppColors.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              earned ? 'Earned ${DateFormat.MMMd().format(earnedOn!)}' : info.description,
              style: text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
