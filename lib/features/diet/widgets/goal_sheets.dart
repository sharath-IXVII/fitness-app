import 'dart:math' as math;

import '../../../core/i18n/i18n.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/form_controls.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../onboarding/widgets/ruler_picker.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/profile_providers.dart';
import '../diet_providers.dart';
import '../domain/weight_goal.dart';
import 'sheet_frame.dart';

/// "Reach X kg by a date" with a live preview of the pace and calories,
/// and a clear warning when the deadline isn't safe.
class GoalSheet extends ConsumerStatefulWidget {
  const GoalSheet({super.key});

  @override
  ConsumerState<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<GoalSheet> {
  late final UserProfile _p = ref.read(profileProvider)!;
  late final WeightGoal? _existing = ref.read(weightGoalProvider);
  late double _target = _existing?.targetKg ?? _suggested();
  late DateTime _deadline = _existing?.deadline ?? DateTime.now().add(const Duration(days: 84));

  double _suggested() => switch (_p.goal) {
    FitnessGoal.loseWeight => (_p.weightKg - 5).roundToDouble(),
    FitnessGoal.buildMuscle => (_p.weightKg + 3).roundToDouble(),
    FitnessGoal.maintain => _p.weightKg.roundToDouble(),
  };

  WeightGoal get _goal => WeightGoal(
    startKg: _existing?.startKg ?? _p.weightKg,
    targetKg: _target,
    deadline: _deadline,
    createdAt: _existing?.createdAt ?? DateTime.now(),
  );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: now.add(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _deadline = d);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final g = _goal;
    final pace = g.pace(_p.weightKg, now);
    final perWeek = g.neededPerWeek(_p.weightKg, now);
    final tdee = ref.read(targetsProvider)!.tdee;
    final floor = _p.gender == Gender.male ? 1500 : 1200;
    final kcal = math.max(floor, tdee + g.dailyAdjustment(_p.weightKg, now));
    final weeks = g.weeksLeft(now).round();
    final (Color tone, String headline, String detail) = switch (pace) {
      GoalPace.maintain => (AppColors.primary, 'Maintain your weight', 'Eat about $kcal kcal a day.'),
      GoalPace.realistic => (
        AppColors.primary,
        'Realistic pace',
        '${perWeek.abs().toStringAsFixed(2)} kg a week · about $kcal kcal a day.',
      ),
      GoalPace.ambitious => (
        AppColors.amber,
        'Ambitious but safe',
        '${perWeek.abs().toStringAsFixed(2)} kg a week · about $kcal kcal a day. Stay consistent with protein.',
      ),
      GoalPace.tooFast => (
        AppColors.danger,
        'Faster than is safe',
        'That needs ${perWeek.abs().toStringAsFixed(1)} kg a week. We\'ll cap it at the safe pace '
            '($kcal kcal a day), which reaches $_target kg around '
            '${DateFormat.yMMMd().format(g.safeEta(_p.weightKg, now))}.',
      ),
    };

    return SheetFrame(
      title: tr('Weight goal'),
      action: _existing == null
          ? null
          : TextButton(
              onPressed: () {
                ref.read(weightGoalProvider.notifier).set(null);
                Navigator.pop(context);
              },
              child: Text(tr('Remove')),
            ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Now ${_p.weightKg.toStringAsFixed(1)} kg', style: text.bodyMedium),
            FormSection(
              title: tr('Target weight'),
              child: RulerPicker(
                min: 30,
                max: 180,
                step: 0.5,
                decimals: 1,
                value: _target,
                unit: 'kg',
                onChanged: (v) => setState(() => _target = v),
              ),
            ),
            FormSection(
              title: tr('By when'),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final w in const [4, 8, 12, 16, 24])
                    ChoicePill(
                      label: '$w weeks',
                      selected: weeks == w,
                      onTap: () => setState(() => _deadline = now.add(Duration(days: w * 7))),
                    ),
                  ChoicePill(label: DateFormat.MMMd().format(_deadline), selected: false, onTap: _pickDate),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tone.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline, style: text.titleSmall?.copyWith(color: tone)),
                  const SizedBox(height: 4),
                  Text(detail, style: text.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Safe limits: lose up to 1 kg or gain up to 0.5 kg a week. Calories never go below $floor kcal.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: _existing == null ? 'Set goal' : 'Update goal',
              icon: Icons.flag_outlined,
              onPressed: () {
                ref.read(weightGoalProvider.notifier).set(g);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class WeighInSheet extends ConsumerStatefulWidget {
  const WeighInSheet({super.key});

  @override
  ConsumerState<WeighInSheet> createState() => _WeighInSheetState();
}

class _WeighInSheetState extends ConsumerState<WeighInSheet> {
  late double _kg = (ref.read(profileProvider)!.weightKg * 2).round() / 2;

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      title: tr('Log weight'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          children: [
            RulerPicker(
              min: 30,
              max: 180,
              step: 0.5,
              decimals: 1,
              value: _kg,
              unit: 'kg',
              onChanged: (v) => setState(() => _kg = v),
            ),
            const SizedBox(height: 12),
            Text(
              tr('Weigh in at the same time each day, ideally in the morning. Your targets update to match.'),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: tr('Save'),
              icon: Icons.check_rounded,
              onPressed: () {
                ref.read(weightLogProvider.notifier).log(_kg);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
