import '../../arcs/domain/arc.dart';
import '../../streaks/domain/daily_log.dart';

/// An Arc in numbers, for the end-of-season "Wrapped" story.
class ArcWrapped {
  const ArcWrapped({
    required this.period,
    required this.activeDays,
    required this.perfectDays,
    required this.workouts,
    required this.steps,
    required this.waterMl,
    required this.meals,
    required this.topFoods,
    required this.bestStreak,
    required this.bestDay,
    this.tier,
  });

  /// Works out the numbers from the day logs and meal names in [period].
  factory ArcWrapped.of(
    ArcPeriod period,
    Map<DateTime, DailyLog> logs,
    Map<DateTime, DayScore> scores, {
    Map<DateTime, List<String>> mealNames = const {},
    ArcTier? tier,
  }) {
    final inArc = {
      for (final e in logs.entries)
        if (period.contains(e.key)) e.key: e.value,
    };
    final arcScores = {
      for (final e in scores.entries)
        if (period.contains(e.key)) e.key: e.value,
    };
    final counts = <String, int>{};
    for (final e in mealNames.entries) {
      if (!period.contains(e.key)) continue;
      for (final n in e.value) {
        counts[n] = (counts[n] ?? 0) + 1;
      }
    }
    final top = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    DateTime? bestDay;
    var bestSteps = 0;
    for (final l in inArc.values) {
      if (l.steps > bestSteps) {
        bestSteps = l.steps;
        bestDay = l.date;
      }
    }
    return ArcWrapped(
      period: period,
      activeDays: arcScores.values.where((s) => s.count > 0).length,
      perfectDays: arcScores.values.where((s) => s.count == DayScore.total).length,
      workouts: inArc.values.where((l) => l.workoutDone).length,
      steps: inArc.values.fold(0, (a, l) => a + l.steps),
      waterMl: inArc.values.fold(0, (a, l) => a + l.waterMl),
      meals: inArc.values.fold(0, (a, l) => a + l.mealsLogged),
      topFoods: [for (final e in top.take(3)) e.key],
      bestStreak: longestStreak(arcScores),
      bestDay: bestDay == null ? null : (bestDay, bestSteps),
      tier: tier,
    );
  }

  final ArcPeriod period;
  final int activeDays;
  final int perfectDays;
  final int workouts;
  final int steps;
  final int waterMl;
  final int meals;
  final List<String> topFoods;
  final int bestStreak;

  /// The day with the most steps, and how many.
  final (DateTime, int)? bestDay;

  /// The badge earned, once the Arc is over.
  final ArcTier? tier;

  /// Steps as a distance, roughly (0.75 m a step).
  double get km => steps * 0.75 / 1000;

  bool get isEmpty => activeDays == 0;
}
