import 'package:flutter/material.dart';

/// What the user has to do to turn an alarm off.
enum AlarmChallenge {
  workout('Workout', 'Finish your routine on camera', Icons.fitness_center_rounded),
  math('Maths', 'Solve a few sums', Icons.calculate_outlined),
  memory('Memory', 'Repeat a pattern of tiles', Icons.grid_view_rounded),
  order('Number order', 'Tap the numbers 1, 2, 3… in order', Icons.format_list_numbered_rounded),
  mixed('Mixed games', 'A different brain game each round', Icons.shuffle_rounded);

  const AlarmChallenge(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  bool get isGame => this != workout;
}

enum ChallengeLevel {
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  const ChallengeLevel(this.label);

  final String label;
}
