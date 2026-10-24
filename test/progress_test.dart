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
      expect([for (var n = 1; n <= 5; n++) Level.threshold(n)], [0, 100, 400, 900, 1600]);
      expect(Level.of(0).number, 1);
      expect(Level.of(99).number, 1);
      expect(Level.of(100).number, 2);
      expect(Level.of(250).number, 2);
      expect(Level.of(250).progress, closeTo(0.5, 1e-9));
      expect(Level.of(250).toNext, 150);
      expect(Level.of(400).number, 3);
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
    expect(a[(kind: Achievement.firstWorkout, set: 1)], day(0));
    expect(a[(kind: Achievement.perfectDay, set: 1)], day(0));
    expect(a[(kind: Achievement.tenK, set: 1)], day(0));
    expect(a[(kind: Achievement.proteinPro, set: 1)], day(4));
    expect(a[(kind: Achievement.streak7, set: 1)], day(6));
    expect(a[(kind: Achievement.hydrated, set: 1)], day(6));
    expect(a[(kind: Achievement.perfectWeek, set: 1)], day(6));
    expect(a.containsKey((kind: Achievement.streak30, set: 1)), isFalse);
    expect(a.containsKey((kind: Achievement.tenWorkouts, set: 1)), isFalse);
  });

  test('a gap breaks runs', () {
    final logs = {
      for (var i = 0; i < 4; i++) day(i): perfect(day(i)),
      for (var i = 5; i < 8; i++) day(i): perfect(day(i)),
    };
    expect(earnedAchievements(logs, t).containsKey((kind: Achievement.streak7, set: 1)), isFalse);
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

  test('later badge sets are harder and earned on their own days', () {
    final logs = {for (var i = 0; i < 15; i++) day(i): perfect(day(i))};
    final a = earnedAchievements(logs, t);
    expect(a[(kind: Achievement.streak7, set: 1)], day(6));
    expect(a[(kind: Achievement.streak7, set: 2)], day(13)); // 14-day streak
    expect(a.containsKey((kind: Achievement.streak7, set: 3)), isFalse); // needs 21
    expect(a[(kind: Achievement.perfectDay, set: 2)], day(9)); // 10 perfect days
  });

  test('finishing all 12 badges of a set pays XP and opens the next set', () {
    BadgeKey k(Achievement a, int set) => (kind: a, set: set);
    final set1 = [for (final a in Achievement.values) k(a, 1)];
    expect(completedSets(set1.take(11)), 0);
    expect(completedSets(set1), 1);
    expect(setBonusXp(1), 100);
    // Set 2 counts only after set 1 is done.
    final set2 = [for (final a in Achievement.values) k(a, 2)];
    expect(completedSets(set2), 0);
    expect(completedSets([...set1, ...set2]), 2);
    expect(setBonusXp(2), 100 + 250);
    expect(setBonusXp(badgeSets), 100 + 250 + 500 + 1000 + 2000);
  });

  test('every badge in every set has a title and description', () {
    for (final a in Achievement.values) {
      for (var set = 1; set <= badgeSets; set++) {
        final i = a.info(set);
        expect(i.title, isNotEmpty);
        expect(i.description, isNotEmpty);
        if (set > 1) expect(a.target(set), greaterThan(a.target(set - 1)));
      }
    }
    expect(parseBadgeId(badgeId((kind: Achievement.tenK, set: 3))), (kind: Achievement.tenK, set: 3));
    expect(parseBadgeId('nonsense'), isNull);
  });
}
