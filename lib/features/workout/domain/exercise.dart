import 'package:flutter/material.dart';

/// Exercises the camera can verify.
enum Exercise {
  squat(
    label: 'Squats',
    icon: Icons.accessibility_new_rounded,
    tip: 'Stand facing the phone, about 2 m away. Your whole body should be visible.',
  ),
  pushUp(
    label: 'Push-ups',
    icon: Icons.fitness_center_rounded,
    tip: 'Put the phone on the floor to your side so it sees you from the side.',
  ),
  jumpingJack(
    label: 'Jumping jacks',
    icon: Icons.sports_gymnastics_rounded,
    tip: 'Face the phone, about 2.5 m away, with room for your arms overhead.',
  ),
  lunge(
    label: 'Lunges',
    icon: Icons.directions_walk_rounded,
    tip: 'Stand sideways to the phone so both knees are visible.',
  ),
  highKnees(
    label: 'High knees',
    icon: Icons.directions_run_rounded,
    tip: 'Face the phone and drive each knee up to hip height. Each knee counts.',
  ),
  plank(
    label: 'Plank',
    icon: Icons.horizontal_rule_rounded,
    tip: 'Phone on the floor to your side. The timer only runs while your body is straight.',
    timed: true,
  );

  const Exercise({required this.label, required this.icon, required this.tip, this.timed = false});

  final String label;
  final IconData icon;
  final String tip;

  /// Timed exercises have a target in seconds instead of reps.
  final bool timed;

  String formatTarget(int target) => timed ? '${target}s' : '$target';
}
