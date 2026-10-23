import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import 'arc_providers.dart';
import 'domain/arc.dart';
import 'widgets/arc_widgets.dart';

/// The current arc: progress, the three badges in reach, the year's arcs
/// and every arc badge earned so far.
class ArcScreen extends ConsumerWidget {
  const ArcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final arc = ref.watch(currentArcProvider);
    final r = ref.watch(currentArcResultProvider);
    final today = ref.watch(todayProvider);
    final badges = ref.watch(arcBadgesProvider);
    final preview = ref.watch(arcPreviewProvider);
    final day = today.difference(arc.start).inDays + 1;
    final dates = DateFormat('d MMM');
    final lateStart = r.from.isAfter(arc.start);

    return Scaffold(
      appBar: AppBar(title: Text(arc.label)),
      body: PageBackground(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
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
                    Positioned.fill(child: ArcWeather(effect: arc.season.effect, dark: true)),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(arc.season.icon, color: AppColors.energyLight, size: 34),
                          const SizedBox(height: 10),
                          Text(arc.season.title, style: text.displaySmall?.copyWith(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(arc.season.tagline, style: text.bodyLarge?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 16),
                          Text(
                            '${dates.format(arc.start)} – ${dates.format(arc.lastDay)} ${arc.year}  ·  '
                            'Day $day of ${arc.totalDays}',
                            style: text.labelLarge?.copyWith(color: AppColors.energyLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${r.active}', style: text.displaySmall?.copyWith(color: AppColors.primary)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('active days of ${r.eligible}', style: text.titleSmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _TierBar(result: r),
                  const SizedBox(height: 10),
                  Text(
                    'An active day is one where you hit at least 3 of your 5 daily goals.'
                    '${lateStart ? ' Your arc counts from ${dates.format(r.from)}, the day you joined.' : ''}',
                    style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('Badges this arc', style: text.titleLarge),
            const SizedBox(height: 10),
            for (final t in ArcTier.values) ...[_TierRow(result: r, tier: t), const SizedBox(height: 10)],
            const SizedBox(height: 14),
            Text('Your arc badges', style: text.titleLarge),
            const SizedBox(height: 10),
            if (badges.isEmpty)
              Text(
                'Finish an arc to keep its badge forever. Your first one: ${arc.label}.',
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              )
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final (p, t) in badges)
                    SizedBox(
                      width: 96,
                      child: Column(
                        children: [
                          ArcMedal(season: p.season, tier: t, size: 72),
                          const SizedBox(height: 6),
                          Text(p.badgeName(t), style: text.labelMedium, textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 26),
            Text('The year in arcs', style: text.titleLarge),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (final s in [Season.winter, Season.revolution, Season.summer, Season.monsoon])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: s.palette.primarySoft, shape: BoxShape.circle),
                            child: Icon(s.icon, color: s.palette.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.title, style: text.titleSmall),
                                Text(s.months, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          if (s == arc.season)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Now', style: text.labelMedium?.copyWith(color: AppColors.primary)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text('Preview a look', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'The look changes by itself with each arc. Try the others here.',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoicePill(
                  label: 'Automatic',
                  selected: preview == null,
                  onTap: () => ref.read(arcPreviewProvider.notifier).set(null),
                ),
                for (final s in Season.values)
                  ChoicePill(
                    label: s.title,
                    selected: preview == s,
                    onTap: () => ref.read(arcPreviewProvider.notifier).set(s),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress across the arc with markers where each badge unlocks.
class _TierBar extends StatelessWidget {
  const _TierBar({required this.result});

  final ArcResult result;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SizedBox(
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 7,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: result.share.clamp(0, 1),
                minHeight: 8,
                backgroundColor: AppColors.surfaceHigh,
                color: AppColors.primary,
              ),
            ),
          ),
          for (final t in ArcTier.values)
            Positioned(
              left: (box.maxWidth * t.share - 11).clamp(0, box.maxWidth - 22),
              top: 0,
              child: Icon(
                Icons.star_rounded,
                size: 22,
                color: result.earned != null && result.earned!.index >= t.index ? t.ring : AppColors.stroke,
              ),
            ),
        ],
      ),
    ),
  );
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.result, required this.tier});

  final ArcResult result;
  final ArcTier tier;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final season = result.period.season;
    final need = result.needed(tier);
    final secured = result.earned != null && result.earned!.index >= tier.index;
    final reachable = result.reachable(tier);
    final (label, color) = secured
        ? ('Secured', AppColors.primary)
        : reachable
        ? ('${need - result.active} to go', AppColors.amber)
        : ('Out of reach', AppColors.textMuted);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ArcMedal(season: season, tier: tier, earned: secured, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.period.badgeName(tier), style: text.titleSmall),
                Text(
                  tier == ArcTier.master ? 'Active every single day' : 'Active on $need of ${result.eligible} days',
                  style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(label, style: text.labelMedium?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}
