import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import 'arc_providers.dart';
import 'domain/arc.dart';
import 'widgets/arc_widgets.dart';

/// Every arc badge for five years: earned ones in colour, the rest waiting.
class BadgeCollectionScreen extends ConsumerWidget {
  const BadgeCollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final now = ref.watch(currentArcProvider);
    final current = ref.watch(currentArcResultProvider);
    final earned = {for (final (p, t) in ref.watch(arcBadgesProvider)) p: t};
    final catalog = arcCatalog();
    final total = catalog.length * ArcTier.values.length;
    final count = earned.values.fold(0, (a, t) => a + t.index + 1) + (current.earned?.index ?? -1) + 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Badge collection')),
      body: PageBackground(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('$count of $total badges', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Each arc has three badges. Earn the top one and you also hold the two below it.',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final p in catalog) ...[
              _ArcRow(
                period: p,
                tier: p == now ? current.earned : earned[p],
                isNow: p == now,
                upcoming: p.start.isAfter(now.start),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArcRow extends StatelessWidget {
  const _ArcRow({required this.period, required this.tier, required this.isNow, required this.upcoming});

  final ArcPeriod period;

  /// Highest badge earned in this arc, if any.
  final ArcTier? tier;
  final bool isNow;
  final bool upcoming;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = period.season;
    final status = isNow
        ? 'Happening now'
        : upcoming
        ? 'Starts ${DateFormat('d MMM yyyy').format(period.start)}'
        : tier == null
        ? 'Ended'
        : period.badgeName(tier!);
    return Opacity(
      opacity: upcoming ? 0.7 : 1,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        glow: isNow ? s.palette.primary : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(s.icon, size: 18, color: s.palette.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(period.label, style: text.titleSmall)),
                Text(
                  status,
                  style: text.labelMedium?.copyWith(color: isNow ? s.palette.primary : AppColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final t in ArcTier.values)
                  Expanded(
                    child: Column(
                      children: [
                        ArcMedal(season: s, tier: t, earned: tier != null && tier!.index >= t.index, size: 52),
                        const SizedBox(height: 4),
                        Text(s.tierName(t), style: text.labelSmall, textAlign: TextAlign.center, maxLines: 2),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
