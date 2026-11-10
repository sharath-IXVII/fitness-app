import '../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../activity/widgets/activity_quick_row.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../workout/widgets/exercise_demo.dart';
import 'domain/move.dart';
import 'domain/plans.dart';
import 'training_providers.dart';
import 'workout_reminder.dart';
import 'widgets/move_widgets.dart';

/// The Workouts tab: 30-day challenges, workouts by body part, quick
/// sessions and the exercise library. Everything is guided, no camera.
class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final state = ref.watch(trainingProvider);
    final week = state.thisWeek(DateTime.now());
    // Challenges in progress come first.
    final sorted = [...challenges]
      ..sort((a, b) => (state.challenges.containsKey(a.id) ? 0 : 1) - (state.challenges.containsKey(b.id) ? 0 : 1));

    final sections = <Widget>[
      Row(
        children: [
          Expanded(child: Text(tr('Workouts'), style: text.headlineMedium)),
          IconButton(
            tooltip: tr('Workout reminder'),
            onPressed: () => _reminderSheet(context, ref),
            icon: Icon(
              ref.watch(workoutReminderProvider).enabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(tr('Home workouts, no gym needed'), style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 16),
      _WeekCard(workouts: week.workouts, minutes: week.minutes, kcal: week.kcal),
      const SizedBox(height: 24),
      Row(
        children: [
          const Expanded(child: _Title('Run · Walk · Cycle')),
          TextButton(onPressed: () => context.push(Routes.activities), child: Text(tr('History'))),
        ],
      ),
      const SizedBox(height: 8),
      const ActivityQuickRow(),
      const SizedBox(height: 24),
      const _Title('30-day challenges'),
      const SizedBox(height: 12),
      SizedBox(
        height: currentLang == AppLang.en ? 168 : 232,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          physics: const BouncingScrollPhysics(),
          itemCount: sorted.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final c = sorted[i];
            final p = state.challenges[c.id];
            return SizedBox(
              width: MediaQuery.sizeOf(context).width - 72,
              child: HeroWorkoutCard(
                demo: c.demo,
                eyebrow: p == null ? '30 days' : p.level.label,
                title: c.title,
                onTap: () => context.push(Routes.trainingChallenge, extra: c.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.blurb, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 14),
                    if (p == null)
                      Text(tr('Start now  →'), style: text.labelLarge?.copyWith(color: AppColors.energyLight))
                    else ...[
                      Text(
                        p.nextDay == null ? 'Completed!' : 'Day ${p.nextDay} of ${Challenge.days}',
                        style: text.labelLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      EnergyBar(value: p.fraction),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 26),
      const _Title('Train by body part'),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, box) {
          const gap = 10.0;
          final w = (box.maxWidth - gap * 2) / 3;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final f in BodyFocus.values)
                SizedBox(
                  width: w,
                  child: _FocusTile(focus: f),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 26),
      const _Title('Quick sessions'),
      const SizedBox(height: 12),
      for (final w in quickWorkouts) ...[_QuickCard(workout: w), const SizedBox(height: 10)],
      const SizedBox(height: 16),
      Pressable(
        onTap: () => context.push(Routes.trainingLibrary),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.menu_book_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Exercise library'), style: text.titleSmall),
                    Text(
                      '${Moves.all.length} exercises with how-to animations',
                      style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
      if (state.history.isNotEmpty) ...[
        const SizedBox(height: 26),
        const _Title('Recent'),
        const SizedBox(height: 8),
        for (final h in state.history.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(h.title, style: text.bodyMedium)),
                Text(
                  '${DateFormat('d MMM').format(h.at)} · ${(h.seconds / 60).ceil()} min',
                  style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
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
              s
                  .animate(delay: (i * 25).ms)
                  .fadeIn(duration: 300.ms)
                  .moveY(begin: 8, end: 0, curve: Curves.easeOutCubic),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(title, style: Theme.of(context).textTheme.titleLarge);
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.workouts, required this.minutes, required this.kcal});

  final int workouts;
  final int minutes;
  final int kcal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.energy),
              const SizedBox(width: 4),
              Text(value, style: text.headlineSmall),
            ],
          ),
          Text(label, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          stat(Icons.bolt_rounded, '$workouts', 'Workouts'),
          stat(Icons.timer_outlined, '$minutes', 'Minutes'),
          stat(Icons.local_fire_department_rounded, '$kcal', 'kcal'),
        ],
      ),
    );
  }
}

class _FocusTile extends StatelessWidget {
  const _FocusTile({required this.focus});

  final BodyFocus focus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => context.push(Routes.trainingFocus, extra: focus),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.stroke),
          boxShadow: AppColors.softShadow(),
        ),
        child: Column(
          children: [
            ExerciseDemo.move(demoId: focus.demo, label: focus.label, height: 62),
            const SizedBox(height: 4),
            Text(focus.label, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.workout});

  final TrainingWorkout workout;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => context.push(Routes.trainingPreview, extra: workout),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            MoveThumb(move: workout.items.first.move, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workout.title, style: text.titleSmall),
                  Text(
                    workout.subtitle,
                    style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
              child: Text('${workout.minutes} min', style: text.labelMedium?.copyWith(color: AppColors.amber)),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _reminderSheet(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  backgroundColor: AppColors.surface,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
  builder: (c) => Consumer(
    builder: (c, ref, _) {
      final text = Theme.of(c).textTheme;
      final s = ref.watch(workoutReminderProvider);
      final n = ref.read(workoutReminderProvider.notifier);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Workout reminder'), style: text.titleLarge),
              const SizedBox(height: 4),
              Text(
                tr('A daily nudge that names your next challenge day. Quiet on days you have already worked out.'),
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Remind me')),
                value: s.enabled,
                onChanged: (v) => n.set(enabled: v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: s.enabled,
                title: Text(tr('Time')),
                trailing: Text(s.time.format(c), style: text.titleMedium?.copyWith(color: AppColors.primary)),
                onTap: () async {
                  final t = await showTimePicker(context: c, initialTime: s.time);
                  if (t != null) await n.set(time: t);
                },
              ),
            ],
          ),
        ),
      );
    },
  ),
);
