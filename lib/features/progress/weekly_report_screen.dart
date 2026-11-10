import '../../core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/week_bars.dart';
import '../streaks/domain/daily_log.dart';
import 'progress_providers.dart';

/// The last 7 days at a glance, compared with the week before.
class WeeklyReportScreen extends ConsumerWidget {
  const WeeklyReportScreen({super.key});

  static const _focusTip = {
    DailyTask.workout:
        'Workouts were the hardest to fit in. Try an earlier alarm or the Beginner routine on busy days.',
    DailyTask.water: 'Water was the goal you missed most. Turn on water reminders or keep a bottle on your desk.',
    DailyTask.steps: 'Steps were the goal you missed most. A 15-minute walk after lunch adds around 1,800 steps.',
    DailyTask.diet: 'Meal logging slipped. Open Diet from the Meals card on Today and snap each meal with the camera.',
    DailyTask.protein: 'Protein fell short. Add curd, paneer, dal, eggs or a shake to one meal a day.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final r = ref.watch(weekReportProvider);
    if (r == null) return const SizedBox.shrink();
    final f = NumberFormat.decimalPattern();
    final range = '${DateFormat.MMMd().format(r.start)} – ${DateFormat.MMMd().format(r.end)}';
    final best = r.bestDay;

    final sections = <Widget>[
      Text(range, style: text.bodyMedium),
      const SizedBox(height: 14),
      GlassCard(
        child: Row(
          children: [
            ProgressRing(
              progress: r.completion,
              color: AppColors.primary,
              size: 96,
              stroke: 10,
              child: Text('${(r.completion * 100).round()}%', style: text.titleLarge),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(switch (r.completion) {
                    >= 0.8 => 'An excellent week',
                    >= 0.6 => 'A strong week',
                    >= 0.3 => 'A steady week',
                    _ => 'A quiet week',
                  }, style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text('of all your daily goals completed · +${f.format(r.xp)} XP', style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          _Compare(label: tr('Workouts'), value: r.workouts, previous: r.prevWorkouts),
          const SizedBox(width: 10),
          _Compare(label: tr('Streak days'), value: r.streakDays, previous: r.prevStreakDays),
          const SizedBox(width: 10),
          _Compare(label: tr('Steps'), value: r.steps, previous: r.prevSteps, compactNumber: true),
        ],
      ),
      const SizedBox(height: 22),
      Text(tr('Goals hit'), style: text.titleMedium),
      const SizedBox(height: 10),
      GlassCard(
        child: Column(
          children: [
            _Pillar(icon: Icons.fitness_center_rounded, label: tr('Workout'), days: r.workouts),
            _Pillar(icon: Icons.water_drop_outlined, label: tr('Water'), days: r.waterDays),
            _Pillar(icon: Icons.directions_walk_rounded, label: tr('Steps'), days: r.stepDays),
            _Pillar(icon: Icons.restaurant_outlined, label: tr('3+ meals logged'), days: r.mealDays),
            _Pillar(icon: Icons.egg_alt_outlined, label: tr('Protein'), days: r.proteinDays, last: true),
          ],
        ),
      ),
      const SizedBox(height: 22),
      Text(tr('Steps'), style: text.titleMedium),
      const SizedBox(height: 10),
      GlassCard(
        child: WeekBars(
          days: [for (final d in r.days) (d.date, d.steps)],
          goal: r.targets.steps,
          format: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : '$v',
        ),
      ),
      const SizedBox(height: 14),
      if (best != null)
        _Line(
          icon: Icons.star_outline_rounded,
          text:
              'Best day: ${DateFormat.EEEE().format(best.date)}, '
              '${DayScore.of(best, r.targets).count} of ${DayScore.total} goals.',
        ),
      _Line(icon: Icons.lightbulb_outline_rounded, text: _focusTip[r.focus]!),
      const SizedBox(height: 32),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(tr('Your week'))),
      body: PageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          children: [
            for (final (i, s) in sections.indexed)
              s.animate(delay: (i * 30).ms).fadeIn(duration: 280.ms).moveY(begin: 6, end: 0),
          ],
        ),
      ),
    );
  }
}

class _Compare extends StatelessWidget {
  const _Compare({required this.label, required this.value, required this.previous, this.compactNumber = false});

  final String label;
  final int value;
  final int previous;
  final bool compactNumber;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fmt = compactNumber ? NumberFormat.compact() : NumberFormat.decimalPattern();
    final diff = value - previous;
    final up = diff > 0;
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmt.format(value), style: text.titleLarge),
            Text(label, style: text.bodySmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  diff == 0
                      ? Icons.remove_rounded
                      : up
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 14,
                  color: diff == 0
                      ? AppColors.textMuted
                      : up
                      ? AppColors.primary
                      : AppColors.danger,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    diff == 0 ? 'same' : '${fmt.format(diff.abs())} vs last',
                    style: text.labelSmall?.copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
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

class _Pillar extends StatelessWidget {
  const _Pillar({required this.icon, required this.label, required this.days, this.last = false});

  final IconData icon;
  final String label;
  final int days;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: text.bodyLarge)),
          for (var i = 0; i < 7; i++)
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: i < days ? AppColors.primary : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          SizedBox(
            width: 34,
            child: Text('$days/7', textAlign: TextAlign.right, style: text.labelMedium),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
