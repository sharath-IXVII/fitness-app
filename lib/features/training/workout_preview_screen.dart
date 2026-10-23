import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/page_background.dart';
import '../profile/profile_providers.dart';
import 'domain/plans.dart';
import 'widgets/move_widgets.dart';

/// Everything in a workout before starting it.
class WorkoutPreviewScreen extends ConsumerWidget {
  const WorkoutPreviewScreen({super.key, required this.workout});

  final TrainingWorkout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final weight = ref.watch(profileProvider)?.weightKg ?? 65;
    final equipment = workout.equipment;

    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.energy, size: 20),
          const SizedBox(height: 4),
          Text(value, style: text.titleMedium),
          Text(label, style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(workout.title)),
      body: PageBackground(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  if (workout.subtitle.isNotEmpty) ...[
                    Text(workout.subtitle, style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                  ],
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        stat(Icons.timer_outlined, '${workout.minutes} min', 'Duration'),
                        stat(Icons.format_list_numbered_rounded, '${workout.items.length}', 'Exercises'),
                        stat(
                          Icons.local_fire_department_rounded,
                          '~${workout.kcal(weight, workout.estimatedSeconds)}',
                          'kcal',
                        ),
                      ],
                    ),
                  ),
                  if (equipment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.handyman_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You will need: ${equipment.join(', ').toLowerCase()}.',
                              style: text.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text('Exercises', style: text.titleLarge),
                  const SizedBox(height: 6),
                  for (final item in workout.items)
                    MoveRow(
                      move: item.move,
                      target: item.label,
                      onTap: () => showMoveHowTo(context, item.move, item: item),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: GradientButton(
                  label: 'Start workout',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => context.push(Routes.trainingPlayer, extra: workout),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
