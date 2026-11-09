import 'package:fitalarm/features/alarm/domain/challenge.dart';
import 'package:fitalarm/features/profile/domain/user_profile.dart';
import 'package:fitalarm/features/workout/domain/exercise.dart';
import 'package:fitalarm/features/workout/domain/routine.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _p(int age, FitnessLevel level) => UserProfile.fromJson({
  'name': 'Asha',
  'gender': 'female',
  'age': age,
  'heightCm': 162,
  'weightKg': 64,
  'goal': 'maintain',
  'activity': 'light',
  'diet': 'veg',
  'level': level.name,
  'wake': 390,
  'sleep': 1380,
});

void main() {
  test('the wake-up workout suits the age', () {
    expect(Routine.forProfile(_p(25, FitnessLevel.advanced)), Routine.advanced);
    expect(Routine.forProfile(_p(25, FitnessLevel.beginner)), Routine.beginner);
    expect(Routine.forProfile(_p(50, FitnessLevel.advanced)), Routine.moderate);
    expect(Routine.forProfile(_p(16, FitnessLevel.advanced)), Routine.moderate);
    expect(Routine.forProfile(_p(50, FitnessLevel.beginner)), Routine.beginner);
    expect(Routine.forProfile(_p(62, FitnessLevel.advanced)), Routine.gentle);
    expect(Routine.forProfile(_p(75, FitnessLevel.beginner)), Routine.gentle);
  });

  test('the gentle routine has no jumping and no floor work', () {
    const hard = {
      Exercise.jumpingJack,
      Exercise.burpee,
      Exercise.highKnees,
      Exercise.plank,
      Exercise.sitUp,
      Exercise.mountainClimber,
      Exercise.pushUp,
    };
    expect(Routine.gentle.steps.where((s) => hard.contains(s.exercise)), isEmpty);
  });

  test('brain games are easier from 60', () {
    expect(challengeLevelForAge(30), ChallengeLevel.medium);
    expect(challengeLevelForAge(65), ChallengeLevel.easy);
  });
}
