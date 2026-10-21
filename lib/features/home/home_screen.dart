import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_number.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_ring.dart';
import '../profile/domain/health_targets.dart';
import '../alarm/alarm_providers.dart';
import '../profile/profile_providers.dart';
import '../streaks/daily_log_providers.dart';
import '../streaks/domain/daily_log.dart';
import '../streaks/widgets/consistency_card.dart';
import '../workout/routine_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final targets = ref.watch(targetsProvider);
    if (profile == null || targets == null) return const SizedBox.shrink();

    final log = ref.watch(todayLogProvider);
    final score = DayScore.of(log, targets);
    final streak = ref.watch(streakProvider);
    final scores = ref.watch(dayScoresProvider);

    final sections = <Widget>[
      _Header(name: profile.name, streak: streak.current),
      const SizedBox(height: 24),
      _ScoreCard(score: score),
      const SizedBox(height: 14),
      const _NextAlarmCard(),
      const SizedBox(height: 28),
      const _SectionTitle('Today'),
      const SizedBox(height: 12),
      _TaskGrid(log: log, targets: targets, score: score),
      const SizedBox(height: 28),
      const _SectionTitle('Consistency'),
      const SizedBox(height: 12),
      ConsistencyCard(scores: scores, current: streak.current, longest: streak.longest),
      const SizedBox(height: 120),
    ];

    return AuroraBackground(
      intensity: 0.09,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          children: [
            for (final (i, s) in sections.indexed)
              s.animate(delay: (i * 45).ms).fadeIn(duration: 500.ms).slideY(begin: 0.06, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.streak});

  final String name;
  final int streak;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase(),
                style: text.labelSmall?.copyWith(color: AppColors.textMuted, letterSpacing: 1.4),
              ),
              const SizedBox(height: 4),
              Text('$_greeting,\n${name.split(' ').first}', style: text.headlineMedium?.copyWith(height: 1.15)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.steps.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.steps.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: AppColors.steps, size: 22)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.9, end: 1.1, duration: 700.ms, curve: Curves.easeInOut),
              const SizedBox(width: 6),
              AnimatedNumber(streak, style: text.titleLarge?.copyWith(color: AppColors.steps)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final DayScore score;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final left = DayScore.total - score.count;
    final message = switch (score.count) {
      0 => "Let's light up today's square.",
      DayScore.total => 'Perfect day! Your square is glowing. ✨',
      _ when score.keepsStreak => '$left more for a perfect day.',
      _ => '${3 - score.count} more to keep your streak alive.',
    };

    return GlassCard(
      glow: AppColors.primary,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          ProgressRing(
            progress: score.count / DayScore.total,
            color: AppColors.primary,
            secondaryColor: AppColors.accent,
            size: 104,
            stroke: 11,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedNumber(score.count, style: text.headlineLarge),
                Text('of ${DayScore.total}', style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's score", style: text.titleLarge),
                const SizedBox(height: 6),
                Text(message, style: text.bodyMedium?.copyWith(height: 1.4)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final t in DailyTask.values)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        margin: const EdgeInsets.only(right: 6),
                        width: 22,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: score.completed.contains(t) ? _taskColor(t) : AppColors.surfaceHigh,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _taskColor(DailyTask t) => switch (t) {
  DailyTask.workout => AppColors.workout,
  DailyTask.water => AppColors.water,
  DailyTask.steps => AppColors.steps,
  DailyTask.diet => AppColors.diet,
  DailyTask.protein => AppColors.protein,
};

class _NextAlarmCard extends ConsumerWidget {
  const _NextAlarmCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final next = ref.watch(nextAlarmProvider);
    final routines = ref.watch(routinesProvider);
    final String title, subtitle;
    if (next == null) {
      title = 'Set a workout alarm';
      subtitle = 'Wake up and move — the camera checks';
    } else {
      final (alarm, at) = next;
      final day = DateUtils.isSameDay(at, DateTime.now()) ? 'Today' : DateFormat.EEEE().format(at);
      title = alarm.label;
      subtitle = '$day · ${routineById(routines, alarm.routineId).name} routine';
    }
    return Pressable(
      onTap: () => context.go(Routes.alarms),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(next == null ? Icons.alarm_add_rounded : Icons.alarm_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (next != null)
              Text(next.$1.time.format(context), style: text.titleLarge?.copyWith(color: AppColors.primary)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(title, style: Theme.of(context).textTheme.titleLarge);
}

class _TaskGrid extends ConsumerWidget {
  const _TaskGrid({required this.log, required this.targets, required this.score});

  final DailyLog log;
  final HealthTargets targets;
  final DayScore score;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.read(dailyLogsProvider.notifier);

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _TaskTile(
                  title: 'Water',
                  value: '${_litres(log.waterMl)} / ${_litres(targets.waterMl)} L',
                  progress: log.waterMl / targets.waterMl,
                  color: AppColors.water,
                  icon: Icons.water_drop_rounded,
                  done: score.completed.contains(DailyTask.water),
                  action: _QuickAction(
                    label: '+250 ml',
                    color: AppColors.water,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      logs.addWater(250);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TaskTile(
                  title: 'Steps',
                  value:
                      '${NumberFormat.compact().format(log.steps)} / ${NumberFormat.compact().format(targets.steps)}',
                  progress: log.steps / targets.steps,
                  color: AppColors.steps,
                  icon: Icons.directions_walk_rounded,
                  done: score.completed.contains(DailyTask.steps),
                  caption: 'Verified',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _TaskTile(
                  title: 'Workout',
                  value: log.workoutDone ? 'Completed' : 'Pending',
                  progress: log.workoutDone ? 1 : 0,
                  color: AppColors.workout,
                  icon: Icons.fitness_center_rounded,
                  done: log.workoutDone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TaskTile(
                  title: 'Meals',
                  value: '${log.mealsLogged} / 3 logged',
                  progress: log.mealsLogged / 3,
                  color: AppColors.diet,
                  icon: Icons.restaurant_rounded,
                  done: score.completed.contains(DailyTask.diet),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ProteinBar(current: log.proteinG, target: targets.proteinG),
      ],
    );
  }
}

/// 1500 → "1.5", 250 → "0.25", 2000 → "2".
String _litres(int ml) => (ml / 1000).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.title,
    required this.value,
    required this.progress,
    required this.color,
    required this.icon,
    required this.done,
    this.action,
    this.caption,
  });

  final String title;
  final String value;
  final double progress;
  final Color color;
  final IconData icon;
  final bool done;
  final Widget? action;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      glow: done ? color : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                progress: progress,
                color: color,
                size: 46,
                stroke: 5,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Icon(done ? Icons.check_rounded : icon, key: ValueKey(done), color: color, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              if (caption != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        caption!,
                        style: text.labelSmall?.copyWith(color: color),
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 14),
          Text(title, style: text.titleMedium),
          const SizedBox(height: 2),
          Text(
            value,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}

class _ProteinBar extends StatelessWidget {
  const _ProteinBar({required this.current, required this.target});

  final int current;
  final int target;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final progress = (current / target).clamp(0.0, 1.0);
    return GlassCard(
      glow: current >= target ? AppColors.protein : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.egg_alt_rounded, color: AppColors.protein, size: 20),
              const SizedBox(width: 8),
              Text('Protein', style: text.titleMedium),
              const Spacer(),
              Text('$current / $target g', style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (_, c) => Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(5)),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Container(
                    height: 10,
                    width: c.maxWidth * v,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: const LinearGradient(colors: [AppColors.protein, AppColors.diet]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
