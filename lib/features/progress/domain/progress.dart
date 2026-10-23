import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../profile/domain/health_targets.dart';
import '../../streaks/domain/daily_log.dart';

/// XP is derived from history, never stored, so it can't drift or be lost.
///
/// Per day: 10 XP per pillar done, +20 for a perfect 5/5 day, and while a
/// streak is alive +1 XP per streak day (capped at +30).
int dayXp(DayScore s) => s.count * 10 + (s.count == DayScore.total ? 20 : 0);

int totalXp(Map<DateTime, DayScore> scores) {
  final days = scores.keys.toList()..sort();
  var xp = 0, run = 0;
  DateTime? prev;
  for (final d in days) {
    final s = scores[d]!;
    xp += dayXp(s);
    if (s.keepsStreak) {
      run = (prev != null && daysBetween(prev, d) == 1) ? run + 1 : 1;
      prev = d;
      xp += math.min(run, 30);
    }
  }
  return xp;
}

class Level {
  const Level(this.number, this.xp);

  final int number;
  final int xp;

  /// XP needed to reach level [n]: 0, 100, 300, 600, 1000, … (50·n·(n−1)).
  static int threshold(int n) => 50 * n * (n - 1);

  factory Level.of(int xp) {
    var n = 1;
    while (xp >= threshold(n + 1)) {
      n++;
    }
    return Level(n, xp);
  }

  int get floor => threshold(number);
  int get next => threshold(number + 1);
  double get progress => (xp - floor) / (next - floor);
  int get toNext => next - xp;

  String get title => switch (number) {
    1 => 'Starter',
    2 => 'Mover',
    3 => 'Regular',
    4 || 5 => 'Committed',
    6 || 7 => 'Disciplined',
    8 || 9 => 'Athlete',
    10 || 11 || 12 => 'Elite',
    _ => 'Legend',
  };
}

/// Achievement badges. Each is checked against the full history and
/// reports the first day it was earned.
enum Achievement {
  firstWorkout('First rep', 'Finish your first workout', Icons.fitness_center_rounded),
  perfectDay('Perfect day', 'Complete all five goals in one day', Icons.auto_awesome_rounded),
  streak7('One week', 'Keep a 7-day streak', Icons.local_fire_department_rounded),
  streak30('One month', 'Keep a 30-day streak', Icons.whatshot_rounded),
  streak100('Hundred', 'Keep a 100-day streak', Icons.military_tech_rounded),
  tenWorkouts('Up and moving', 'Finish 10 workouts', Icons.wb_twilight_rounded),
  hydrated('Hydrated', 'Hit your water goal 7 days in a row', Icons.water_drop_rounded),
  tenK('10K club', 'Walk 10,000 verified steps in a day', Icons.directions_walk_rounded),
  marathon('Marathon month', 'Walk 250,000 steps in 30 days', Icons.route_rounded),
  proteinPro('Protein pro', 'Hit your protein goal 5 days in a row', Icons.egg_alt_rounded),
  mealLogger('Food diary', 'Log 3+ meals a day for 7 days', Icons.restaurant_menu_rounded),
  perfectWeek('Perfect week', 'Seven perfect days in a row', Icons.emoji_events_rounded);

  const Achievement(this.title, this.description, this.icon);

  final String title;
  final String description;
  final IconData icon;
}

/// For each badge, the first day it was earned (or absent).
Map<Achievement, DateTime> earnedAchievements(Map<DateTime, DailyLog> logs, HealthTargets t) {
  final days = logs.keys.toList()..sort();
  final earned = <Achievement, DateTime>{};
  void earn(Achievement b, DateTime d) => earned.putIfAbsent(b, () => d);

  final runs = <Achievement, int>{};
  int bump(Achievement b, bool hit, DateTime d, DateTime? prev) {
    final consecutive = prev != null && daysBetween(prev, d) == 1;
    final run = hit ? ((consecutive ? runs[b] ?? 0 : 0) + 1) : 0;
    runs[b] = run;
    return run;
  }

  var workouts = 0;
  DateTime? prev;
  for (final d in days) {
    final log = logs[d]!;
    final s = DayScore.of(log, t);
    if (log.workoutDone) {
      workouts++;
      earn(Achievement.firstWorkout, d);
      if (workouts >= 10) earn(Achievement.tenWorkouts, d);
    }
    if (s.count == DayScore.total) earn(Achievement.perfectDay, d);
    if (log.steps >= 10000) earn(Achievement.tenK, d);

    final streak = bump(Achievement.streak7, s.keepsStreak, d, prev);
    if (streak >= 7) earn(Achievement.streak7, d);
    if (streak >= 30) earn(Achievement.streak30, d);
    if (streak >= 100) earn(Achievement.streak100, d);
    if (bump(Achievement.hydrated, log.waterMl >= t.waterMl, d, prev) >= 7) earn(Achievement.hydrated, d);
    if (bump(Achievement.proteinPro, log.proteinG >= t.proteinG, d, prev) >= 5) earn(Achievement.proteinPro, d);
    if (bump(Achievement.mealLogger, log.mealsLogged >= 3, d, prev) >= 7) earn(Achievement.mealLogger, d);
    if (bump(Achievement.perfectWeek, s.count == DayScore.total, d, prev) >= 7) earn(Achievement.perfectWeek, d);

    final windowStart = addDays(d, -29);
    final month = days.where((x) => !x.isBefore(windowStart) && !x.isAfter(d)).fold(0, (a, x) => a + logs[x]!.steps);
    if (month >= 250000) earn(Achievement.marathon, d);
    prev = d;
  }
  return earned;
}

/// Totals for a 7-day window ending on [end] (inclusive), compared with the
/// 7 days before it.
class WeekReport {
  const WeekReport({
    required this.start,
    required this.end,
    required this.days,
    required this.previous,
    required this.targets,
  });

  final DateTime start;
  final DateTime end;
  final List<DailyLog> days;
  final List<DailyLog> previous;
  final HealthTargets targets;

  factory WeekReport.of(Map<DateTime, DailyLog> logs, HealthTargets t, DateTime end) {
    final e = dayOnly(end);
    List<DailyLog> window(int fromDaysAgo) => [
      for (var i = fromDaysAgo + 6; i >= fromDaysAgo; i--)
        () {
          final d = DateTime(e.year, e.month, e.day - i);
          return logs[d] ?? DailyLog(date: d);
        }(),
    ];
    return WeekReport(
      start: DateTime(e.year, e.month, e.day - 6),
      end: e,
      days: window(0),
      previous: window(7),
      targets: t,
    );
  }

  static int _count(List<DailyLog> d, bool Function(DailyLog) f) => d.where(f).length;

  int get workouts => _count(days, (l) => l.workoutDone);
  int get prevWorkouts => _count(previous, (l) => l.workoutDone);
  int get steps => days.fold(0, (a, l) => a + l.steps);
  int get prevSteps => previous.fold(0, (a, l) => a + l.steps);
  int get waterMl => days.fold(0, (a, l) => a + l.waterMl);
  int get waterDays => _count(days, (l) => l.waterMl >= targets.waterMl);
  int get stepDays => _count(days, (l) => l.steps >= targets.steps);
  int get proteinDays => _count(days, (l) => l.proteinG >= targets.proteinG);
  int get mealDays => _count(days, (l) => l.mealsLogged >= 3);
  int get streakDays => _count(days, (l) => DayScore.of(l, targets).keepsStreak);
  int get prevStreakDays => _count(previous, (l) => DayScore.of(l, targets).keepsStreak);
  int get xp => days.fold(0, (a, l) => a + dayXp(DayScore.of(l, targets)));

  /// Completion of all pillars across the week, 0–1.
  double get completion => days.fold(0, (a, l) => a + DayScore.of(l, targets).count) / (7 * DayScore.total);

  DailyLog? get bestDay {
    final active = days.where((l) => DayScore.of(l, targets).count > 0).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => DayScore.of(b, targets).count.compareTo(DayScore.of(a, targets).count));
    return active.first;
  }

  /// The pillar hit least often this week, for a gentle suggestion.
  DailyTask get focus {
    final counts = {
      DailyTask.workout: workouts,
      DailyTask.water: waterDays,
      DailyTask.steps: stepDays,
      DailyTask.diet: mealDays,
      DailyTask.protein: proteinDays,
    };
    return counts.entries.reduce((a, b) => b.value < a.value ? b : a).key;
  }
}
