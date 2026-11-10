import '../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../share/share_card.dart';
import '../streaks/daily_log_providers.dart';
import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_number.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import 'domain/plans.dart';
import 'training_providers.dart';

class TrainingDoneArgs {
  const TrainingDoneArgs({required this.workout, required this.seconds, required this.kcal});

  final TrainingWorkout workout;
  final int seconds;
  final int kcal;
}

class TrainingDoneScreen extends ConsumerWidget {
  const TrainingDoneScreen({super.key, required this.args});

  final TrainingDoneArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final w = args.workout;
    final challenge = w.challengeId == null ? null : challengeById(w.challengeId!);
    final progress = challenge == null ? null : ref.watch(trainingProvider).challenges[challenge.id];

    Widget stat(String label, int value, String suffix) => Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            AnimatedNumber(
              value,
              suffix: suffix,
              style: text.titleLarge?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 2),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: PageBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.energyGradient,
                          boxShadow: AppColors.softShadow(AppColors.energy),
                        ),
                        child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 48),
                      )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .scaleXY(begin: 0.8, end: 1, duration: 500.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 22),
                  Text(
                    w.day != null ? 'Day ${w.day} complete!' : 'Workout complete!',
                    style: text.headlineMedium,
                    textAlign: TextAlign.center,
                  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
                  const SizedBox(height: 6),
                  Text(
                    challenge?.title ?? w.title,
                    style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ).animate(delay: 300.ms).fadeIn(),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      stat('Minutes', (args.seconds / 60).ceil(), ''),
                      const SizedBox(width: 12),
                      stat('Exercises', w.items.length, ''),
                      const SizedBox(width: 12),
                      stat('kcal', args.kcal, ''),
                    ],
                  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2),
                  if (progress != null) ...[
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.flag_rounded, color: AppColors.energy),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              progress.nextDay == null
                                  ? 'You finished all ${Challenge.days} days. Amazing!'
                                  : '${progress.done.length} of ${Challenge.days} days done. See you tomorrow!',
                              style: text.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 500.ms).fadeIn(),
                  ],
                  const Spacer(),
                  GradientButton(label: tr('Done'), onPressed: () => context.go(Routes.training)),
                  TextButton.icon(
                    onPressed: () => context.push(
                      Routes.shareCard,
                      extra: ShareCardData.workout(
                        name: args.workout.title,
                        seconds: args.seconds,
                        kcal: args.kcal,
                        streak: ref.read(streakProvider).current,
                      ),
                    ),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(tr('Share my workout')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
