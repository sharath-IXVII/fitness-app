import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_background.dart';
import '../../../core/widgets/pressable.dart';
import '../arc_providers.dart';
import '../domain/arc.dart';

/// A round medal for an arc badge: the season's colours and icon inside a
/// bronze, silver or gold ring. Grey when [tier] isn't earned.
class ArcMedal extends StatelessWidget {
  const ArcMedal({super.key, required this.season, required this.tier, this.earned = true, this.size = 64});

  final Season season;
  final ArcTier tier;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = season.palette;
    final ring = earned ? tier.ring : AppColors.stroke;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.07),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: earned
            ? LinearGradient(
                colors: [Color.lerp(ring, Colors.white, 0.45)!, ring],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: earned ? null : AppColors.surfaceHigh,
        boxShadow: earned
            ? [BoxShadow(color: ring.withValues(alpha: 0.45), blurRadius: size * 0.25, spreadRadius: -4)]
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: earned
              ? LinearGradient(colors: [p.inkSoft, p.primary], begin: Alignment.topCenter, end: Alignment.bottomCenter)
              : null,
          color: earned ? null : AppColors.surface,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(season.icon, size: size * 0.42, color: earned ? Colors.white : AppColors.textMuted),
            Positioned(
              bottom: size * 0.08,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i <= tier.index; i++)
                    Icon(Icons.star_rounded, size: size * 0.14, color: earned ? ring : AppColors.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The arc happening now, for the top of Today: name, day of the arc and
/// the badge in reach. Opens the arc page.
class ArcCard extends ConsumerWidget {
  const ArcCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final arc = ref.watch(currentArcProvider);
    final r = ref.watch(currentArcResultProvider);
    final today = ref.watch(todayProvider);
    final day = today.difference(arc.start).inDays + 1;
    // While previewing another arc's look, the card wears it too.
    final look = ref.watch(themeSeasonProvider);
    final previewing = look != arc.season;
    final target = r.target;
    final status = r.earned == ArcTier.master
        ? 'Master badge secured!'
        : target == null
        ? 'Keep going: every active day counts'
        : '${r.active} active days · ${arc.season.tierName(target)} needs ${r.needed(target)}';

    return Pressable(
      onTap: () => context.push(Routes.arc),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.inkSoft, AppColors.ink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: ArcWeather(effect: look.effect, dark: true, count: 14)),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            previewing ? 'PREVIEW · ${look.months.toUpperCase()}' : 'DAY $day OF ${arc.totalDays}',
                            style: text.labelSmall?.copyWith(color: AppColors.energyLight, letterSpacing: 1.4),
                          ),
                          const SizedBox(height: 2),
                          Text(look.title, style: text.headlineSmall?.copyWith(color: Colors.white)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: day / arc.totalDays,
                              minHeight: 6,
                              backgroundColor: Colors.white12,
                              color: AppColors.energy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(status, style: text.bodySmall?.copyWith(color: Colors.white70)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ArcMedal(
                      season: look,
                      tier: r.earned ?? target ?? ArcTier.survivor,
                      earned: r.earned != null,
                      size: 62,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Arc badges on the profile: earned medals, or the current arc's first
/// badge as something to aim for. Opens the arc page.
class ArcBadgeShelf extends ConsumerWidget {
  const ArcBadgeShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final badges = ref.watch(arcBadgesProvider);
    final arc = ref.watch(currentArcProvider);
    final r = ref.watch(currentArcResultProvider);
    return Pressable(
      onTap: () => context.push(Routes.arcBadges),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.stroke),
          boxShadow: AppColors.softShadow(),
        ),
        child: Row(
          children: [
            if (badges.isEmpty)
              ArcMedal(season: arc.season, tier: r.earned ?? ArcTier.survivor, earned: r.earned != null, size: 52)
            else
              for (final (p, t) in badges.take(3))
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ArcMedal(season: p.season, tier: t, size: 52),
                ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badges.isEmpty ? 'Arc badges' : '${badges.length} arc badge${badges.length == 1 ? '' : 's'}',
                    style: text.titleSmall,
                  ),
                  Text(
                    badges.isEmpty
                        ? 'Earn your first in the ${arc.season.title}'
                        : badges.first.$1.badgeName(badges.first.$2),
                    style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// The best arc badge as a title under a name, e.g. "Master of Winter 2026".
/// Shows nothing until a badge is earned.
class BadgeTitle extends ConsumerWidget {
  const BadgeTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final best = ref.watch(bestBadgeProvider);
    if (best == null) return const SizedBox.shrink();
    final (period, tier) = best;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
        decoration: BoxDecoration(
          color: tier.ring.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tier.ring.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArcMedal(season: period.season, tier: tier, size: 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                period.badgeName(tier),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
