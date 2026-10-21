import 'package:fitalarm/features/profile/domain/health_targets.dart';
import 'package:fitalarm/features/profile/domain/user_profile.dart';
import 'package:fitalarm/features/streaks/domain/daily_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final targets = HealthTargets.from(
    const UserProfile(
      name: 'T',
      gender: Gender.male,
      age: 25,
      heightCm: 175,
      weightKg: 70,
      goal: FitnessGoal.maintain,
      activity: ActivityLevel.sedentary,
      diet: DietType.veg,
      level: FitnessLevel.beginner,
      wakeTime: TimeOfDay(hour: 6, minute: 0),
      sleepTime: TimeOfDay(hour: 22, minute: 0),
    ),
  );
  final day = DateTime(2026, 10, 21);

  test('score levels get lighter as tasks are missed', () {
    final empty = DayScore.of(DailyLog(date: day), targets);
    expect(empty.level, 0);

    final perfect = DayScore.of(
      DailyLog(
        date: day,
        workoutDone: true,
        waterMl: targets.waterMl,
        steps: targets.steps,
        mealsLogged: 3,
        proteinG: targets.proteinG,
      ),
      targets,
    );
    expect(perfect.count, 5);
    expect(perfect.level, 4);

    final three = DayScore.of(DailyLog(date: day, workoutDone: true, waterMl: 9999, mealsLogged: 3), targets);
    expect(three.level, 2);
    expect(three.keepsStreak, isTrue);

    final one = DayScore.of(DailyLog(date: day, workoutDone: true), targets);
    expect(one.level, 1);
    expect(one.keepsStreak, isFalse);
  });

  const good = DayScore({DailyTask.workout, DailyTask.water, DailyTask.diet});
  const weak = DayScore({DailyTask.workout});

  test('current streak counts back from today, tolerating an unfinished today', () {
    final scores = {
      day.subtract(const Duration(days: 3)): good,
      day.subtract(const Duration(days: 2)): good,
      day.subtract(const Duration(days: 1)): good,
      day: weak,
    };
    expect(currentStreak(scores, day), 3);
    expect(currentStreak({...scores, day: good}, day), 4);
  });

  test('a missed day breaks the streak', () {
    final scores = {
      day.subtract(const Duration(days: 3)): good,
      day.subtract(const Duration(days: 1)): good,
      day: good,
    };
    expect(currentStreak(scores, day), 2);
    expect(longestStreak(scores), 2);
  });
}
