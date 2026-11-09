import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_number.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/progress_ring.dart';
import '../domain/daily_log.dart';
import '../../arcs/widgets/arc_calendar.dart';

/// Streak stats, the arc calendar, and this week at a glance.
class ConsistencyCard extends StatelessWidget {
  const ConsistencyCard({
    super.key,
    required this.scores,
    required this.current,
    required this.longest,
    this.freezes = 0,
  });

  final Map<DateTime, DayScore> scores;
  final int current;
  final int longest;

  /// Streak freezes saved up (one per 7 days in a row, at most 2).
  final int freezes;

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final perfect = scores.values.where((s) => s.count == DayScore.total).length;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                _Stat(
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.steps,
                  value: current,
                  label: 'Day streak',
                ),
                const _Divider(),
                _Stat(icon: Icons.emoji_events_rounded, color: AppColors.gold, value: longest, label: 'Best streak'),
                const _Divider(),
                _Stat(icon: Icons.verified_rounded, color: AppColors.primary, value: perfect, label: 'Perfect days'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Tooltip(
            message: 'Every 7 days in a row earns a streak freeze (keep up to 2). '
                'If you miss a day, a freeze saves your streak automatically.',
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 5),
            child: Row(
              children: [
                Text('❄️', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    freezes == 0
                        ? 'Streak freeze: earn one with 7 days in a row'
                        : '$freezes streak freeze${freezes == 1 ? '' : 's'} ready: a missed day won\'t break your streak',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ArcCalendar(scores: scores),
          const SizedBox(height: 16),
          _WeekStrip(scores: scores, today: today),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 4),
              AnimatedNumber(value, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 4), color: AppColors.stroke);
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.scores, required this.today});

  final Map<DateTime, DayScore> scores;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final monday = addDays(today, -(today.weekday - 1));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final day = addDays(monday, i);
                  final future = day.isAfter(today);
                  final isToday = day == today;
                  final count = scores[day]?.count ?? 0;
                  final perfect = count == DayScore.total;
                  return Column(
                    children: [
                      Text(
                        DateFormat.E().format(day).substring(0, 1),
                        style: text.labelSmall?.copyWith(
                          color: isToday ? AppColors.primary : AppColors.textTertiary,
                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ProgressRing(
                        progress: future ? 0 : count / DayScore.total,
                        color: AppColors.primary,
                        secondaryColor: AppColors.accent,
                        size: 34,
                        stroke: 3.5,
                        child: perfect
                            ? Icon(Icons.check_rounded, size: 16, color: AppColors.primary)
                            : Text(
                                '${day.day}',
                                style: text.labelMedium?.copyWith(
                                  color: future ? AppColors.textMuted : AppColors.textPrimary,
                                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
