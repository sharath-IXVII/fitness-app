import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../festivals/festival_widgets.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/beta_tag.dart';
import '../../core/widgets/animated_number.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/progress_ring.dart';
import '../profile/domain/health_targets.dart';
import '../alarm/alarm_providers.dart';
import '../profile/profile_providers.dart';
import '../progress/progress_card.dart';
import '../streaks/daily_log_providers.dart';
import '../arcs/widgets/arc_widgets.dart';
import '../friends/friends_providers.dart';
import '../steps/steps_providers.dart';
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
      _Header(name: profile.name),
      const SizedBox(height: 18),
      // On festival days: "Happy Diwali, Asha!".
      FestivalBanner(name: profile.name),
      // The season's arc sets the tone for the whole app.
      const ArcCard(),
      const SizedBox(height: 14),
      // The streak calendar leads the page — it's the habit we want to build.
      ConsistencyCard(scores: scores, current: streak.current, longest: streak.longest),
      const SizedBox(height: 14),
      _ScoreCard(score: score),
      const SizedBox(height: 12),
      _TaskGrid(log: log, targets: targets, score: score),
      const SizedBox(height: 26),
      const _SectionTitle('Coming up'),
      const SizedBox(height: 12),
      const _NextAlarmCard(),
      const SizedBox(height: 12),
      const ProgressCard(),
      const SizedBox(height: 32),
    ];

    return PageBackground(
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          children: [
            for (final (i, s) in sections.indexed)
              s
                  .animate(delay: (i * 30).ms)
                  .fadeIn(duration: 300.ms)
                  .moveY(begin: 8, end: 0, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

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
                style: text.labelSmall?.copyWith(color: AppColors.textTertiary, letterSpacing: 1.4),
              ),
              const SizedBox(height: 4),
              Text('$_greeting, ${name.split(' ').first}', style: text.headlineSmall),
            ],
          ),
        ),
        const _FriendsButton(),
        const SizedBox(width: 8),
        // The streak lives in the calendar card below; this opens the profile.
        Tooltip(
          message: 'Profile',
          child: Pressable(
            onTap: () => context.push(Routes.profile),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.stroke),
              ),
              child: Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style: text.titleMedium?.copyWith(color: AppColors.primary),
              ),
            ),
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

    // Dark "energy" hero card: the sportiest moment on the page.
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.inkSoft, AppColors.ink],
        ),
        boxShadow: AppColors.softShadow(),
      ),
      child: Row(
        children: [
          ProgressRing(
            progress: score.count / DayScore.total,
            color: AppColors.energy,
            secondaryColor: AppColors.energyLight,
            trackColor: Colors.white12,
            size: 84,
            stroke: 9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedNumber(score.count, style: text.headlineMedium?.copyWith(color: Colors.white)),
                Text('of ${DayScore.total}', style: text.bodySmall?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: AppColors.energyLight, size: 20),
                    const SizedBox(width: 4),
                    Text("TODAY'S SCORE", style: text.titleSmall?.copyWith(color: Colors.white, letterSpacing: 1.2)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message, style: text.bodyMedium?.copyWith(height: 1.4, color: Colors.white70)),
                const SizedBox(height: 12),
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
                          color: score.completed.contains(t) ? AppColors.energyLight : Colors.white12,
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
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
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
                  onTap: () => context.push(Routes.water),
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
                  onTap: () => context.push(Routes.steps),
                  title: 'Steps',
                  value:
                      '${NumberFormat.compact().format(log.steps)} / ${NumberFormat.compact().format(targets.steps)}',
                  progress: log.steps / targets.steps,
                  color: AppColors.steps,
                  icon: Icons.directions_walk_rounded,
                  done: score.completed.contains(DailyTask.steps),
                  // Distance walked today, from GPS where it ran and steps × stride elsewhere.
                  caption:
                      '${(ref.watch(stepsProvider).day.distanceMeters(targets.strideM) / 1000).toStringAsFixed(1)} km today',
                  action: _QuickAction(
                    label: 'Track walk',
                    color: AppColors.steps,
                    onTap: () => context.push(Routes.steps),
                  ),
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
                  onTap: () => context.go(Routes.alarms),
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
                  onTap: () => context.go(Routes.diet),
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
        const SizedBox(height: 12),
        const _HealthEntry(),
      ],
    );
  }
}

/// A small card that opens the Health page (heart rate, watch, height,
/// weight and BMI). It is a card here, not a tab, to save space.
class _HealthEntry extends StatelessWidget {
  const _HealthEntry();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => context.push(Routes.health),
      scale: 0.98,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.monitor_heart_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text('Health check', style: text.titleMedium, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      const BetaTag(),
                    ],
                  ),
                  Text(
                    'Heart rate, watch, height, weight and BMI',
                    style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    this.onTap,
  });

  final String title;
  final String value;
  final double progress;
  final Color color;
  final IconData icon;
  final bool done;
  final Widget? action;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final card = GlassCard(
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
    return onTap == null ? card : Pressable(onTap: onTap, scale: 0.97, child: card);
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
              Icon(Icons.egg_alt_rounded, color: AppColors.protein, size: 20),
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
                      gradient: LinearGradient(colors: [AppColors.protein, AppColors.diet]),
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

/// Opens Friends; a dot shows how many challenges are waiting on you.
class _FriendsButton extends ConsumerWidget {
  const _FriendsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(challengesToDoProvider);
    return Tooltip(
      message: 'Friends',
      child: Pressable(
        onTap: () => context.push(Routes.friends),
        child: Badge(
          isLabelVisible: waiting > 0,
          label: Text('$waiting'),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.stroke),
            ),
            child: Icon(Icons.group_rounded, color: AppColors.primary, size: 22),
          ),
        ),
      ),
    );
  }
}
