import 'package:fitalarm/features/profile/domain/health_targets.dart';
import 'package:fitalarm/features/profile/domain/user_profile.dart';
import 'package:fitalarm/features/progress/domain/progress.dart';
import 'package:fitalarm/features/streaks/domain/daily_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t = HealthTargets.from(
    const UserProfile(
      name: 'A',
      gender: Gender.male,
      age: 25,
      heightCm: 175,
      weightKg: 70,
      goal: FitnessGoal.maintain,
      activity: ActivityLevel.moderate,
      diet: DietType.veg,
      level: FitnessLevel.beginner,
      wakeTime: TimeOfDay(hour: 6, minute: 0),
      sleepTime: TimeOfDay(hour: 22, minute: 0),
    ),
  );
  final start = DateTime(2026, 1, 1);
  DateTime day(int i) => DateTime(start.year, start.month, start.day + i);
  DailyLog perfect(DateTime d) =>
      DailyLog(date: d, workoutDone: true, waterMl: t.waterMl, steps: 10000, mealsLogged: 3, proteinG: t.proteinG);
  DailyLog three(DateTime d) => DailyLog(date: d, workoutDone: true, waterMl: t.waterMl, steps: t.steps);

  group('levels', () {
    test('thresholds', () {
      expect([for (var n = 1; n <= 5; n++) Level.threshold(n)], [0, 100, 300, 600, 1000]);
      expect(Level.of(0).number, 1);
      expect(Level.of(99).number, 1);
      expect(Level.of(100).number, 2);
      expect(Level.of(450).number, 3);
      expect(Level.of(450).progress, closeTo(0.5, 1e-9));
      expect(Level.of(450).toNext, 150);
    });
  });

  test('xp counts pillars, perfect days and streak bonus', () {
    final scores = {
      day(0): DayScore.of(perfect(day(0)), t), // 50 + 20 + streak 1
      day(1): DayScore.of(three(day(1)), t), // 30 + streak 2
      day(3): DayScore.of(DailyLog(date: day(3), workoutDone: true), t), // 10, no streak
    };
    expect(totalXp(scores), 71 + 32 + 10);
  });

  test('achievements are earned on the right day', () {
    final logs = {for (var i = 0; i < 8; i++) day(i): perfect(day(i))};
    final a = earnedAchievements(logs, t);
    expect(a[Achievement.firstWorkout], day(0));
    expect(a[Achievement.perfectDay], day(0));
    expect(a[Achievement.tenK], day(0));
    expect(a[Achievement.proteinPro], day(4));
    expect(a[Achievement.streak7], day(6));
    expect(a[Achievement.hydrated], day(6));
    expect(a[Achievement.perfectWeek], day(6));
    expect(a.containsKey(Achievement.streak30), isFalse);
    expect(a.containsKey(Achievement.tenWorkouts), isFalse);
  });

  test('a gap breaks runs', () {
    final logs = {
      for (var i = 0; i < 4; i++) day(i): perfect(day(i)),
      for (var i = 5; i < 8; i++) day(i): perfect(day(i)),
    };
    expect(earnedAchievements(logs, t).containsKey(Achievement.streak7), isFalse);
  });

  test('weekly report compares with the week before', () {
    final logs = {
      for (var i = 0; i < 7; i++) day(i): three(day(i)),
      for (var i = 7; i < 14; i++) day(i): i.isEven ? perfect(day(i)) : DailyLog(date: day(i), steps: 3000),
    };
    final r = WeekReport.of(logs, t, day(13));
    expect(r.start, day(7));
    expect(r.workouts, 3);
    expect(r.prevWorkouts, 7);
    expect(r.streakDays, 3);
    expect(r.prevStreakDays, 7);
    expect(r.steps, 3 * 10000 + 4 * 3000);
    expect(r.bestDay!.date, day(8));
    expect(r.completion, closeTo(15 / 35, 1e-9));
  });
}
