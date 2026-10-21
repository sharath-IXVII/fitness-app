import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../alarm/alarm_providers.dart';
import '../streaks/daily_log_providers.dart';
import 'domain/user_profile.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _goalLabel = {
    FitnessGoal.loseWeight: 'Lose weight',
    FitnessGoal.maintain: 'Stay fit',
    FitnessGoal.buildMuscle: 'Build muscle',
  };
  static const _dietLabel = {
    DietType.veg: 'Vegetarian',
    DietType.nonVeg: 'Non-veg',
    DietType.eggetarian: 'Eggetarian',
    DietType.vegan: 'Vegan',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final t = ref.watch(targetsProvider);
    if (p == null || t == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final streak = ref.watch(streakProvider);

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(label, style: text.bodyMedium),
          const Spacer(),
          Text(value, style: text.titleSmall),
        ],
      ),
    );

    return AuroraBackground(
      intensity: 0.08,
      child: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Center(
              child: Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                child: Text(
                  p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                  style: text.displaySmall?.copyWith(color: Colors.white),
                ),
              ),
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 14),
            Center(child: Text(p.name, style: text.headlineSmall)),
            Center(child: Text('🔥 ${streak.current}-day streak · best ${streak.longest}', style: text.bodyMedium)),
            const SizedBox(height: 28),
            GlassCard(
              child: Column(
                children: [
                  row('Goal', _goalLabel[p.goal]!),
                  row('Diet', _dietLabel[p.diet]!),
                  row('Height', '${p.heightCm.round()} cm'),
                  row('Weight', '${p.weightKg.toStringAsFixed(1)} kg'),
                  row('BMI', '${t.bmi}'),
                  row('Stride length', '${t.strideM} m'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Column(
                children: [
                  row('Calories', '${t.calories} kcal'),
                  row('Protein', '${t.proteinG} g'),
                  row('Carbs', '${t.carbsG} g'),
                  row('Fat', '${t.fatG} g'),
                  row('Fiber', '${t.fiberG} g'),
                  row('Water', '${(t.waterMl / 1000).toStringAsFixed(1)} L'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: AppColors.surfaceHigh,
                    title: const Text('Start over?'),
                    content: const Text('This clears your profile and history on this device.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Reset', style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(dailyLogsProvider.notifier).clearAll();
                  await ref.read(alarmsProvider.notifier).clearAll();
                  await ref.read(profileProvider.notifier).clear();
                }
              },
              icon: const Icon(Icons.restart_alt_rounded, color: AppColors.danger),
              label: const Text('Reset profile', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      ),
    );
  }
}
