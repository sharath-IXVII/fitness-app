import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animated_number.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import 'domain/routine.dart';

/// How a friend challenge went.
enum ChallengeOutcome { done, notCounted }

class WorkoutDoneArgs {
  const WorkoutDoneArgs({
    required this.routine,
    required this.results,
    required this.duration,
    required this.fromAlarm,
    this.challenge,
  });

  /// Set when the workout was a friend challenge.
  final ChallengeOutcome? challenge;

  final Routine routine;
  final List<int> results;
  final Duration duration;
  final bool fromAlarm;
}

class WorkoutDoneScreen extends StatelessWidget {
  const WorkoutDoneScreen({super.key, required this.args});

  final WorkoutDoneArgs args;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final mins = args.duration.inMinutes, secs = args.duration.inSeconds % 60;
    final totalReps = [
      for (var i = 0; i < args.results.length; i++)
        if (!args.routine.steps[i].exercise.timed) args.results[i],
    ].fold(0, (a, b) => a + b);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: PageBackground(
          child: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    children: [
                      const Spacer(),
                      Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.brandGradient,
                              boxShadow: AppColors.softShadow(AppColors.primary),
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
                          )
                          .animate()
                          .fadeIn(duration: 300.ms)
                          .scaleXY(begin: 0.9, end: 1, duration: 400.ms, curve: Curves.easeOutCubic),
                      const SizedBox(height: 24),
                      Text(
                        switch (args.challenge) {
                          ChallengeOutcome.done => 'Challenge done! 🔥',
                          ChallengeOutcome.notCounted => 'Not every rep counted',
                          null => args.fromAlarm ? 'Alarm off. You earned it.' : 'Workout complete!',
                        },
                        style: text.headlineMedium,
                        textAlign: TextAlign.center,
                      ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
                      const SizedBox(height: 8),
                      Text(
                        switch (args.challenge) {
                          ChallengeOutcome.done => 'Saved. Once your friend finishes too, you become friends.',
                          ChallengeOutcome.notCounted =>
                            'The camera has to count every rep for a challenge. Try again from Friends.',
                          null => "Today's workout square is lit up.",
                        },
                        style: text.bodyMedium,
                        textAlign: TextAlign.center,
                      ).animate(delay: 300.ms).fadeIn(),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          _stat(context, 'Total reps', totalReps, ''),
                          const SizedBox(width: 12),
                          _stat(context, 'Time', mins, 'm ${secs}s'),
                          const SizedBox(width: 12),
                          _stat(context, 'Exercises', args.results.length, ''),
                        ],
                      ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2),
                      const SizedBox(height: 16),
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            for (var i = 0; i < args.results.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    Icon(args.routine.steps[i].exercise.icon, size: 20, color: AppColors.primary),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(args.routine.steps[i].exercise.label, style: text.titleSmall)),
                                    Text(
                                      args.routine.steps[i].exercise.formatTarget(args.results[i]),
                                      style: text.titleSmall,
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.check_circle_rounded, size: 18, color: AppColors.accent),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ).animate(delay: 500.ms).fadeIn(),
                      const Spacer(),
                      if (args.challenge != null)
                        GradientButton(label: 'Back to Friends', onPressed: () => context.go(Routes.friends))
                      else
                        GradientButton(label: 'Back to Today', onPressed: () => context.go(Routes.home)),
                      const SizedBox(height: 4),
                      // The wake-up workout is a warm-up; offer a full session next.
                      TextButton.icon(
                        onPressed: () => context.go(Routes.training),
                        icon: const Icon(Icons.fitness_center_rounded),
                        label: const Text('Keep going: full workouts'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int value, String suffix) {
    final text = Theme.of(context).textTheme;
    return Expanded(
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
  }
}
