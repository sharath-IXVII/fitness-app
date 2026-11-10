import '../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/page_background.dart';
import '../../core/widgets/pressable.dart';
import '../profile/profile_providers.dart';
import 'domain/move.dart';
import 'domain/plans.dart';
import 'widgets/move_widgets.dart';

/// One body part: pick a level, see the exercises.
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key, required this.focus});

  final BodyFocus focus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final weight = ref.watch(profileProvider)?.weightKg ?? 65;
    final moves = {for (final i in focusMoves[focus]!) i.move.id: i.move}.values;

    return Scaffold(
      appBar: AppBar(title: Text(focus.label)),
      body: PageBackground(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            HeroWorkoutCard(demo: focus.demo, eyebrow: 'Body part', title: focus.label, child: Text(focus.blurb)),
            const SizedBox(height: 22),
            Text(tr('Choose your level'), style: text.titleLarge),
            const SizedBox(height: 10),
            for (final level in Level.values) ...[
              _LevelCard(workout: focusWorkout(focus, level), level: level, weight: weight),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            Text(tr('Exercises'), style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              tr('Tap any exercise to see how to do it.'),
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final m in moves) MoveRow(move: m),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.workout, required this.level, required this.weight});

  final TrainingWorkout workout;
  final Level level;
  final double weight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: () => context.push(Routes.trainingPreview, extra: workout),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                for (var i = 2; i >= 0; i--)
                  Icon(Icons.bolt_rounded, size: 16, color: i <= level.index ? AppColors.energy : AppColors.stroke),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(level.label, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${workout.items.length} exercises · ${workout.minutes} min · '
                    '~${workout.kcal(weight, workout.estimatedSeconds)} kcal',
                    style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 34),
          ],
        ),
      ),
    );
  }
}
