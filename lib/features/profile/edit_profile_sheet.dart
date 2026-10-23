import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/pressable.dart';
import '../diet/widgets/sheet_frame.dart';
import '../water/water_providers.dart';
import 'domain/user_profile.dart';
import 'profile_providers.dart';

/// Change anything set during onboarding. Targets update immediately.
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late UserProfile _p = ref.read(profileProvider)!;
  late final _name = TextEditingController(text: _p.name);

  static const goals = {
    FitnessGoal.loseWeight: 'Lose weight',
    FitnessGoal.maintain: 'Stay fit',
    FitnessGoal.buildMuscle: 'Build muscle',
  };
  static const diets = {
    DietType.veg: 'Vegetarian',
    DietType.eggetarian: 'Eggetarian',
    DietType.nonVeg: 'Non-veg',
    DietType.vegan: 'Vegan',
  };
  static const activities = {
    ActivityLevel.sedentary: 'Mostly sitting',
    ActivityLevel.light: 'Lightly active',
    ActivityLevel.moderate: 'Moderately active',
    ActivityLevel.active: 'Very active',
    ActivityLevel.veryActive: 'Athlete',
  };
  static const levels = {
    FitnessLevel.beginner: 'Beginner',
    FitnessLevel.moderate: 'Moderate',
    FitnessLevel.advanced: 'Advanced',
  };

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool wake) async {
    final t = await showTimePicker(context: context, initialTime: wake ? _p.wakeTime : _p.sleepTime);
    if (t != null) setState(() => _p = wake ? _p.copyWith(wakeTime: t) : _p.copyWith(sleepTime: t));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final old = ref.read(profileProvider)!;
    await ref.read(profileProvider.notifier).save(_p.copyWith(name: name.isEmpty ? old.name : name));
    // Water reminders run between wake and sleep time.
    if (old.wakeTime != _p.wakeTime || old.sleepTime != _p.sleepTime) {
      await ref.read(waterSettingsProvider.notifier).reschedule();
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _pills<T>(Map<T, String> options, T value, ValueChanged<T> onPick) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final e in options.entries) ChoicePill(label: e.value, selected: e.key == value, onTap: () => onPick(e.key)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SheetFrame(
      title: 'Edit profile',
      footer: GradientButton(label: 'Save', icon: Icons.check_rounded, onPressed: _save),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormSection(
              title: 'Name',
              child: TextField(controller: _name, textCapitalization: TextCapitalization.words),
            ),
            FormSection(
              title: 'Body',
              child: Column(
                children: [
                  _Stepper(
                    label: 'Age',
                    value: _p.age.toDouble(),
                    unit: 'years',
                    min: 13,
                    max: 90,
                    onChanged: (v) => setState(() => _p = _p.copyWith(age: v.round())),
                  ),
                  _Stepper(
                    label: 'Height',
                    value: _p.heightCm,
                    unit: 'cm',
                    min: 120,
                    max: 220,
                    onChanged: (v) => setState(() => _p = _p.copyWith(heightCm: v)),
                  ),
                  _Stepper(
                    label: 'Weight',
                    value: _p.weightKg,
                    unit: 'kg',
                    min: 30,
                    max: 180,
                    step: 0.5,
                    onChanged: (v) => setState(() => _p = _p.copyWith(weightKg: v)),
                  ),
                  const SizedBox(height: 4),
                  _pills({Gender.male: 'Male', Gender.female: 'Female', Gender.other: 'Other'}, _p.gender, (g) {
                    setState(() => _p = _p.copyWith(gender: g));
                  }),
                ],
              ),
            ),
            FormSection(
              title: 'Goal',
              child: _pills(goals, _p.goal, (g) => setState(() => _p = _p.copyWith(goal: g))),
            ),
            FormSection(
              title: 'Diet',
              child: _pills(diets, _p.diet, (d) => setState(() => _p = _p.copyWith(diet: d))),
            ),
            FormSection(
              title: 'Activity outside workouts',
              child: _pills(activities, _p.activity, (a) => setState(() => _p = _p.copyWith(activity: a))),
            ),
            FormSection(
              title: 'Fitness level',
              child: _pills(levels, _p.level, (l) => setState(() => _p = _p.copyWith(level: l))),
            ),
            FormSection(
              title: 'Your day',
              child: Row(
                children: [
                  Expanded(
                    child: _TimeBox(label: 'Wake up', time: _p.wakeTime, onTap: () => _pickTime(true)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeBox(label: 'Sleep', time: _p.sleepTime, onTap: () => _pickTime(false)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Calories, protein, water and step goals update from these.', style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = step < 1 ? value.toStringAsFixed(1) : value.round().toString();
    Widget btn(IconData icon, double next) => Pressable(
      onTap: next < min || next > max
          ? null
          : () {
              HapticFeedback.selectionClick();
              onChanged(next);
            },
      scale: 0.9,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: AppColors.surfaceHigh, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyLarge)),
          btn(Icons.remove_rounded, value - step),
          SizedBox(
            width: 96,
            child: Text('$shown $unit', textAlign: TextAlign.center, style: text.titleSmall),
          ),
          btn(Icons.add_rounded, value + step),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.time, required this.onTap});

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.bodySmall),
            Text(time.format(context), style: text.titleMedium),
          ],
        ),
      ),
    );
  }
}
