import 'move.dart';

enum Level {
  beginner('Beginner', 1.0, 1, 20),
  intermediate('Intermediate', 1.35, 2, 20),
  advanced('Advanced', 1.7, 3, 15);

  const Level(this.label, this.multiplier, this.rounds, this.restSec);

  final String label;

  /// Scales reps and seconds.
  final double multiplier;
  final int rounds;
  final int restSec;
}

/// One exercise in a workout: reps, or seconds when [timed].
class WorkoutItem {
  // Named parameters can't be private, so no initializing formal here.
  // ignore: prefer_initializing_formals
  const WorkoutItem(this.move, this.target, {bool? timed}) : _timed = timed;

  final Move move;
  final int target;
  final bool? _timed;

  /// Counted in seconds; a rep move can be done "for 30 seconds" instead.
  bool get timed => _timed ?? move.timed;

  /// "×12", "30s", "×10 each side".
  String get label {
    final base = timed ? '${target}s' : '×$target';
    return move.perSide ? '$base each side' : base;
  }

  /// Rough seconds of work, both sides included.
  int get workSeconds => (timed ? target : target * move.secondsPerRep) * (move.perSide ? 2 : 1);
}

class TrainingWorkout {
  const TrainingWorkout({
    required this.id,
    required this.title,
    required this.items,
    this.subtitle = '',
    this.restSec = 20,
    this.met = 5,
    this.challengeId,
    this.day,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<WorkoutItem> items;

  /// Rest after each exercise.
  final int restSec;

  /// Effort level for calorie estimates (MET).
  final double met;

  /// Set when this is a day of a 30-day challenge.
  final String? challengeId;
  final int? day;

  int get estimatedSeconds => items.fold(0, (a, i) => a + i.workSeconds) + restSec * (items.length - 1) + 10;

  int get minutes => (estimatedSeconds / 60).ceil();

  /// Calories for [seconds] of this workout at [weightKg].
  int kcal(double weightKg, int seconds) => (met * 3.5 * weightKg / 200 * seconds / 60).round();

  /// Equipment needed, without repeats.
  List<String> get equipment => {for (final i in items) ?i.move.equipment}.toList();
}

int _scale(int base, double m) => (base * m / (base >= 20 ? 5 : 1)).round() * (base >= 20 ? 5 : 1);

/// A short warm-up and cool-down around every focus workout.
const _warmUp = [WorkoutItem(Moves.jumpingJack, 30), WorkoutItem(Moves.armCircles, 20)];

List<WorkoutItem> _coolDown(BodyFocus f) => switch (f) {
  BodyFocus.abs || BodyFocus.back => const [WorkoutItem(Moves.cobra, 30), WorkoutItem(Moves.childPose, 30)],
  BodyFocus.legs ||
  BodyFocus.glutes => const [WorkoutItem(Moves.quadStretch, 20), WorkoutItem(Moves.hamstringStretch, 30)],
  BodyFocus.fullBody => const [WorkoutItem(Moves.hamstringStretch, 30), WorkoutItem(Moves.childPose, 30)],
  _ => const [WorkoutItem(Moves.childPose, 30)],
};

/// The core moves for each focus with beginner targets, easiest first.
/// Beginners do the first six; harder levels add the rest and more rounds.
const Map<BodyFocus, List<WorkoutItem>> focusMoves = {
  BodyFocus.abs: [
    WorkoutItem(Moves.crunch, 12),
    WorkoutItem(Moves.heelTouch, 16),
    WorkoutItem(Moves.reverseCrunch, 10),
    WorkoutItem(Moves.plank, 20),
    WorkoutItem(Moves.bicycleCrunch, 16),
    WorkoutItem(Moves.mountainClimber, 20),
    WorkoutItem(Moves.legRaise, 10),
    WorkoutItem(Moves.russianTwist, 16),
    WorkoutItem(Moves.sidePlank, 15),
    WorkoutItem(Moves.vUp, 8),
  ],
  BodyFocus.chest: [
    WorkoutItem(Moves.inclinePushUp, 10),
    WorkoutItem(Moves.kneePushUp, 8),
    WorkoutItem(Moves.pushUp, 5),
    WorkoutItem(Moves.widePushUp, 5),
    WorkoutItem(Moves.shoulderTap, 12),
    WorkoutItem(Moves.diamondPushUp, 4),
    WorkoutItem(Moves.hinduPushUp, 5),
    WorkoutItem(Moves.declinePushUp, 5),
  ],
  BodyFocus.biceps: [
    WorkoutItem(Moves.bicepCurl, 12),
    WorkoutItem(Moves.hammerCurl, 12),
    WorkoutItem(Moves.towelCurl, 8),
    WorkoutItem(Moves.doorwayRow, 10),
    WorkoutItem(Moves.concentrationCurl, 8),
    WorkoutItem(Moves.curlHold, 20),
    WorkoutItem(Moves.bicepCurl, 15),
    WorkoutItem(Moves.hammerCurl, 15),
  ],
  BodyFocus.triceps: [
    WorkoutItem(Moves.tricepDip, 8),
    WorkoutItem(Moves.overheadExtension, 10),
    WorkoutItem(Moves.closeKneePushUp, 8),
    WorkoutItem(Moves.tricepKickback, 12),
    WorkoutItem(Moves.plankUpDown, 6),
    WorkoutItem(Moves.diamondPushUp, 5),
    WorkoutItem(Moves.tricepDip, 12),
    WorkoutItem(Moves.overheadExtension, 12),
  ],
  BodyFocus.shoulders: [
    WorkoutItem(Moves.armCircles, 30),
    WorkoutItem(Moves.lateralRaise, 12),
    WorkoutItem(Moves.frontRaise, 12),
    WorkoutItem(Moves.shoulderPress, 10),
    WorkoutItem(Moves.yRaise, 10),
    WorkoutItem(Moves.shoulderTap, 12),
    WorkoutItem(Moves.pikePushUp, 6),
    WorkoutItem(Moves.punches, 30),
    WorkoutItem(Moves.hinduPushUp, 5),
  ],
  BodyFocus.back: [
    WorkoutItem(Moves.superman, 10),
    WorkoutItem(Moves.birdDog, 12),
    WorkoutItem(Moves.snowAngel, 10),
    WorkoutItem(Moves.yRaise, 10),
    WorkoutItem(Moves.doorwayRow, 10),
    WorkoutItem(Moves.catCow, 30),
    WorkoutItem(Moves.superman, 15),
    WorkoutItem(Moves.plank, 30),
  ],
  BodyFocus.legs: [
    WorkoutItem(Moves.squat, 12),
    WorkoutItem(Moves.lunge, 12),
    WorkoutItem(Moves.calfRaise, 15),
    WorkoutItem(Moves.sideLunge, 10),
    WorkoutItem(Moves.sumoSquat, 12),
    WorkoutItem(Moves.wallSit, 30),
    WorkoutItem(Moves.jumpSquat, 10),
    WorkoutItem(Moves.reverseLunge, 12),
  ],
  BodyFocus.glutes: [
    WorkoutItem(Moves.gluteBridge, 15),
    WorkoutItem(Moves.donkeyKick, 10),
    WorkoutItem(Moves.sumoSquat, 12),
    WorkoutItem(Moves.gluteKickback, 10),
    WorkoutItem(Moves.reverseLunge, 12),
    WorkoutItem(Moves.singleLegBridge, 8),
    WorkoutItem(Moves.skater, 30),
    WorkoutItem(Moves.squat, 15),
  ],
  BodyFocus.fullBody: [
    WorkoutItem(Moves.jumpingJack, 30),
    WorkoutItem(Moves.squat, 12),
    WorkoutItem(Moves.kneePushUp, 8),
    WorkoutItem(Moves.mountainClimber, 20),
    WorkoutItem(Moves.lunge, 12),
    WorkoutItem(Moves.plank, 20),
    WorkoutItem(Moves.burpee, 6),
    WorkoutItem(Moves.highKnees, 30),
    WorkoutItem(Moves.inchworm, 5),
    WorkoutItem(Moves.jumpSquat, 10),
  ],
};

/// The workout for [focus] at [level].
TrainingWorkout focusWorkout(BodyFocus focus, Level level) {
  final pool = focusMoves[focus]!;
  final core = level == Level.beginner ? pool.take(6) : pool;
  final rounds = [
    for (var r = 0; r < level.rounds; r++)
      for (final i in core) WorkoutItem(i.move, _scale(i.target, level.multiplier), timed: i.timed),
  ];
  return TrainingWorkout(
    id: '${focus.name}-${level.name}',
    title: '${focus.label} · ${level.label}',
    subtitle: focus.blurb,
    items: [..._warmUp, ...rounds, ..._coolDown(focus)],
    restSec: level.restSec,
    met: focus == BodyFocus.fullBody ? 7 : 5,
  );
}

/// Short sessions for any day.
final quickWorkouts = <TrainingWorkout>[
  const TrainingWorkout(
    id: 'morning-warmup',
    title: 'Morning warm-up',
    subtitle: 'Wake your body up gently',
    restSec: 8,
    met: 3.5,
    items: [
      WorkoutItem(Moves.march, 40),
      WorkoutItem(Moves.armCircles, 30),
      WorkoutItem(Moves.catCow, 30),
      WorkoutItem(Moves.toeTouch, 8),
      WorkoutItem(Moves.squat, 10),
      WorkoutItem(Moves.inchworm, 4),
      WorkoutItem(Moves.jumpingJack, 30),
      WorkoutItem(Moves.hamstringStretch, 30),
    ],
  ),
  const TrainingWorkout(
    id: 'seven-minute',
    title: '7-minute workout',
    subtitle: 'The classic: 12 moves, 30 seconds each',
    restSec: 10,
    met: 8,
    items: [
      WorkoutItem(Moves.jumpingJack, 30),
      WorkoutItem(Moves.wallSit, 30),
      WorkoutItem(Moves.pushUp, 30, timed: true),
      WorkoutItem(Moves.crunch, 30, timed: true),
      WorkoutItem(Moves.reverseLunge, 30, timed: true),
      WorkoutItem(Moves.squat, 30, timed: true),
      WorkoutItem(Moves.tricepDip, 30, timed: true),
      WorkoutItem(Moves.plank, 30),
      WorkoutItem(Moves.highKnees, 30),
      WorkoutItem(Moves.lunge, 30, timed: true),
      WorkoutItem(Moves.shoulderTap, 30, timed: true),
      WorkoutItem(Moves.sidePlank, 15),
    ],
  ),
  TrainingWorkout(
    id: 'fat-burn',
    title: 'Fat-burn HIIT',
    subtitle: 'Fast cardio, no equipment',
    restSec: 15,
    met: 8,
    items: [
      for (var r = 0; r < 2; r++) ...const [
        WorkoutItem(Moves.jumpingJack, 30),
        WorkoutItem(Moves.highKnees, 30),
        WorkoutItem(Moves.burpee, 30, timed: true),
        WorkoutItem(Moves.mountainClimber, 30),
        WorkoutItem(Moves.skater, 30),
        WorkoutItem(Moves.punches, 30),
        WorkoutItem(Moves.jumpSquat, 30, timed: true),
        WorkoutItem(Moves.buttKicks, 30),
      ],
    ],
  ),
  const TrainingWorkout(
    id: 'cool-down',
    title: 'Stretch & cool-down',
    subtitle: 'Relax after a workout or before bed',
    restSec: 5,
    met: 2.5,
    items: [
      WorkoutItem(Moves.childPose, 40),
      WorkoutItem(Moves.catCow, 30),
      WorkoutItem(Moves.cobra, 30),
      WorkoutItem(Moves.hamstringStretch, 40),
      WorkoutItem(Moves.quadStretch, 30),
      WorkoutItem(Moves.lungeStretch, 30),
      WorkoutItem(Moves.childPose, 30),
    ],
  ),
];

TrainingWorkout? quickWorkoutById(String id) => quickWorkouts.where((w) => w.id == id).firstOrNull;

/// A 30-day plan: workouts that get a little harder each day, with a rest
/// day every fourth day.
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.blurb,
    required this.demo,
    required this.pool,
    this.met = 6,
  });

  final String id;
  final String title;
  final String blurb;

  /// Move animated on the challenge card.
  final String demo;

  /// Moves with day-1 beginner targets.
  final List<WorkoutItem> pool;
  final double met;

  static const days = 30;
  static const perDay = 7;

  static bool isRestDay(int day) => day % 4 == 0;

  /// The workout for [day] (1–30); null on rest days.
  TrainingWorkout? workoutFor(int day, Level level) {
    if (isRestDay(day)) return null;
    // Rotate through the pool so days differ, and build up over the month.
    final start = (day * 3) % pool.length;
    final picked = [for (var i = 0; i < perDay; i++) pool[(start + i) % pool.length]];
    final growth = 1 + 0.8 * (day - 1) / (days - 1);
    final rounds = level == Level.beginner ? 1 : 2;
    return TrainingWorkout(
      id: '$id-day$day',
      title: '$title · Day $day',
      subtitle: level.label,
      challengeId: id,
      day: day,
      restSec: level.restSec,
      met: met,
      items: [
        ..._warmUp,
        for (var r = 0; r < rounds; r++)
          for (final i in picked) WorkoutItem(i.move, _scale(i.target, level.multiplier * growth), timed: i.timed),
        const WorkoutItem(Moves.childPose, 30),
      ],
    );
  }
}

const challenges = [
  Challenge(
    id: 'fullbody30',
    title: 'Full body 30 days',
    blurb: 'Lose fat and get fit all over',
    demo: 'burpee',
    met: 7,
    pool: [
      WorkoutItem(Moves.squat, 12),
      WorkoutItem(Moves.kneePushUp, 8),
      WorkoutItem(Moves.mountainClimber, 20),
      WorkoutItem(Moves.lunge, 10),
      WorkoutItem(Moves.plank, 20),
      WorkoutItem(Moves.highKnees, 20),
      WorkoutItem(Moves.gluteBridge, 12),
      WorkoutItem(Moves.burpee, 5),
      WorkoutItem(Moves.crunch, 12),
      WorkoutItem(Moves.superman, 10),
      WorkoutItem(Moves.jumpSquat, 8),
      WorkoutItem(Moves.pushUp, 5),
    ],
  ),
  Challenge(
    id: 'abs30',
    title: 'Abs in 30 days',
    blurb: 'A flatter, stronger core',
    demo: 'bicycleCrunch',
    met: 5,
    pool: [
      WorkoutItem(Moves.crunch, 12),
      WorkoutItem(Moves.heelTouch, 16),
      WorkoutItem(Moves.plank, 20),
      WorkoutItem(Moves.bicycleCrunch, 14),
      WorkoutItem(Moves.legRaise, 8),
      WorkoutItem(Moves.mountainClimber, 20),
      WorkoutItem(Moves.russianTwist, 14),
      WorkoutItem(Moves.reverseCrunch, 10),
      WorkoutItem(Moves.flutterKick, 20),
      WorkoutItem(Moves.sidePlank, 15),
      WorkoutItem(Moves.vUp, 6),
    ],
  ),
  Challenge(
    id: 'arms30',
    title: 'Arms & shoulders 30 days',
    blurb: 'Biceps, triceps and shoulders',
    demo: 'bicepCurl',
    met: 5,
    pool: [
      WorkoutItem(Moves.bicepCurl, 12),
      WorkoutItem(Moves.tricepDip, 8),
      WorkoutItem(Moves.lateralRaise, 10),
      WorkoutItem(Moves.kneePushUp, 8),
      WorkoutItem(Moves.hammerCurl, 12),
      WorkoutItem(Moves.overheadExtension, 10),
      WorkoutItem(Moves.shoulderPress, 10),
      WorkoutItem(Moves.armCircles, 30),
      WorkoutItem(Moves.tricepKickback, 10),
      WorkoutItem(Moves.pikePushUp, 5),
      WorkoutItem(Moves.doorwayRow, 10),
    ],
  ),
  Challenge(
    id: 'legs30',
    title: 'Legs & glutes 30 days',
    blurb: 'Stronger legs, lifted glutes',
    demo: 'lunge',
    met: 6,
    pool: [
      WorkoutItem(Moves.squat, 12),
      WorkoutItem(Moves.gluteBridge, 12),
      WorkoutItem(Moves.lunge, 10),
      WorkoutItem(Moves.donkeyKick, 10),
      WorkoutItem(Moves.calfRaise, 15),
      WorkoutItem(Moves.sumoSquat, 12),
      WorkoutItem(Moves.wallSit, 20),
      WorkoutItem(Moves.sideLunge, 8),
      WorkoutItem(Moves.singleLegBridge, 8),
      WorkoutItem(Moves.jumpSquat, 8),
      WorkoutItem(Moves.skater, 20),
    ],
  ),
];

Challenge? challengeById(String id) => challenges.where((c) => c.id == id).firstOrNull;
