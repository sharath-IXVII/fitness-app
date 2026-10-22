import 'package:fitalarm/features/training/domain/move.dart';
import 'package:fitalarm/features/training/domain/plans.dart';
import 'package:fitalarm/features/training/training_providers.dart';
import 'package:fitalarm/features/workout/domain/exercise.dart';
import 'package:fitalarm/features/workout/widgets/exercise_demo.dart';
import 'package:fitalarm/features/workout/widgets/move_demos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every move has its own animation, and every animation is well formed', () {
    final exercises = {for (final e in Exercise.values) e.name};
    for (final m in Moves.all) {
      expect(moveDemos.containsKey(m.demo) || exercises.contains(m.demo), isTrue, reason: m.id);
      expect(m.steps, hasLength(greaterThanOrEqualTo(3)), reason: m.id);
    }
    expect({for (final m in Moves.all) m.id}, hasLength(Moves.all.length), reason: 'ids are unique');
    // Frames are blended joint by joint, so all frames need the same joints.
    for (final id in [...moveDemos.keys, ...exercises]) {
      final frames = demoFor(id).frames;
      for (final f in frames) {
        expect(f.keys.toSet(), frames.first.keys.toSet(), reason: id);
      }
    }
  });

  test('every body part has three levels that get harder', () {
    for (final f in BodyFocus.values) {
      final b = focusWorkout(f, Level.beginner);
      final i = focusWorkout(f, Level.intermediate);
      final a = focusWorkout(f, Level.advanced);
      expect(b.items.length, lessThan(i.items.length), reason: f.name);
      expect(i.items.length, lessThan(a.items.length), reason: f.name);
      expect(b.minutes, inInclusiveRange(4, 15), reason: f.name);
      expect(a.minutes, lessThan(45), reason: f.name);
      expect(f.label, isNotEmpty);
    }
  });

  test('challenges rest every fourth day and grow over the month', () {
    for (final c in challenges) {
      expect(c.workoutFor(4, Level.beginner), isNull);
      expect(c.workoutFor(28, Level.beginner), isNull);
      final d1 = c.workoutFor(1, Level.beginner)!;
      final d29 = c.workoutFor(29, Level.beginner)!;
      int total(TrainingWorkout w) => w.items.fold(0, (a, i) => a + i.workSeconds);
      expect(total(d29), greaterThan(total(d1)), reason: c.id);
      expect(d1.challengeId, c.id);
      expect(d1.day, 1);
    }
  });

  test('item labels and challenge progress', () {
    expect(const WorkoutItem(Moves.squat, 12).label, '×12');
    expect(const WorkoutItem(Moves.plank, 30).label, '30s');
    expect(const WorkoutItem(Moves.sidePlank, 20).label, '20s each side');
    expect(const WorkoutItem(Moves.pushUp, 30, timed: true).label, '30s');

    const p = ChallengeProgress(level: Level.beginner, done: {1, 2, 4});
    expect(p.nextDay, 3);
    final round = ChallengeProgress.fromJson(p.toJson());
    expect(round.done, {1, 2, 4});
    expect(round.level, Level.beginner);
  });
}
