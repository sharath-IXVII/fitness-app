import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../diet/widgets/sheet_frame.dart';
import 'domain/health.dart';
import 'domain/report.dart';
import 'health_providers.dart';
import 'widgets/add_reading_sheet.dart';
import 'widgets/health_widgets.dart';

/// Health: blood pressure, blood sugar, pulse and oxygen from real devices,
/// sorted by the standard ranges, with the 7-day home blood pressure method.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  Future<void> _add(BuildContext context, ReadingKind kind) async {
    final r = await SheetFrame.show<HealthReading>(context, AddReadingSheet(kind: kind));
    if (r == null || !context.mounted) return;
    final rating = r.rating;
    if (rating.needsCare) {
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: rating.level.color, size: 36),
          title: Text('${r.kind.label}: ${rating.label}'),
          content: Text(rating.advice),
          actions: [TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('I understand'))],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: ${r.display} · ${rating.label}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final all = ref.watch(healthLogProvider);

    final sections = <Widget>[
      Text('Health', style: text.headlineMedium),
      Text('Your own readings, understood.', style: text.bodyMedium),
      const SizedBox(height: 14),
      const _HonestNote(),
      const SizedBox(height: 16),
      const _HomeBpCard(),
      const SizedBox(height: 22),
      Text('Add a reading', style: text.titleLarge),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
        children: [
          for (final k in ReadingKind.values) _AddTile(kind: k, onTap: () => _add(context, k)),
        ],
      ),
      const SizedBox(height: 22),
      for (final k in ReadingKind.values) ...[_KindCard(kind: k), const SizedBox(height: 12)],
      if (all.isNotEmpty) ...[
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => SharePlus.instance.share(ShareParams(text: buildReport(all, clock.now()))),
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('Share a summary with my doctor'),
        ),
      ],
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () => SheetFrame.show<void>(context, const _MeasureWellSheet()),
        icon: const Icon(Icons.help_outline_rounded, size: 18),
        label: const Text('How to measure accurately'),
      ),
      const SizedBox(height: 32),
    ];

    return PageBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          children: [
            for (final (i, s) in sections.indexed)
              s.animate(delay: (i < 8 ? i * 30 : 0).ms).fadeIn(duration: 300.ms).moveY(begin: 8, end: 0),
          ],
        ),
      ),
    );
  }
}

class _HonestNote extends StatelessWidget {
  const _HonestNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fittarc does not measure these itself. A phone cannot measure blood pressure accurately. Type in '
              'what your own monitor, glucometer or oximeter shows, and Fittarc sorts it by medical guidelines. '
              'This is not medical advice.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// The 7-day home blood pressure method.
class _HomeBpCard extends ConsumerWidget {
  const _HomeBpCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final s = ref.watch(homeBpProvider);
    final progress = (s.count / s.needed).clamp(0.0, 1.0);
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('7-day home blood pressure', style: text.titleMedium)),
              if (s.rating != null && s.complete) RatingChip(rating: s.rating!),
            ],
          ),
          const SizedBox(height: 12),
          if (!s.hasAverage) ...[
            Text(
              'One reading is not enough to judge blood pressure. Doctors advise measuring twice every morning and '
              'evening for 7 days, then looking at the average.',
              style: text.bodyMedium,
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${s.avgSystolic}/${s.avgDiastolic}', style: text.displaySmall),
                const SizedBox(width: 6),
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('mmHg average', style: text.bodySmall)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.surfaceHigh,
                color: s.complete ? AppColors.primary : AppColors.amber,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.complete
                  ? '${s.count} readings over ${s.days} days. ${s.rating!.advice}'
                  : '${s.count} of ${s.needed} readings so far. Keep going for a reliable average.',
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _AddTile extends ConsumerWidget {
  const _AddTile({required this.kind, required this.onTap});

  final ReadingKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(kind.icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(kind.label, style: text.titleSmall)),
            Icon(Icons.add_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// The latest reading of one kind, its trend, and the history.
class _KindCard extends ConsumerWidget {
  const _KindCard({required this.kind});

  final ReadingKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(readingsOfProvider(kind));
    if (list.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final latest = list.first;
    final rating = latest.rating;
    return Pressable(
      onTap: () => SheetFrame.show<void>(context, _HistorySheet(kind: kind)),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        glow: rating.needsCare ? rating.level.color : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(kind.icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(kind.label, style: text.titleSmall)),
                RatingChip(rating: rating),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(latest.display, style: text.headlineMedium),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${kind.unit} · ${_when(latest.at)}',
                    style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Sparkline(kind: kind, readings: list),
          ],
        ),
      ),
    );
  }
}

String _when(DateTime at) {
  final now = clock.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final time = DateFormat('h:mm a').format(at);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'today $time';
  if (diff == 1) return 'yesterday $time';
  return '${DateFormat('d MMM').format(at)} $time';
}

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet({required this.kind});

  final ReadingKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final list = ref.watch(readingsOfProvider(kind));
    return SheetFrame(
      title: kind.label,
      child: list.isEmpty
          ? Padding(padding: const EdgeInsets.all(24), child: Text('No readings yet.', style: text.bodyMedium))
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Text(list.first.rating.advice, style: text.bodyMedium),
                const SizedBox(height: 10),
                for (final r in list.take(60))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Row(
                      children: [
                        Text('${r.display} ${kind.unit}', style: text.titleSmall),
                        const SizedBox(width: 10),
                        RatingChip(rating: r.rating),
                      ],
                    ),
                    subtitle: Text(
                      [
                        _when(r.at),
                        if (r.pulse != null) 'pulse ${r.pulse}',
                        if (r.context != null) r.context!.label.toLowerCase(),
                      ].join(' · '),
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete this reading',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref.read(healthLogProvider.notifier).remove(r.id);
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MeasureWellSheet extends StatelessWidget {
  const _MeasureWellSheet();

  static const _steps = [
    ('Blood pressure', Icons.favorite_rounded, [
      'Use an upper-arm monitor that has been validated. Wrist and finger devices are less reliable.',
      'No coffee, exercise or smoking for 30 minutes. Use the toilet first.',
      'Sit with your back supported, feet flat, arm resting on a table at heart level, cuff on bare skin.',
      'Rest quietly for 5 minutes. Do not talk while measuring.',
      'Take 2 readings, 1 minute apart, in the morning before medicines and in the evening. Do this for 7 days.',
    ]),
    ('Blood sugar', Icons.water_drop_rounded, [
      'Wash and dry your hands. Use a fresh strip that is in date.',
      'Fasting means at least 8 hours without food. After a meal means 2 hours after the first bite.',
    ]),
    ('Oxygen and pulse', Icons.air_rounded, [
      'Warm, still hand. Remove nail polish. Rest for 5 minutes, sitting.',
      'Wait until the number is steady for about 10 seconds before you read it.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SheetFrame(
      title: 'Measuring accurately',
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          for (final (title, icon, points) in _steps) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(title, style: text.titleSmall),
                ],
              ),
            ),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(p, style: text.bodyMedium)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Text(
            'Fittarc sorts readings by AHA/ACC blood pressure ranges and ADA blood sugar ranges. A single high '
            'reading is not a diagnosis. See a doctor if you are worried, and call emergency services (112 in '
            'India) for chest pain, trouble breathing or sudden weakness.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
