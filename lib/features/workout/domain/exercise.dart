import 'package:flutter/material.dart';

enum ExerciseGroup {
  legs('Legs & glutes'),
  upper('Arms, chest & shoulders'),
  core('Core'),
  cardio('Full body & cardio');

  const ExerciseGroup(this.label);

  final String label;
}

/// Exercises the camera can verify.
enum Exercise {
  squat(
    label: 'Squats',
    group: ExerciseGroup.legs,
    muscles: 'Quads, glutes',
    icon: Icons.accessibility_new_rounded,
    tip: 'Stand facing the phone, about 2 m away. Your whole body should be visible.',
  ),
  lunge(
    label: 'Lunges',
    group: ExerciseGroup.legs,
    muscles: 'Quads, glutes',
    icon: Icons.directions_walk_rounded,
    tip: 'Stand sideways to the phone so both knees are visible.',
  ),
  gluteBridge(
    label: 'Glute bridges',
    group: ExerciseGroup.legs,
    muscles: 'Glutes, hamstrings',
    icon: Icons.airline_seat_flat_angled_rounded,
    tip: 'Lie on your back, knees bent, phone on the floor to your side. Lift your hips until your body is straight.',
  ),
  wallSit(
    label: 'Wall sit',
    group: ExerciseGroup.legs,
    muscles: 'Quads',
    icon: Icons.event_seat_rounded,
    tip: 'Back against a wall, knees at about 90°, side-on to the phone. The timer runs while you hold.',
    timed: true,
  ),
  pushUp(
    label: 'Push-ups',
    group: ExerciseGroup.upper,
    muscles: 'Chest, triceps, shoulders',
    icon: Icons.fitness_center_rounded,
    tip: 'Put the phone on the floor to your side so it sees you from the side.',
  ),
  kneePushUp(
    label: 'Knee push-ups',
    group: ExerciseGroup.upper,
    muscles: 'Chest, triceps',
    icon: Icons.fitness_center_rounded,
    tip: 'Push-ups from your knees. Phone on the floor to your side.',
  ),
  bicepCurl(
    label: 'Biceps curls',
    group: ExerciseGroup.upper,
    muscles: 'Biceps',
    icon: Icons.sports_handball_rounded,
    tip: 'Face the phone holding dumbbells or water bottles. Keep elbows at your sides; each arm counts.',
  ),
  tricepDip(
    label: 'Triceps dips',
    group: ExerciseGroup.upper,
    muscles: 'Triceps, shoulders',
    icon: Icons.chair_alt_rounded,
    tip: 'Hands on a chair or bed edge behind you, side-on to the phone. Bend your elbows to about 90°.',
  ),
  shoulderPress(
    label: 'Shoulder press',
    group: ExerciseGroup.upper,
    muscles: 'Shoulders, triceps',
    icon: Icons.upload_rounded,
    tip: 'Face the phone. Start with hands at shoulder height and press straight overhead.',
  ),
  lateralRaise(
    label: 'Lateral raises',
    group: ExerciseGroup.upper,
    muscles: 'Shoulders',
    icon: Icons.open_with_rounded,
    tip: 'Face the phone. Raise both arms out to the side to shoulder height, then lower.',
  ),
  plank(
    label: 'Plank',
    group: ExerciseGroup.core,
    muscles: 'Core',
    icon: Icons.horizontal_rule_rounded,
    tip: 'Phone on the floor to your side. The timer only runs while your body is straight.',
    timed: true,
  ),
  sitUp(
    label: 'Sit-ups',
    group: ExerciseGroup.core,
    muscles: 'Abs',
    icon: Icons.airline_seat_recline_normal_rounded,
    tip: 'Lie on your back with knees bent, phone on the floor to your side. Sit up until your chest nears your knees.',
  ),
  mountainClimber(
    label: 'Mountain climbers',
    group: ExerciseGroup.core,
    muscles: 'Core, shoulders',
    icon: Icons.terrain_rounded,
    tip: 'Start in a push-up position, side-on to the phone, and drive your knees to your chest. Each knee counts.',
  ),
  jumpingJack(
    label: 'Jumping jacks',
    group: ExerciseGroup.cardio,
    muscles: 'Full body',
    icon: Icons.sports_gymnastics_rounded,
    tip: 'Face the phone, about 2.5 m away, with room for your arms overhead.',
  ),
  highKnees(
    label: 'High knees',
    group: ExerciseGroup.cardio,
    muscles: 'Legs, cardio',
    icon: Icons.directions_run_rounded,
    tip: 'Face the phone and drive each knee up to hip height. Each knee counts.',
  ),
  burpee(
    label: 'Burpees',
    group: ExerciseGroup.cardio,
    muscles: 'Full body',
    icon: Icons.bolt_rounded,
    tip: 'Side-on to the phone, about 2.5 m away. Drop to a plank, then stand back up. Each return to standing counts.',
  );

  const Exercise({
    required this.label,
    required this.group,
    required this.muscles,
    required this.icon,
    required this.tip,
    this.timed = false,
  });

  final String label;
  final ExerciseGroup group;
  final String muscles;
  final IconData icon;
  final String tip;

  /// Timed exercises have a target in seconds instead of reps.
  final bool timed;

  String formatTarget(int target) => timed ? '${target}s' : '$target';

  /// A sensible starting target when added to a routine.
  int get defaultTarget => switch (this) {
    plank || wallSit => 30,
    burpee => 8,
    mountainClimber || highKnees || jumpingJack => 20,
    _ => 10,
  };
}
