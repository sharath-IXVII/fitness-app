import 'dart:convert';

import 'package:fitalarm/core/storage.dart';
import 'package:fitalarm/features/profile/domain/health_targets.dart';
import 'package:fitalarm/features/profile/domain/user_profile.dart';
import 'package:fitalarm/features/streaks/daily_log_providers.dart';
import 'package:fitalarm/features/streaks/domain/daily_log.dart';
import 'package:fitalarm/features/streaks/streak_reminder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final today = DateTime(2026, 11, 15);

  group('streak reminder text', () {
    test('quiet once three goals are done today', () {
      expect(streakReminderText(day: today, today: today, doneToday: 3, streak: 4), isNull);
      expect(streakReminderText(day: today, today: today, doneToday: 5, streak: 0), isNull);
    });

    test('says how long the streak is and how many goals are left', () {
      final (title, body) = streakReminderText(day: today, today: today, doneToday: 1, streak: 12)!;
      expect(title, contains('12-day streak'));
      expect(body, contains('2 more goals keep'));
      final (_, one) = streakReminderText(day: today, today: today, doneToday: 2, streak: 12)!;
      expect(one, contains('1 more goal keeps'));
    });

    test('with no streak yet, it invites one instead of warning', () {
      final (title, _) = streakReminderText(day: today, today: today, doneToday: 0, streak: 0)!;
      expect(title, contains('Start a streak'));
    });

    test('later days get a plain nudge, since their score is not known yet', () {
      final (title, body) = streakReminderText(day: addDays(today, 1), today: today, doneToday: 5, streak: 9)!;
      expect(title, isNot(contains('9')));
      expect(body, contains('3 of your 5 goals'));
    });
  });

  group('closest goal', () {
    test('picks the unfinished goal that is nearest to done', () {
      final log = DailyLog(date: today, waterMl: targets.waterMl - 300, steps: 1000, mealsLogged: 1);
      final next = closestGoal(log, targets)!;
      expect(next.task, DailyTask.water);
      expect(next.left, '300 ml of water');
    });

    test('with nothing started, a workout is the suggestion', () {
      expect(closestGoal(DailyLog(date: today), targets)!.task, DailyTask.workout);
    });

    test('finished goals are never suggested, and a perfect day has none', () {
      final most = DailyLog(
        date: today,
        workoutDone: true,
        waterMl: targets.waterMl,
        steps: targets.steps,
        mealsLogged: 2,
        proteinG: targets.proteinG,
      );
      final next = closestGoal(most, targets)!;
      expect(next.task, DailyTask.diet);
      expect(next.left, '1 meal to log');
      expect(closestGoal(most.copyWith(mealsLogged: 3), targets), isNull);
    });
  });

  test('quick taps on "+250 ml" all count, one after another', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    final logs = c.read(dailyLogsProvider.notifier);
    // Not awaited one by one: this is four taps in a row.
    await Future.wait([for (var i = 0; i < 4; i++) logs.addWater(250)]);
    expect(logs.today().waterMl, 1000);
    final stored = prefs.getKeys().firstWhere((k) => k.startsWith('log.v1.'));
    expect((jsonDecode(prefs.getString(stored)!) as Map)['water'], 1000);
  });
}
