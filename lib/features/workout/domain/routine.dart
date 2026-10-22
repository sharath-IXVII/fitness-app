import '../../profile/domain/user_profile.dart';
import 'exercise.dart';

class RoutineStep {
  const RoutineStep(this.exercise, this.target);

  final Exercise exercise;

  /// Reps, or seconds for timed exercises.
  final int target;

  Map<String, dynamic> toJson() => {'exercise': exercise.name, 'target': target};

  factory RoutineStep.fromJson(Map<String, dynamic> j) =>
      RoutineStep(Exercise.values.byName(j['exercise'] as String), j['target'] as int);
}

class Routine {
  const Routine({required this.id, required this.name, required this.steps, this.builtIn = false});

  final String id;
  final String name;
  final List<RoutineStep> steps;
  final bool builtIn;

  String get summary =>
      steps.map((s) => '${s.exercise.formatTarget(s.target)} ${s.exercise.label.toLowerCase()}').join(' · ');

  Routine copyWith({String? name, List<RoutineStep>? steps}) =>
      Routine(id: id, name: name ?? this.name, steps: steps ?? this.steps, builtIn: builtIn);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'steps': [for (final s in steps) s.toJson()],
  };

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
    id: j['id'] as String,
    name: j['name'] as String,
    steps: [for (final s in j['steps'] as List) RoutineStep.fromJson(s as Map<String, dynamic>)],
  );

  static const beginner = Routine(
    id: 'beginner',
    name: 'Beginner',
    builtIn: true,
    steps: [
      RoutineStep(Exercise.squat, 10),
      RoutineStep(Exercise.pushUp, 5),
      RoutineStep(Exercise.jumpingJack, 10),
      RoutineStep(Exercise.plank, 20),
    ],
  );

  static const moderate = Routine(
    id: 'moderate',
    name: 'Moderate',
    builtIn: true,
    steps: [
      RoutineStep(Exercise.squat, 20),
      RoutineStep(Exercise.pushUp, 15),
      RoutineStep(Exercise.lunge, 20),
      RoutineStep(Exercise.plank, 40),
    ],
  );

  static const advanced = Routine(
    id: 'advanced',
    name: 'Advanced',
    builtIn: true,
    steps: [
      RoutineStep(Exercise.squat, 30),
      RoutineStep(Exercise.pushUp, 25),
      RoutineStep(Exercise.jumpingJack, 30),
      RoutineStep(Exercise.lunge, 20),
      RoutineStep(Exercise.plank, 60),
    ],
  );

  static const upperBody = Routine(
    id: 'upper',
    name: 'Upper body',
    builtIn: true,
    steps: [
      RoutineStep(Exercise.pushUp, 12),
      RoutineStep(Exercise.bicepCurl, 20),
      RoutineStep(Exercise.shoulderPress, 12),
      RoutineStep(Exercise.lateralRaise, 12),
      RoutineStep(Exercise.tricepDip, 12),
    ],
  );

  static const core = Routine(
    id: 'core',
    name: 'Core',
    builtIn: true,
    steps: [
      RoutineStep(Exercise.sitUp, 15),
      RoutineStep(Exercise.mountainClimber, 20),
      RoutineStep(Exercise.gluteBridge, 15),
      RoutineStep(Exercise.plank, 40),
    ],
  );

  static const cardio = Routine(
    id: 'cardio',
    name: 'Wake-up cardio',
    builtIn: true,
    steps: [
      RoutineStep(Exercise.jumpingJack, 30),
      RoutineStep(Exercise.highKnees, 30),
      RoutineStep(Exercise.burpee, 6),
    ],
  );

  static const presets = [beginner, moderate, advanced, upperBody, core, cardio];

  static Routine forLevel(FitnessLevel level) => switch (level) {
    FitnessLevel.beginner => beginner,
    FitnessLevel.moderate => moderate,
    FitnessLevel.advanced => advanced,
  };
}
