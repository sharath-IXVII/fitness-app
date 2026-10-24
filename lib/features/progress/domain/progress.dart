import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  /// XP needed to reach level [n]: 0, 100, 400, 900, 1600, … (100·(n−1)²).
  static int threshold(int n) => 100 * (n - 1) * (n - 1);

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
    13 || 14 || 15 => 'Champion',
    16 || 17 || 18 || 19 => 'Master',
    _ => 'Legend',
  };

  /// Every level from 1 to [upTo], for the "all levels" table.
  static List<Level> table({int upTo = 20}) => [for (var n = 1; n <= upTo; n++) Level(n, threshold(n))];
}

/// The kinds of achievement badge. Every kind comes in [badgeSets] sets of
/// growing difficulty (Set 1 is the Starter set): finishing all 12 badges of
/// a set pays a XP bonus and opens the next one. All sets ship with the app,
/// so new levels never need an update.
enum Achievement {
  firstWorkout(Icons.fitness_center_rounded),
  perfectDay(Icons.auto_awesome_rounded),
  streak7(Icons.local_fire_department_rounded),
  streak30(Icons.whatshot_rounded),
  streak100(Icons.military_tech_rounded),
  tenWorkouts(Icons.wb_twilight_rounded),
  hydrated(Icons.water_drop_rounded),
  tenK(Icons.directions_walk_rounded),
  marathon(Icons.route_rounded),
  proteinPro(Icons.egg_alt_rounded),
  mealLogger(Icons.restaurant_menu_rounded),
  perfectWeek(Icons.emoji_events_rounded);

  const Achievement(this.icon);

  final IconData icon;

  /// What each badge asks for in sets 1…5.
  static const _targets = {
    Achievement.firstWorkout: [1, 50, 150, 400, 1000], // workouts in total
    Achievement.perfectDay: [1, 10, 30, 75, 150], // perfect days in total
    Achievement.streak7: [7, 14, 21, 45, 90], // days of streak
    Achievement.streak30: [30, 60, 120, 200, 300],
    Achievement.streak100: [100, 150, 250, 365, 500],
    Achievement.tenWorkouts: [10, 100, 250, 600, 1500], // workouts in total
    Achievement.hydrated: [7, 14, 30, 60, 100], // days in a row
    Achievement.tenK: [10000, 12000, 15000, 20000, 30000], // steps in one day
    Achievement.marathon: [250000, 350000, 450000, 600000, 800000], // steps in 30 days
    Achievement.proteinPro: [5, 10, 21, 45, 90], // days in a row
    Achievement.mealLogger: [7, 14, 30, 60, 120], // days in a row
    Achievement.perfectWeek: [7, 10, 14, 21, 30], // perfect days in a row
  };

  int target(int set) => _targets[this]![set - 1];

  /// Title and description of this badge in [set].
  ({String title, String description}) info(int set) {
    final n = target(set);
    final f = NumberFormat.decimalPattern();
    return switch (this) {
      firstWorkout =>
        n == 1
            ? (title: 'First rep', description: 'Finish your first workout')
            : (title: '$n workouts', description: 'Finish $n workouts in total'),
      tenWorkouts =>
        set == 1
            ? (title: 'Up and moving', description: 'Finish 10 workouts')
            : (title: '$n workouts', description: 'Finish $n workouts in total'),
      perfectDay =>
        n == 1
            ? (title: 'Perfect day', description: 'Complete all five goals in one day')
            : (title: '$n perfect days', description: 'Complete all five goals on $n days'),
      streak7 =>
        set == 1
            ? (title: 'One week', description: 'Keep a 7-day streak')
            : (title: '$n-day streak', description: 'Keep a $n-day streak'),
      streak30 =>
        set == 1
            ? (title: 'One month', description: 'Keep a 30-day streak')
            : (title: '$n-day streak', description: 'Keep a $n-day streak'),
      streak100 =>
        set == 1
            ? (title: 'Hundred', description: 'Keep a 100-day streak')
            : (title: '$n-day streak', description: 'Keep a $n-day streak'),
      hydrated =>
        set == 1
            ? (title: 'Hydrated', description: 'Hit your water goal 7 days in a row')
            : (title: 'Hydrated ×$n', description: 'Hit your water goal $n days in a row'),
      tenK =>
        set == 1
            ? (title: '10K club', description: 'Walk 10,000 verified steps in a day')
            : (title: '${n ~/ 1000}K club', description: 'Walk ${f.format(n)} verified steps in a day'),
      marathon =>
        set == 1
            ? (title: 'Marathon month', description: 'Walk 250,000 steps in 30 days')
            : (title: '${f.format(n ~/ 1000)}K month', description: 'Walk ${f.format(n)} steps in 30 days'),
      proteinPro =>
        set == 1
            ? (title: 'Protein pro', description: 'Hit your protein goal 5 days in a row')
            : (title: 'Protein pro ×$n', description: 'Hit your protein goal $n days in a row'),
      mealLogger =>
        set == 1
            ? (title: 'Food diary', description: 'Log 3+ meals a day for 7 days')
            : (title: 'Food diary ×$n', description: 'Log 3+ meals a day for $n days'),
      perfectWeek =>
        set == 1
            ? (title: 'Perfect week', description: 'Seven perfect days in a row')
            : (title: '$n perfect days in a row', description: 'Complete all five goals $n days in a row'),
    };
  }
}

/// One badge: a kind in a set. Records compare by value, so this works as a
/// map key.
typedef BadgeKey = ({Achievement kind, int set});

/// Stable text id, used to store and sync badges.
String badgeId(BadgeKey k) => '${k.kind.name}:${k.set}';

BadgeKey? parseBadgeId(String id) {
  final parts = id.split(':');
  if (parts.length != 2) return null;
  final kind = Achievement.values.where((a) => a.name == parts[0]).firstOrNull;
  final set = int.tryParse(parts[1]);
  if (kind == null || set == null || set < 1 || set > badgeSets) return null;
  return (kind: kind, set: set);
}

const badgeSets = 5;
const badgeSetNames = ['Starter', 'Mover', 'Regular', 'Committed', 'Elite'];

/// XP paid for finishing every badge in a set (sets 1…5).
const badgeSetBonusXp = [100, 250, 500, 1000, 2000];

/// How many sets, counted from Set 1, have all 12 badges earned.
int completedSets(Iterable<BadgeKey> earned) {
  final have = earned.toSet();
  var n = 0;
  while (n < badgeSets && Achievement.values.every((a) => have.contains((kind: a, set: n + 1)))) {
    n++;
  }
  return n;
}

/// XP from finished badge sets.
int setBonusXp(int completed) => badgeSetBonusXp.take(completed).fold(0, (a, b) => a + b);

/// For each badge, the first day it was earned (or absent), across all sets.
Map<BadgeKey, DateTime> earnedAchievements(Map<DateTime, DailyLog> logs, HealthTargets t) {
  final days = logs.keys.toList()..sort();
  final earned = <BadgeKey, DateTime>{};
  void earn(Achievement kind, int set, DateTime d) => earned.putIfAbsent((kind: kind, set: set), () => d);
  void check(Achievement kind, num value, DateTime d) {
    for (var set = 1; set <= badgeSets; set++) {
      if (value >= kind.target(set)) earn(kind, set, d);
    }
  }

  final runs = <Achievement, int>{};
  int bump(Achievement b, bool hit, DateTime d, DateTime? prev) {
    final consecutive = prev != null && daysBetween(prev, d) == 1;
    final run = hit ? ((consecutive ? runs[b] ?? 0 : 0) + 1) : 0;
    runs[b] = run;
    return run;
  }

  var workouts = 0, perfectDays = 0;
  DateTime? prev;
  for (final d in days) {
    final log = logs[d]!;
    final s = DayScore.of(log, t);
    if (log.workoutDone) workouts++;
    if (s.count == DayScore.total) perfectDays++;
    check(Achievement.firstWorkout, workouts, d);
    check(Achievement.tenWorkouts, workouts, d);
    check(Achievement.perfectDay, perfectDays, d);
    check(Achievement.tenK, log.steps, d);

    final streak = bump(Achievement.streak7, s.keepsStreak, d, prev);
    check(Achievement.streak7, streak, d);
    check(Achievement.streak30, streak, d);
    check(Achievement.streak100, streak, d);
    check(Achievement.hydrated, bump(Achievement.hydrated, log.waterMl >= t.waterMl, d, prev), d);
    check(Achievement.proteinPro, bump(Achievement.proteinPro, log.proteinG >= t.proteinG, d, prev), d);
    check(Achievement.mealLogger, bump(Achievement.mealLogger, log.mealsLogged >= 3, d, prev), d);
    check(Achievement.perfectWeek, bump(Achievement.perfectWeek, s.count == DayScore.total, d, prev), d);

    final windowStart = addDays(d, -29);
    final month = days.where((x) => !x.isBefore(windowStart) && !x.isAfter(d)).fold(0, (a, x) => a + logs[x]!.steps);
    check(Achievement.marathon, month, d);
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
